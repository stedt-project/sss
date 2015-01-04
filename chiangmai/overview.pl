#!/usr/bin/perl -w


use utf8;
use DBI;
use CGI;
use CGI qw/:standard *table/;

use STEDTUtil;

my $cgi = new CGI;
my $dbh = STEDTUtil::connectdb();

sub get_stats {

my $sql = "show table status";
my $sth = $dbh->prepare($sql);

$sth->execute();

my ($Name,$Engine,$Version,$Row_format,$Rows,$Avg_row_length,$Data_length,
$Max_data_length,$Index_length,$Data_free,$Auto_increment,$Create_time,
$Update_time,$Check_time,$Collation,$Checksum,$Create_options,$Comment);

$sth->bind_columns(\$Name,\$Engine,\$Version,\$Row_format,\$Rows,\$Avg_row_length,\$Data_length,
\$Max_data_length,\$Index_length,\$Data_free,\$Auto_increment,\$Create_time,
\$Update_time,\$Check_time,\$Collation,\$Checksum,\$Create_options,\$Comment);

my %tables = (
'chapters' =>  'Chapters',
'etyma' => 'Etyma (reconstructions)',
'hptb' => 'Reconstructions from HPTB',
'languagegroups' => 'Language Groups',
'languagenames' => 'Language Names',
'lexicon' => 'Reflexes (= "lexical items"="citations")',
'lx_et_hash' => 'Links',
'notes' => 'Notes',
'srcbib' => 'Sources (of lexical data)'
) ;

while ( (my $key, my $value) = each %tables) {
  #print "$key = $value\n";
}

my $result = "<table border=\"1\"><tr><th>Table Name<th>Rows";
#my $result = "<table border=\"1\"><tr><th>Table Name<th>Rows<th>Avg. Row Length";
while ($sth->fetch()) {
  if ($tables{$Name}) {
    my $table = $cgi->a({-href=>"tagger.pl?command=showtable&table=$Name",
			 -target=>'reflexes'},$tables{$Name}) ;
    #$result .= "<tr><td>" . join("<td>",($table,$Rows,$Avg_row_length));
    $result .= "<tr><td>" . join("<td>",($table,$Rows));
    }
}
$result .= "</table>";

return $result ;
}


STEDTUtil::make_header($cgi,'STEDT Database Overview');

$overview = <<EndXML;
    The STEDT database consists of a lexical file, an etyma file, a  language file, 
    a source bibliography file, and a number of  linking files relating them. 
    Lexical data has been loaded into  
    the database from hundreds of Sino-Tibetan languages.  
    Data-sources range from published dictionaries and wordlists to  
    questionnaires solicited from field researchers. Most of the  data is entered 
    manually into the computer by STEDT personnel,  and is loaded into the 
    lexical file after extensive  proofreading. Some data has been made 
    available to us on  computer disk and was loaded directly.
EndXML

$termsofuse = <<EndXML;
This is a TEST version of the database and its "browser."
<p/>
You may search this database as much as you like, but please, at least for now, refrain from trying to crawl the entire database content, until we have a chance to complete our testing and verification.
EndXML

print $cgi->table(
  $cgi->Tr($cgi->td($cgi->h3('Overview'))),
  $cgi->Tr($cgi->td($overview)),
  $cgi->Tr($cgi->td($cgi->h3('Terms of Use'))),
  $cgi->Tr($cgi->td($termsofuse)),
  $cgi->Tr($cgi->td($cgi->h3("Database Statistics"))),
  $cgi->Tr($cgi->td("as of: ", scalar localtime)),
  get_stats($dbh)),"\n";

$dbh->disconnect;
STEDTUtil::make_footer($cgi);
