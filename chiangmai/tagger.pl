#!/usr/bin/perl -w

use strict;
use DBI;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;

use STEDTUtil;

######################################################################
# CONSTANTS
######################################################################
# Both @fields and $names must be edited when the set of fields in the
# interface changes.

my $SearchLimit = 3000;
my $SubgroupWidth = 23;

# A list of database fields ordered by their sequence in the UI
my @fields = ('lexicon.reflex',
	      'lexicon.gloss', 
	      'languagenames.language', 'languagegroups.grp',
	      'languagenames.srcabbr', 'lexicon.srcid',
	      'lexicon.semcat', 
	      'lexicon.rn',
	      'COUNT(notes.noteid)'
	     );
# A hash-reference consisting of database field names
# related to the names used in the user interface.
my $names = {
	     'lexicon.reflex' => 'Reflex',
	     'lexicon.gloss' => 'Gloss',
	     'languagenames.language' => 'Language',
	     'languagegroups.grp' => 'Subgroup',
	     'languagenames.srcabbr' => 'Source',
	     'lexicon.semcat' => 'SemCat',
	     'COUNT(notes.noteid)' => 'Notes',
	     'lexicon.srcid' => 'SourceID',
	     'lexicon.rn' => 'RecNum'
};
# A list of UI names in order.
my @values = map {$names->{$_}} @fields;

# A list of UI names in order.
my @labels = map {$names->{$_}} @fields;

# A hash-reference designating the fields which are editable.
my $editable = {
#		 'lexicon.reflex' => 1,
#		 'lexicon.gloss' => 1,
		 };
# Query strings
my $qdata = {
	     'from' => q|lexicon LEFT JOIN notes USING (rn), languagenames, languagegroups|,
	     # IMPORTANT: we can ignore spec='L' here because rn is only used for lexicon entries
	     'where' => 'lexicon.lgid=languagenames.lgid AND languagenames.grpid=languagegroups.grpid',
	     'order' => 'SUBSTRING(languagegroups.grpno,1,1), languagenames.lgsort, reflex, languagenames.srcabbr, lexicon.srcid',
	     	#'lexicon.gloss,languagegroups.grp,languagenames.language',
	     	# ,lexicon.reflex
	     'table' => 'lexicon',
	     'key' => 'lexicon.rn',
};

######################################################################
# DATABASE CONNECTIVITY
######################################################################

# Returns a database connection
sub connectdb {
  my $host = 'localhost';
  my $db = 'stedt';
  my $db_user = 'root';
  my $db_password = '';

  my $dbh = DBI->connect("dbi:mysql:$db:$host", "$db_user",
			 "$db_password",
			 {RaiseError => 1,AutoCommit => 1})
    || die "Can't connect to the database. $DBI::errstr\n";
  # This makes the database connection unicode aware
  $dbh->do(qq{SET NAMES 'utf8';});
  return $dbh;
}

# Returns an SQL query based on the parameters passed to the script.
sub get_query {
  my $cgi = shift;
  my $where = query_where($cgi) or return;
  
  my $flds = join(', ', @fields);
  my $from = $qdata->{'from'};
  my $order = $qdata->{'order'};
  my $limita = ($cgi->param('pagenum') + ($cgi->param('next') ? 1 : ($cgi->param('prev') ? -1 : 0))) * $SearchLimit;
  return
  	"SELECT DISTINCT $flds FROM $from WHERE $where GROUP BY lexicon.rn " .
  	"ORDER BY $order";
#  	" LIMIT $limita, $SearchLimit";
}

