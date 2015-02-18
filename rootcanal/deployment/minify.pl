#! /usr/bin/perl
# minify.pl
# by Dominic Yu
# read in a javascript file and output the minified version in the right dir
use strict;
use Storable;

my %config;
if (-r 'deploy.cfg') {
	open F, '<deploy.cfg' or die "couldn't open config file: $!";
	while (<F>) {
		chomp;
		my ($key, $val)	= split / *= */;
		$config{$key} = $val;
	}
	close F;
}
die "no valid web dir" unless -d $config{webdir};

my $in = shift @ARGV;
my $out = $in;
$out =~ s|^.*?/web/|$config{webdir}/|;
# print "$in -> $out\n";
# exit;

my $google_compiler = -r $config{minifyjar};
my $last_mod_hashref;
my $storefile = 'lastminified.store';
if ($google_compiler) {
	# it's slow, so skip if possible
	if (-r $storefile) {
		$last_mod_hashref = retrieve($storefile);
	}
	my $last_rev = $last_mod_hashref->{$in};
	my $last_mod = `git log -1 --pretty=format:%H -- $in`;
	if ($last_mod eq $last_rev) {
#		print "$in is at $last_mod, not newer than $last_rev\n";
		exit;
	}
	$last_mod_hashref->{$in} = $last_mod;
} else {
	eval { require JavaScript::Packer };
	die "no javascript minifier installed" if $@;
	import JavaScript::Packer;
}

undef $/; # 'slurp' mode to read in a whole file
open F, "<$in" or die $!;
open G, "<$out" or die $!;
if ($google_compiler) {
	print STDERR "analyzing $in... ";
}
my $java = $config{pathtojava} || 'java';
my $minified = $google_compiler
	? `$java -jar $config{minifyjar} --js $in`
	: JavaScript::Packer::minify(\<F>, {remove_copyright=>1});
my $dst_txt = <G>;
if ($dst_txt eq $minified) {
	print STDERR "skipped.\n" if $google_compiler;
	store $last_mod_hashref, $storefile;
	exit;
}
close G or die $!;
open G, ">$out" or die "$! - $out";
print G $minified;
close F or die $!;
close G or die $!;
print STDERR "minified $out\n";
store $last_mod_hashref, $storefile;
