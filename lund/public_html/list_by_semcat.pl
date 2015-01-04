#!/usr/bin/perl -w
# edited by dwbruhn to use protected STEDTUser.pm, 2010-December-07

use strict;
use utf8;
use DBI;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser set_message/;
BEGIN {
        $^W = 1;
        unshift @INC, "../pm" if -e "../pm";
        CGI::Carp::set_message("Report bugs/features to stedt@socrates.berkeley.edu");
}
use STEDTUser;

my $dbh = STEDTUser::connectdb();

my $sql;
my $sth;

$sql = "SELECT DISTINCT reflex, gloss, language FROM lexicon, languagenames WHERE lexicon.lgid=languagenames.lgid AND (semcat='2a.1/14' OR semcat='2a.1/13') ORDER BY gloss, reflex"; ###"gloss, groupabbr, reflex";

$sth = $dbh->prepare($sql);
$sth->execute();
my ($reflex, $gloss, $language);
$sth->bind_columns( undef, \$reflex, \$gloss, \$language );

print "Content-type: text/html; charset=utf-8\n\n";

print <<EndOfHTML;
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <style type="text/css">
  td {
        font-family: STEDTU,"TITUS Cyberbit Basic",SILDoulosUnicodeIPA,Gentium,Thryomanes,Cardo,"Arial Unicode MS","Lucida Sans Unicode";
      }
  </style>
</head>
<body>
  <table>\n
EndOfHTML

while ($sth->fetch()) {
    next if ($reflex eq '' or $reflex eq '*');
    print <<EndOfHTML;
   <tr>
     <td>$reflex</td>
     <td>$gloss</td>
     <td>$language</td>
   </tr>
EndOfHTML
}

print "</body>\n</table>\n</html>\n";

$dbh->disconnect();
