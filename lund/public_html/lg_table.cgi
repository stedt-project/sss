#!/usr/bin/perl
# edited by dwbruhn, 2009-Dec-15
# rscook 2009年12月12日
# by Dominic Yu, 2009.12.09
# based on HTML and work by Daniel Bruhn
# based on initial work by Nina Keefer and rscook

use CGI::Carp qw/fatalsToBrowser warningsToBrowser set_message/;
BEGIN { 
	$^W = 1; 
	unshift @INC, "../pm" if -e "../pm";
	CGI::Carp::set_message("Report bugs/features to stedt@berkeley.edu");
}

use CGI qw/:standard *table/;
use STEDTUtil;

my $dbh = STEDTUtil::connectdb();

# open the language lookup table and make our hash
open F, "<:utf8", "sil2lg.txt" or die $!;
my %sil2lg;
while (<F>) {
	my ($silcode, $lgname) = split /\t/;
	if ($silcode eq "mwq") {
	    $lgname = "Mün Chin";  #this is a cheap hack to fix the display of u-umlaut
	}

	$sil2lg{$silcode} = $lgname;
}
close F or die $!;


# print HTML headers and stuff
print header(-charset => "UTF-8"), # calls charset for free, so forms don't mangle text
    start_html(-head => meta( {-http_equiv => 'Content-Type', -content => 'text/html; charset=UTF-8'}),
	       -encoding => 'UTF-8',
	       -title=>'STEDT Database Language Statistics');

my $time = scalar localtime;
print <<EOF;
<h2 align="center">STEDT Database Language Statistics</h2>
<p align="center">(as of $time)</p>
EOF


my @stats = (
[ 'Total language entries (unique to source):', 'SELECT count(*) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid)', 'e.g. <i>Bantawa</i> from Rai (1985), <i>Bantawa</i> from Weidert (1987), and <i>Lahu</i> from Weidert (1987) are 3 separate entries' ],
[ 'Unique ISO 639-3 codes:', 'SELECT -1 + count(distinct(silcode)) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid)', '<b>underestimates</b> the true number of languges in the database, because not all language entries have codes assigned' ],
[ 'Unique language names:', 'SELECT count(distinct(language)) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid)', '<b>overestimates</b> the true number of languages in the database, due to variant names for the same language (e.g. <i>Darang Deng</i> and <i>Digaro</i>)' ],
[ 'Language entries with ISO 639-3 codes:', 'SELECT count(*) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode<>""', '' ],
[ 'Language entries without ISO 639-3 codes:', 'SELECT count(*) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode=""', '' ],
[ 'Unique combinations of language name + ISO 639-6 code:', 'SELECT language, silcode, count(*) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode<>"" GROUP BY language, silcode', 'e.g. <i>Bai</i> [bca] and <i>Bai</i> [bfs] are 2 separate entries; <i>Ao (Chungli)</i> [njo] and <i>Ao (Mongsen)</i> [njo] are also 2 separate entries' ],
[ 'Unique language names without ISO 639-3 codes:', 'SELECT count(distinct(language)) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode=""', '(see the <b>NO CODE</b> section of the table below)' ],
[ 'Language names that correspond to more than one unique ISO 639-3 code:', 'SELECT language, count(language) FROM (SELECT language, silcode FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode<>"" GROUP BY language, silcode) AS table1 GROUP BY language HAVING count(*)>1', 'e.g. <i>Bai</i> [bfs, bca], <i>Chinese</i> [och, cmn], <i>Tujia</i> [tjs, tji]' ],
[ 'ISO 639-3 codes that correspond to exactly one unique language name:', 'SELECT silcode, count(silcode) FROM (SELECT silcode, language FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode<>"" GROUP BY silcode, language) AS table1 GROUP BY silcode HAVING count(*)=1', 'e.g. [aim] => <i>Aimol</i>, [adl] => <i>Gallong</i>' ],
[ 'ISO 639-3 codes that correspond to multiple unique language names:', 'SELECT silcode, count(silcode) FROM (SELECT silcode, language FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode<>"" GROUP BY silcode, language) AS table1 GROUP BY silcode HAVING count(*)>1', 'e.g. [kdv] (<i>Andro</i>, <i>Ganan</i>, <i>Kadu</i>, <i>Sak</i>, <i>Sengmai</i>, etc.), [bap] (<i>Bantawa</i>, <i>Rungchangbung</i>)' ],
);


print "<table border=\"1\" align=\"center\" cellpadding=\"5\" cellspacing=\"1\">";
print "<tr bgcolor=\"#99CCFF\"><th align=\"left\">Statistic</th><th align=\"left\">Number</th><th align=\"left\">Notes</th></tr>";
foreach (@stats) {
	my ($desc, $query, $notes) = @$_;
	print "<tr><td>$desc</td><td align=\"right\">";
	my $a = $dbh->selectall_arrayref($query);
	if (1 == @$a) { # if contains one row, print the value
		print $a->[0][0];
	} else {
		print scalar @$a;
	}
	print "</td><td>$notes</td></tr>\n";
}
print "</table>";

print <<EOF;
<br/><br/>
<table border="1" cellpadding="1" cellspacing="0" align="center">
 <tr align="left" bgcolor="#99CCFF">
  <th>ISO 639-3 Code&nbsp;&nbsp;</th>
  <th>Ethnologue Name</th>
  <th>STEDT Name(s)</th>
  <th>Sources</th>
 </tr>
EOF


# look up stuff from the database
my $a = $dbh->selectall_arrayref("SELECT silcode,language,COUNT(*) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) GROUP BY silcode,language ORDER BY silcode");

# first pass: move empty silcodes to end
while ($a->[0][0] eq '')
	# test if the silcode is empty
	# (they're sorted so the empty ones are at the top)
{
	push @$a, shift @$a; # take the first item and tack it to the end
}

# second pass: count number of lines for each sil code
my %sil_count;
foreach (@$a) {
	my $silcode = $_->[0];
	$sil_count{$silcode}++;
}

# third pass: count number of lines for each sil code
my $lastsilcode = '';
foreach (@$a) {
	my ($silcode, $lgname, $num) = @$_;
	print "<tr>";
	if ($silcode ne $lastsilcode) {
		my $n = $sil_count{$silcode};
		if ($silcode) {
			print td({-rowspan=>$n}, a({-href=>"http://www.sil.org/iso639-3/documentation.asp?id=$silcode"},$silcode)),
				  td({-rowspan=>$n}, a({-href=>"http://www.ethnologue.com/show_language.asp?code=$silcode"},$sil2lg{$silcode}));
		} else {
			print td({-rowspan=>$n, -colspan=>2, -valign=>'top'}, "<b>NO CODE</b>");
		}
		$lastsilcode = $silcode;
	}
	print td($lgname), td($num);
	print "</tr>\n";
}

print end_table;

print <<EOF;
<p align="center">
    <a href="http://validator.w3.org/check?uri=referer"><img
        src="http://www.w3.org/Icons/valid-xhtml10-blue"
        alt="Valid XHTML 1.0 Transitional" /></a>
</p>
EOF

print end_html;
