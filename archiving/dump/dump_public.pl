#!/usr/bin/perl
#
# script to sanitize STEDT database and dump it for public dissemination
# sanitize users table (delete inactive users, clear emails, reset passwords to 'pass')
# clear sessions and querylog tables
# generate mysql dump
#
# WARNING: This script alters your local mysql database. Have a backup!
# Also, note that all tables get dumped, so drop any scratch/bkup tables first
#
# dwbruhn 2014-08-11

use lib '.';
use strict;
use utf8;
use STEDTUtil;

# prep I/O
my $dbh = STEDTUtil::connectdb();
binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

# prep filename
my ($mday, $mon, $year) = (localtime)[3..5];
$year += 1900;
$mon++;
my $filename = sprintf("STEDT_public_%04d%02d%02d.sql", $year, $mon, $mday);

# query to get uids of guest account & active users (those with tags, etyma, notes, changes, or mesoroots)
my $query_users = "SELECT DISTINCT uid FROM lx_et_hash UNION
		SELECT DISTINCT uid FROM etyma UNION
		SELECT DISTINCT uid FROM changelog UNION
		SELECT DISTINCT uid FROM notes UNION
		SELECT DISTINCT uid FROM mesoroots UNION
		SELECT DISTINCT owner_uid AS uid FROM changelog WHERE owner_uid > 0 UNION
		SELECT uid FROM users WHERE username = 'guest'
		ORDER BY uid";

my @uids = @{$dbh->selectcol_arrayref($query_users)};

# delete inactive users
my $del_users = "DELETE FROM users WHERE uid NOT IN(" . join(',', ('?') x @uids) . ")";
my $num_deleted = $dbh->do($del_users, undef, @uids);
print "$num_deleted inactive users deleted.\n";

# clear email addresses
my $emails = $dbh->do("UPDATE users SET email=''");
print "$emails email addresses cleared.\n";

# reset passwords (leave guest password as 'guest')
my $pass = $dbh->do("UPDATE users SET password=sha1('pass') WHERE username != 'guest'");
print "$pass passwords reset to 'pass'.\n";

# clear sessions table
my $sessions = $dbh->do("DELETE FROM sessions");
print "$sessions sessions deleted.\n";

# clear querylog table
my $queries = $dbh->do("DELETE FROM querylog");
print "$queries queries deleted from querylog.\n";

# dump db to file
print "Beginning database dump...\n";
`mysqldump --defaults-extra-file=db_creds -l --add-drop-database --databases stedt > $filename`;
print "Bzipping it...\n";
`bzip2 -f $filename`;
print "Completed!\n";