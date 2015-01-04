#! /usr/bin/perl
# minify.pl
# by Dominic Yu
# read in a javascript file and output the minified version in the right dir

my $in = shift @ARGV;
my $out = $in;
$out =~ s|^.*?/web/|$ENV{HOME}/public_html/|;
# print "$in -> $out\n";
# exit;

my $google_compiler = 1;
if ($google_compiler) {
	# it's slow, so skip if possible
	my ($last_rev) = `cat $ENV{HOME}/deployed.txt` =~ /(\d+)$/g;
	my ($last_mod) = `svn info $in | grep 'Last Changed Rev'` =~ /(\d+)$/g;
	if ($last_mod <= $last_rev) {
#		print "$in is at $last_mod, not newer than $last_rev\n";
		exit;
	}
} else {
	require JavaScript::Packer;
	import JavaScript::Packer;
}

undef $/; # 'slurp' mode to read in a whole file
open F, "<$in" or die $!;
open G, "<$out" or die $!;
if ($google_compiler) {
	print STDERR "analyzing $in... ";
}
my $minified = $google_compiler
	? `java -jar $ENV{HOME}/lib/bin/compiler.jar --js $in`
	: JavaScript::Packer::minify(\<F>, {remove_copyright=>1});
my $dst_txt = <G>;
if ($dst_txt eq $minified) {
	print STDERR "skipped.\n" if $google_compiler;
	exit;
}
close G or die $!;
open G, ">$out" or die "$! - $out";
print G $minified;
close F or die $!;
close G or die $!;
print STDERR "minified $out\n";
