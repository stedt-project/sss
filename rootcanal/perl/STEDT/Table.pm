package STEDT::Table;
use strict;

# by Dominic Yu
# 2008.04.21, 2009.10.14
# This is a base class to specify the fields, attributes, and behavior
# of a particular table in the database.
# That is, subclasses specify e.g. which fields to use in queries,
# and this module uses that info to actually do the searches.
# See Etyma.pm for a subclass example.

# for AUTOLOAD, we have three kinds of data to access:
# scalars, hashes, and sets
our %ivars = map {$_,1} qw(
	table
	key
	query_from
	default_where
	order_by
	group_by
	search_limit
	debug
	allow_delete
	
	footer_extra
	
	delete_hook
	add_check
);

our %hash_vars = map {$_,1} qw(
	field_visible_privs
	field_editable_privs
	sizes
	search_form_items
	
	add_form_items
	save_hooks
);

# for backwards compatibility, you can set either "editable" or "field_editable_privs".
# "editable" will allow editing by all users; "field_editable_privs" lets you set
# more fine-grained privileges. If both are set (to non-zero values), you will
# get the more lenient of the two (because the two are "or"ed together). So don't do that.

our %set_vars = map {$_,1} qw(
	calculated_fields
	searchable
	editable
	addable
	reload_on_save
	
	search_by_disjunction
);

my %preset_wheres = (
	'int' => \&where_int,
	'word' => \&where_word,
	'value' => \&where_value,
	'beginvalue' => \&where_beginvalue,
	'beginword' => \&where_beginword,
	'rlike' => \&where_rlike,
);

# METHODS

sub new {
	my $class = shift;
	my $self = {};
	@{$self}{qw/dbh table key privs/} = @_;
		# table and key must be set by each subclass!

	# set some defaults
	$self->{privs} ||= 2;  # 2 is the priv bit for non-special users
	$self->{wheres}{$self->{key}} = \&where_int;
	$self->{search_limit} = 1000;
	return bless $self, $class;
}

sub index_of_key {
	my $self = shift;
	my $i = 0;
	foreach ($self->fields()) {
		return $i if $_ eq $self->{key};
		$i++;
	}
}

# the list of fields is *ordered*, and this order is used by other
# subroutines (see e.g. AUTOLOAD).
sub fields {
	my $self = shift;
	if (@_) {
		my @a = @_;
		my @full_fields = @a;	# save the full fields for queries
		foreach (@a) {					# for all other purposes, use the "AS" aliases, if there is one
			if (/ AS /) {
				$_ =~ s/^.+ AS //s; # single-line mode in case there are newlines in the string
				$self->calculated_fields($_); # add this to the set
			}
		}
		$self->{fields} = [@a];
		%{$self->{is_field}} = map {$_,1} @a;	# for efficient lookup later
		%{$self->{field_visible_privs}} = map {$_,31} @a;	# all visible by default
		@{$self->{full_fields}}{@a} = @full_fields;
		die "key not in fields list!" unless $self->{is_field}{$self->{key}};
	} else {
		return @{$self->{fields}}; # return a list
	}
}

sub fields_for_priv {
	my ($self, $fullnames) = @_;
	my @result;
	
	for (@{$self->{fields}}) {
		push @result, ($fullnames ? $self->{full_fields}{$_} : $_)
			if $self->{privs} & $self->{field_visible_privs}{$_};
	}
	return @result;
}

