#!/usr/bin/perl -wT
# edited by dwbruhn to use protected pm, 2010-December-07

use strict;
use CGI qw/:standard :cgi-lib/;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser set_message/;
BEGIN {
        $^W = 1;
        unshift @INC, "../pm" if -e "../pm";
        CGI::Carp::set_message("Report bugs/features to stedt@socrates.berkeley.edu");
}
use STEDTUtil;

print header(-charset => "utf8"); # calls charset for free, so forms don't mangle text

use utf8;
use DBI;


my ($sql, $sth);

my $dbh = STEDTUtil::connectdb();

# Drop existing hash table
$dbh->do("DROP TABLE IF EXISTS lx_et_hash");

# Create a new hash table
$sql = <<EndOfSQL;
CREATE TABLE lx_et_hash
	(
	 rn MEDIUMINT UNSIGNED NOT NULL,
	 tag VARCHAR(15) NOT NULL,
	 ind TINYINT UNSIGNED NOT NULL);
EndOfSQL
#id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
#	  INDEX xrntag (rn,tag));
#EndOfSQL
$dbh->do($sql);

# Query for all lexicon records with non-null analysis field
$sql = <<EndOfSQL;
SELECT rn, analysis
	FROM lexicon
	WHERE analysis NOT LIKE ''
EndOfSQL
$sth = $dbh->prepare($sql);
$sth->execute();

# Query to insert values into the hash table
$sql = <<EndOfSQL;
INSERT 
	INTO lx_et_hash (rn, tag, ind)
	VALUES (?,?,?);
EndOfSQL
my $isth = $dbh->prepare($sql)
	or die "Can't prepare SQL statement.\n";

my $num_done = 0;
while (my @row = $sth->fetchrow_array() ) {
	my ($rn, $analysis) = @row;
	my $ind = 0;
	foreach my $tag (split (/, */, $analysis)) {
		$isth->execute($rn, $tag, $ind); # if ($tag =~ /^\d+$/);
		print "WARNING! rn $rn has a tag longer than 15 chars!" if length($tag) > 15;
		$ind++;
	}
	if ($num_done++ % 10000 == 0) { print "$num_done<br>" }
}
print $num_done . "\nAdding rn index...\n";
$dbh->do("ALTER TABLE `lx_et_hash` ADD INDEX ( `rn` )");
print "Adding tag index...\n";
$dbh->do("ALTER TABLE `lx_et_hash` ADD INDEX ( `tag` )");
print "done\n";
