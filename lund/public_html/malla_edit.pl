#!/usr/bin/perl -wT
# edited by dwbruhn to use protected pm, 2010-December-07

use strict;
use DBI;
use CGI;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser set_message/;
BEGIN {
        $^W = 1;
        unshift @INC, "../pm" if -e "../pm";
        CGI::Carp::set_message("Report bugs/features to stedt@socrates.berkeley.edu");
}
use STEDTUtil;

my $SearchLimit = 200;

# A list of database fields ordered by their sequence in the UI
my @fields = ('lexicon.rn', 'lexicon.reflex',
	     'lexicon.gloss', 'languagenames.language', 
	     'languagenames.srcabbr', 'COUNT(notes.noteid)'
	     );
# A hash-reference consisting of database field names
# related to the names used in the user interface.
my $names = {
	     'lexicon.rn' => 'RecNum',
	     'lexicon.reflex' => 'Reflex',
	     'lexicon.gloss' => 'Gloss',
	     'languagenames.language' => 'Language',
	     'languagenames.srcabbr' => 'Source (blank == KPM-pc)',
	     'COUNT(notes.noteid)' => 'Notes',
	     'lexicon.srcid' => 'srcid'
};
# A list of UI names in order.
my @values = map {$names->{$_}} @fields;

# A list of UI names in order.
my @labels = map {$names->{$_}} @fields;

# A hash-reference designating the fields which are editable.
my $editable = {
		 'lexicon.analysis' => 1,
		 'lexicon.reflex' => 1,
		 'lexicon.gloss' => 1,
		 'languagenames.language' => 1,
		 'languagenames.srcabbr' => 1,
		 };
# Query strings
my $qdata = {
	     'from' => q|lexicon LEFT JOIN notes USING (rn), languagenames|,
	     # IMPORTANT: we can ignore spec='L' here because rn is only used for lexicon entries
	     'where' => 'lexicon.lgid=languagenames.lgid ',
	     'order' => 'languagenames.language, lexicon.gloss',
	     	#'lexicon.gloss,languagegroups.grp,languagenames.language',
	     	# ,lexicon.reflex
	     'table' => 'lexicon',
	     'key' => 'lexicon.rn',
};

######################################################################
# DATABASE CONNECTIVITY
######################################################################

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
  	"ORDER BY $order LIMIT $limita, $SearchLimit";
#  	" LIMIT $limita, $SearchLimit";
}

sub query_where {
	my $cgi = shift;
	my @wheres;
	my $query_ok = 0;
	
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
						$restriction = $key . " RLIKE '[[:<:]]" . $value . "'";# . "[[:>:]]'";
					}
				} else {
					$restriction = $key . " RLIKE '" . $value . "' ";
				}
				push @restrictions, $restriction;
			}
			push(@wheres, "(" . join(" OR ", @restrictions) .")");
		}
	}
	return $query_ok ? join(' AND ', ($qdata->{'where'}, @wheres)) : '';
}

# Save the data in the update form (regardless of whether it has
# changed or not)
sub save_data {
  my $cgi = shift;
  my @params = $cgi->param;
  my $dbh = STEDTUtil::connectdb();
  # SQL and handle for deleting records from lx_et_hash
  my $delete = qq{DELETE FROM lx_et_hash WHERE rn=?};
  my $delete_sth = $dbh->prepare($delete);
  # SQL and handle for inserting records into lx_et_hash
  my $insert = qq{INSERT INTO lx_et_hash (rn, tag, ind) VALUES (?, ?, ?)};
  my $insert_sth = $dbh->prepare($insert);
  # Iterate over parameters
  foreach my $param (@params) {
    # Find the parameters that have a numeric suffix
    if ($param =~ m/(.+)_([0-9]+)/) {
      # Assume that the first part of the parameter is a field name
      # and that the suffix is a record number
      my ($field, $id) = ($1, $2);
      # Only allow things to change if the field is designated as
      # editable.
      if ($editable->{$field} && $field ne 'languagenames.language') {
		my $value = $cgi->param($param);
        if ($field eq 'languagenames.srcabbr') {
        	
        	next unless $value eq '';
        
        	my %name2id = ('Newari'=>1918, 'Newari (Kathmandu)'=>1919, 'Newari (Dolakhali)'=>1931);
        	$field = 'lexicon.lgid';
        	$value = $name2id{$cgi->param("languagenames.language_$id")};
        }
		
		
		# SQL and handle for updating records in lexicon
		my $update = qq{UPDATE lexicon SET $field=? WHERE rn=?};
		my $update_sth = $dbh->prepare($update);
		$update_sth->execute($value, $id);
		# Do special things for the analysis field.
		if ($field eq 'lexicon.analysis') {
		  # Delete records from lx_et_hash where the rn matches $field
		  $delete_sth->execute($id);
		  my $index = 0;
		  # Split the contents of the field on contents
		  for my $tag (split(/, */, $value)) {
			# Insert new records into lx_et_hash based upon the new
			# value of the analysis field
			$insert_sth->execute($id, $tag, $index) if ($tag =~ /^\d+$/);
			$index++;
		  }
		}
      }
    }
  }
}

