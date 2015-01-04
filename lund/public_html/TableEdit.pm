package TableEdit;

# by Dominic Yu
# 2008.04.21
# see hptb.pl for usage example.
# important: your SQL field names cannot have underscores in them!

use strict;
use CGI qw/-no_xhtml/;
use CGI::Carp qw/fatalsToBrowser/;

# for AUTOLOAD, we have three kinds of data to access:
# scalars, hashes, and sets
our %ivars = map {$_,1} qw(
	table
	key
	query_from
	order_by
	search_limit
	debug
	allow_delete
	
	footer_extra
	
	delete_hook
	add_check
);

our %hash_vars = map {$_,1} qw(
	field_labels
	sizes
	search_form_items
	
	update_form_items
	print_form_items
	add_form_items
	save_hooks
);

our %set_vars = map {$_,1} qw(
	calculated_fields
	searchable
	editable
	always_editable
	addable
	
	search_by_disjunction
);

my %preset_wheres = (
	'int' => \&where_int,
	'word' => \&where_word,
	'beginword' => \&where_beginword,
	'rlike' => \&where_rlike,
);

# METHODS

sub new {
	shift; # discard class name
	my $self = {};
	$self->{dbh} = shift;
	$self->{table} = shift;
	
	my $key = shift;
	$self->{key} = $key;
	$self->{wheres}{$key} = \&where_int;
	
	$self->{search_limit} = 1000;
	bless $self;
}

# the list of fields is *ordered*, and this order is used by other
# subroutines (see e.g. AUTOLOAD).
sub fields {
	my $self = shift;
	if (@_) {
		my @a = @_;
		$self->{full_fields} = [@a];	# save the full fields for queries
		foreach (@a) {					# for all other purposes, use the "AS" aliases, if there is one
			if (/ AS /) {
				$_ =~ s/^.+ AS //;
				$self->calculated_fields($_);
			}
		}
		$self->{fields} = [@a];
		%{$self->{is_field}} = map {$_,1} @a;	# for efficient lookup later
		die "key not in fields list!" unless $self->{is_field}{$self->{key}};
		my $i = 0;
		for (@_) {
			last if $_ eq $self->{key};
			$i++;
		}
		$self->{index_of_key} = $i;
	} else {
		return @{$self->{fields}}; # return a list
	}
}

sub field_labels {
	my $self = shift;
	if (scalar @_ == 1) {
		my $s = $self->{field_labels}{$_[0]};
		if (!$s) {
			$s = $_[0];
			$s =~ s/^[^.]+\.//;
		}
		return $s;
	} elsif (@_) {
		while (@_) {
			my $key = shift;
			$self->{field_labels}{$key} = shift; # set key/value pairs
		}
	} else {
		return $self->{field_labels};	# return a hash ref
	}
}

sub AUTOLOAD {
	return if our $AUTOLOAD =~ /::DESTROY$/;
	my $name = $AUTOLOAD;
	$name =~ s/.*:://;

	if ($ivars{$name}) {
		my $self = shift;
		my $s = shift;
		if ($s) {
			$self->{$name} = $s;
		} else {
			return $self->{$name};
		}

	} elsif ($hash_vars{$name}) { 
		my $self = shift;
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
		my $self = shift;
		if (@_) {
			$self->{$name}{$_} = 1 foreach @_;
			$self->{tbledit_arrays}{$name} = [@_];
		} else {
			return unless defined $self->{$name};
			# return grep {$self->{$name}{$_}} @{$self->{fields}} if wantarray; # returns an ordered list!
			# return keys %{$self->{$name}};
			return @{$self->{tbledit_arrays}{$name}} if wantarray;
			return scalar keys %{$self->{$name}};
		}

	} elsif ($name =~ s/^in_// && $set_vars{$name}) {
		my $self = shift;
		my $key = shift;
		return $self->{$name}{$key} == 1;

	} else {
		die "Undefined method $AUTOLOAD called in TableEdit";
	}
}