sub query_where {
	my $cgi = shift;
	my @wheres;
	my $query_ok = 0;
	my $need_hash = 0;
	
	foreach my $key ($cgi->param) {
		if ($names->{$key} and $cgi->param($key) ne '') {
			$query_ok = 1;
			my $value = $cgi->param($key);
			$value =~ s/'/''/g;	# security, don't let people put weird sql in here!
			$value =~ s/\\/\\\\/g;

			my @restrictions;
			for my $value (split /, */, $value) {
				my $restriction;
				if ($key eq 'lexicon.rn') {
					$restriction = $key . '=' . $value;
				} elsif ($key eq 'lexicon.gloss') {
					if ($value eq '0') {
						$restriction = "$key=''";
					} else {
						$restriction = $key . " LIKE '" . $value . "'";
						#$restriction = $key . " RLIKE '[[:<:]]" . $value . "'";# . "[[:>:]]'";
					}
				} elsif ($key eq 'languagegroups.grp') {
					# exception for grpid!
					$value =~ s/\.0//g; # make it search all subgroups as well
					$restriction = "languagegroups.grpno LIKE '$value%'";
				} else {
					$restriction = $key . " LIKE '" . $value . "' ";
				}
				push @restrictions, $restriction;
			}
			push(@wheres, "(" . join(" OR ", @restrictions) .")");
		}
	}
	if ($need_hash) {
		$qdata->{'from'} .= ', lx_et_hash' unless $qdata->{'from'} =~ /lx_et_hash$/;
		$qdata->{'where'} = 'lx_et_hash.rn=lexicon.rn AND ' . $qdata->{'where'}
			unless $qdata->{'where'} =~ /^lx_et_hash.rn=/;
	}
	return $query_ok ? join(' AND ', ($qdata->{'where'}, @wheres)) : '';
}

######################################################################
# HTML GENERATION
######################################################################

sub make_query_form {
  my $cgi = shift;
  my $dbh = shift;
  
  # get list of subgroups
  my $grps = $dbh->selectall_arrayref("SELECT grpno, CONCAT(grpno,' ',grp) FROM languagegroups");
  my @grp_nos = map {$_->[0]} @$grps;
  my %grp_labels;
  @grp_labels{@grp_nos}
   = map {length $_->[1] <= $SubgroupWidth
   		? $_->[1]
   		: substr($_->[1], 0, $SubgroupWidth) . '...' } @$grps;

  print $cgi->start_form(-method => 'GET');
  print $cgi->start_table(-border => '0');
  my $makePrintButton = "";
  my $makeSaveButton  = "";
  if (1) {
     $makePrintButton = $cgi->submit("submit", "Print");
     $makeSaveButton  = $cgi->submit("submit",  "Save");
  }
  print $cgi->Tr(
		 $cgi->td({-align=>'center', -valign=>'middle', -colspan=>'2'}, $cgi->submit("submit", "Search"),$makePrintButton,$makeSaveButton),
		 $cgi->td({-colspan=>20}, $cgi->h3("STEDT Lexicon")),
		);
  print $cgi->param('sortkey') ? $cgi->hidden( {-name => 'sortkey', -default => $cgi->param('sortkey')}) : '';
  print $cgi->Tr({-valign => 'top'}, [$cgi->th([grep {$_ ne 'Notes'} @values])] );
  print "<tr valign='top'>";
  foreach my $field (@fields) {
    if ($field eq 'COUNT(notes.noteid)') {
      # do nothing
    } elsif ($field eq 'languagegroups.grp') {
      print $cgi->td($cgi->popup_menu(-name => $field, -values=>['',@grp_nos],
				      -labels=>\%grp_labels));
    } else {
      print $cgi->td($cgi->textfield(-name => $field,
				     -size=>'10%'));
    }
  }
  print "</tr>";
  print $cgi->end_table;
  print $cgi->end_form;
}