sub delete_data {
  my $cgi = shift;
  my $dbh = shift;
  my @params = $cgi->param;

  foreach my $param (@params) {
    if ($param =~ m/^delete_([0-9]+)/) {
      my $id = $1;
      my $table = $qdata->{'table'};
      my $key = $qdata->{'key'};
      my $delete = qq{DELETE FROM $table WHERE $key=$id};
      my $delete_sth = $dbh->prepare($delete);
      $delete_sth->execute();
      
      # now for the lx_et_hash
      $delete = qq{DELETE FROM lx_et_hash WHERE rn=?};
      $delete_sth = $dbh->prepare($delete);
      $delete_sth->execute($id);
    }
  }
}

######################################################################
# HTML GENERATION
######################################################################

sub make_header {
  my $stylesheet = 'styles/tagger.css';
  my $cgi = shift;
  print $cgi->header(-charset => "utf8");
  print $cgi->start_html(-head =>
			 $cgi->meta( 
				    {-http_equiv => 'Content-Type', 
				     -content => 'text/html; charset=utf8'}),
			 -encoding => 'utf-8',
			 -title=>'Edit STEDT Database', 
			 -style=>{'src'=>$stylesheet},
	);
}

sub make_footer {
  my $cgi = shift;
  print $cgi->end_html;
}

