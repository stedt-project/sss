#!/usr/bin/perl -wT

# edited by dwbruhn to use protected STEDTUser.pm, 2010-May-16
# chapters.pl
# by Dominic Yu
# 2007.03.04
# ----------
# This lets you browse the chapters of the STEDT database.
# Currently the chapters are only for Vol I, Body Parts.
# Presumably the other seven volumes are forthcoming, but not
# yet planned in the database.
#
# No editing here; use phpmyadmin for that.

use strict;
use DBI;
use CGI;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser set_message/;
BEGIN {
        $^W = 1;
        unshift @INC, "../pm" if -e "../pm";
        CGI::Carp::set_message("Report bugs/features to stedt@socrates.berkeley.edu");
}
use STEDTUser;


my $cgi = new CGI;
my $self = $cgi->url(-relative=>1);
make_header($cgi);
my $dbh = STEDTUser::connectdb();

my $chapter = $cgi->param('c');
my $section = $cgi->param('s');
if (!$chapter) {
	my $a = $dbh->selectall_arrayref(
		q#SELECT chapter, chaptertitle, chapterabbr, chapter+0 FROM `chapters`
		WHERE `chapter` rlike '^[0-9]{1,2}\.0$' order by 4#);
	for my $row (@$a) {
		my ($num, $title, $abbr, $c) = @$row;
		print $cgi->p("$num " . $cgi->a({-href=>"$self?c=$c"},$title)
						. ($abbr ? " ($abbr)" : ''));
	}
} elsif ($chapter && !$section) {
	my $a = $dbh->selectall_arrayref(
		qq#SELECT chapter, chaptertitle, chapterabbr FROM `chapters`
		WHERE `chapter` like '$chapter.%' order by 1#);
	my $counts = $dbh->selectall_arrayref(
		qq#SELECT chapter, COUNT(*) FROM `etyma` WHERE chapter LIKE '$chapter.%'
		GROUP BY chapter #);
	my %etyma_count;
	for my $r (@$counts) {
		$etyma_count{$r->[0]} = $r->[1];
	}
	for my $row (@$a) {
		my ($num, $title, $abbr) = @$row;
		print $cgi->p("$num " . ($etyma_count{$num} ? $cgi->a({-href=>"$self?c=$num"},$title) : $title)
						. ($etyma_count{$num} ? " ($etyma_count{$num} etyma)" : '')
						. ($abbr ? " [$abbr]" : '')
					);
		delete $etyma_count{$num};
	}
	print "Orphaned etyma: " if %etyma_count;
	for (sort keys %etyma_count) {
		print $cgi->a({-href=>"$self?c=$_"}, $_ . " ($etyma_count{$_} etyma)") . " ";
	}
	print $cgi->hr;
	print $cgi->a({-href=>$self},"back to chapters");
} else {
	
}

$dbh->disconnect;
print $cgi->end_html;


sub make_header {
  my $cgi = shift;
  print $cgi->header(-charset => "utf8");
  print $cgi->start_html(-head =>
			 $cgi->meta( 
				    {-http_equiv => 'Content-Type', 
				     -content => 'text/html; charset=utf8'}),
			 -encoding => 'utf-8',
			 -title=>'STEDT Database - Chapters (Vol. I)', 
#			 -style=>{'src'=>$stylesheet}
		);
}
