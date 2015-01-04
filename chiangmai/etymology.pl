#!/usr/bin/perl

use strict;
use utf8;
use DBI;
use CGI qw/:standard *table/;
use SyllabificationStation;
use Encode qw/decode/;
use CGI::Carp qw(fatalsToBrowser); #remove this later
use STEDTUtil;

binmode(STDOUT, 'utf8');

if (param()) {

my $dbh = STEDTUtil::connectdb();
my $sql;
my $sth;

my $etymon = param('tag');

# Query for record from Etyma database

$sql = "SELECT protoform, protogloss, chapters.semkey, chapters.chaptertitle FROM etyma, chapters WHERE etyma.chapter=chapters.semkey AND tag=?";
#print STDERR "$sql\n";
$sth = $dbh->prepare($sql);
$sth->execute($etymon);

my ($protoform, $protogloss, $chapter, $chaptertitle);
$sth->bind_columns(undef, \$protoform, \$protogloss, \$chapter,
		   \$chaptertitle); $sth->fetch() or warn "Can't get etyma info\n";

$protoform = format_protoform($protoform);
$protogloss = from_utf8_to_xml_entities($protogloss);

#print STDERR "$protoform\t$protogloss\t$chapter\t$chaptertitle\n";

print "Content-type: text/xml\n\n";

print <<EndXML;
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet href="fascicle.xsl" type="text/xsl"?>
<fascicle>
  <chapter>
  <chapternum>$chapter</chapternum>
  <chaptertitle>$chaptertitle</chaptertitle>
  <etymology>
    <stedtnum>$etymon</stedtnum>
    <paf>$protoform</paf>
    <pgloss>$protogloss</pgloss>
    <desc>
EndXML

# Query for records from Notes database for etymon

$sql = "SELECT xmlnote FROM notes WHERE id=?";
$sth = $dbh->prepare($sql);
$sth->execute($etymon);

my $note;
$sth->bind_columns(undef, \$note);

while ($sth->fetch()) {
    $note = decode('utf-8', $note);
    print "      <note>$note</note>\n";

}
print "    </desc>\n";

# Monster query from Lexicon, LanguageNames, LanguageGroups, and Lexicon-Etyma Hash

$sql = <<EndOfSQL;
SELECT DISTINCT languagegroups.grpno, grp, language, lexicon.rn, 
       (SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis, 
       reflex, gloss, languagenames.srcabbr, lexicon.srcid 
  FROM lexicon, languagenames, languagegroups, lx_et_hash
  WHERE (lx_et_hash.tag = $etymon
    AND lx_et_hash.rn=lexicon.rn
    AND languagenames.lgid=lexicon.lgid
    AND languagenames.grpid=languagegroups.grpid)
  ORDER BY languagegroups.grpno, language
EndOfSQL
# $sql = <<EndOfSQL;
# SELECT DISTINCT languagegroups.grpno, grp, language, lexicon.rn, 
#        analysis, reflex, gloss, languagenames.srcabbr, lexicon.srcid, 
#        notes.xmlnote
#   FROM lexicon, languagenames, languagegroups, lx_et_hash
#   LEFT JOIN notes ON notes.rn=lexicon.rn
#   WHERE (lx_et_hash.tag=?
#     AND lx_et_hash.rn=lexicon.rn
#     AND languagenames.lgid=lexicon.lgid
#     AND languagenames.grpid=languagegroups.grpid)
#   ORDER BY languagegroups.grpno, language
# EndOfSQL

$sth = $dbh->prepare($sql);

$sth->execute();
#$sth->execute($etymon);

my ($grpno, $grp, $language, $rn, $analysis, 
    $reflex, $gloss, $srcabbr, $srcid, $rnote);
$sth->bind_columns( undef, \$grpno, \$grp, \$language, 
		    \$rn, \$analysis, \$reflex, \$gloss, 
		    \$srcabbr, \$srcid);

my ($prev_grpno, $prev_lang);
my $first = 1;

my $syls = SyllabificationStation->new();

my $nonempty = 0;

while ($sth->fetch()) {
    $nonempty = 1;
    $gloss = from_utf8_to_xml_entities($gloss);
    $reflex = decode('utf8', $reflex);
    $analysis = decode('utf8', $analysis);
    $syls->fit_word_to_analysis($analysis, $reflex);
    my $xml = $syls->get_xml_mark_cog($etymon);

    if ($first) {
	print <<EndXML;
    <subgroup>
      <sgnum>$grpno</sgnum>
      <sgname>$grp</sgname>
EndXML
    $first = 0;
    } elsif (not $grpno eq $prev_grpno) {
	print <<EndXML;
    </subgroup>
    <subgroup>
      <sgnum>$grpno</sgnum>
      <sgname>$grp</sgname>
EndXML
    }
    print <<EndXML;
      <reflex>
    	<lgname>$language</lgname>
	<rn>$rn</rn>
	<analysis>$analysis</analysis>
	<form>$xml</form>
	<gloss>$gloss</gloss>
	<srcabbr>$srcabbr</srcabbr>
	<srcid>$srcid</srcid>
EndXML
    if ($rnote) {
	print "	<rnote>$rnote</rnote>\n";
    }
    print "      </reflex>\n";
    ($prev_grpno, $prev_lang) = ($grpno, $language);
}
print "    </subgroup>\n" if ($nonempty);

$dbh->disconnect();

print <<EndXML;
  </etymology>
</chapter>
</fascicle>
EndXML

} else {
	print 
		header,
		start_html({-encoding=>'UTF-8',-title=>'STEDT Database: Electronic Dessimination of Etymologies'}),
		start_table({border=>'1', cellpadding=>'10'}),Tr,td{width=>'40'},
		img({src=>'http://stedt.berkeley.edu/images/STB32x32.gif',align=>'LEFT'}),  
		td,h3('STEDT Database Online'),       
		b('Electronic dissemination of Etymologies'),
		td,font({-size=>'-2'}, 'v0.1 24 Mar 2005',br,'Lowe, Mortensen, Yu'),
		Tr,td({colspan=>'3'},
		start_form({ -action => 'etymology.pl'}),
		"tag? ",textfield('tag'),
		submit{name=>'Make set'},
		end_form),  
		end_table, 
		hr,"\n";
	
	print end_html;
}

sub format_protoform {
    my $string = shift;
    $string = decode('utf8', $string);
    $string =~ s{(\A|\s)(\w)}{$1*$2}gx;
    return $string;
}

sub from_utf8_to_xml_entities {
    my $string = shift;
    my @subst = (
	['&', '&amp;'],
	['<', '&lt;'],
	['>', '&gt;'],
	["'", '&apos;'],
	['"', '&quot;']);
    for my $pair (@subst) {
	my ($symbol, $entity) = @$pair;
	$string =~ s($symbol)($entity)g;
    }
    return $string;
}
