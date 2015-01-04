#!/usr/bin/perl -wT

use strict;
use CGI qw/:standard :cgi-lib/;

print header(-charset => "utf8"); # calls charset for free, so forms don't mangle text

if (param) {
    print Dump;
} else {
	print "this script dumps the params of a cgi script.";
	foreach ( keys %ENV ) {
	    print "$_\t$ENV{$_}\n";
	    }
}
