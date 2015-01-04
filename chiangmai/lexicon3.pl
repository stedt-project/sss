#!/usr/bin/perl -wT

use strict;
use DBI;
use utf8;
use Encode qw/is_utf8 decode/;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser); #remove this later
$CGI::POST_MAX=1024 * 2;  # max 2K posts
$CGI::DISABLE_UPLOADS = 1;  # no uploads

sub process_analysis {
    my $ana = shift;
    $ana =~ s{([0-9]+)}
      {<a href="etymology.pl?tag=$1">$1</a>}xg;
    return ($ana);
}

# autoEscape(0);

print header(-charset => "utf8"), # calls charset for free, so forms don't mangle text
    start_html(-head => meta( {-http_equiv => 'Content-Type', -content => 'text/html; charset=utf8'}),
	       -encoding => 'utf-8',
	       -title=>'Query STEDT Lexicon', 
	       -style=>{'src'=>'/styles/styles.css'}),
    h1('Query STEDT Lexicon'),
    p('v.4 (9 April 2005). Mortensen, Lowe, and Yu.'),
    hr,
    start_form({-enctype => 'multipart/form-data', -method => 'GET'}),
    table( {-border => 0},
    Tr( {-valign => 'top'}, td(submit) ),
    Tr( {-valign => 'top'}, th({-class=> 'reflex'}, "Reflex"), 
	th({-class=> 'gloss'}, "Gloss"), 
	th({-class=> 'language'}, "Language"), 
	th({-class=> 'subgroup'}, "Subgroup"),
        th({-class=> 'srcabbr'}, "Source Abbr")),
    Tr( {-valign => 'top'}, td(textfield('reflex')),
	td(textfield('gloss')),
	td(textfield('language')),
	td(textfield('grp')),
        td(textfield('srcabbr'))),
	),
    end_form,
    doSearch(),
    hr;
    print end_html;

sub doSearch {
  
  if (param) {
    
    my @fields = param;
    
    my $sql= <<EndOfSQL;
SELECT analysis, reflex, gloss, gfn, language, grp,
  languagenames.srcabbr, lexicon.srcid
    FROM lexicon, languagenames, languagegroups 
    WHERE lexicon.lgid=languagenames.lgid
    AND languagenames.grpid=languagegroups.grpid
EndOfSQL
    foreach my $field (@fields) {
      my $value = param($field);
      next if (not $value);
      $sql .= " AND $field RLIKE '$value'";
    }
    $sql .= ' ORDER BY languagegroups.grpno, language, gloss, reflex LIMIT 0,1000';
    
    #print "<p>$sql</p>\n";
    
    my $host = 'localhost';
    my $db = 'stedt';
    my $db_user = 'root';
    my $db_password = '';
    
    my $dbh = DBI->connect(
			   "dbi:mysql:$db:$host",
			   "$db_user",
			   "$db_password", 
			   {
			    RaiseError => 1, 
			    AutoCommit => 1
			   }
			  )
      || die "Can't connect to the database. $DBI::errstr\n";
    
    my $set_names = qq{SET NAMES 'utf8';};
    $dbh->do($set_names);
    
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    
    
    my ($analysis, $reflex, $gloss, $gfn, $language, $grp, $srcabbr, $srcid);
    $sth->bind_columns( undef, \$analysis, \$reflex, \$gloss, \$gfn, \$language, \$grp, \$srcabbr, \$srcid );
    print <<EndOfHTML;
 <!--
<table>
 <thead>
   <tr>
     <th class="analysis">Analysis</th>
     <th class="reflex">Reflex</th>
     <th class="gloss">Gloss</th>
     <th class="gfn">Gfn</th>
     <th class="language">Language</th>
     <th class="subgroup">Subgroup</th>
     <th class="src">Source</th>
   </tr>
 </thead>
 <tbody>
--!>
EndOfHTML
    
    while ($sth->fetch()) {
      next if ($reflex eq '' or $reflex eq '*');
      $analysis = process_analysis($analysis);
      print <<EndOfHTML;
   <tr>
     <td>$analysis</td>
     <td>$reflex</td>
     <td>$gloss</td>
     <td>$gfn</td>
     <td>$language</td>
     <td>$grp</td>
     <td>$srcabbr ($srcid)</td>
   </tr>
EndOfHTML
    }
    
    #    print "</tbody>\n</table>\n";
    
    $dbh->disconnect();
  }
  
}
