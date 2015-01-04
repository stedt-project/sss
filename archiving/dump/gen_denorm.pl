#!/usr/bin/perl
#
# script to generate denormalized versions of lexicon & etyma tables
#
# WARNING: This script alters your local mysql database temporarily
# by creating and then dropping a stedt_tags table.
#
# dwbruhn 2014-08-22

use lib '.';
use strict;
use utf8;
use STEDTUtil;

# prep I/O
my $dbh = STEDTUtil::connectdb();
binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

# prep filenames
my ($mday, $mon, $year) = (localtime)[3..5];
$year += 1900;
$mon++;
my $filename_ety = sprintf("STEDT_denormalized-etyma_%04d%02d%02d.csv", $year, $mon, $mday);
my $filename_lex = sprintf("STEDT_denormalized-lexicon_%04d%02d%02d.csv", $year, $mon, $mday);

print "Generating denormalized etyma table...\n";

# generate denormalized etyma table as tab-delimited file with column headers
`mysql --defaults-extra-file=db_creds -D stedt -e "SELECT tag, plg, protoform, protogloss,notes,chapter AS semkey FROM etyma LEFT JOIN languagegroups USING (grpid) WHERE STATUS != 'DELETE' ORDER BY tag;" > $filename_ety`;

print "Preparing temporary stedt_tags table...\n";

# remove stedt_tags table if it already exists
$dbh->do("DROP TABLE IF EXISTS stedt_tags;");

# create temporary stedt_tags table of just stedt tagging
$dbh->do("CREATE TABLE stedt_tags (PRIMARY KEY (rn)) AS
	SELECT rn, GROUP_CONCAT(tag_str) AS tagging
	FROM lx_et_hash
	WHERE uid=8
	GROUP BY rn
	ORDER BY rn;");

print "Generating denormalized lexicon table...\n";

# generate denormalized lexicon table as tab-delimited file with column headers
my @lex_rows = `mysql --defaults-extra-file=db_creds -D stedt -e "SELECT rn, languagenames.language, reflex AS form, gloss, gfn, semkey, tagging AS analysis, CONCAT_WS(' - ',grpno,grp) AS subgroup, srcabbr, citation, srcid FROM lexicon LEFT JOIN stedt_tags USING (rn) LEFT JOIN languagenames USING (lgid) LEFT JOIN languagegroups USING (grpid) LEFT JOIN srcbib USING (srcabbr) WHERE lexicon.status != 'DELETED' AND lexicon.status != 'HIDE' ORDER BY rn;"`;

# replace NULL with empty strings
foreach (@lex_rows) {
	s/\tNULL\t/\t\t/;
}

# write to file
open(LEX,">$filename_lex");
foreach (@lex_rows) {
	print LEX $_;
}
close(LEX);

print "Removing temporary stedt_tags table...\n";

# remove temporary stedt_tags table
$dbh->do("DROP TABLE IF EXISTS stedt_tags;");

print "Done! See $filename_ety and $filename_lex.\n";