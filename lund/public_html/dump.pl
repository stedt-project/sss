#!/usr/bin/perl -wT

use strict;
use CGI qw/:standard :cgi-lib/;

print header(-charset => "utf8"), # calls charset for free, so forms don't mangle text
    start_html(-head => meta( {-http_equiv => 'Content-Type', -content => 'text/html; charset=utf8'}),
	       -encoding => 'utf-8',
	       -title=>'param dump test script', 
	       -style=>{'src'=>'/styles/tagger.css'});

if (param) {
    print Dump;
} else {
	print "this script dumps the params of a cgi script."
}
print end_html;