sub generate {
	my $self = shift;
	my $cgi = new CGI;
	my $dbh = $self->{dbh};
	
	# special handling for TableKit AJAX updates
	if ($cgi->param('row')) {
		print $cgi->header(-charset => "utf8");
		my ($field, $id, $value) = ($cgi->param('field'), $cgi->param('id'), $cgi->param('value'));
		if ($self->in_editable($field)) {
			my $update = qq{UPDATE $self->{table} SET $field=? WHERE $self->{key}=?};
			my $update_sth = $dbh->prepare($update);
			$update_sth->execute($value, $id);

			my $sub = $self->save_hooks($field);
			$sub->($id, $value) if $sub;

			$value = $cgi->escapeHTML($value); # escape, because the AjaxUpdater expects HTML

			$sub = $self->update_form_items($field);
			$value = $sub->($cgi,$value,$id) if $sub; # transmogrify if necessary
			
			print $value;
		} else {
			print "ERROR: field not editable";
		}
	
	} elsif ($cgi->param('addrecord')) {
		my @params = $cgi->param;
		my @fields;
		for my $param (@params) {
			push @fields, $param if $self->in_addable($param);
		}
		# check for valid data
		my $sub = $self->add_check();
		if ($sub && (my $err = $sub->($cgi))) {
			print $cgi->header('text/html','400 Error');
			print $err;
		} else {
			# add a new record
			my $sth = $dbh->prepare("INSERT $self->{table} ("
				. join(',', @fields)
				. ") VALUES ("
				. join(',', (('?') x @fields))
				. ")");
			eval { $sth->execute(map {$cgi->param($_)} @fields)	};
			if ($@) {
				print $cgi->header('text/html','400 Error');
				print $sth->errstr;
			} else {
				my $id = $cgi->param($self->{key})
					|| $dbh->selectrow_array("SELECT LAST_INSERT_ID()");
					# only get the last insert id if the key wasn't explicitly set
				for my $field (@fields) {
					my $sub = $self->save_hooks($field);
					$sub->($id, $cgi->param($field)) if $sub;
				}
				
				# now retrieve it and send back some html
				print $cgi->header(-charset => "utf8", '-x-json'=>qq|{"id":"$id"}|);
				$cgi->delete_all();
				$cgi->param($self->{key},$id);
				my ($q) = $self->get_query($cgi);
				my $a = $dbh->selectall_arrayref($q);
		
				$self->print_row($cgi, $id, $a->[0]);
			}
		}

	# normal HTML generation
	} else {
		my $btn = $cgi->param('submit');

		$self->make_header($cgi, $btn);
		$self->make_query_form($cgi, $dbh) unless $btn eq 'Print';
		
		if ($btn eq 'Print') {
			$self->print_data($cgi, $dbh);
		} elsif ($btn) {
			if ($btn eq 'Save All') {
				$self->save_data($cgi, $dbh);
			} elsif ($btn eq 'Delete Selected') {
				$self->save_data($cgi, $dbh);
				$self->delete_data($cgi, $dbh);
			}
			$self->make_update_form($cgi, $dbh) unless $btn eq 'Print';
		} else {
			### put a default search here
			$self->make_update_form($cgi, $dbh)
		}
		$self->make_footer($cgi);
	}
}

# HTML GENERATION

sub make_header {
	my $self = shift;
	my ($cgi, $btn) = @_;
	
	print $cgi->header(-charset => "utf8");
	print $cgi->start_html(
		-head => $cgi->meta({-http_equiv => 'Content-Type', 
							 -content    => 'text/html; charset=utf8' }),
		-encoding => 'utf-8',
		-title    => "Edit $self->{table}", 
		-style    => {'src'=>'styles/tagger.css'},
		-script=>[
			{-type => "text/javascript",
			 -src  => 'scriptaculous/lib/prototype.js' },
			{-type => "text/javascript",
			 -src  => 'tablekit.js' },
		]);
	### insert H1, credits, or whatever here ... unless Print, then do a text line, the query, and the date.
}

sub make_footer {
	my $self = shift;
	my $cgi = shift;
	print $cgi->end_html;
}

sub make_query_form {
	my $self = shift;
	my ($cgi, $dbh) = @_;
	
	### get special inputs (popups, etc.) here
	
	$cgi->delete_all() if $cgi->param('reset');# eq 'Reset';
	
	my @searchable = $self->searchable();
	
	print $cgi->start_form(-method => 'GET');
	print $cgi->start_table(-border => '0');
	print $cgi->Tr(
		[ $cgi->th(  [map {$self->field_labels($_)} @searchable]  ) ]);
	print "<tr>";
	for my $fld (@searchable) {
		my $sub = $self->search_form_items($fld);
		print $cgi->td(
			$sub ? $sub->($cgi) :
				$cgi->textfield(
					-name => $fld,
					-default=>'', -override=>1,
					-size => $self->{sizes}{$fld},
		));
	}
	print "</tr>\n";
	print $cgi->end_table;
	print "\n"; # force output, hangs sometimes if you don't?
	print $cgi->hidden('sortkey') if $cgi->param('sortkey');
	print $cgi->submit("submit", "Search"),
		  $cgi->submit('reset', 'Clear Form');
	print $cgi->end_form;
	print "\n";
}

