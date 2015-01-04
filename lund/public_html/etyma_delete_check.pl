#!/usr/bin/perl
# edited by dwbruhn to use protected pm, 2010-December-07

use strict;
use utf8;	# for the down arrow ↓
use DBI;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser set_message/;
BEGIN {
        $^W = 1;
        unshift @INC, "../pm" if -e "../pm";
        CGI::Carp::set_message("Report bugs/features to stedt@socrates.berkeley.edu");
}
use STEDTUtil;
use TableEdit;
use Encode;
use FascicleXetexUtil;

my $dbh = STEDTUtil::connectdb();
$dbh->do("SET SESSION group_concat_max_len = 7000");
$FascicleXetexUtil::tag2info = sub {
	my ($t, $s) = @_;
	my @a = $dbh->selectrow_array("SELECT tag,chapter,printseq,etyma.protoform,etyma.protogloss,hptb.mainpage FROM etyma LEFT JOIN hptb USING (hptbid) WHERE tag=$t");
	return "[ERROR! Dead etyma ref #$t!]" unless $a[0];
	my (undef, $c, $p, $form, $gloss, $hptb_page) = map {decode_utf8($_)} @a;
	if ($c =~ /^9\./) { # if the root is in chapter 9, then put the print ref
		$t = "#$t ($p)";
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
	return "<b>$t</b>$s";
};

# specify the database structure and fields to display
my $t = new TableEdit $dbh, 'etyma', 'etyma.tag';	# table, key
$t->query_from(q|etyma LEFT JOIN notes USING (tag) LEFT JOIN lx_et_hash USING (tag)|); # ON (notes.spec = 'E' AND notes.id = etyma.tag) 
$t->order_by('etyma.tag'); #printseq+0, etyma.printseq -- this was needed before we made sequence redundant with printseq

$t->fields('etyma.tag',
	'COUNT(DISTINCT lx_et_hash.rn) AS num_recs',
	'etyma.protoform', 'etyma.protogloss',
	'etyma.notes', 'etyma.hptbid',
	'etyma.xrefs',
	'etyma.possallo',
	'etyma.allofams',
	'COUNT(DISTINCT notes.noteid) AS num_notes',
	'GROUP_CONCAT(DISTINCT notes.xmlnote SEPARATOR \'\') AS xmlnotes',
);
$t->field_labels(
	'etyma.tag' => 'Tag',
	'num_recs','recs',
	'etyma.protoform' => 'Protoform',
	'etyma.protogloss' => 'Protogloss',
	'etyma.chapter' => 'Ch.',
	'etyma.plg' => 'pLg',
	'etyma.notes' => 'Tagging Note',
	'num_notes' => 'Notes',
	'etyma.xrefs'     => 'xrefs',
	'etyma.exemplary' => 'x',
	'etyma.sequence' => 'seq',
	'etyma.printseq' => 'p',
	'etyma.possallo' => '↭',
	'etyma.allofams' => '⪤',
	'etyma.hptbid'   => 'HPTB id',
);
$t->searchable('etyma.tag');
$t->editable(
	'etyma.notes',
	'etyma.xrefs',
	'etyma.possallo' ,
	'etyma.allofams' ,
);

# Sizes are in number of characters for text inputs (for searching).
# These values will also be used as relative table column widths
# for display.
$t->sizes(
	'etyma.tag' => '15',
	'etyma.chapter' => '4',
	'etyma.protoform' => '15',
	'etyma.protogloss' => '15',
	'etyma.plg' => '5',
	'etyma.notes' => 20,
	'etyma.hptbid'   => 4,
	'etyma.sequence' => 4,
	'etyma.printseq' => 4,
	'num_notes' => 6,
	'etyma.xrefs'   => 4,
	'etyma.possallo' => 2,
	'etyma.allofams' => 2,
	'num_recs' => 4,
);

# Stuff for searching
#$t->search_form_items();

$t->wheres(
	'etyma.tag'	=> sub {my ($k,$v) = @_;
		$t->{user_tag} = $v;
#		"etyma.tag=$v OR etyma.notes RLIKE '[[:<:]]${v}[[:>:]]' OR etyma.xrefs RLIKE '[[:<:]]${v}[[:>:]]' OR etyma.possallo RLIKE '[[:<:]]${v}[[:>:]]' OR etyma.allofams RLIKE '[[:<:]]${v}[[:>:]]' OR notes.xmlnote RLIKE '[[:<:]]${v}[[:>:]]'"
		"etyma.tag=$v OR etyma.notes RLIKE '$v' OR etyma.xrefs RLIKE '$v' OR etyma.possallo RLIKE '$v' OR etyma.allofams RLIKE '$v' OR notes.xmlnote RLIKE '$v'"
	},
);


# Special handling of results
$t->update_form_items(
	'num_recs' => sub {
		my ($cgi,$n,$key) = @_;
		return $n == 0 ? 0 :
			$cgi->a({-href=>"tagger2.pl?submit=Search&lexicon.analysis=$key",
					   -target=>'reflexes'}, "$n r's");
	},
	'etyma.hptbid' => sub {
		my ($cgi,$s,$key) = @_;
		return $cgi->a({-href=>"hptb.pl?submit=Search&hptbid=$s", -target=>'hptbwindow', -onclick=>'dontedit()'},
			$s);
	},
	'etyma.tag' => \&hilite_text,
	'etyma.notes' => \&hilite_text,
	'etyma.xrefs' => \&hilite_text,
	'etyma.possallo' => \&hilite_text,
	'etyma.allofams' => \&hilite_text,
	xmlnotes => sub {my ($cgi,$s,$key) = @_; return hilite_text($cgi,
		FascicleXetexUtil::xml2html(decode_utf8($s)))
	},
);
sub hilite_text {
	my ($cgi,$s,$key) = @_;
	my $n = $t->{user_tag};
	$s =~ s|$n|<span class="cognate">$n</span>|g;
	return $s;
}


$t->footer_extra(sub {
	my $cgi = shift;
    print $cgi->h1('Important!'), $cgi->p("Remember, only delete if (1) there are no records tagged, (2) no other etyma or notes reference it, and (3) no hptb references!");
});


$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);
$t->generate;

$dbh->disconnect;
