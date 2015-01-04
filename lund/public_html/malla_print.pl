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

my $SearchLimit = 2200;

# A list of database fields ordered by their sequence in the UI
my @fields = ('lexicon.rn', 'lexicon.reflex',
	     'lexicon.gloss', 'languagenames.language', 
	     'languagenames.srcabbr', 'GROUP_CONCAT(notes.xmlnote SEPARATOR " ")'
	     );
# A hash-reference consisting of database field names
# related to the names used in the user interface.
my $names = {
	     'lexicon.rn' => 'rn',
	     'lexicon.reflex' => 'Reflex',
	     'lexicon.gloss' => 'Gloss',
	     'languagenames.language' => 'Language',
	     'languagenames.srcabbr' => 'Source',
	     'GROUP_CONCAT(notes.xmlnote SEPARATOR " ")' => 'Notes',
};
my $sizes = {
	     'rn' => '8%',
	     'Reflex' => '20',
	     'Gloss' => '22',
	     'Language' => '20%',
	     'Source' => '15%',
	     'Notes' => '15%',
};
# A list of UI names in order.
my @values = map {$names->{$_}} @fields;

# A list of UI names in order.
my @labels = map {$names->{$_}} @fields;

# A hash-reference designating the fields which are editable.
my $editable = {
};
# Query strings
my $qdata = {
	     'from' => q|lexicon LEFT JOIN notes USING (rn), languagenames|,
	     # IMPORTANT: we can ignore spec='L' here because rn is only used for lexicon entries
	     'where' => 'languagenames.language LIKE \'Newar%\' AND lexicon.lgid=languagenames.lgid ',
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
	return $qdata->{'where'};
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

	print "$numrows found.";
		# cut out the extra fluff
	return unless ($numrows > 0);
	

	# now for the results/update table
	
    print $cgi->start_form(
			   {-enctype => 'multipart/form-data',
			    -method => 'POST'});	
    my $sth = $dbh->prepare($query);
    $sth->execute();
 my %results;
    @results{@fields} = ();
    # Map the columns from the query to the hash %results
    $sth->bind_columns(map { \$results{$_} } @fields);
    
    
    $cgi->delete_all(); # get rid of form defaults

	print $cgi->start_table;
	print "<tr valign='top'>";
	foreach (@values) {
		print $cgi->th({width=>$sizes->{$_}}, $_);
	}
	print "</tr>\n";
    while ($sth->fetch()) {
      my $key = $results{$qdata->{'key'}};
      print "<tr valign='top' id='$key'>";
      for my $field (@fields) {
			if ($field eq 'lexicon.rn') {
			   print $cgi->td($results{$field});
			} elsif ($field =~ /^GROUP_CONCAT/) {
				$results{$field} =~ s/<[^>]*>//g;
				print $cgi->td($cgi->escapeHTML($results{$field}));
			} else {
			  print $cgi->td($cgi->escapeHTML($results{$field}));
			  # you MUST escape the html entities!
			  # the docs say escapeHTML turns everything into HTML entities if encoding is not latin, but that can't be right...
			}
      }
      print "</tr>";
    }
	print $cgi->end_table;
    print $cgi->end_form;
}


my $cgi = new CGI;
my $dbh = STEDTUtil::connectdb();
make_header($cgi);

make_update_form($cgi, $dbh);
make_footer($cgi);

$dbh->disconnect;