# Returns an SQL query based on the parameters passed to the script.
sub get_query {
	my $self = shift;
	my $cgi = shift;
	my ($where, $having) = $self->query_where($cgi);
	my $flds = join(', ', @{$self->{full_fields}});
	my $from = $self->{query_from} || $self->{table};
	return "SELECT $flds FROM $from GROUP BY $self->{key} LIMIT 1", '[first item]' unless $where;
	
	my $order = $self->{order_by} || $self->{key};
	return "SELECT $flds FROM $from WHERE $where "
		. "GROUP BY $self->{key} "
		. ($having ? "HAVING $having " : '')
		. "ORDER BY $order LIMIT 20000", # a sane limit to prevent overburdening the database
		$where . ($having ? " HAVING $having" : '');
}

# helper WHERE bits
sub where_int { my ($k,$v) = @_; $v =~ /^([<>])(.+)/ ? "$k$1$2" : "$k=$v" }
sub where_rlike { my ($k,$v) = @_; "$k RLIKE '$v'" }
sub where_word { my ($k,$v) = @_; "$k RLIKE '[[:<:]]${v}[[:>:]]'" }
sub where_beginword { my ($k,$v) = @_; "$k RLIKE '[[:<:]]$v'" }

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
		if ($self->{is_field}{$key} || $self->in_searchable($key) # make sure the field name is in one of these lists, just to be safe
			and (my $value = $cgi->param($key)) ne '') { # might be numeric 0, so must check for empty string
			$query_ok = 1;
			$value =~ s/'/''/g;	# security, don't let people put weird sql in here!
			# $value =~ s/\\/\\\\/g;

			my @restrictions;
			for my $value (split /, */, $value) {
				my $sub = $self->wheres($key) || ($self->in_calculated_fields($key) ? \&where_int : \&where_rlike);
				push @restrictions, $sub->($key,$value);
			}
			if ($self->in_calculated_fields($key)) {
				push(@havings, "(" . join(" OR ", @restrictions) .")");
			} else {
				push(@wheres, "(" . join(" OR ", @restrictions) .")");
			}
		}
	}
	my $conj = ' AND ';
	if (scalar $self->search_by_disjunction()) {
		my @flds = $self->search_by_disjunction();
		my $n = grep { $cgi->param($_) ne '' } @flds;
		$conj = ' OR ' if $n == scalar @flds;
	}
	if ($query_ok) {
		return join($conj, @wheres) || 1, join($conj, @havings);
	}
	return;
}

