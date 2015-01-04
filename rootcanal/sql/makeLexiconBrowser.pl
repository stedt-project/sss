#!/usr/bin/perl

use strict;
use Data::Dumper;
use utf8;
use Encode qw/decode/;
use CGI qw/:standard *table/;
use FileHandle;

my @bins = qw(1 aa ar ba be bo bu ce cl co de dr el fa fi fo gh gu he hu in la li ma mo na of ou pe po ra ro sc sh si sm so sp st sw ta te th ti to tr tu up vi wa we wi ya zzz);
my %binhash;
my $i = 0;
grep { $binhash{$_} = $i++; } @bins;
print "$i bins created\n";

# function to encode the 5 XML entities
# NB: this sub avoids double encoding & when it is used in an existing entity...
my @entities_bare=qw/&(?!\w{2,4};) " ' < >/;
my @entities_encoded=qw/&amp; &quot; &apos; &lt; &gt;/;

sub encode_entities {
  my $string=shift;
  for(my $n=0;$n<scalar @entities_bare;++$n){
    if(not $string=~s/$entities_bare[$n]/$entities_encoded[$n]/g){
    }
  }
  return $string;
}

binmode(STDOUT, 'utf8');

# open an output file for each bin
my %fhs;
foreach my $bin (@bins) {

  my $fh = FileHandle->new(">stedt-finder_$bin.html") || die $!;  
  binmode($fh, 'utf8');

  header(-charset => 'UTF-8');
  print $fh   
    start_html(-head => meta( {-http_equiv => 'Content-Type', -content => 'text/html; charset=UTF-8'}),               
	       -encoding => 'UTF-8',
	       -style => { -src => 'acd.css'  },
	       -title=>"STEDT $bin");

  print $fh <<HEADER;
<p class="titleline">Sino-Tibetan Etymological Dictionary and Thesaurus</p>
<p class="subtitleline">English Gloss Finderlist</p>
<p class="indexline">
HEADER

  grep {
    if ($_ eq $bin) {
    print $fh "&nbsp;$_&nbsp;&nbsp;\n";
    }
    else {
    print $fh "<a href=\"stedt-finder_$_.html\">&nbsp;$_&nbsp;</a> &nbsp;\n";
    }
  } (@bins);

print $fh "</p>";

  printf $fh "<h1>%s</h1>\n", $bin;
  print  $fh p(),start_table({-class => 'findertable'});
  print  $fh '<tr><td class="innertable">';
  
  $fhs{$bin} = $fh;
}

my $time = scalar localtime;

my $formline = <<HERE1;
<p class="formline">
<span class="FormPw">%s</span><span class="FormPLg">%s</span>
<span class="FormGroup">%s</span> 
<span class="FormGloss">%s</span> 
<span class="pLang">%s</span> 
<a class="setword2" href="acd-s_q.htm#%s">*<span class="pForm">%s</span></a>
HERE1

my $glosswordline = <<HERE2;
<p class="engline"><a name="%s"></a></p>
<p class="engword">%s</p>
HERE2

my $glossline = <<HERE2a;
<p class="engline">%s &nbsp;&nbsp;<span alt="%s" class="langgroup">%s</span> <a class="setword" href="stedt-s_%s.htm#%s">%s</a></p>
HERE2a
# <p class="engline">able - *<a class="setword" href="$url/acd-lo_a.htm#able"><span class="loansymbol">(loan)</span></a></p>

my $setline = <<HERE3;
<a name="%s"></a>
<a name="%s"></a></p>
<p class="engword">%s</p>
<p class="engline">%s &nbsp;&nbsp; <span class="langgroup">%s</span> <a class="setword" href="stedt-s_b.htm#27146">bula</a>
HERE3

# pf,plg,group,gloss,plg,tag,pform

my %rows;
my %glosslist;
my %tags;
my $input       = 0;
my $lines       = 0;
my $glosses     = 0;
my $outgloss    = 0;
my $outrecs     = 0;
my $duplicates  = 0;

while (<>) {
  $lines++;
  chomp;
  $_= decode('utf8', $_);
  my ($rn,$reflex,$gloss,$gfn,$glosshandle,$lg,$grp,$grpno,$srcabbr,$srcid,$semkey,$lgid) = split("\t");
  $_ = encode_entities($_);
  $rows{$rn} = $_;
  #$gloss = from_utf8_to_xml_entities($gloss);
  my $workinggloss = $gloss;
  $workinggloss =~ s/\b(and|or|the|a|an|of|by|to)\b//g;
  foreach my $token (split/[^\w\-\.]+/,$workinggloss) {
    $token = tr/A-Z/a-z/ if $token =~ /^[A-Z]+$/; # translate to lc if token is all UC.
    if ($token =~ /^[\w\-\.]+$/) { # skip all weird lookin' tokens
      $glosslist{$token} .= $rn . ',';
      $glosses++;
    }
    else { 
      print "weird token skipped: $token\n";
    }
  }
}

warn $lines;
warn $glosses;

my $binnum = 0;
foreach (sort { lc $a cmp lc $b } keys %glosslist) {
  my $prefix = $_;
  $prefix =~ s/\W//g;
  $prefix = lc substr($_,0,2);
  $binnum = $binhash{$prefix} ? $binhash{$prefix} : $binnum ;
  #$bin = 'zzz' unless $binhash{$bin};
  my $bin = @bins[$binnum];
  $bin = 'zzz' if ($prefix gt 'zzz' || $prefix lt '1');
  #print "bin, binnum :: $bin, $binnum \n";
  my $fh = $fhs{$bin};
  printf $fh $glosswordline,$_,$_;
  $outgloss++;
  #print "zzz $_ $glosslist{$_}\n";
  my @records = split ',',$glosslist{$_};
  my $key = '';
  foreach my $rnx (@records) {
    #print "xxx $rnx\n";
    my ($rn,$reflex,$gloss,$gfn,$glosshandle,$lg,$grp,$grpno,$srcabbr,$srcid,$semkey,$lgid) = split("\t",$rows{$rnx});
    if ($key eq "$lg $reflex") { 
      # we have a dup; skip the line
      $duplicates++;
    }
    else {
      $gloss =~ s/($_)/<b>\1<\/b>/;
      printf $fh $glossline, ($gloss,$srcabbr.' '.$srcid,$lg,$bin,$rn,$reflex);
      $outrecs++;
    }
    $key = "$lg $reflex";
  }
}


foreach my $bin (@bins) {

  my $fh = $fhs{$bin};
  print  $fh "\n</td></tr>\n";
  print  $fh end_table();
  print  $fh end_html();
}

warn $outgloss;
warn $outrecs;
warn $duplicates;

sub format_protoform {
  my $string = shift;
  $string = decode('utf8', $string);
  # reverse order of tone letters (i.e.an initial cap) in reconstructions
  $string =~ s{(\A|\s)(\w)}{$1*$2}gx;
  return $string;
}
