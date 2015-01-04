#!/usr/bin/perl -w
BEGIN { $^W = 1 }
use strict;
use HTML::Entities;
use utf8; # allows UTF-8 in the perl source code
use open ':utf8'; # in and out layers
#use open IN => ':bytes', OUT => ':utf8'; # in and out layers
use open ':std'; # STDIN, STDOUT and STDERR
printf "Perl version %vd\n", $^V;
print "x"x84,"\nStarting on ", scalar localtime,"...\n";


#my $if = "text1.txt";
my $of = "index.html";
#open IF, "< $if" or die "cannot open `$if': $!";
open OF, "> $of" or die "cannot create `$of': $!";
my ($dir,$file,$thumb,@dir,@file);

print OF <<ZIP;

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title>Scans of STC</title>
<BODY>
<H1>Electronic <i>Sino-Tibetan: a Conspectus</i> (STC)</H1>
<P>Selections of STC are already a part of the <a href ="stedt.berkeley.edu">STEDT</a> lexical database system. Scanned images of STC will be linked into the Etyma DB via a new ancillary database. Large portions of this text were once scanned and OCR’d, but the resulting data still needs to be manually corrected. This text is incredibly complex typographically, often with enormous, complicated footnotes. STEDT has received permission from Cambridge University Press to reproduce this ground-breaking volume, which is now and would otherwise remain out of print. Sample pages are included below. This web page will be updated as work progresses.</P>

<HR>
(jpeg images, will open in a new window)
<HR>
ZIP


opendir(DIR, '.') or die 'cannot open : $!';
    @file = readdir(DIR);
    closedir(DIR);
    my $n = 0;
    foreach $file (sort @file) {
        next unless $file =~ /\.jpg$/i;
        ($thumb = $file) =~ s/\.jpg/\.gif/i;
        $n++;#
        print OF ("<A HREF=\"$file\" target=\"_blank\"><img src=\"thumbs/$thumb\" alt=\"$thumb\"></A> $file <BR>\n<HR>\n");
  }
print OF ("<HR><HR><B>Page Generated in Perl:</B><BR>", 
scalar localtime, "<BR> Berkeley, California, USA <BR><HR>\n");

print OF <<WWW;

    <a href="http://validator.w3.org/check?uri=referer"><img
        src="http://www.w3.org/Icons/valid-html40" 
        alt="Valid HTML 4.0 Transitional" height="31" width="88"></a>

WWW

print OF "</BODY></HTML>\n";
close OF or die "trouble closing `$of': $!";
#warn "line count: $.";
warn "Finished in ", time() - $^T, " second(s), ",scalar localtime,".\n";