sub make_query_form {
  my $cgi = shift;
  my $dbh = shift;
  
  # get list of proto-lgs

  print $cgi->start_form(-method => 'GET');
  print $cgi->start_table(-border => '0');
  print $cgi->Tr($cgi->td($cgi->submit("submit", "Search Lexicon"),
  	    	$cgi->param('sortkey') ? $cgi->hidden( -name => 'sortkey',
			    -default => $cgi->param('sortkey')) : ''));
  print $cgi->Tr({-valign => 'top'}, [$cgi->th([grep {$_ ne 'Notes'} @values])] );
  print "<tr valign='top'>";
  foreach my $field (@fields) {
  	if ($field eq 'COUNT(notes.noteid)') {
  		# do nothing
  	} else {
		print $cgi->td($cgi->textfield(-name => $field,
										-value=>'', -override=>1,
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
	if ($sortkey) {
		$qdata->{'order'} = $sortkey;
	}

    my $query = get_query($cgi) or return;
  
  		# print $query, $cgi->br();return;
    
    # count the records in our result
    
 	my $where = query_where($cgi);
	my $numrows = $dbh->selectrow_array("SELECT COUNT(*) from lexicon, languagenames"
		. " WHERE $where");

	print "$numrows found. (WHERE ".substr($where,length($qdata->{where})+5).")";
		# cut out the extra fluff
	return unless ($numrows > 0);
	


	# implement our paging algorithm
	if ($numrows > $SearchLimit) {
		print $cgi->start_form;
		foreach my $field (@fields, 'sortkey') {
			if ($cgi->param($field)) {
				print $cgi->hidden( -name => $field,
						-default => $cgi->param($field));
			}
		}


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

		# print $cgi->submit('submit', 'Print');
		print $cgi->end_form;
	}


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
	
    
    # create links to be placed in <TH> for sorting
    my $fakeq = CGI->new;
    $fakeq->delete_all();
    foreach my $field ('submit', @fields) {
		$fakeq->param($field, $cgi->param($field)) if ($cgi->param($field));
    }
    my @sortlinks;
	for (0..(scalar @values - 1)) {
		$fakeq->param('sortkey',$fields[$_]);
		push @sortlinks, $fakeq->a({-href=>$fakeq->self_url},$values[$_]);
	}
	
    my $sth = $dbh->prepare($query);
    $sth->execute();
 my %results;
    @results{@fields} = ();
    # Map the columns from the query to the hash %results
    $sth->bind_columns(map { \$results{$_} } @fields);
    
    
    
    
    $cgi->delete_all(); # get rid of form defaults

	print $cgi->start_table;
    # print $cgi->Tr({-valign => 'top'}, [$cgi->th(\@values)] );
	push @sortlinks, 'Delete';
	print $cgi->Tr({-valign => 'top'}, [$cgi->th(\@sortlinks)] );
    while ($sth->fetch()) {
      my $key = $results{$qdata->{'key'}};
      print "<tr valign='top' id='$key'>";
      for my $field (@fields) {
	if ($editable->{$field}) {
	  my $fieldname = $field . '_' . $key;
	  print $cgi->td(
	  		
	  		($field eq 'lexicon.analysis' && $results{$field}
	  			? $cgi->a({-href=>"etyma.pl?submit=Search%20Etyma&etyma.tag=$results{$field}",-target=>'etyma_detail'},'↩')
	  			: ()),
	  			
	  			$cgi->textfield(
					 -name => $fieldname,
					 -value => $results{$field},	# (escaping is automatically done for forms)
					 -size => ($field =~ /reflex|gloss/ ? 25 : 12)
	                )
	  	);
	} elsif ($field eq 'languagenames.srcabbr') {
	   print $cgi->td($cgi->a({-href=>"srcbib.pl?submit=Search+Etyma&srcbib.srcabbr=$results{$field}", -target=>'srcbib'},
								$results{$field}));
	} elsif ($field eq 'COUNT(notes.noteid)') {
		my $n = $results{$field};
		print $cgi->td($cgi->a({-href=>"notes.pl?L=$key", -target=>'noteswindow'},
			$n == 0 ? "+..." : "$results{$field} note" . ($n == 1 ? '' : 's')));
	} elsif ($field eq 'lexicon.rn') {
	   print $cgi->td($results{$field});
	} else {
	  print $cgi->td($cgi->escapeHTML($results{$field}));
	  # you MUST escape the html entities!
	  # the docs say escapeHTML turns everything into HTML entities if encoding is not latin, but that can't be right...
	}
      }
      # the delete checkbox
      my $checkboxname = 'delete' . '_' . $key;
	  print $cgi->td($cgi->checkbox(-name => $checkboxname,
					  -value => 'off',
					 -label => ''));
      print "</tr>";
    }
    print $cgi->tfoot(
    	$cgi->Tr($cgi->td($cgi->submit('submit', 'Save All')),
    			$cgi->td($cgi->reset)),
		$cgi->Tr($cgi->td($cgi->submit(-name=>'submit', -value=>'Delete Selected',-onClick=>"if (confirm('Are you sure you want to delete this record?')) return true; else return false;")))
	);
	print $cgi->end_table;
    print $cgi->end_form;
	my $url = $cgi->url(-absolute=>1);
}

sub print_data {
    my $cgi = shift;
    my $dbh = shift;
    my %results;
    $SearchLimit = 2000;	# set this higher for printing
    my $query = get_query($cgi) or return;
				 
	my $sth = $dbh->prepare($query);
	$sth->execute();
	@results{@fields} = ();
	$sth->bind_columns(map { \$results{$_} } @fields);
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
			print $cgi->td("$results{$field} note" . ($n == 1 ? '' : 's'));
		} else {
		    print $cgi->td("$results{$field}");
	        }
	    }
	    print "</tr>";
	}
	print $cgi->end_table;
}


my $cgi = new CGI;
my $dbh = STEDTUtil::connectdb();
if ($cgi->param('row')) {	# for TableKit AJAX magic
	print $cgi->header(-charset => "utf8");
	my ($field, $id, $value) = ($cgi->param('field'), $cgi->param('id'), $cgi->param('value'));
	my $table = $qdata->{'table'};
	my $key = $qdata->{'key'};
	my $update = qq{UPDATE $table SET $field=? WHERE $key=?};
	my $update_sth = $dbh->prepare($update);
	$update_sth->execute($value, $id);
	print $value;	## transmogrify if necessary
} else {
	make_header($cgi);
	make_query_form($cgi, $dbh) unless $cgi->param('submit') eq 'Print';###
	
	if ($cgi->param('submit') || $cgi->param('next') || $cgi->param('prev')) {
	  if ($cgi->param('submit') eq 'Save All') {
		save_data($cgi, $dbh);
	  } elsif ($cgi->param('submit') eq 'Delete Selected') {
		save_data($cgi, $dbh);
		delete_data($cgi, $dbh);
	  } elsif ($cgi->param('submit') eq 'Print') {
		print_data($cgi, $dbh);
	  }
	  make_update_form($cgi, $dbh) unless $cgi->param('submit') eq 'Print';###
	}
	make_footer($cgi);
}

$dbh->disconnect;
