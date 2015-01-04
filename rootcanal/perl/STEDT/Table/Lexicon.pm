package STEDT::Table::Lexicon;
use base STEDT::Table;
use strict;

=pod
This is the magic command that we first tried to use to select lexicon records
based on the content of lx_et_hash and generate analysis fields on the fly.
The join condition(s) restrict the found analyses to, e.g., the STEDT user,
which we have arbitrarily chosen to be uid 8.

SELECT ***DISTINCT*** lexicon.rn,
	GROUP_CONCAT(analysis_table.tag_str ORDER BY analysis_table.ind),
	lexicon.reflex, lexicon.gloss
FROM lexicon
	***LEFT JOIN lx_et_hash ON (lexicon.rn = lx_et_hash.rn AND lx_et_hash.uid=8)***
	LEFT JOIN lx_et_hash AS analysis_table ON (lexicon.rn = analysis_table.rn AND analysis_table.uid=8)
	LEFT JOIN lx_et_hash AS an2 ON (analysis_table.rn = an2.rn AND analysis_table.ind = an2.ind AND an2.uid=1)
WHERE ***lx_et_hash.tag=[[TAG]]***
GROUP BY lexicon.rn ***,lx_et_hash.ind***

The parts in ***'s are necessary if you want to search by tag. The
extra WHERE clause is obviously to search by tag, but that means you
need another JOIN in the FROM. Then, to prevent multiple rows for
records that have been tagged multiple times with the same etymon
(e.g. a reduplicated form u-u for EGG), we add the additional GROUP BY
to expand the record set to have a result row for each value of ind,
thus causing GROUP_CONCAT to concatenate the sequence of tag_str's
once for each time the tag is found. Finally, the DISTINCT modifier
collapses those extra result rows into each other.

Unfortunately, to get a second user's tagging, there does not seem to be
an easy way to do a second join at the same time while disentangling it
from the first; in fact, it may not be possible (remember that there might
be user tagging but no stedt tagging, so you can't piggyback the second join
onto the first). Luckily, subqueries come to the rescue:

(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis

This avoids the need to do DISTINCT or an extra GROUP BY, allows you to retrieve
an unlimited (for all practical purposes) number of user columns, and actually
appears to be more efficient since it saves the extra GROUP BY processing time.


On the other hand, searching by tag is still more efficient using a JOIN
vs. a subquery. Look at this query with a subquery (note the WHERE clause):

SELECT lexicon.rn,
	(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis,
	lexicon.reflex, lexicon.gloss
FROM lexicon
WHERE lexicon.rn IN (SELECT rn FROM lx_et_hash WHERE uid=8 AND tag=[[TAG]])
GROUP BY lexicon.rn

This is equivalent, but it seems to be over 180 times slower!


A second kind search is one where we want to pull out multiple taggers' analyses
at the same time.

SELECT
	lexicon.rn, an_tbl.uid,
	GROUP_CONCAT(an_tbl.tag_str ORDER BY an_tbl.ind) as analysis,
	lexicon.reflex, lexicon.gloss
FROM lexicon
	LEFT JOIN lx_et_hash AS an_tbl ON (lexicon.rn = an_tbl.rn)
WHERE gloss LIKE 'body%'
GROUP BY lexicon.rn, an_tbl.uid

This will return a separate row for each combination of rn/uid, that is
a separate row containing each analysis belonging to a record.
=cut

sub new {

# STEDT::Table::Lexicon looks for two additional, optional uids, $uid1 and $uid2. 
# If specified,there will be additional columns returned giving the analyses 
# belonging to those uids; saving new analyses will also use these uids.
# This is useful for "proofreaders" and "authorizers" modifying/correcting other people's tags.

my ($self, $dbh, $privs, $uid2, $uid1) = @_;

	# note: if $uid1 or $uid2 have non-zero values,
	# we generate an analysis column for each.
	# Note that $uid1 = 8 by default; but this is currently set
	# in Base.pm (i.e. not in this file!) for all Table/Xxx.pm, not just Lexicon.pm.

my $t = $self->SUPER::new($dbh, 'lexicon', 'lexicon.rn', $privs); # dbh, table, key, privs

$t->query_from(q|lexicon LEFT JOIN languagenames USING (lgid) LEFT JOIN languagegroups USING (grpid) LEFT JOIN chapters USING (semkey) 
		LEFT JOIN srcbib USING (srcabbr)|);
$t->default_where('lexicon.status != "HIDE" AND lexicon.status != "DELETED"');
$t->order_by('languagegroups.grp0, languagegroups.grp1, languagegroups.grp2, languagegroups.grp3, languagegroups.grp4, languagenames.lgsort, lexicon.reflex, languagenames.srcabbr, lexicon.srcid');
$t->fields(
	'lexicon.rn',
	($uid1 ? "(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=$uid1) AS analysis" : () ),
	($uid2 ? "(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=$uid2) AS user_an" : () ),
	($uid2 ? "(SELECT GROUP_CONCAT(CONCAT(uid, ':', tag_str) ORDER BY uid,ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid!=$uid1 AND uid!=$uid2) AS other_an" : () ),
	'lexicon.reflex',
	'lexicon.gloss',
	'lexicon.gfn',
	'languagenames.lgid',
	'languagenames.language',
	'languagegroups.grpid',
	'languagegroups.grpno',
	'languagegroups.grp',
	'srcbib.citation AS citation',
	'languagenames.srcabbr', 'lexicon.srcid',
#	'lexicon.status',
#	'lexicon.semcat',
	'lexicon.semkey',
	'chapters.chaptertitle',
	# if $privs is undefined then it's a public user and internal notes should be excluded from the note count
	((defined $privs && ($privs & 2)) ? '(SELECT COUNT(*) FROM notes WHERE rn=lexicon.rn) AS num_notes' : '(SELECT COUNT(*) FROM notes WHERE rn=lexicon.rn AND notetype!=\'I\') AS num_notes'),
);
$t->searchable('lexicon.rn', 'analysis', 'user_an', 'lexicon.reflex',
	'lexicon.gloss', 'lexicon.gfn',
	'languagenames.language', 'languagegroups.grp',
	'languagenames.srcabbr', 'lexicon.srcid',
#	'lexicon.semcat', 
	'lexicon.semkey',
#	'lexicon.status',
	'lexicon.lgid',
	'languagenames.lgcode',
);
$t->field_visible_privs(
#	'user_an' => 1,
);
$t->field_editable_privs(
	'analysis' => 8,
	'user_an' => 1,
	'lexicon.reflex' => 1,
	'lexicon.gloss' => 16,
	'lexicon.gfn' => 16,
	'lexicon.srcid' => 16,
	'lexicon.semcat' => 16, 
#	'lexicon.status' => 16,
	'lexicon.semkey' => 16,
);

# Stuff for searching
$t->search_form_items(
	'languagegroups.grp' => sub {
		my $cgi = shift;
		my $grps = $dbh->selectall_arrayref("SELECT grpno, CONCAT(grpno,' ',LEFT(grp,18)) FROM languagegroups ORDER BY grp0,grp1,grp2,grp3,grp4");
		my @grp_nos = map {$_->[0]} @$grps;
		my %grp_labels;
		@grp_labels{@grp_nos} = map {$_->[1]} @$grps;
		
		return $cgi->popup_menu(-name => 'languagegroups.grp', -values=>['',@grp_nos],
  								-default=>'', # -override=>1,
  								-labels=>\%grp_labels)
  			. '<small><input type="checkbox" name="strict_grp" id="strict_grp"'
  			. ($cgi->param('strict_grp') ? ' checked' : '')
  			. '><label for="strict_grp">strict</label></small>';
	},
#	'lexicon.status' => sub {
#		my $cgi = shift;
#		# get list of statuses
#		my $statuses = $dbh->selectall_arrayref("SELECT DISTINCT status FROM lexicon");
#		return $cgi->popup_menu(-name => 'lexicon.status', -values=>['', map {@$_} @$statuses], -labels=>{'0'=>'(no value)'},  -default=>'');
#	},
);

$t->wheres(
	'languagegroups.grpid' => 'int',
	'languagenames.srcabbr' => 'beginword',
	'lexicon.lgid' => 'int',
	'lexicon.srcid' => 'value',
	'languagenames.lgcode' => 'int',
	'lexicon.semkey' => 'value',
	'analysis' => sub {
		my ($k,$v) = @_;
		if ($v eq '0') { # use special value of 0 to search for empty analysis (i.e., nobody's tagged it anywhere)
			return "0 = (SELECT COUNT(*) FROM lx_et_hash WHERE rn=lexicon.rn)";
		} elsif ($v eq '!0') {
			return "0 < (SELECT COUNT(*) FROM lx_et_hash WHERE rn=lexicon.rn)";
		} else {
			my $is_string = ($v !~ /^\d+$/);
			unless ($t->{query_from} =~ / lx_et_hash ON \(lexicon.rn/) {
				if ($uid2) {
					$t->{query_from} .= " LEFT JOIN lx_et_hash ON (lexicon.rn = lx_et_hash.rn)"; # if user is logged in, search for all tags regardless of tagger
				} else {
					$t->{query_from} .= " LEFT JOIN lx_et_hash ON (lexicon.rn = lx_et_hash.rn AND uid=8)"; # otherwise just show official stedt tags
				}
			}
			if ($is_string) {
				STEDT::Table::prep_regex $v;
				# use * to search for tag_str's that end with a particular string
				if ($v =~ s/^\*//) {
					# special case for * by itself to mean empty tag_str
					# ** for all numeric + non-numeric combinations
					# *** for aberrant combinations
					# otherwise make sure there's a numeric char before it
					if ($v eq '') { $v = '^'; }
					elsif ($v eq '*') { return "lx_et_hash.tag_str NOT LIKE lx_et_hash.tag AND lx_et_hash.tag_str RLIKE '[[:digit:]]'"; }
					elsif ($v eq '**') { return "lx_et_hash.tag_str NOT LIKE lx_et_hash.tag AND lx_et_hash.tag_str RLIKE '[[:digit:]]' AND lx_et_hash.tag_str NOT RLIKE '^[[:digit:]]+[^[:digit:]]+\$'"; }
					else { $v = "[[:digit:]]$v"; }
					return "lx_et_hash.tag_str RLIKE '$v\$'";
				}
				return "lx_et_hash.tag_str='$v'";
			}
			return "lx_et_hash.tag=$v";
		}
	},
	'user_an' => sub {
		my ($k,$v) = @_;
		if ($v eq '0') {
			return "0 = (SELECT COUNT(*) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=$uid2)";
		} elsif ($v eq '!0') {
			return "0 < (SELECT COUNT(*) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=$uid2)";
		} else {
			my $is_string = ($v !~ /^\d+$/);
			unless ($t->{query_from} =~ / lx_et_hash AS l_e_h2 ON \(lexicon.rn/) {
				$t->{query_from} .= " LEFT JOIN lx_et_hash AS l_e_h2 ON (lexicon.rn = l_e_h2.rn AND l_e_h2.uid=$uid2)";
			}
			if ($is_string) {
				STEDT::Table::prep_regex $v;
				if ($v =~ s/^\*//) {
					if ($v eq '') { $v = '^'; }
					elsif ($v eq '*') { return "l_e_h2.tag_str NOT LIKE l_e_h2.tag AND l_e_h2.tag_str RLIKE '[[:digit:]]'"; }
					elsif ($v eq '**') { return "l_e_h2.tag_str NOT LIKE l_e_h2.tag AND l_e_h2.tag_str RLIKE '[[:digit:]]' AND l_e_h2.tag_str NOT RLIKE '^[[:digit:]]+[^[:digit:]]+\$'"; }
					else { $v = "[[:digit:]]$v"; }
					return "l_e_h2.tag_str RLIKE '$v\$'";
				}
				return "l_e_h2.tag_str='$v'";
			}
			return "l_e_h2.tag=$v";
		}
	},
	'lexicon.gloss' => 'word',
	'languagegroups.grp' => sub {
		my ($k,$v,$cgi) = @_;
		if ($cgi->param('strict_grp')) {
			return "languagegroups.grpno='$v'";
		}
		$v =~ s/(\.0)+$//;
		return "languagegroups.grpno='$v' OR languagegroups.grpno LIKE '$v.\%'" # make it search all subgroups as well
	},
	'languagenames.language' => sub {
		my ($k,$v) = @_;
		if ($v eq '0') {
			return "lexicon.lgid=0";
		}
		if ($v =~ s/^=//) { # do an exact match if it starts with '=' (e.g. from autosuggest)
			return "$k='$v'";
		}
		# see STEDT::Table::Languagenames.pm for comments
		if ($v =~ s/^\*/\\\*/) { # escape initial *
			STEDT::Table::prep_regex $v;
			return "$k RLIKE '^$v'";
		}
		$v =~ s/\(/\\\(/g; # escape parens
		$v =~ s/\)/\\\)/g;
		$v =~ s/\[/\\\[/g; # escape square brackets
		$v =~ s/\]/\\\]/g;
		STEDT::Table::prep_regex $v;
		$v =~ s/(\w)/[[:<:]]$1/;
		return "$k RLIKE '$v'";
	},
);


$t->save_hooks(
	'analysis' => sub {
		my ($rn, $s) = @_;
		$s =~ s/\s//g; # strip all whitespace
		# check for valid tags if it's a number
		for my $tag (split(/,/, $s)) {
			next unless ($tag =~ s/^(\d+).*/$1/); # initial digits will be interpreted as a tag number; skip otherwise.
			die "$tag is too big of a tag number\n" unless $tag <= 65535;
			my ($n, $status) = $dbh->selectrow_array("SELECT tag,status FROM etyma WHERE tag=$tag");
			die "$tag is not a valid tag\n" unless $n;
			die "$tag has been deleted!\n" if uc($status) eq 'DELETE';
		}
		# simultaneously update lx_et_hash
		$dbh->do('DELETE FROM lx_et_hash WHERE rn=? AND uid=?', undef, $rn, $uid1);
		my $sth = $dbh->prepare(qq{INSERT INTO lx_et_hash (rn, tag, ind, tag_str, uid) VALUES (?, ?, ?, ?, ?)});
		my $index = 0;
		for my $tag (split(/,/, $s)) {
			# Insert new records into lx_et_hash based on the updated analysis field
			my $tag_str = $tag;
			$tag = 0 unless ($tag =~ s/^(\d+).*/$1/); # allow tag numbers followed by any string that begins with a non-numeric character
			$sth->execute($rn, $tag, $index, $tag_str, $uid1);
			$index++;
		}
		return 0;
	},
	'user_an' => sub {
		my ($rn, $s) = @_;
		$s =~ s/\s//g;
		for my $tag (split(/,/, $s)) {
			next unless ($tag =~ s/^(\d+).*/$1/); # initial digits will be interpreted as a tag number; skip otherwise.
			die "$tag is too big of a tag number\n" unless $tag <= 65535;
			my ($n, $status) = $dbh->selectrow_array("SELECT tag,status FROM etyma WHERE tag=$tag");
			die "$tag is not a valid tag\n" unless $n;
			die "$tag has been deleted!\n" if uc($status) eq 'DELETE';
		}
		$dbh->do('DELETE FROM lx_et_hash WHERE rn=? AND uid=?', undef, $rn, $uid2);
		my $sth = $dbh->prepare(qq{INSERT INTO lx_et_hash (rn, tag, ind, tag_str, uid) VALUES (?, ?, ?, ?, ?)});
		my $index = 0;
		for my $tag (split(/\s*,\s*/, $s)) {
			my $tag_str = $tag;
			$tag = 0 unless ($tag =~ s/^(\d+).*/$1/); # allow tag numbers followed by any string that begins with a non-numeric character
			$sth->execute($rn, $tag, $index, $tag_str, $uid2);
			$index++;
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
	if (x[i].name.match(/^analysis/)) {
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
	'lexicon.lgid',
	'lexicon.srcid',
	'analysis', # N.B. "save_hook"s get called when adding records, so no worries about lx_et_hash
	'lexicon.reflex',
	'lexicon.gloss',
	'lexicon.gfn',
	'lexicon.semkey',
);

$t->add_form_items(
	'lexicon.lgid' => sub {
		my $cgi = shift;
		my $self_url = $cgi->url(-absolute=>1);
		# make a list of srcabbr's which have one or more languages
		my $a = $dbh->selectall_arrayref("SELECT srcabbr, COUNT(lgid) as numlgs FROM srcbib LEFT JOIN languagenames USING (srcabbr) GROUP BY srcabbr HAVING numlgs > 0 ORDER BY srcabbr");
		return $cgi->popup_menu(-name => 'srcabbr-ignore',
			-values=>[0, map {$_->[0]} @$a],
			-labels=>{'0'=>'(Select...)'},
			-default=>'', -override=>1,
			-id=>'add_srcabbr',
			-onChange => <<EOF) .
new Ajax.Request('$self_url/json_lg/' + \$('add_srcabbr').value, {
	method: 'get',
    onSuccess: function(transport){
		var response = transport.responseText;
		var recs = response.evalJSON();
		var lg_menu = \$('add_language');
		lg_menu.options.length = 0;
		for (var i=0; i<recs.length; i++) {
			lg_menu.options[i] = new Option(recs[i][1],recs[i][0]);
		}
    },
    onFailure: function(){ alert('Error when attempting to retrieve language names.') }
});
EOF
			$cgi->popup_menu(-name=>'lexicon.lgid',
				-values=>[''],
				-id=>'add_language'
			);
	},
);

$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "Language not specified!\n" unless $cgi->param('lexicon.lgid');
	$err .= "Reflex is empty!\n" unless $cgi->param('lexicon.reflex');
	$err .= "Gloss is empty!\n" unless $cgi->param('lexicon.gloss');
	return $err;
});


#$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(500);

return $t;
}

1;