# the following lets you access object data using method calls.
# the names of these data items just need to be set in the corresponding hash.
# ivars: set and get.
# hash_vars: add key/value pairs to the hash, or return the value for a key.
# set_vars: add a member (or a list of members) to the set, or return the
# 	(ordered!) list.
# To check for membership in a set_vars list, call in_[[name of a set_vars list]].
sub AUTOLOAD {
	return if our $AUTOLOAD =~ /::DESTROY$/;
	my $self = shift;
	my $name = $AUTOLOAD;
	$name =~ s/.*:://;

	if ($ivars{$name}) {
		if (@_) {
			$self->{$name} = $_[0];
		} else {
			return $self->{$name};
		}

	} elsif ($hash_vars{$name}) {
		if (scalar @_ == 1) {
			return $self->{$name}{$_[0]};	# return value by key
		} elsif (@_) {
			while (@_) {
				my $key = shift;
				$self->{$name}{$key} = shift; # set key/value pairs
			}
		} else {
			return $self->{$name};	# return a hash ref
		}

	} elsif ($set_vars{$name}) {
		if (@_) {
			$self->{$name}{$_} = 1 foreach @_;
			push @{$self->{tbledit_arrays}{$name}}, @_;
		} else {
			return unless defined $self->{$name};
			return @{$self->{tbledit_arrays}{$name}} if wantarray;
			return scalar keys %{$self->{$name}};
		}

	} elsif ($name =~ s/^in_// && $set_vars{$name}) {
		my $key = shift;
		return $self->{$name}{$key};

	} else {
		die "Undefined method $AUTOLOAD called in TableEdit";
	}
}

sub search {
	my $self = shift;
	my ($cgi, $debug) = @_; ### pass in the query as a cgi obj
	my $dbh = $self->{dbh};
    
	# sort by a separate key if specified
	if (my $sortkey = $cgi->param('sortkey')) {
		$self->{order_by} = $sortkey;
	}

    # construct our query
    my ($query, $where) = $self->get_query($cgi);
	
	# fetch the data so we can count the rows
	my $sth = $dbh->prepare($query);
	$sth->execute();
	my $ary = $sth->fetchall_arrayref();

	my $result = {table => $self->{table}, fields => [$self->fields_for_priv()], data => $ary};
	$result->{debug} = $where; # if $self->{privs} & 1;
	return $result;
}


# Returns an SQL query based on the parameters passed to the script.
# actually returns two values: the first is the entire SQL query;
# the second is a string consisting of the WHERE and HAVING clauses,
# which is nicer to display to the user than the entire query string.
sub get_query {
	my $self = shift;
	my $cgi = shift;
	
	my ($where, $having) = $self->query_where($cgi);
	my $flds = join(', ', $self->fields_for_priv('full'));
	my $from = $self->{query_from} || $self->{table};
	if (!$where) {
		my $default_where = $self->{default_where} ? 'WHERE ' . $self->{default_where} : '';
		return "SELECT $flds FROM $from $default_where GROUP BY $self->{key} LIMIT 1", '[first item]' unless $where;
	}

	my $order = $self->{order_by} || $self->{key};
	my $group = $self->{group_by} || $self->{key};
	if ($self->{default_where}) {
		$where .= ' AND ' . $self->{default_where};
	}
	return "SELECT $flds FROM $from WHERE $where "
		. "GROUP BY $group "
		. ($having ? " HAVING $having " : '')
		. " ORDER BY $order LIMIT 10000", # a sane limit to prevent sending too much back to the user
		$where . ($having ? " HAVING $having" : '');
}

# helper sub to prepare regexes for sql
# this will modify the value passed in!
# things to pay attention to:
# 1. REGEX (aka RLIKE) passes the string to the regex engine,
#    which will need another round of backslash escaping.
# 2. substitute \b with ([[:<:]]|[[:>:]]). (\b must be preceded
#    by an even number of backslashes)
sub prep_regex ($) {
	for ($_[0]) {
		s/(?<!\\)((?:\\\\)*)\\b/$1([[:<:]]|[[:>:]])/g;
		# s/^([+*?|{])/\\$1/g; # try to escape initial +*?|{; we'll need to switch the order of this with s/^\*(?=.)//
		s/\\/\\\\/g;
	}
}

# helper WHERE bits
# $v has single quotes escaped already, so they should be
# safe to use in a single-quote context. Any other use of $v
# (e.g. used bare as an integer) must be carefully controlled!
# See where_int for an example where non-digits are stripped.

