#!/usr/bin/perl

use strict;
use Data::Dumper;
use utf8;
use DBI;
use SyllabificationStation;
use Encode qw/decode/;
use STEDTUtil;

binmode(STDOUT, 'utf8');

my $syls = SyllabificationStation->new();

while (<>) {
  chomp;
  my $reflex = decode('utf8', $_);
  my $syll = join("\n",syll($reflex));
  print "$syll\n";
}

sub syll {
  my $m = shift;
  
  return(split("",$m));
  my $tonchar = "⁰¹²³⁴⁵⁶⁷⁸0-9ˊˋ";
  my $cons = "";
  my $vowel = "";
  
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
