#!/usr/bin/perl -I..
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

my $dbh = STEDTUtil::connectdb();

# specify the database structure and fields to display
my $t = new TableEdit $dbh, 'etyma', 'etyma.tag';	# table, key
$t->query_from(q|etyma LEFT JOIN notes USING (tag) LEFT JOIN lx_et_hash USING (tag)|); # ON (notes.spec = 'E' AND notes.id = etyma.tag) 
$t->order_by('etyma.extraction, etyma.chapter, etyma.sequence, etyma.protogloss, etyma.protoform'); #printseq+0, etyma.printseq -- this was needed before we made sequence redundant with printseq

$t->fields('etyma.tag',
	'COUNT(DISTINCT lx_et_hash.rn) AS num_recs',
			'etyma.extraction', 'etyma.chapter', 'etyma.protoform', 'etyma.protogloss',
		'etyma.plg', 'etyma.notes', 'etyma.hptbid',
		'COUNT(DISTINCT notes.noteid) AS num_notes',
		'etyma.xrefs',
	'etyma.exemplary',
	'etyma.sequence' ,
	'etyma.printseq' ,
	'etyma.possallo' ,
	'etyma.allofams' ,
);
$t->field_labels(
	'etyma.tag' => 'Tag',
	'num_recs','recs',
	'etyma.protoform' => 'Protoform',
	'etyma.protogloss' => 'Protogloss',
	'etyma.extraction' => "Ex.",
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
$t->searchable('etyma.tag',
	'num_recs',
	'etyma.extraction',
	'etyma.chapter',
	'etyma.protoform', 'etyma.protogloss',
	'etyma.plg', 'etyma.notes', 'etyma.printseq',
	'etyma.xrefs',#'etyma.possallo','etyma.allofams'	# search these and tagging note and notes DB before deleting records. Also switch to OR searching below.
	'num_notes',
);
$t->editable(
		'etyma.extraction','etyma.chapter', 'etyma.protoform', 'etyma.protogloss',
		'etyma.plg', 'etyma.notes', 'etyma.hptbid',
		'etyma.xrefs',
	'etyma.possallo' ,
	'etyma.allofams' ,
);
$t->always_editable('etyma.printseq');

# Sizes are in number of characters for text inputs (for searching).
# These values will also be used as relative table column widths
# for display.
$t->sizes(
	'etyma.tag' => '5',
	'etyma.extraction' => '3',
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
$t->search_form_items(
	'etyma.plg' => sub {
		my $cgi = shift;
		# get list of proto-lgs
		my $plgs = $dbh->selectall_arrayref("SELECT DISTINCT plg FROM etyma");
		if ($plgs->[0][0] eq '') {
			# indexes 0,0 relies on sorted list of plgs.
			# allow explicit searching for empty strings
			# see 'wheres' sub, below
			$plgs->[0][0] = '0';
		}
		
		return $cgi->popup_menu(-name => 'etyma.plg', -values=>['', map {@$_} @$plgs], -labels=>{'0'=>'(no value)'},  -default=>'', -override=>1);
	}
);

$t->wheres(
	'etyma.plg'	=> sub {my ($k,$v) = @_; $v = '' if $v eq '0'; "$k LIKE '$v'"},
	'etyma.chapter' => sub { my ($k,$v) = @_; "$k LIKE '$v'" },
	'etyma.protogloss'	=> 'word',
	'etyma.printseq'=> sub { my ($k,$v) = @_; "$k RLIKE '^${v}[abc]*\$'" },
	'etyma.hptbid' => sub {
		my ($k,$v) = @_;
		if ($v eq '0') {
			return "$k=''";
		} else {
			return "$k RLIKE '[[:<:]]${v}[[:>:]]'";
		}
	},
);


# Special handling of results
$t->update_form_items(
	'etyma.tag' => sub {
		my ($cgi,$s,$key) = @_;
		return $cgi->a({-href=>"etymology.pl?tag=$s", -target=>'madeset'}, "#$s");
	},
	'num_recs' => sub {
		my ($cgi,$n,$key) = @_;
		return $n == 0 ? 0 :
			$cgi->a({-href=>"tagger2.pl?submit=Search&lexicon.analysis=$key",
					   -target=>'reflexes'}, "$n r's");
	},
	'num_notes' => sub {
		my ($cgi,$n,$key) = @_;
		return $cgi->a({-href=>"notes.pl?E=$key", -target=>'noteswindow'},
			$n == 0 ? "add..." : "$n note" . ($n == 1 ? '' : 's'));
	},
	'etyma.hptbid' => sub {
		my ($cgi,$s,$key) = @_;
		return $cgi->a({-href=>"hptb.pl?submit=Search&hptbid=$s", -target=>'hptbwindow', -onclick=>'dontedit()'},
			$s);
	}
);

$t->print_form_items(
	'num_notes' => sub {
		my ($cgi,$n,$key) = @_;
		return $n == 0 ? '' : "$n note" . ($n == 1 ? '' : 's');
	}
);

$t->save_hooks(
	'etyma.printseq' => sub {
		my ($id, $value) = @_;
		# simultaneously update sequence fld
		my ($num, $c) = $value =~ /^(\d+)(.*)/;
		$c = ord($c) - ord('a') + 1 if $c;
		my $sth = $dbh->prepare(qq{UPDATE etyma SET etyma.sequence=? WHERE etyma.tag=?});
		$sth->execute("$num.$c", $id);
	},
	'etyma.hptbid' => sub {
		my ($tag, $s) = @_;
		# simultaneously update et_hptb_hash
		$dbh->do('DELETE FROM et_hptb_hash WHERE tag=?', undef, $tag);
		my $sth = $dbh->prepare(qq{INSERT INTO et_hptb_hash (tag, hptbid, ord) VALUES (?, ?, ?)});
		my $index = 0;
		for my $id (split(/, */, $s)) {
			$sth->execute($tag, $id, $index) if ($id =~ /^\d+$/);
			$index++;
		}
	}
);

$t->footer_extra(sub {
	my $cgi = shift;
	# special utility to renumber printseq
    print $cgi->start_form(-onsubmit=><<EOF); # escape \\ once for perl, once for js
var x = document.getElementById('update_form').elements;
var r = new RegExp('\\\\d+', 'g');
var n = document.getElementById('startfrom').value;
var old_n = 0;
for (i=0; i< x.length; i++) {
	if (x[i].name.match(/^etyma.printseq/)) {
		var a = x[i].value.match(/\\d+/); if (old_n == 0) old_n = a[0];
		if (a[0] != old_n) n++;
		x[i].value = x[i].value.replace(r,n)
		old_n = a[0];
	}
}
return false;
EOF
	print "starting from ", $cgi->textfield(-id=>'startfrom',-name =>'startfrom', -size =>4 ),
		"... ",
		$cgi->submit(-name=>'Renumber printseq');
	print $cgi->end_form;
});

# Add form stuff
$t->addable(
	'etyma.tag',
	'etyma.extraction',
	'etyma.protoform',
	'etyma.protogloss',
	'etyma.plg',
	'etyma.notes',
	'etyma.hptbid',
	'etyma.printseq' ,
);
$t->add_form_items(
	'etyma.tag' => sub {
		my $cgi = shift;
		my $tags = $dbh->selectall_arrayref("SELECT tag FROM etyma ORDER BY tag");
		my @a;	# available tag numbers
		my $i = shift @$tags;
		$i = $i->[0];
		foreach (@$tags) {
			$_ = $_->[0];
			next if ++$i == $_;
			$i--; # reset
			while (++$i < $_) {
				push @a, $i;
			}
		}
		$i++;
		
		return $cgi->popup_menu(-name => 'etyma.tag', -values=>['',$i,@a],  -default=>'', -override=>1);
	},
	'etyma.plg' => sub {
		my $cgi = shift;
		my $plgs = $dbh->selectall_arrayref("SELECT DISTINCT plg FROM etyma");
		return $cgi->popup_menu(-name => 'etyma.plg', -values=>[map {@$_} @$plgs],  -default=>'PTB', -override=>1);
	}
);
$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "Protoform is empty!\n" unless $cgi->param('etyma.protoform');
	$err .= "Protogloss is empty!\n" unless $cgi->param('etyma.protogloss');
	$err .= "Protolanguage is empty!\n" unless $cgi->param('etyma.plg');
	return $err;
});


#$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);
$t->generate;

$dbh->disconnect;