sub make_update_form {
	my $self = shift;
	my ($cgi, $dbh) = @_;
    
	# sort by a separate key if specified
	if (my $sortkey = $cgi->param('sortkey')) {
		$self->{order_by} = $sortkey;
	}

    # construct our query
    my ($query, $where) = $self->get_query($cgi) or return;

	print $query if $self->{debug};
	
	# fetch the data so we can count the rows
	my $sth = $dbh->prepare($query);
	print "<!-- query prepared -->\n";
	$sth->execute();
	print "<!-- query executed -->\n";
	my $results_array = $sth->fetchall_arrayref();
	my $numrows = @$results_array;

	# short summary; "Print" button
	if ($numrows > 0) {
		# separate form for printing, target in new window
		print $cgi->start_form({-target=>'tableedit_print'}, -method => 'POST');
	}
	print "$numrows found. (WHERE $where)";
	if ($numrows > 0) {
		foreach my $field ($self->searchable()) {
			if ($cgi->param($field) ne '') {
				print $cgi->hidden($field);
			}
		}
		print $cgi->submit('submit', 'Print');
		print $cgi->end_form;
	} else {
		return;
	}

	# manual paging for large results
	my ($manual_paging, $a, $b) = (0, 1, $numrows);
	my $SearchLimit = $self->{search_limit};
	if ($numrows > $SearchLimit) {
		$manual_paging = 1;
		my $n = $cgi->param('pagenum') + ($cgi->param('next') ? 1 : ($cgi->param('prev') ? -1 : 0));
		$a = $n*$SearchLimit + 1;
		$b = $a + $SearchLimit - 1;
		$b = $numrows if $numrows < $b;
		
		$cgi->param('pagenum', $n); # set it to the new, correct page number
		print $cgi->start_form({-method => 'POST'});
		# save state, required for paging! see identical code below.
		foreach my $field ($self->searchable(), 'sortkey') {
			if ($cgi->param($field) ne '') {
				print $cgi->hidden( -name => $field, 
									-default => $cgi->param($field));
			}
		}
		print $cgi->hidden('submit');
		print $cgi->hidden('pagenum');
		print $cgi->submit('prev', 'Previous Page') unless $n == 0;
		print "Displaying items $a-$b of $numrows.";
		print $cgi->submit('next', 'Next Page') unless $numrows == $b;
		print $cgi->end_form;
	}
	
    # create links to be placed in <TH> for sorting
    my %sortlinks;
    if ($manual_paging) {
		my $fakeq = CGI->new;
		$fakeq->delete_all();
		foreach my $fld ($self->searchable()) {
			# copy in the old, non-empty parameters
			$fakeq->param($fld, $cgi->param($fld)) if ($cgi->param($fld) ne '');
		}
		$fakeq->param('submit','Search');
		for my $fld ($self->fields()) {
			$fakeq->param('sortkey',$fld);
			$sortlinks{$fld} = $fakeq->self_url;
		}
	}

	# put results in a table
	print $cgi->start_form(
	    {-enctype => 'multipart/form-data',
	     -method => 'POST',
	     -id => 'update_form'});
	# save state for the search form while we're inside the edit form
	# this is required to reload data after saving!
	# the annoying thing with CGI.pm is you have to set override=>1 for your form inputs
	foreach my $field ($self->searchable(), 'sortkey') {
	    if ($cgi->param($field) ne '') {
			print $cgi->hidden( -name => $field, 
								-default => $cgi->param($field));
	    }
	}
	
	print $cgi->start_table({-class => ($manual_paging ? '' : "sortable " )
		. "resizable editable"}
	); # use js sorting only if we're not paging
	
	# set column widths
	for my $fld ($self->fields()) {
		print '<col width="' . ($self->sizes($fld) || '10') . '*">';
	}
	
	# make headings
	print '<thead><tr>';
	if ($manual_paging) {
		print map {$cgi->th(
					($_ eq $self->{key} || !$self->in_editable($_) || $self->in_always_editable($_)
						? {-class=>'noedit'}
						: {-id=>$_}),
					$cgi->a({-href=>$sortlinks{$_}}, $self->field_labels($_))
				)}
			$self->fields();
		print $cgi->th({-class=>'noedit'}, 'Select') if $self->{allow_delete};
	} else {
		print map {$cgi->th(
					($_ eq $self->{key} || !$self->in_editable($_) || $self->in_always_editable($_)
						? {-class=>'noedit'}
						: {-id=>$_}),
					$self->field_labels($_)
				)}
			$self->fields();
		print $cgi->th({-class=>'noedit nosort'}, 'Select') if $self->{allow_delete};
	}
	print qq|</tr></thead><tbody id="update_table">\n\n|;
	
	for my $row (@{$results_array}[($a-1)..($b-1)]) { # array slice, for paging
		my $key = $row->[$self->{index_of_key}];
	    print "<tr id='$key'>";
	    $self->print_row($cgi, $key, $row);
	    print "</tr>";
	}
	print "\n\n</tbody>";
	print $cgi->tfoot( $cgi->Tr(
		$cgi->td({-colspan=>5},
			($self->always_editable() ? $cgi->submit('submit', 'Save All') : ()),
			($self->always_editable() ? $cgi->reset : ()),
			($self->{allow_delete} ? $cgi->submit('submit', 'Delete Selected') : ())
		)
	));
	print $cgi->end_table;
	print $cgi->end_form;
	my $url = $cgi->url(-relative=>1);
	# set up tables and make clicking on links not trigger editing
	print <<EOF;
<script type="text/javascript">
TableKit.options.editAjaxURI = '$url';
TableKit.options.defaultSort = 1;
scrollEnd = function() {
	if (document.body.scrollHeight) { window.scrollTo(0, document.body.scrollHeight); 
	} else if (screen.height) { window.scrollTo(0, screen.height); } // IE5 
}
dontedit = function(e) {
	if (!e) var e = window.event;
	e.cancelBubble = true; if (e.stopPropagation) e.stopPropagation();
	return true;
}
</script>
EOF
	my $sub = $self->footer_extra();
	$sub->($cgi) if $sub;
	
	# form for adding a record
	if ($self->addable()) {
		print $cgi->a({-href=>'#',-onclick=>"var n = \$('add_form_span').style; n['display'] = n['display'] == 'none' ? 'inline' : 'none'; scrollEnd(); return false"},
			'Add a record...');
		print '<span id="add_form_span" style="display:none">';
		print $cgi->start_form({-id=>'add_form', -onsubmit=><<EOF}); # escape \\ once for perl, once for js
new Ajax.Request('$url', {
	parameters: \$('add_form').serialize(true),
    onSuccess: function(transport,json){
		var response = transport.responseText || "ERROR: no response text";
		var newRow = document.getElementById('update_table').insertRow(-1);
		newRow.id = json.id; newRow.vAlign = "top"; newRow.innerHTML = response;
		TableKit.reload();
		scrollEnd();
		\$\$('.add_reset').each(function(i) {i.value = ''});
    },
    onFailure: function(transport){ alert('Error: ' + transport.responseText) }
});
return false;
EOF
		print $cgi->start_table(-border => '0');
		for my $fld ($self->addable()) {
			my $sub = $self->add_form_items($fld);
			print $cgi->Tr($cgi->th($self->field_labels($fld)), $cgi->td($sub ? $sub->($cgi) :
				$cgi->textfield(-name => $fld,
								-size => $self->sizes($fld)*2,
								-default => '',
								-override => 1,
								-class => 'add_reset',)
			));
		}
		print $cgi->end_table;
		print $cgi->hidden('addrecord',1);
		print $cgi->submit('btn','Add Record');
		print $cgi->end_form;
		print "</span>";
	}
}

