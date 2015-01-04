package STEDT::Table::Morphemes;
use base STEDT::Table;
use strict;

=pod
The morphemes table is constructed by chopping up each form in the lexicon table using Syllabification Station and
saving each morpheme (syllable) as a separate record, storing gloss and other fields redundantly with each.
It is therefore a "denormalization" of the data to aid in creating other types of interfaces.

Someday something will need to be done to ensure that morphemes and lexicon stay in sync.
=cut

sub new {

# STEDT::Table::Morphemes looks for two additional, optional uids, $uid1 and $uid2. 
# If specified,there will be additional columns returned giving the analyses 
# belonging to those uids; saving new analyses will also use these uids.
# This is useful for "proofreaders" and "authorizers" modifying/correcting other people's tags.

my ($self, $dbh, $privs, $uid2, $uid1) = @_;

	# note: if $uid1 or $uid2 have non-zero values,
	# we generate an analysis column for each.
	# Note that $uid1 = 8 by default; but this is currently set
	# in Base.pm (i.e. not in this file!) for all Table/Xxx.pm, not just Morphemes.pm.

my $t = $self->SUPER::new($dbh, 'morphemes', 'morphemes.id', $privs); # dbh, table, key, privs

$t->query_from(q|morphemes|);
#$t->query_from(q|morphemes LEFT JOIN languagenames USING (lgid) LEFT JOIN languagegroups USING (grpid)|);
$t->order_by('morphemes.handle, morphemes.glosshandle, morphemes.grpno, morphemes.language, morphemes.morpheme, morphemes.srcabbr, morphemes.srcid');
$t->fields(
	'morphemes.id',
	'morphemes.rn',
	'morphemes.tag',
	"CONCAT(handle,' :: ',glosshandle,' :: ',LEFT(grpno,3)) AS lexkey",
	'morphemes.handle',
	'morphemes.morpheme',
	'morphemes.reflex',
	'morphemes.glosshandle',
	'morphemes.gloss',
	'morphemes.language',
	'morphemes.semkey',
	'morphemes.prefx',
	'morphemes.initial',
	'morphemes.rhyme',
	'morphemes.tone',
#	'languagenames.lgid',
#	'languagegroups.grpid',
	'morphemes.grpno',
	'morphemes.grp',
#	'morphemes.srcabbr', 
	'morphemes.srcid',
#	'morphemes.status',
#	'morphemes.semcat',
);
$t->searchable('morphemes.tag',
	'morphemes.handle',
	'morphemes.glosshandle',
	'morphemes.language',
	'morphemes.semkey',
	'morphemes.prefx',
	'morphemes.initial',
	'morphemes.rhyme',
	'morphemes.tone',
	'morphemes.lgid',
);
$t->field_visible_privs(
	'morphemes.tag' => 1,
);
$t->field_editable_privs(
	'morphemes.tag' => 16,
	'morphemes.reflex' => 16,
	'morphemes.morpheme' => 16,
	'morphemes.gloss' => 16,
	'morphemes.gfn' => 16,
	'morphemes.srcid' => 16,
	'morphemes.semcat' => 16, 
#	'morphemes.status' => 16,
	'morphemes.semkey' => 16,
);

# Stuff for searching
$t->search_form_items(
	'morphemes.grp' => sub {
		my $cgi = shift;
		my $grps = $dbh->selectall_arrayref("SELECT grpno, CONCAT(grpno,' ',LEFT(grp,15),' (id:',grpid,')') FROM languagegroups");
		my @grp_nos = map {$_->[0]} @$grps;
		my %grp_labels;
		@grp_labels{@grp_nos} = map {$_->[1]} @$grps;
		
		return $cgi->popup_menu(-name => 'morphemes.grp', -values=>['',@grp_nos],
 								-default=>'', # -override=>1,
  								-labels=>\%grp_labels);
	},
	'morphemes.protolg' => sub {
		my $cgi = shift;
		# get list of protolgs
		my $protolg = $dbh->selectall_arrayref("SELECT DISTINCT protolg FROM morphemes");
		return $cgi->popup_menu(-name => 'morphemes.protolg', -values=>['', map {@$_} @$protolg], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'morphemes.initial' => sub {
		my $cgi = shift;
		# get list of initials
		my $initial = $dbh->selectall_arrayref("SELECT DISTINCT initial FROM morphemes ORDER by initial");
		return $cgi->popup_menu(-name => 'morphemes.initial', -values=>['', map {@$_} @$initial], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'morphemes.rhyme' => sub {
		my $cgi = shift;
		# get list of rhymes
		my $rhyme = $dbh->selectall_arrayref("SELECT DISTINCT rhyme FROM morphemes ORDER BY rhyme");
		return $cgi->popup_menu(-name => 'morphemes.rhyme', -values=>['', map {@$_} @$rhyme], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'morphemes.tone' => sub {
		my $cgi = shift;
		# get list of tones
		my $tone = $dbh->selectall_arrayref("SELECT DISTINCT tone FROM morphemes ORDER by tone");
		return $cgi->popup_menu(-name => 'morphemes.tone', -values=>['', map {@$_} @$tone], -labels=>{'0'=>'(no value)'},  -default=>'');
	}
);

$t->wheres(
#	'languagegroups.grpid' => 'int',
	'morphemes.lgid' => 'int',
	'morphemes.semkey' => 'value',
	'morphemes.tag' => sub {
		my ($k,$v) = @_;
		if ($v eq '0') { # use special value of 0 to search for empty tag
			return "0 = (SELECT COUNT(*) FROM lx_et_hash WHERE rn=morphemes.rn AND uid=$uid1)";
		} elsif ($v eq '!0') {
			return "0 < (SELECT COUNT(*) FROM lx_et_hash WHERE rn=morphemes.rn AND uid=$uid1)";
		} else {
			my $is_string = ($v !~ /^\d+$/);
			unless ($t->{query_from} =~ / lx_et_hash ON \(morphemes.rn/) {
				$t->{query_from} .= " LEFT JOIN lx_et_hash ON (morphemes.rn = lx_et_hash.rn AND lx_et_hash.uid=$uid1)";
			}
			$v = '' if $v eq '\\\\'; # hack to find empty tag_str using a backslash
			return $is_string ? "lx_et_hash.tag_str='$v'" : "lx_et_hash.tag=$v";
		}
	},
	'morphemes.gloss' => 'word',
	'morphemes.glosshandle' => 'value',
	'morphemes.handle' => 'value',
	'morphemes.morpheme' => 'value',
	'morphemes.prefx' => 'value',
	'morphemes.initial' => 'value',
	'morphemes.rhyme' => 'value',
	'morphemes.tone' => 'value',
	'morphemes.lgid' => 'value',
	'morphemes.grp' => sub {my ($k,$v) = @_; $v =~ s/(\.0)+$//; "morphemes.grpno LIKE '$v\%'"},
		# make it search all subgroups as well
	'morphemes.language' => sub {
		my ($k,$v) = @_;
		if ($v eq '0') {
			return "morphemes.lgid=0";
		} else {
			STEDT::Table::prep_regex $v;
			if ($v =~ s/^\*(?=.)//) {
				return "$k RLIKE '$v'";
			}
			return "$k RLIKE '[[:<:]]$v'";
		}
	},
);


$t->save_hooks(
	'morphemes.tag' => sub {
		my ($rn, $s) = @_;
		# simultaneously update lx_et_hash
		$dbh->do('DELETE FROM lx_et_hash WHERE rn=? AND uid=?', undef, $rn, $uid1);
		my $sth = $dbh->prepare(qq{INSERT INTO lx_et_hash (rn, tag, ind, tag_str, uid) VALUES (?, ?, ?, ?, ?)});
		my $index = 0;
		for my $tag (split(/, */, $s)) { # Split the contents of the field on commas
			# Insert new records into lx_et_hash based on the updated tag field
			my $tag_str = $tag;
			$tag = 0 unless ($tag =~ /^\d+$/);
			$sth->execute($rn, $tag, $index, $tag_str, $uid1);
			$index++;
		}
		# for old time's sake, save this in the tag field too
		if ($uid1 == 8) {
			my $update = qq{UPDATE morphemes SET tag=? WHERE rn=?};
			my $update_sth = $dbh->prepare($update);
			$update_sth->execute($s, $rn);
		}
		return 0;
	}
);

$t->footer_extra(sub {
	my $cgi = shift;
	# special utility to replace etyma tags
	print $cgi->start_form(-onsubmit=><<EOF); # escape \\ once for perl, once for js
var x = document.getElementById('update_form').elements;
var r = new RegExp('\\\\b' + document.getElementById('oldtag').value + '\\\\b', 'g');
for (i=0; i< x.length; i++) {
	if (x[i].name.match(/^tag/)) {
		x[i].value = x[i].value.replace(r,document.getElementById('newtag').value)
	}
}
return false;
EOF
	print $cgi->textfield(-id=>'oldtag',-name =>'oldtag', -size =>4 ),
		$cgi->textfield(-id=>'newtag', -name =>'newtag', -size =>4 ),
		$cgi->submit(-name=>'Replace Tags');
	print $cgi->end_form;
});

# Add form stuff
$t->addable(
	'morphemes.lgid',
	'morphemes.srcid',
	'morphemes.tag',
	'morphemes.reflex',
	'morphemes.gloss',
	'morphemes.gfn',
	'morphemes.semkey',
);

$t->add_form_items(
);

$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "Language not specified!\n" unless $cgi->param('morphemes.lgid');
	$err .= "Reflex is empty!\n" unless $cgi->param('morphemes.reflex');
	$err .= "Gloss is empty!\n" unless $cgi->param('morphemes.gloss');
	return $err;
});


#$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(500);

return $t;
}

1;
