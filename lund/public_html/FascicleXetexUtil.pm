package FascicleXetexUtil;
use strict;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(bold_protoform prettify_protoform escape_tex xml2tex
				eq_reflexes merge_glosses src_concat);
use utf8;

=head1 NAME

FascicleXetexUtil

=head1 SYNOPSIS

Some utility functions for generating LaTeX code for the fascicle.

Not everything function in here is strictly TeX, of course, (like
record-combining ones, at the end), but they're only useful in the
context of generating a print volume where you need to save space
and make things pretty.

=head1 USAGE

You can just call the functions, they're all exported.

BUT you have to set the $FascicleXetexUtil::tag2info sub ref manually.
This is a subroutine that should accept a tag number (and an optional alternate gloss)
and return a string that is valid XeTeX and will be inserted inline into notes.

=head1 AUTHOR

by Dominic Yu

=head1 VERSION

0.1 - 2008.02.23

=over

=item *

work in progress

=back

=cut

my @italicize_abbrevs =
qw|GSR GSTC STC HPTB TSR AHD VSTB TBT HCT LTBA BSOAS CSDPN TIL OED|;

our $tag2info;  # sub ref only used inside xml2tex, set from the outside

sub bold_protoform { # pass in something already escape_tex'd
	my $s = shift;
	for ($s) {
		s/⪤} +/⪤} */g;
		s/\\textasciitilde\\ +/\\textasciitilde\\ */g;
		s/ = +/ = */g;
		s/ or +/ or */g;
		$_ = '*' . $_;
		s/(\*\S+)/\\textbf{$1}/g; # bold only the protoform, not allofam or "or"
	}
	return $s;
}

sub prettify_protoform {
	my $s = shift;
	$s =~ s#\(?(.)/(.)(?:/(.))?\)?#_tabularify($1,$2,$3)#ge;
	return $s;
}

sub _tabularify {
	my $s = "\\begin{tabular}[c]{c}";
	foreach (@_) {
		$s .= "$_\\\\" if $_;
	}
	$s .= "\\end{tabular}";
	return $s;
}

sub escape_tex {
	my $s = shift;
	my $ignore_curly_braces = shift; # second argument means "Don't escape curly braces"
	$s =~ s/{/\\{/g unless $ignore_curly_braces;
	$s =~ s/}/\\}/g unless $ignore_curly_braces;
	$s =~ s/#/\\#/g;
	$s =~ s/&/\\&/g;
	$s =~ s/~/\\textasciitilde\\ /g;
#	$s =~ s/</\\textless\\ /g;
#	$s =~ s/>/\\textgreater\\ /g;
	$s =~ s/([ⓁⓋⓒⒸⓈ˯˰⪤↮↭])/\\STEDTU{$1}/g;
	# this marks special symbols not really in unicode as STEDTU font
	# VL, VD, checked, tone C, stopped tone, low open, low stopped, allofam symbols
	$s =~ s/◦/\\,/g; # STEDT delimiter, not in Charis SIL, can be del'd (\, is a mini-space in TeX)
	$s =~ s/\|//g; # STEDT overriding delimiter, can be safely ignored
	return $s;
}

sub _qtd {
	my $s = $_[0];
	$s =~ s/&apos;/'/g;
	$s =~ s/&quot;/"/g;
	return $s;
}

sub _nonbreak_hyphens {
	my $s = $_[0];
	$s =~ s/-/‑/g;
	return $s;
}

