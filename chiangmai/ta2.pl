#!/usr/bin/perl -w

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
      {<a href="etymology.pl?tag=$1" target="tag$1">$1</a>}xg;
    return ($ana);
}

sub browseDB {

    my ($fields,$query,$tbl) = @_;

#    my $fields = 'protoform,protogloss,tag';
#    my $query  = "protogloss = 'foot'";
    
    my $sql = "select $fields from $tbl where $query limit 1,10;";
    
    print "$sql\n\n";
    
    my $host = 'localhost';
    my $db = 'stedt';
    my $db_user = 'root';
    my $db_password = '';

    #my $db_user = 'root';
    #my $db_password = '';
    
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
    
#my ($etymon,$protogloss);
#$sth->bind_columns( undef, \$etymon,\$protogloss);
    
#    my ($analysis, $reflex, $gloss, $gfn, $language, $grp, $srcabbr, $srcid);
#    $sth->bind_columns( undef, \$analysis, \$reflex, \$gloss, \$gfn, \$language, \$grp, \$srcabbr, \$srcid );
    
    my $tablehead = "<table border=1>\n<thead>\n<tr>\n";
    foreach (split ',',$fields) {
	$tablehead .= "<th class=\"$_\">$_</th>";
    }
    $tablehead .= "</tr>\n</thead>\n<tbody>\n";
    print $tablehead;
    
    while (my @row = $sth->fetchrow_array()) {
	#next if ($reflex eq '' or $reflex eq '*');
	#$analysis = process_analysis($analysis);
	print "<tr><td>" . join("<td>",@row) . "\n";
    }
    
    print "</tbody>\n</table>\n";
    
    $dbh->disconnect();
    
}

# autoEscape(0);

print header(-charset => "utf8"), # calls charset for free, so forms don't mangle text
    start_html(-head => meta( {-http_equiv => 'Content-Type', -content => 'text/html; charset=utf8'}),
	       -encoding => 'utf-8',
	       -title=>'Tagger\'s Assistant', 
	       -style=>{'src'=>'/styles/ta.css'}),
    h4('Tagger\'s Assistant'),
#    p({size => 'tiny'},'v.1 (5 May 2005). Lowe, Mortensen and Yu.'),
    hr,
    start_form({-enctype => 'multipart/form-data', -method => 'GET',-target => 'NResultsWindow'}),
    table( {-border => 1},    Tr( {-valign => 'top'}, th({-class=> 'dbbrow'}, "retFLds"),td({-colspan=> '8'},textfield('retFlds'))),     Tr( {-valign => 'top'}, th({-class=> 'dbbrow'}, "search"),td({-colspan=> '8'},textfield('search'))), 
    Tr( {-valign => 'top'}, th({-class=> 'reflex'}, "Form"),td({-colspan=> '8'},textfield('reflex'))), 
    Tr( {-valign => 'top'}, th({-class=> 'gloss'}, "Gloss"),td({-colspan=> '8'},textfield('gloss'))), 
    Tr( {-valign => 'top'}, th({-class=> 'language'}, "Language"),td({-colspan=> '8'},textfield('language'))), 
    Tr( {-valign => 'top'}, th({-class=> 'subgroup'}, "Subgroup"),td({-colspan=> '8'},textfield('grp'))),
    Tr( {-valign => 'top'}, 
        th({-class=> 'initial'}, "Struct"),
	th({-class=> 'initial'}, "I"),td(textfield({size => 3},'initial')),
	th({-class=> 'initial'}, "R"),td(textfield({size => 3},'rhyme')),
	th({-class=> 'initial'}, "T"),td(textfield({size => 3},'tone')),
	th({-class=> 'initial'}, "Syll"),td(textfield({size => 8},'syll')),
	),
    Tr( {-valign => 'top'}, 
	th({-class=> 'Query'}, "Search"),
	td({-colspan=> '8'},
	   submit(-name=>'Query',-value=>'Cognate Sets'),
	   submit(-name=>'Query',-value=>'Etymologies'),
	   submit(-name=>'Query',-value=>'Lexicon'),
	   reset) ),
	 ),
    end_form
    ;

if (param) {

    browseDB(param('retFlds'),param('search'),param('reflex')) ;
}
else {
    
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
	    next if ($field eq "Query");
	    $sql .= " AND $field LIKE '$value'";
	}
    $sql .= ' ORDER BY languagegroups.grpno, language, gloss, reflex LIMIT 1,1000';
    
    print "<p>$sql</p>\n";
    
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

    print "</tbody>\n</table>\n";

    $dbh->disconnect();
}

sub genSQL {
    
    my @fields = $_;
    my $lexfields = 'analysis, reflex, gloss, gfn, language, grp, languagenames.srcabbr, lexicon.srcid';
    my $sql= 'SELECT  $lexfields FROM  lexicon, languagenames, languagegroups ' .
	'WHERE lexicon.lgid=languagenames.lgid AND languagenames.grpno=languagegroups.grpno ' ;
    foreach my $field (@fields) {
	my $value = param($field);
	next if (not $value);
	$sql .= " AND $field LIKE '$value'";
    }
    $sql .= ' ORDER BY languagegroups.grpno, language, gloss, reflex LIMIT 1,1000';
    
    print "<p>$sql</p>\n";
    
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

    print "</tbody>\n</table>\n";

    $dbh->disconnect();
}

print end_html;
