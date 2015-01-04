package STEDT::RootCanal::Edit;
use strict;
use base 'STEDT::RootCanal::Base';
use Encode;
use utf8;
use Time::HiRes qw(time);
use CGI::Application::Plugin::Redirect;

sub table : StartRunmode {
	my $self = shift;
	my $t0 = time();
	my $tbl = $self->param('tbl');
	# restrict particular tables from users without appropriate privs
	if    ($tbl eq  'projects')	{ $self->require_privs(8) }	# approver privs
	elsif ($tbl eq  'notes')	{ $self->require_privs(1) }	# tagger privs (due to username exposure)
#	elsif ($tbl eq  'mesoroots')	{ $self->require_privs(8) }
#	elsif ($tbl eq  'hptb')		{ $self->require_privs(8) }
#	elsif ($tbl eq  'glosswords')	{ $self->require_privs(8) }
#	elsif ($tbl eq  'morphemes')	{ $self->require_privs(8) }
#	elsif ($tbl eq  'chapters')	{ $self->require_privs(8) }
	else			        { $self->require_privs(2) }	# logged-in user (available to public via guest account)
	
	my $q = $self->query;

	my $download = $q->param('download');

	# get 2 uids from edit.tt: the values selected in the two dropdowns.
	# these will be passed in to the select for the analysis and user_an columns
	# just in case bad values get passed in, we convert it to a number (by adding 0)
	# and then switch to default values when 0 (or not a number, which yields 0 when you add 0)
	my ($uid1, $uid2);
	if ($tbl eq 'lexicon') {
		no warnings 'uninitialized';
		$uid1 = $q->param('uid1')+0 || 8;
		$uid2 = $q->param('uid2')+0 || $self->param('uid');
	}
	my $t = $self->load_table_module($tbl,$uid2,$uid1);
	$q->param($_, decode_utf8($q->param($_))) foreach $q->param; # the template will expect these all to be utf8, so convert them here

	my $result = $t->search($q);
	# it doesn't seem to be too inefficient to pull out all the results
	# and then count them and/or send partial results to the browser (for paging)
	# The alternative is to do a COUNT * first, which mysql should be optimized for,
	# but we can do that if performance becomes an issue.

	my $numrows = scalar @{$result->{data}};
	
	# manual paging for large results
	my ($manual_paging, $a, $b) = (0, 1, $numrows);
	my $SearchLimit = 500;
	my $pagenum;
	my %sortlinks;

	if ($numrows > $SearchLimit*2) {
		$manual_paging = 1;
		my $n = $q->param('pagenum') + ($q->param('next') ? 1 : ($q->param('prev') ? -1 : 0));
		$a = $n*$SearchLimit + 1;
		$b = $a + $SearchLimit - 1;
		$b = $numrows if $numrows < $b;
		$pagenum = $n;
		
		# make links for manual sorting
		my $fakeq = $q->new();
		for my $fld ($t->searchable()) {
			# copy in the old, non-empty parameters
			$fakeq->param($fld, $q->param($fld)) if $q->param($fld);
		}
		for my $fld (@{$result->{fields}}) {
			$fakeq->param('sortkey',$fld);
			$sortlinks{$fld} = $fakeq->self_url;
			# for each field, generate a clickable URL to re-sort
		}
	}

	my %hash = (
		t=>$t, key_index=>$t->index_of_key(),
		result => $result, time_elapsed => sprintf("%0.3g", time()-$t0),
		manual => $manual_paging, sortlinks => \%sortlinks,
		a => $a, b => $b, pagenum => $pagenum
	);
	
	# special case: add a legend for projects
	if ($tbl eq 'projects') {
	  my %legend = ('1 * = In progress' => '#fff2b3', '2 $ Done' => '#b3ffb3', '3 # Blocked' => '#ffb3b3', '4 % Other' => '#ccbcff') ;
	  my $message = '<table style="cellpadding : 10px"><tr>';
	  foreach my $status (sort keys %legend) {
		$message .= '<td style="text-align : center; width : 150px; background-color : ' . $legend{$status} . ';">' . substr($status,1) . '</td>';
	      }
	  $message .= '</tr></table>';
	  $hash{message} = $message;
	}
	# special case: include footnotes and list of users, etc., for lexicon table
	# Note that collect_lex_notes appears to require that the last field in each row be num_notes
	# Otherwise, the last field gets clobbered
	elsif ($tbl eq 'lexicon') {
		my @footnotes;
		my $footnote_index = 1;
		require STEDT::RootCanal::Notes;
		STEDT::RootCanal::Notes::collect_lex_notes($self,
			# only collect notes for the records on this page
			[@{$result->{data}}[($a-1)..($b-1)]], $self->has_privs(2),
			\@footnotes, \$footnote_index);
		$hash{footnotes} = \@footnotes;

		#make a list of uids and users to be passed in to make the dropdowns for selecting sets of tags.
		my @users;
		# find the users who have tagged something, plus the current user if no tags
		my $u = $self->dbh->selectall_arrayref("SELECT username, users.uid
			FROM users LEFT JOIN lx_et_hash USING (uid)
			WHERE tag != 0 OR users.uid=? GROUP BY uid", undef, $self->param('uid'));
		foreach (@$u) {
			push @users, {uid=>$_->[1], username=>$_->[0]};
		}
		$hash{users} = \@users;
		$hash{uid1} = $uid1;
		$hash{uid2} = $uid2;
	}
	elsif ($tbl eq 'etyma') {
		my $plgs = $self->dbh->selectall_arrayref("SELECT plg, grpid FROM languagegroups WHERE plg != '' ORDER BY grp0,grp1,grp2,grp3,grp4");
		# unshift @$plgs, ['(other)', '']; # not sure why this is here, because choosing 'other' causes a database error
		push @$plgs, ['', 0];
		require JSON;
		$hash{plgs} = JSON::to_json($plgs);
	}

	if ($download) {
	  # start with header
	  my $dwnld = join("\t",@{$result->{fields}}) . "\n";
	  # add query results
	  for my $row (@{$result->{data}}) {
	    $dwnld .= join("\t", @$row) . "\n";
	  }
	  $self->header_add(-type => 'text/csv',
			    -attachment => "$tbl.csv",
			    -Content_length => length(encode_utf8($dwnld)));
	  return $dwnld;
	}
	else {
	  # pass to tt: searchable fields, results, addable fields, etc.
	  return $self->tt_process("admin/edit.tt", \%hash);
	}
}


sub add : Runmode {
	my $self = shift;
	my $tblname = $self->param('tbl');
	# taggers can only add etyma, not lexicon/languagename/etc. records
	$self->require_privs($tblname eq 'etyma' ? 1 : 16);

	my $t = $self->load_table_module($tblname);
	my $q = $self->query;
	
	my ($id, $result, $err) = $t->add_record($q);
	if ($err) {
		$self->header_add(-status => 400);
		return $err;
	}
	# update changelog (note that oldval and newval are TEXT type fields, which cannot have default values
	# so we have to explcitly set them to the empty string)
	$self->dbh->do("INSERT changelog (uid, change_type, `table`, id, oldval, newval, time)
					VALUES (?,?,?,?,?,?,NOW())", undef,
		       $self->param('uid'), 'new_rec', $tblname, $id, '', '');
	
	# now retrieve it and send back some html
	$id =~ s/"/\\"/g;
	$self->header_add('-x-json'=>qq|{"id":"$id"}|);
	require JSON;
	return JSON::to_json($result);
}


# check to see if the only change involves adding or deleting delimiters. if so, it
# directly modifies the second argument by replacing added spaces with a STEDT delim,
# and also strips out surrounding whitespace.
sub delims_only {
	my @a = split '', $_[0]; # split our strings into chars
	my @b = split '', ($_[1] =~ /(\S.*\S)/)[0]; # ignore starting/trailing whitespace ((...)[0] forces list context)
	my $delims_only = 1;
	my $i = 0;
	my $j = 0;
	
	while ($delims_only && $i < @a && $j < @b) { # while the strings match and we haven't reached the end yet...
		if ($a[$i] ne $b[$j]) { # do nothing if they match at the current indexes
			unless (
				($i+1 < @a && $a[$i+1] eq $b[$j] && $a[$i] =~ /[◦\|]/ && $i++) ||
					# char was deleted and it was '◦' or '|'
				($j+1 < @b && $b[$j+1] eq $a[$i] && ($b[$j] =~ /[◦\|]/ || ($b[$j] eq ' ' && ($b[$j] = '◦'))) && $j++)
					# char was added and it was '◦' or '|',
					# or it was a space, in which case we change it to be '◦', and so yes that's *supposed* to be an assignment operator!
					# Finally, increment the counter if all the other tests pass.
					) {
				$delims_only = 0;
			}
		}
		$i++;
		$j++;
	}
	return 0 if !$delims_only;
	# make sure both strings have been read to the end
	if (($i == @a && $j == @b) ||
		($j == @b && $i+1 == @a && $a[$i] eq '|') ||
		($i == @a && $j+1 == @b && $b[$j] eq '|') # special case: allow add/delete of overriding delim at the end
		) {
		$_[1] = join '', @b;	# modify-in-place
		return 1;
	}
	return 0;
}

sub update : Runmode {
	my $self = shift;
	my $q = $self->query;
	unless ($self->has_privs(1)) {
		$self->header_add(-status => 403);
		return "Insufficient privileges.";
	}

	# this is a bit complicated. 
	# If this is the edit/lexicon view, we get 2 userids passed in.
	# If this is the notes/etymon view, we get one passed in, viz. uid2.
	# Both are optional, but uid1 is more optional than uid2, since
	# uid2 is used by both lexicon and etymon views, but uid1 is only used by edit/lexicon.
	# In the edit/lexicon view, these 2 uids correspond to the users selected
	# in the dropdown and whose tagging appears in the analysis and user_an columns.
	# In the etymon view, only uid2 is relevant because the first column is always
	# the stedt analysis.
	
	# NB: because $q->param(X) is evaluated in list context, it will return an empty list
	# if there is no parameter X. Thus, for something like this:
	# ($a, $b, $c) = (1, $q->param('nonexistent_parameter_name'), 3);
	# you will get $a = 1, $b = 3, and $c undefined since the second item in the list
	# was collapsed away. To avoid such problems we pull the optional params out
	# and set them in their own statements.
	
	# we test to see which field is being updated, and set $fake_uid accordingly.
	# note that users with sufficient privileges can change other users' (and even stedt's) tagging
	# in which case the changelog reflects the actual user as the changer and records
	# the 'pilfered' tags by storing the uid of the original tagger under owner_uid
	# and recording the field as "user_an" (or "analysis" if changing the stedt tags).
	my ($tblname, $field, $id, $value) = ($q->param('tbl'), $q->param('field'),
		$q->param('id'), decode_utf8($q->param('value')));

	$value =~ s/\t//g;	# strip out any tab characters
	
	# restrict taggers from editing etyma not their own
	# this just seemed like the best place to put this code
	if ($tblname eq 'etyma' && !$self->has_privs(8)) {
		my $cur_uid = $self->param('uid');
		my ($ety_owner) = $self->dbh->selectrow_array("SELECT uid FROM etyma WHERE tag=$id");
		if ($cur_uid != $ety_owner) {
			$self->header_add(-status => 403); # Forbidden
			return "You are not allowed to edit other users' etyma.";
		}
		# print STDERR "Etymon tag is $id. Uid is $cur_uid. Etymon owner is $ety_owner."
	}
	# end tagger restriction test
	
	my $uid2 = $q->param('uid2');
	my $uid1 = $q->param('uid1'); # these will be set to undef if there is no such param
	my $fake_uid;
	if ($tblname eq 'lexicon' && $field eq 'analysis') { $fake_uid = $uid1; }
	elsif ($tblname eq 'lexicon' && $field eq 'user_an' ) { $fake_uid = $uid2; }
	undef $fake_uid if $fake_uid && ($fake_uid == $self->param('uid')); # $fake_uid should be undef for the current user
	if ($fake_uid && !$self->has_privs(8)) {
		$self->header_add(-status => 403); # Forbidden
		return "You are not allowed to edit other people's tags.";
	}
	my $t;
	
	if (($t = $self->load_table_module($tblname, $uid2, $uid1))
	   && ($t->{field_editable_privs}{$field} & $self->param('userprivs') || $t->in_editable($field))) {
		my $oldval = $t->get_value($field, $id);

		# special case for lexicon form editing by taggers: restrict to delimiters
		if ($tblname eq 'lexicon' && $field eq 'lexicon.reflex') {
			my $delims_only = delims_only($oldval,$value);
			# this has the effect of converting spaces to stedt delimiters if the only things added were delimiters
			
			if (!$self->has_privs(16) && !$delims_only) {
				# this prevents non-superusers from making modifications to the form field
				# other than adding and removing delimiters
				$self->header_add(-status => 403);
				return "You are only allowed to add delimiters to the form!";
			}
		}

		$t->save_value($field, $value, $id);
		$value = $t->get_value($field, $id); # fetch the new value in case it's not quite the same
		if ($fake_uid) {
			$field = $fake_uid == 8 ? 'analysis' : "user_an";
		}
		if ($oldval ne $value) {
			$self->dbh->do("INSERT changelog (uid, `table`, id, col, oldval, newval, owner_uid, time)
							VALUES (?,?,?,?,?,?,?,NOW())", undef,
				$self->param('uid'), $tblname, $id, $field =~ /([^.]+)$/,
				$oldval || '', $value || '',  # $oldval might be undefined (and interpreted as NULL by mysql)
				$fake_uid || 0);
		}
		if ($t->in_reload_on_save($field)) {
			my $q2 = $q->new('');
			$q2->param($t->key, $id);
			require JSON;
			$self->header_add('-X-JSON' => JSON::to_json($t->search($q2)));
		}
		return $value;
	} else {
		$self->header_add(-status => 403); # Forbidden
		return "Field $field not editable";
	}
}

# helper method to do on-the-fly language selection
sub json_lg : Runmode {
	my $self = shift;
	my $srcabbr = $self->param('srcabbr');
	my $a = $self->dbh->selectall_arrayref("SELECT lgid, language FROM languagenames WHERE srcabbr LIKE ? ORDER BY language", undef, $srcabbr);
	require JSON;
	return JSON::to_json($a);
}

sub single_record : Runmode {
	my $self = shift;
	$self->require_privs(16);
	my $tbl = $self->param('tbl');
	my $id = $self->param('id');
	my $t = $self->load_table_module($tbl);
	my $q = $self->query;
	
	my $key = $t->{key};
	$key =~ s/^.*\.//;
	my $sth = $self->dbh->prepare("SELECT * FROM $tbl WHERE `" . $key . "`=?");
	$sth->execute($id);
	my $result = $sth->fetchrow_arrayref;
	my $cols = $sth->{NAME};
	
	# if getting an update form, process it
	my $i = 0;
	my %colname2num;
	$colname2num{$_} = $i++ foreach @$cols;
	my %updated;
	for my $col ($q->param) {
		next if $col eq 'rootcanal_btn';
		if ($q->param($col) ne $result->[$colname2num{$col}]) {
			$updated{$col} = $q->param($col);
		}
	}
	if (%updated) {
		my @keys = keys %updated;
		my $update_str = join ', ', map {"`$_`=?"} @keys;
		$self->dbh->do("UPDATE $tbl SET $update_str WHERE `" . $key . "`=?", undef, @updated{@keys}, $id);
		# update successful! now update the "changes" table
		for my $col (@keys) {
			$self->dbh->do("INSERT changelog (uid, `table`, id, col, oldval, newval, time) VALUES (?,?,?,?,?,?,NOW())", undef,
				$self->param('uid'), $tbl, $id, $col, $result->[$colname2num{$col}], $updated{$col});
		}
		$sth->execute($id);
		$result = $sth->fetchrow_arrayref;
	}
	
	return $self->tt_process("admin/single_record.tt", {
		t=>$t, id=>$id,
		result => $result,
		cols => $cols,
		key => $key
	});
}

1;