sub make_update_form {
  my $cgi = shift;
  my $dbh = shift;
  
  # sort by a separate key if specified
  my $sortkey = $cgi->param('sortkey');
  if ($sortkey && $sortkey ne 'languagegroups.grp') {
    $qdata->{'order'} = $sortkey;
  }
  
  my $query = get_query($cgi) or return;
  
  #print $query, $cgi->br();#return;
  
  # count the records in our result
  
  my $where = query_where($cgi);

  my $sth = $dbh->prepare($query);
  $sth->execute();
  my $numrows = $sth->rows;
  
  print "$numrows found. Ordering by ",$sortkey;
  # cut out the extra fluff
  return unless ($numrows > 0);
  
  # special utility to replace etyma tags
  
#  print $cgi->start_form(-onsubmit=><<EOF); # escape \\ once for perl, once for js
  
  print $cgi->end_form;
  
  # now for the results/update table
  
  print $cgi->start_form(
			 {-enctype => 'multipart/form-data',
			  -method => 'POST'});
  
  # remember certain parameters
  foreach my $field (@fields, 'sortkey') {
    if ($cgi->param($field)) {
      print $cgi->hidden( -name => $field,
			  -default => $cgi->param($field));
    }
  }
  
  # implement our paging algorithm
  my $manual_paging = 1;
  if ($numrows > $SearchLimit) {
    $manual_paging = 1;
    my $n = $cgi->param('pagenum') + ($cgi->param('next') ? 1 : ($cgi->param('prev') ? -1 : 0));
    # dupe code, maybe stick this further up, before calling get_query?
    my $a = $n*$SearchLimit + 1;
    my $b = $a + $SearchLimit - 1;
    $b = $numrows if $numrows < $b;
    
    $cgi->param('pagenum', $n); # set it to the new, correct page number
    print $cgi->hidden('pagenum');
    print $cgi->submit('prev', 'Previous Page') unless $n == 0;
    print "Displaying items $a-$b of $numrows.";
    print $cgi->submit('next', 'Next Page') unless $numrows == $b;
    
    print $cgi->submit('submit', 'Print');
  }
    
  # create links to be placed in <TH> for sorting
  my $fakeq = CGI->new;
  $fakeq->delete_all();
  foreach my $field ('submit', @fields) {
    $fakeq->param($field, $cgi->param($field)) if ($cgi->param($field));
  }
  my @sortlinks;
  if ($manual_paging) {
    for (0..(scalar @values - 1)) {
      $fakeq->param('sortkey',$fields[$_]);
      push @sortlinks, $fakeq->a({-href=>$fakeq->self_url},$values[$_]);
    }
  }
  

  my %results;
  @results{@fields} = ();
  # Map the columns from the query to the hash %results
  $sth->bind_columns(map { \$results{$_} } @fields);
  
  print $cgi->start_table({-class=>
			   ($manual_paging ? '' : "sortable " )
			   . "resizable editable"});
  # use js sorting only if we're not paging
  # print $cgi->Tr({-valign => 'top'}, [$cgi->th(\@values)] );
    if ($manual_paging) {
      #push @sortlinks, 'Delete';
      print $cgi->Tr({-valign => 'top'}, [$cgi->th(\@sortlinks)] );
    } else {
      print $cgi->thead($cgi->Tr({-valign => 'top'},
	    (map {$cgi->th(
	    ($_ eq $qdata->{'key'} || $_ eq 'COUNT(notes.noteid)' || $editable->{$_} || $_ eq 'languagenames.srcabbr'
	     ? {-class=>'noedit'}
	     : {-id=>$_}),
	     $names->{$_}
	     )} @fields),
	     #$cgi->th({-class=>'noedit'},'Delete'),
	));
    }
  while ($sth->fetch()) {
    my $key = $results{$qdata->{'key'}};
    print "<tr valign='top' id='$key'>";
    for my $field (@fields) {
      if ($field eq 'lexicon.analysis' && $results{$field}) {
	my @f = split(",",$results{$field});
	my $analysis;
	foreach my $tag (@f) {
	  if ($tag =~ /^\d+$/) {
	    #$analysis .= $cgi->a({-href=>"etyma.pl?submit=search&etyma.tag=$tag",-target=>'etyma_detail'},
	    $analysis .= $cgi->a({-href=>"etymology.pl?tag=$tag",-target=>'etyma_detail'},
				 $tag) . "+";
	  }
	  else {
	    $analysis .= $tag . "+";
	  }
	}
	$analysis =~ s/\+$//;
	print $cgi->td($analysis);
      } elsif ($field eq 'languagenames.srcabbr') {
	#print $cgi->td($cgi->a({-href=>"rendersource.pl?submit=Search+Etyma&srcbib.srcabbr=$results{$field}", -target=>'-new'},
	print $cgi->td($cgi->a({-href=>"rendersource.pl?submit=search&srcbib.srcabbr=$results{$field}"},
			       $results{$field}));
      } elsif ($field eq 'lexicon.semcat') {
	print $cgi->td($cgi->a({-href=>"tagger.pl?submit=search&lexicon.semcat=$results{$field}"},
			       $results{$field}));
      } elsif ($field eq 'COUNT(notes.noteid)') {
	my $n = $results{$field};
	print $cgi->td($cgi->a({-href=>"notes.pl?L=$key", -target=>'noteswindow'},
			       $n == 0 ? "" : "$results{$field} note" . ($n == 1 ? '' : 's')));
      } elsif ($field eq 'lexicon.rn') {
	print $cgi->td($results{$field});
      } else {
	print $cgi->td($cgi->escapeHTML($results{$field}));
	# you MUST escape the html entities!
	# the docs say escapeHTML turns everything into HTML entities if encoding is not latin, but that can't be right...
      }
    }
    # the delete checkbox
    #my $checkboxname = 'delete' . '_' . $key;
    #print $cgi->td($cgi->checkbox(-name => $checkboxname,
				 # -value => 'off',
				 # -label => ''));
    print "</tr>";
  }
  #print $cgi->tfoot(
		    #$cgi->Tr(
		    #$cgi->td($cgi->submit('submit', 'Save All')),
		    #$cgi->Tr($cgi->td($cgi->submit(-name=>'submit', -value=>'Delete Selected',-onClick=>"if (confirm('Are you sure you want to delete this record?')) return true; else return false;")))
		   #);
  print $cgi->end_table;
  print $cgi->end_form;
  my $url = $cgi->url(-absolute=>1);
  print <<EOF;
<script type="text/javascript">
	TableKit.options.editAjaxURI = '$url';
</script>
EOF
}

