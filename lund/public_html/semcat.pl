#!/usr/bin/perl -w
# edited by dwbruhn to use protected pm, 2010-December-07

use strict;
use utf8;
use DBI;
use CGI;

use CGI qw/:standard *table/;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser set_message/;
BEGIN {
        $^W = 1;
        unshift @INC, "../pm" if -e "../pm";
        CGI::Carp::set_message("Report bugs/features to stedt@socrates.berkeley.edu");
}
use STEDTUtil;

print 
    header,
    start_html({-encoding=>'UTF-8'},'STEDT Database: Electronic Dessimination of Etymologies'),
    start_table({border=>'1', cellpadding=>'10'}),Tr,td{width=>'40'},
    img({src=>'http://stedt.berkeley.edu/images/STB32x32.gif',align=>'LEFT'}),  
    td,h3('STEDT Database Online'),       
    b('Electronic dissemination of Etymologies'),
    td,font({-size=>'-2'}, 'v0.1 24 Mar 2005',br,'Lowe, Mortensen, Yu'),
    Tr,td({colspan=>'3'},start_form,
    "semcat? ",textfield('tag'),
    submit{name=>'Make set'},
    end_form),  
    end_table, 
    hr,"\n";

if (param) {
    print 
	"Tag ",em(param('tag')),p;
    print fixup(get_data(param('tag')));
    }
print end_html;

sub fixup {
    $_ = shift;
    #s/</&lt;/g;
    #s/>/&gt;<br>/g;
    #return $_;
    s/sgnum/i/g;
    s/reflex/p/g;
    s/sgname/b/g;
    s/gloss>/i>/g;
    s/subgroup/li/g; 
    s/lgname/i/g;
    s/srcabbr/emph/g;
    s/analysis/span/g;
    s/form/i/g;
    s/cognate/b/g;
    s/rn>/tt>/g;
    return $_ ;
}

sub get_data {

my $dbh = STEDTUtil::connectdb();

my $etymon = shift;

# Query from Etyma database

# Query from Notes database, for etymon notes

# Monster query from Lexicon, LanguageNames, LanguageGroups, and Lexicon-Etyma Hash

my $sql = "SELECT lexicon.grpno, grp, language, lexicon.rn, analysis, reflex, gloss, lexicon.srcabbr, notes.note, lexicon.semcat  FROM lexicon, languagenames, languagegroups, lx_et_hash LEFT JOIN notes ON notes.matchinlex=lexicon.rn WHERE (lexicon.semcat=? AND (languagenames.lgabbr=lexicon.lgabbr AND languagenames.srcabbr=lexicon.srcabbr) AND languagenames.groupabbr=languagegroups.groupabbr) ORDER BY lexicon.gloss, lexicon.language";

my $sth = $dbh->prepare($sql);

$sth->execute($etymon);

my ($grpno, $grp, $language, $rn, $analysis, $reflex, $gloss, $srcabbr, $note);
$sth->bind_columns( undef, \$grpno, \$grp, \$language, \$rn, \$analysis, \$reflex,
		    \$gloss, \$srcabbr, \$note);

my ($prev_grpno, $prev_lang);
my $first = 1;
my$result;

while ($sth->fetch()) {
    if ($first) {
       $result =<<EndXML;
    <subgroup>
      <sgnum>$grpno</sgnum>
      <sgname>$grp</sgname>
EndXML
    $first = 0;
    } elsif (not $grpno eq $prev_grpno) {
	$result .=<<EndXML;
    </subgroup>
    <subgroup>
      <sgnum>$grpno</sgnum>
      <sgname>$grp</sgname>
EndXML
    }
    $result .=<<EndXML;
      <reflex>
    	<lgname>$language</lgname>
	<analysis>$analysis</analysis>
	<rn>$rn</rn>
	<form><cognate>$reflex</cognate></form>
	<gloss>$gloss</gloss>
	<srcabbr>$srcabbr</srcabbr>
EndXML
    if ($note) {
	$result .="	<rnote>$note</rnote>\n";
    }
    $result .="      </reflex>\n";
    ($prev_grpno, $prev_lang) = ($grpno, $language);
}
$result .="    </subgroup>\n";

$dbh->disconnect();

return $result ;
}
