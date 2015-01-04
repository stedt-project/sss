#!/usr/bin/perl
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

my $dbh = STEDTUtil::connectdb();
my $q = CGI->new;

my $srcabbr = $q->param('srcabbr');

my $a = $dbh->selectall_arrayref("SELECT lgid, language FROM languagenames WHERE srcabbr LIKE '$srcabbr' ORDER BY language");
my @ids = map {$_->[0]} @$a;
my @names = map {qq|"$_->[1]"|} @$a;

print $q->header(-charset => "utf8", '-x-json'=>qq|{"ids":[| . join(',',@ids)
	. qq|],"names":[| . join(',',@names) . "]}");

$dbh->disconnect;