sub print_data {
    my $cgi = shift;
    my $dbh = shift;
    my %results;
    $SearchLimit = 2000;	# set this higher for printing
    my $query = get_query($cgi) or return;
			 
	my $sth = $dbh->prepare($query);
	$sth->execute();
        my $numrows = $sth->rows;
	@results{@fields} = ();
	$sth->bind_columns(map { \$results{$_} } @fields);
	print $cgi->h2("STEDT database extract");
        my $time = scalar localtime;
        print $cgi->p($cgi->i("on: " . $time));  
	print $cgi->h3("Search terms");
	print $cgi->start_table;
	print $cgi->Tr($cgi->th("Field"),$cgi->th("Value"));
 	my @query = ();
        grep { 
		if (($cgi->param($_) ne "") && ($_ ne 'submit')) {
			push(@query,"$_: ".$cgi->param($_)); 
			print $cgi->Tr($cgi->td("$_ "),$cgi->td($cgi->param($_)));
		}
	} $cgi->param;
        #print $cgi->Tr($cgi->td("QUERY_STRING"),$cgi->td($ENV{QUERY_STRING}));
	print $cgi->end_table;
	print $cgi->h3("Search results");
	print $cgi->start_table;
	print $cgi->Tr({-valign => 'top'}, [$cgi->th(\@labels)] );
	while ($sth->fetch()) {
	    my $key = $results{$qdata->{'key'}};
	    print "<tr valign='top'>";
	    for my $field (@fields) {
		if ($editable->{$field}) {
		    my $fieldname = $field . '_' . $key;
		    print $cgi->td($results{$field});
		} elsif ($field eq 'COUNT(notes.noteid)') {
			my $n = $results{$field};
                        if ($cgi->param('submit') eq 'Print') {
				# format notes for print here...
                        }
                        else {
   				print $cgi->td("$results{$field} note" . ($n == 1 ? '' : 's'));
                        }
		} else {
		    print $cgi->td("$results{$field}");
	        }
	    }
	    print "</tr>";
	}
	print $cgi->end_table;
	if ($cgi->param('submit') eq 'Print') {
		saveResults($cgi,$time,$numrows,join(';',@query));
	}
}

sub saveResults {
        my ($cgi,$time,$numrows,$query) = @_;
	my $who = $ENV{REMOTE_ADDR};
	my $q = $ENV{QUERY_STRING};
	my $reproduce = $cgi->a({-href=>$ENV{SCRIPT_NAME} . '?' . $q} ,$query);
	my $logfile = "printfiles/list.html";

	open my $tmp_fh, ">>:utf8", $logfile or die $!;
	select $tmp_fh; # set default for print

        #print $cgi->start_table;
	print $cgi->Tr($cgi->td($reproduce),$cgi->td($who),$cgi->td($time),$cgi->td($numrows)) . "\n";
        #print $cgi->end_table;

	close $tmp_fh or die $!;
}

my $cgi = new CGI;
my $dbh = STEDTUtil::connectdb();

STEDTUtil::make_header($cgi,'STEDT Database Lexicon Search');

if (0) {
} else {
	make_query_form($cgi, $dbh) unless $cgi->param('submit') eq 'Print';###
	
	if ($cgi->param('submit') || $cgi->param('next') || $cgi->param('prev')) {
	  if ($cgi->param('submit') eq 'Print') {
		print_data($cgi, $dbh);
	  }
	  else {
	    make_update_form($cgi, $dbh);###
	  }
	}
}


$dbh->disconnect;
STEDTUtil::make_footer($cgi);