# subroutine for a results row
sub print_row {
	my $self = shift;
# 	if ($self->custom_print_row()) {
# 		$self->custom_print_row()->(@_);
# 		return;
# 	}
	my ($cgi, $key, $row) = @_;
	my $i = 0;
	for (@$row) {	# for each field (column) of this row...
		my $field = $self->{fields}[$i++];
		my $sub = $self->update_form_items($field);
		if ($sub) {
			print $cgi->td($sub->($cgi, $_, $key));
		} elsif ($self->in_always_editable($field)) {
			print $cgi->td($cgi->textfield(
					   -name => $field . '_' . $key,
					   -value => $_,
					   -size => $self->sizes($field)
			));
		} else {
			print $cgi->td($cgi->escapeHTML($_));
		}
	}
	if ($self->{allow_delete}) {
		print $cgi->td($cgi->checkbox(
			-name => 'delete_' . $key,
			-value => 'off',
			-label => ''
		));
	}
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
			my $s = qq{DELETE FROM $table WHERE $key=$id};
			my $delete_sth = $dbh->prepare($s);
			$delete_sth->execute();
		}
	}
}

sub save_data {
	my $self = shift;
	my $cgi = shift;
	my $dbh = shift;
	my @params = $cgi->param;
	
	foreach my $param (@params) {
		if ($param =~ m/(.+?)_(.+)/) {	### NB: field names cannot have underscores in them! maybe fix by using double underscores?
			my ($field, $id) = ($1, $2);
			if ($self->in_always_editable($field)) {
				my $value = $cgi->param($param);
				my $update_sth = $dbh->prepare(
					qq{UPDATE $self->{table} SET $field=? WHERE $self->{key}=?});
				$update_sth->execute($value, $id);
				
				my $sub = $self->save_hooks($field);
				$sub->($id, $value) if $sub;
			}
		}
	}
}


sub print_data {
	my $self = shift;
    my $cgi = shift;
    my $dbh = shift;
    my ($query, $where) = $self->get_query($cgi) or return;

	my $sth = $dbh->prepare($query);
	$sth->execute();
	my $results_array = $sth->fetchall_arrayref();
	my $numrows = @$results_array;

	print $cgi->p("STEDT database results from $self->{table} table. "
		. "$numrows found [WHERE $where]. "
		. scalar localtime);

	print $cgi->start_table({-class=>'sortable resizable'});
	# set column widths
	for my $fld ($self->fields()) {
		print '<col width="' . ($self->sizes($fld) || '10') . '*">';
	}
	print $cgi->thead($cgi->Tr(
		map {$cgi->th($self->field_labels($_))}
			$self->fields(),
	));
	for my $row (@$results_array) {
	    print "<tr>";
	    my $key = $row->[$self->{index_of_key}];
	    my $i = 0;
		foreach (@$row) {
			my $field = $self->{fields}[$i++];
			my $sub = $self->print_form_items($field);
			if ($sub) {
				print $cgi->td($sub->($cgi, $_, $key));
			} else {
				print $cgi->td($cgi->escapeHTML($_));
			}
		}
	    print "</tr>";
	}
	print $cgi->end_table;
}



1;
