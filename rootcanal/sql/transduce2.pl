#!/usr/bin/perl

use strict;
use Data::Dumper;
use utf8;
use DBI;
use Encode qw/decode/;
use STEDTUtil;

binmode(STDOUT, 'utf8');

# get the list of symbols, and their constituent types (e.g. c, v, t = tone, etc...)
open(DAT, "chars.xls") || die("Could not open file!");
my %tr1;
my %tr2;
while (<DAT>) {
  chomp;
  $_= decode('utf8', $_);
  my ($f,$seg,$type,$fuzzy) = split("\t");
  $tr1{$seg} = $type;
  $tr2{$seg} = $fuzzy;
}

#print $tr1 . "\n";

my $counter = 0;

while (<>) {
  chomp;
  $_ = decode('utf8', $_);
  # just need 1st 3 columns...
  my ($rn,$mseq,$syll) = split("\t");
  $counter++;
  my $syllsegments =  join("\t",segment($syll));
  print $_ . "\t" . $syllsegments . "\t" . "" . "\t" . $counter . "\n";
}

# divide a syllable into syllabic constiuents
sub segment {
  my $reflex = shift;
  my @r = split //, $reflex;
  my ($r2, $r3, $r4);

  foreach my $seg (@r) {      # rewrite (transduce) syllable into a sequence of syllabic class symbols
    if ($tr1{$seg} =~ /[lpr]/) {
      #print "#$seg ";
    }
    else {
      $r2 .= $tr1{$seg};
      $r3 .= $seg;
      $r4 .= $tr2{$seg}
      #print "$seg ";
    }
  }
  #print "\n";
  
  #$r2 =~ s/l([vdc]+r)/v\1/; # recode things like (v) and [vdc] to v or vdc (i.e. cleanup)

  if ($r2 =~ /[^t]/) { # move tone marks, if any, to rear
    while (substr($r2,0,1) eq 't') {
      $r2 = substr($r2,1) . substr($r2,0,1);
      $r3 = substr($r3,1) . substr($r3,0,1);
    }
  }
 
  my $tone = index($r2,'t');
  $tone = length($r3) if ($tone eq -1);

  my $juncture = index($r2,'v');
  my ($P,$C,$R,$T) ;
  if ($juncture > -1) { # if there is an onset...
    $C = substr($r3,0,$juncture);
    $R = substr($r3,$juncture,$tone - $juncture);
    $T = substr($r3,$tone);
  }
  #print "j $juncture t $tone \n";
  my $r5 = $r2;
  $r5 =~ s/^[lrc]+/C/;
  $r5 =~ s/[vdclr]+/R/;
  $r5 =~ s/t+/T/;

  $r4 =~ s/0//g; # final cleanup of handle
  $r4 =~ s/ng/n/g; # rude, but necessary!
  $r4 =~ s/^tsh?/c/g;
  $r4 =~ s/^dz/j/g;

  return ($r2,$r4,$r5,$P,$C,$R,$T);
}

sub format_protoform {
  my $string = shift;
  $string = decode('utf8', $string);
  $string =~ s{(\A|\s)(\w)}{$1*$2}gx;
  return $string;
}

sub from_utf8_to_xml_entities {
  my $string = shift;
  my @subst = (
	       ['&', '&amp;'],
	       ['<', '&lt;'],
	       ['>', '&gt;'],
	       ["'", '&apos;'],
	       ['"', '&quot;']);
  for my $pair (@subst) {
    my ($symbol, $entity) = @$pair;
    $string =~ s($symbol)($entity)g;
  }
  return $string;
}