sub xml2tex { # for the notes
	local $_ = $_[0];
	s/{/\\{/g unless $_[1]; # skip curly braces
	s/}/\\}/g unless $_[1];
	s|^<par>||;
	s|</par>$||;
	s|</par><par>|\n\n|g;
	s|<br />|\\\\\n|g;
	s|<sup>(.*?)</sup>|\$^\\mathrm{$1}\$|g;
	s|<sub>(.*?)</sub>|\$_\\mathrm{$1}\$|g;
	s|<emph>(.*?)</emph>|\\textit{$1}|g;
	s|<strong>(.*?)</strong>|"\\textbf{" . _qtd($1). "}"|ge;
	s|<gloss>(.*?)</gloss>|$1|g;	# no formatting?
	s|<reconstruction>\*(.*?)</reconstruction>|"\\textbf{*" . _nonbreak_hyphens($1) . "}"|ge;
#	s|<xref ref="(\d+)">#\1(.*?)</xref>|#$1$2|g;
	s|<xref ref="(\d+)">#\1(.*?)</xref>|_tag2info($1,$2)|ge;
	s|<footnote>(.*?)</footnote>|\\footnote{$1}|g;
	s|<hanform>(.*?)</hanform>|\\TC{$1}|g;
	s|<latinform>(.*?)</latinform>|"\\textbf{" . _nonbreak_hyphens(_qtd($1)) . "}"|ge; # exception to smart quote
	s|<plainlatinform>(.*?)</plainlatinform>|_qtd($1)|ge; # not used...
	s/&amp;/&/g;
	s/&lt;/</g;
	s/&gt;/>/g;
# some smart-quote code lifted from the internet somewhere, here for reference
# # left_single 
#          sub { $_[0] =~ s/(\s|\A)'/$1&#8216;/g;
#                $_[0] =~ s/(?<!\w)'(?=\w)/&#8216;/g;
#               },
# # right_single
#          sub { $_[0] =~ s/(?<!\s)'/&#8217;/g;
#                $_[0] =~ s/'(?=\s|\z)/&#8217;/g;
	s/(\S)&apos;/$1’/g; # smart quotes
		# this formulation doesn't account for single quotes right
		# after opening-type contexts, like open paren, brackets, etc.
		# it's practically impossible to find good code online to
		# "educate" straight quotes
	s/&apos;/‘/g;
	s/&quot;(?=[\w'])/“/g;
	s/&quot;/”/g;  # or $_[0] =~ s/(?<!\s)"/&#8221;/g; $_[0] =~ s/(\A|\s)"/$1&#8220;/g;
	s/(cf\.) /$1\\ /ig; # no extra spacing after cf., e.g., etc.
	s/(e\. ?g\.) /$1\\ /g;
	s/(i\. ?e\.) /$1\\ /g;
	s/(pp?\.) (?=\d)/$1\\ /g;
	s/(vs\.) /$1\\ /g;
	s/(\bn\.) /$1\\ /g; # means "footnote"
	s/(\bMand\.) /$1\\ /g;
	
	# italicize certain abbreviations
	for my $abbrev (@italicize_abbrevs) {
		s/\b($abbrev)\b/\\textit{$1}/g;
	}
	$_ = escape_tex($_, 1); # pass 1 to mean don't escape curly braces, since we did that already
	
	s/<-+>/\$\\longleftrightarrow\$/g; # convert arrows
	s/< /<~/g; # no break after "comes from" sign
	return $_;
}

sub _tag2info {
	&$tag2info;
}

sub xml2html {
	my @footnotes;
	my $i = 1;
	local $_ = $_[0];
	s|<par>|<p>|g;
	s|</par>|</p>|g;
	s|<emph>|<i>|g;
	s|</emph>|</i>|g;
	s|<gloss>(.*?)</gloss>|$1|g;	# no formatting?
	s|<reconstruction>\*(.*?)</reconstruction>|"<b>*" . _nonbreak_hyphens($1) . "</b>"|ge;
	s|<xref ref="(\d+)">#\1(.*?)</xref>|_tag2info($1,$2)|ge;
	s|<footnote>(.*?)</footnote>|push @footnotes, $1; "<sup>" . $i++ . "</sup>"|ge;
	s|<hanform>(.*?)</hanform>|$1|g;
	s|<latinform>(.*?)</latinform>|"<b>" . _nonbreak_hyphens($1) . "</b>"|ge;
	s|<plainlatinform>(.*?)</plainlatinform>|$1|g;

	s/(\S)&apos;/$1’/g; # smart quotes
	s/&apos;/‘/g;
	s/&quot;(?=[\w'])/“/g;
	s/&quot;/”/g;  # or $_[0] =~ s/(?<!\s)"/&#8221;/g; $_[0] =~ s/(\A|\s)"/$1&#8220;/g;
	
	# italicize certain abbreviations
	for my $abbrev (@italicize_abbrevs) {
		s|\b($abbrev)\b|<i>$1</i>|g;
	}
	### specify STEDTU here?

	s/&lt;-+&gt;/⟷/g; # convert arrows
	s/< /< /g; # no-break space after "comes from" sign
	
	$i = 1;
	for my $f (@footnotes) { $_ .= '<p class="footnote">' . $i++ . ". $f</p>" }
	return $_;
}


# special functions to combine similar records
sub eq_reflexes {
	my ($a, $b) = @_;
	$a =~ tr/-+ .,;~◦⪤=\|//d; # remove spaces and delimiters
	$b =~ tr/-+ .,;~◦⪤=\|//d;
	$a =~ s/ː/:/g; # normalize vowel length to ASCII colon
	$b =~ s/ː/:/g;
	return $a eq $b;
}

sub _magic_gloss_compare {
	my $z = $_[0] eq $_[1];
	return 1 if $z; # dummy case
	return $z unless $_[0] =~ /\("/ || $_[1] =~ /\("/;
	my ($a, $b) = @_; # copy values
	$a =~ s/ +\(".*?"\)//g;
	$b =~ s/ +\(".*?"\)//g;
	return 0 if $a ne $b;
	
	# save the longer string to the first value passed in
	# as a side effect (see sub below)
	$_[0] = $_[1] if length($_[1]) > length($_[0]);
	return 1;
}

sub merge_glosses {
	my ($a, $b) = @_;
	return $a if $a eq $b; # dummy case, save some time?
	$a =~ s| / |;|g; # make slashes equivalent to semicolons
	$b =~ s| / |;|g;
	my @a = split / *; */, $a;
	my @b = split / *; */, $b;
	
	my ($longer, $shorter); # array refs
	if (@a >= @b) { # greater-or-equal, so if they're the same you concatenate left-to-right
		($longer, $shorter) = \(@a,@b);
	} else {
		($longer, $shorter) = \(@b,@a);
	}
	foreach my $s (@$shorter) {
		# add each gloss from the shorter set of glosses
		# as long as you can't find it in the longer set
		push @$longer, $s
			unless grep {_magic_gloss_compare($_,$s)} @$longer;
	}
	return join '; ', @$longer;
}

sub src_concat {
	my @abbrs = split /;/, $_[0];
	my @ids   = split /;/, $_[1];
	my $result = "\\mbox{$abbrs[0]}";
	$result .= ":" . escape_tex($ids[0]) if $ids[0]; # escape the pound symbols in the srcid
	
	my $lastabbr = $abbrs[0];
	for my $i (1..$#abbrs) {
		if ($abbrs[$i] eq $lastabbr) {
			$result .= "," . escape_tex($ids[$i]) if $ids[$i];
		} else {
			$result .= "; \\mbox{$abbrs[$i]}";
			$result .= ":" . escape_tex($ids[$i]) if $ids[$i];
			$lastabbr = $abbrs[$i];
		}
	}
	return $result;
}

1;
