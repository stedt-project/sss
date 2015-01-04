#!/usr/bin/perl
# edited by dwbruhn to use protected pm, 2010-December-07

use strict;
use utf8;
use CGI qw/:standard *table *div/;
use SyllabificationStation;
use Encode;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser set_message/;
BEGIN {
        $^W = 1;
        unshift @INC, "../pm" if -e "../pm";
        CGI::Carp::set_message("Report bugs/features to stedt@socrates.berkeley.edu");
}
use STEDTUtil;
use EtymaSets;
use FascicleXetexUtil;

my $INTERNAL_NOTES = 0;
my $ETYMA_TAGS = 0;

binmode(STDOUT, 'utf8');

if (param()) {

my $dbh = STEDTUtil::connectdb();
my $sql;
my $sth;
my $q = new CGI;
my $syls = SyllabificationStation->new();
my %groupno2name = EtymaSets::groupno2name($dbh);

$FascicleXetexUtil::tag2info = sub {
	my ($t, $s) = @_;
	my $oldtag = $t;
	my @a = $dbh->selectrow_array("SELECT tag,chapter,printseq,etyma.protoform,etyma.protogloss,hptb.mainpage FROM etyma LEFT JOIN hptb USING (hptbid) WHERE tag=$t");
	return "[ERROR! Dead etyma ref #$t!]" unless $a[0];
	my (undef, $c, $p, $form, $gloss, $hptb_page) = map {decode_utf8($_)} @a;
	if ($c =~ /^9\./ || $c eq '6.5') { # if the root is in chapter 9, then put the print ref
		$t = "($p) #$t";
	} else {
		if ($hptb_page) {
			$t = "#$t (H:$hptb_page)";
		} else {
			$t = "#$t";
		}
	}
	if ($s =~ /^\s+$/) { # empty space means only put the number, no protogloss
		$s = '';
	} else {
		$form =~ s/-/‑/g; # non-breaking hyphens
		$form =~ s/^/*/;
		$form =~ s/⪤ /⪤ */g;		# add a star for proto-allofams
		$form =~ s|(\*\S+)|<b>$1</b>|g; # bold the protoform but not the allofam sign or gloss
		if ($s) {			# alternative gloss, add it in
			$s = "$form $s";
		} else {
			$s = "$form $gloss"; # put protogloss if no alt given
		}
		$s = " $s" if $t; # add a space between if there's a printseq
	}
	return '<a href="' . $q->url(-relative=>1) . qq|?tag=$oldtag">$t</a>$s| if $c =~ /^9\./;
	return "<b>$t</b>$s";
};


my $param_tag = param('tag');

print header(-charset => "utf8");
print start_html(-head =>
		 meta({-http_equiv => 'Content-Type', 
				 -content => 'text/html; charset=utf8'}),
		 -encoding => 'utf-8',
		 -title=>'STEDT Etymon #'. $param_tag, 
		 -style=>{'src'=>'styles/tagger.css'}
		 );


# print heading
my ($tag, $printseq, $protoform, $protogloss, $plg,
		$notes, $xrefs, $allofams, $possallo, $hptbid) = map {decode_utf8($_)}
	$dbh->selectrow_array(
		qq#SELECT tag, printseq, protoform, protogloss, plg,
					notes, xrefs, allofams, possallo, hptbid
			FROM `etyma`
			WHERE `tag`=?#, undef, $param_tag);

print $q->h1($FascicleXetexUtil::tag2info->($tag));

# print notes
my $a = $dbh->selectall_arrayref("SELECT notetype, xmlnote, noteid FROM notes "
		. "WHERE tag=$tag AND notetype != 'F' ORDER BY ord");
if (@$a) {
	print $q->h2("Notes");
	print $q->start_div({-style=>'line-height:1.2'});
}
my $seen_hptb;
for my $rec (@$a) {
	my ($notetype, $note, $noteid) = @$rec;
	next if $notetype eq 'I' && !$INTERNAL_NOTES; # skip internal notes if we're publishing
	$seen_hptb = 1 if $notetype eq 'H';

	print '[Internal] <i>' if $notetype eq 'I';
	print FascicleXetexUtil::xml2html(decode_utf8($note));
	print '</i>' if $notetype eq 'I';
}
if ($hptbid && !$seen_hptb) {
	print "See <i>HPTB</i> ";
	my @refs = split /,/, $hptbid;
	my @strings;
	for my $id (@refs) {
		my ($pform, $plg, $pages) =
			$dbh->selectrow_array("SELECT protoform, plg, pages FROM hptb WHERE hptbid=$id");
		$pform = decode_utf8($pform);
		my $p = ($pages =~ /,/ ? "pp" : "p");
		push @strings, ($plg eq 'PTB' ? '' : "$plg ") . "<b>$pform</b>, $p. $pages";
	}
	print join('; ', @strings);
	print ".\n\n";
}
if (@$a) {
	print $q->end_div(-style=>{'-line-height'=>1});
}


# do entries
my $sql = <<EndOfSQL; # this order forces similar reflexes together, and helps group srcabbr's
SELECT DISTINCT languagegroups.ord, grp, language, lexicon.rn, 
analysis, reflex, gloss, languagenames.srcabbr, lexicon.srcid, notes.rn
FROM lexicon LEFT JOIN notes ON notes.rn=lexicon.rn, languagenames, languagegroups, lx_et_hash
WHERE (lx_et_hash.tag = $tag
AND lx_et_hash.rn=lexicon.rn
AND languagenames.lgid=lexicon.lgid
AND languagenames.grpid=languagegroups.grpid)
ORDER BY languagegroups.ord, languagenames.lgsort, reflex, languagenames.srcabbr, lexicon.srcid
EndOfSQL
my $recs = $dbh->selectall_arrayref($sql);
if (@$recs) { # skip if no records
	for my $rec (@$recs) {
		$_ = decode_utf8($_) foreach @$rec; # do it here so we don't have to later
	}
	
	print $q->h2("Reflexes");
	print "<table>";
	my $lastgrpno = '';
	my @footnotes;
	my $footnote_num = 0;
	for my $rec (@$recs) {
		my ($grpno,$grp,$lg,$rn,$an,$form,$gloss,$srcabbr,$srcid,$notern)
			= @$rec;
		
		if ($grpno ne $lastgrpno) {
			# flush footnotes
# 			while (@footnotes) {
# 				print $q->Tr($q->td({-colspan=>5},shift @footnotes));
# 			}
			
			# make subgroup heading
			print $q->Tr($q->td({-colspan=>5},$q->h3($groupno2name{$grpno})));
			$lastgrpno = $grpno;
		}
	
		$syls->fit_word_to_analysis($an, $form);
		$form = $syls->get_xml_mark_cog($tag) || $form;
		$form =~ s/(\S)=(\S)/$1$2/g; # short equals - must be done AFTER syllabification station
		$form =~ s/<cognate>/<span class="cognate">/g;
		$form =~ s|</cognate>|</span>|g;
		$form =~ s/◦//g; # get rid of STEDT delim
		$form = '*' . $form if ($lg =~ /^\*/); # put * for proto-lgs
		my $note_string = '';
		if ($notern) {
			$notern = join(' OR ', map {"`rn`=$_"} split /,/, $notern);
			# only select notes which are generic (empty id) OR those that have specifically been marked as belonging to this etymon/reflex combination
			my @results = @{$dbh->selectall_arrayref("SELECT notetype, xmlnote FROM notes "
					. "WHERE $notern AND (`id`=$tag OR `id`='') ORDER BY ord")};
			for my $rec (@results) {
				my ($notetype, $note) = @$rec;
				next if $notetype eq 'I' && !$INTERNAL_NOTES; # skip internal notes if we're publishing
				next if $notetype eq 'O' && !$INTERNAL_NOTES;
				my $s = FascicleXetexUtil::xml2html(decode_utf8($note));
				$s =~ s/^/[Internal] / if $notetype eq 'I';
				$s =~ s/^/[Source note] / if $notetype eq 'I';
				$s =~ s/^<p>//; $s =~ s|</p>$||;
				$note_string .= ' ' . ++$footnote_num;
				push @footnotes, "$footnote_num. $s";
			}
		}

		print $q->Tr($q->td([$lg,$form,
			$gloss, "$srcabbr" . ($srcid ? ":$srcid" : ''), $note_string ])
		);
		while (@footnotes) {
			print $q->Tr($q->td({-colspan=>5},shift @footnotes));
		}
	}
	print "</table>";
}



# Chinese comparanda
my @comparanda = @{$dbh->selectcol_arrayref("SELECT xmlnote FROM notes WHERE tag=$tag AND notetype = 'F' ORDER BY ord")};
my $comparand_um_a = "Chinese comparand" . (@comparanda == 1 ? 'um' : 'a');
print $q->h2($comparand_um_a) if @comparanda;
for my $note (@comparanda) {
	print FascicleXetexUtil::xml2html(decode_utf8($note));
}




} else {
	print 
		header,
		start_html({-encoding=>'UTF-8'},'STEDT Database: Electronic Dissemination of Etymologies'),
		start_table({border=>'1', cellpadding=>'10'}),Tr,td{width=>'40'},
		img({src=>'http://stedt.berkeley.edu/images/STB32x32.gif',align=>'LEFT'}),  
		td,h3('STEDT Database Online'),       
		b('Electronic dissemination of Etymologies'),
		td,font({-size=>'-2'}, 'v0.1 24 Mar 2005',br,'Lowe, Mortensen, Yu'),
		Tr,td({colspan=>'3'},
		start_form({ -action => 'etymology.pl'}),
		"tag? ",textfield('tag'),
		submit{name=>'Make set'},
		end_form),  
		end_table, 
		hr,"\n";
	
	print end_html;
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