sub where_value { my ($k,$v) = @_; "$k='$v'" }
sub where_beginvalue { my ($k,$v) = @_; prep_regex $v; $v =~ s/^\*(?=.)// ? "$k RLIKE '$v'" : "$k RLIKE '^$v'" }
sub where_int { my ($k,$v) = @_; $v =~ s/[^\d<>]//g; return "'bad int!'='0'" unless $v =~ /\d/; $v =~ /^([<>])(.+)/ ? "$k$1$2" : "$k=$v" }
sub where_rlike {     my ($k,$v) = @_; prep_regex $v; "$k RLIKE '$v'" }
sub where_word {      my ($k,$v) = @_; prep_regex $v; $v =~ s/^\*(?=.)// ? "$k RLIKE '$v'" : "$k RLIKE '[[:<:]]${v}[[:>:]]'" }
sub where_beginword { my ($k,$v) = @_; prep_regex $v; $v =~ s/^\*(?=.)// ? "$k RLIKE '$v'" : "$k RLIKE '[[:<:]]$v'" }

sub wheres {
	my $self = shift;
	if (scalar @_ == 1) {
		return $self->{wheres}{$_[0]};	# return value by key
	} elsif (@_) {
		while (@_) {
			my $key = shift;
			my $val = shift;
			$val = $preset_wheres{$val} || $val;
			$self->{wheres}{$key} = $val; # set key/value pairs
		}
	} else {
		return $self->{wheres};	# return a hash ref
	}
}

# generates the WHERE clause based on the CGI params
sub query_where {
	my $self = shift;
	my $cgi = shift;
	my (@wheres, @havings);
	my $query_ok = 0;
	
	for my $key ($cgi->param) {
		my $val = $cgi->param($key);
		next if $val eq ''; # might be numeric 0, so must check for empty string
		
		 # make sure the field name is in one of these lists, just to be safe
		if ($self->{is_field}{$key} || $self->in_searchable($key)) {
			my @restrictions;
			# split by commas that are not preceded by a single backslash (allows searching for commas)
			foreach (split /(?<!(?<!\\)\\), */, $val) {
				next if $_ eq '';

				# inner loop for AND searches within a field
				my @restrictions2;
				for my $value (split /(?<!(?<!\\)\\) *\& */) {
					next if $value eq '';
					$query_ok = 1;

					# prevent sql injection -- this is specific to mysql strings
					# first remove the last of an odd number of backslashes before any single quote
					# (or end of string), so the backslash can't escape a following char
					$value =~ s/(?<!\\)((?:\\\\)*)\\('|$)/$1$2/g;
					$value =~ s/'/''/g; # escape all single quotes

					# get the WHERE phrase for this key, if specified
					# otherwise, default to an int if it's a calculated field, a string (RLIKE) otherwise.
					my $sub = $self->wheres($key) || ($self->in_calculated_fields($key) ? \&where_int : \&where_rlike);
					my $not = $value =~ s/^!//;
					my $rstring = $sub->($key,$value,$cgi);
					$rstring = "NOT($rstring)" if $not;
					push @restrictions2, $rstring;
				}

				my $rstring = join(" AND ", @restrictions2);
				$rstring = "($rstring)" if @restrictions2 > 1;
				push @restrictions, $rstring;
			}
			# calculated fields should be searched for using a HAVING clause,
			# but make an exception for pseudo-fields - right now this means the former
			# lexicon.analysis field which is now calculated using a GROUP_CONCAT and is editable,
			# so we check if the key is editable
			if ($self->in_calculated_fields($key) && !($self->{field_editable_privs}{$key} || $self->in_editable($key))) { # check if it's editable by *someone*; if it is, the search term should go in WHERE, not HAVING
				push(@havings, "(" . join(" OR ", @restrictions) .")");
			} else {
				push(@wheres, "(" . join(" OR ", @restrictions) .")");
			}
		}
	}
	my $conj = ' AND ';
	if (scalar $self->search_by_disjunction()) {
		my @flds = $self->search_by_disjunction();
		my $n = grep { defined $cgi->param($_) } @flds;
		$conj = ' OR ' if $n == scalar @flds;
	}
	if ($query_ok) {
		return join($conj, @wheres) || 1, join($conj, @havings);
	}
	return;
}

# sub to retrieve the current value of a single column.
# useful if you want to check a value before changing it.
sub get_value {
	my ($self, $field, $id) = @_;
	my $col = $self->{full_fields}{$field}; # this might be different from $field if it's a pseudo-field (like analysis)
	return $self->{dbh}->selectrow_array("SELECT $col FROM $self->{table} WHERE $self->{key}=?", undef, $id);
}

sub save_value {
	my $self = shift;
	my ($field, $value, $id) = @_;
	
	die "bad field name ($field) or insufficient privileges (is $self->{privs}, need $self->{field_editable_privs}{$field}; or not in_editable)!"
		unless $self->{field_editable_privs}{$field} & $self->{privs}
			|| $self->in_editable($field); # this will help prevent sql injection attacks

	my $continue = 1;
	my $sub = $self->save_hooks($field);
	$continue = $sub->($id, $value) if $sub;
	# the sub will return a false value if we are to skip the next (saving) step
	# (e.g. if it took care of it already)

	unless ($self->in_calculated_fields($field) || !$continue) { # don't do this for pseudo-fields
		my $update = qq{UPDATE $self->{table} SET $field=? WHERE $self->{key}=?};
		my $update_sth = $self->{dbh}->prepare($update);
		$update_sth->execute($value, $id);
	}
}

# take a CGI object with fields as params.
# returns the id (value of the key field) and the values in the new row.
# if error, return error string in the third return value.
sub add_record {
	my ($self, $q) = @_;
	
	# check for valid data
	my $sub = $self->add_check();
	if ($sub && (my $err = $sub->($q))) {
		return 0, 0, $err;
	}
	
	# make list of fields to be populated
	my (@fields, @insertable_fields);
	for my $param ($q->param) {
		if ($self->in_addable($param)) {
			push @fields, $param;
			if (!$self->in_calculated_fields($param)) {
				push @insertable_fields, $param; # make a separate list to avoid pseudo-fields
			}
		}
	}

	# add a new record
	my $sth = $self->{dbh}->prepare("INSERT $self->{table} ("
		. join(',', @insertable_fields)
		. ") VALUES ("
		. join(',', (('?') x @insertable_fields))
		. ")");
	eval { $sth->execute(map {$q->param($_)} @insertable_fields)	};
	if ($@) {
		return 0, 0, $sth->errstr;
	}

	my $id = $q->param($self->{key})
		|| $self->{dbh}->selectrow_array("SELECT LAST_INSERT_ID()");
		# only get the last insert id if the key wasn't explicitly set
	for my $field (@fields) {
		my $sub = $self->save_hooks($field);
		$sub->($id, $q->param($field)) if $sub;
	}
	
	$q->delete_all();
	$q->param($self->{key},$id);
	my ($query_string) = $self->get_query($q);
	my $a = $self->{dbh}->selectall_arrayref($query_string);
	# my %result;
	# @result{$self->fields_for_priv()} = @{$a->[0]};
	return $id, $a->[0]; # \%result;
}

sub delete_data {
	my $self = shift;
	my $cgi = shift;
	my $dbh = shift;
	my @params = $cgi->param;
	
	foreach my $param (@params) {
		if ($param =~ m/^delete_(.+)/) {
			my $id = $1;
			my $table = $self->{'table'};
			my $key = $self->{'key'};
			my $s = qq{DELETE FROM $table WHERE $key=?};
			my $delete_sth = $dbh->prepare($s);
			$delete_sth->execute($id);
		}
	}
}

1;
