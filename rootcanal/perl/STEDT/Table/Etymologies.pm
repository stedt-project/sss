package STEDT::Table::Etymologies;
use base STEDT::Table;
use strict;

# This module allows users to view and search all STEDT-tagged etymologies (associations of lexicon records with etyma).
# It purports to allow access to the 'etymologies' table, which is actually a VIEW based on lx_et_hash,
# created with RnUidIndTag as a unique key (concatenation of rn, uid, index, and tag):
#
#	CREATE SQL SECURITY INVOKER VIEW etymologies AS
#	SELECT CONCAT_WS(':',rn,uid,ind,tag) AS RnUidIndTag, rn,uid,ind,tag,tag_str
#	FROM lx_et_hash
#	WHERE tag!=0
#	ORDER BY rn,uid,ind,tag

sub new {

my ($self, $dbh, $privs, $uid) = @_;
my $t = $self->SUPER::new($dbh, 'etymologies', 'etymologies.RnUidIndTag', $privs); # dbh, table, key, privs

$t->query_from(q|etymologies LEFT JOIN lexicon USING (rn)
	LEFT JOIN languagenames USING (lgid)
	LEFT JOIN languagegroups AS Lgrps ON (languagenames.grpid=Lgrps.grpid)
	LEFT JOIN etyma USING (tag)
	LEFT JOIN languagegroups AS Egrps ON (etyma.grpid=Egrps.grpid)|);
$t->default_where('');
$t->order_by('Lgrps.grp0, Lgrps.grp1, Lgrps.grp2, Lgrps.grp3, Lgrps.grp4, languagenames.lgsort, etyma.tag, lexicon.reflex, etymologies.uid');
$t->fields(
	'etymologies.RnUidIndTag',
	'etymologies.rn',
	'etymologies.uid',
	'etymologies.ind',
	'(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=etymologies.rn AND uid=etymologies.uid) AS analysis',
	'lexicon.reflex',
	'lexicon.gloss',
	'lexicon.gfn',
	'languagenames.language',
	'Lgrps.grpid',
	'Lgrps.grpno',
	'Lgrps.grp',
	# if $privs is undefined (or 2), then it's a public user (or a user with a non-privileged account) and internal notes should be excluded from the note count
#	((defined $privs && ($privs & 1)) ? '(SELECT COUNT(*) FROM notes WHERE rn=etymologies.rn) AS num_notes' : '(SELECT COUNT(*) FROM notes WHERE rn=etymologies.rn AND notetype!=\'I\') AS num_notes'),
	'etyma.tag', # could use etymologies.tag, but using this identical field gets the style highlighting correct
	'etyma.protoform',
	'etyma.protogloss',
	'etyma.grpid',
	'Egrps.plg',
	'Egrps.grpno',
);
$t->searchable('etymologies.rn',
	'etymologies.uid',
#	'etymologies.ind',
#	'analysis',
	'lexicon.reflex', 'lexicon.gloss', 'lexicon.gfn',
	'languagenames.language', 'Lgrps.grp',
	'etyma.tag',
	'etyma.protoform', 'etyma.protogloss', 'etyma.grpid',
);
$t->field_visible_privs(
);
$t->field_editable_privs(
);

# Stuff for searching
$t->search_form_items(
	'Lgrps.grp' => sub {
		my $cgi = shift;
		my $grps = $dbh->selectall_arrayref("SELECT grpno, CONCAT(grpno,' ',LEFT(grp,18)) FROM languagegroups ORDER BY grp0,grp1,grp2,grp3,grp4");
		my @grp_nos = map {$_->[0]} @$grps;
		my %grp_labels;
		@grp_labels{@grp_nos} = map {$_->[1]} @$grps;
		
		return $cgi->popup_menu(-name => 'Lgrps.grp', -values=>['',@grp_nos],
  								-default=>'', # -override=>1,
  								-labels=>\%grp_labels)
  			. '<br><small><input type="checkbox" name="strict_grp" id="strict_grp"'
  			. ($cgi->param('strict_grp') ? ' checked' : '')
  			. '><label for="strict_grp">strict</label></small>';
	},
	'etyma.grpid' => sub {
		my $cgi = shift;
		my $a = $dbh->selectall_arrayref("SELECT CONCAT(grpno, ' - ', plg), grpid FROM languagegroups WHERE plg != '' ORDER BY grp0,grp1,grp2,grp3,grp4");
		unshift @$a, ['', ''];
		push @$a, ['(undefined)', 0];
		my @ids = map {$_->[1]} @$a;
		my %labels;
		@labels{@ids} = map {$_->[0]} @$a;
		return $cgi->popup_menu(-name => 'etyma.grpid', -values=>[@ids],
  								-default=>'',
  								-labels=>\%labels);
	},
	'etymologies.uid' => sub {
		my $cgi = shift;
		# get list of users who have tagged items
		my $users = $dbh->selectall_arrayref("SELECT DISTINCT uid, username FROM lx_et_hash LEFT JOIN users USING (uid) ORDER BY uid");
		my @uids = map {$_->[0]} @$users;
		my %usernames;
		@usernames{@uids} = map {$_->[1] . ' (uid:' . $_->[0] . ')'} @$users;
		return $cgi->popup_menu(-name => 'etymologies.uid', -values=>['', @uids],
							-labels=>\%usernames,
							-default=>'');
	},
);

$t->wheres(
	'etymologies.rn' => 'int',
	'etymologies.ind' => 'int',
	'etyma.tag' => 'int',
#	'languagegroups.grpid' => 'int',
	'lexicon.gloss' => 'word',
	'languagenames.language' => sub {
		my ($k,$v) = @_;
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
	'Lgrps.grp' => sub {
		my ($k,$v,$cgi) = @_;
		if ($cgi->param('strict_grp')) {
			return "Lgrps.grpno='$v'";
		}
		$v =~ s/(\.0)+$//;
		return "Lgrps.grpno='$v' OR Lgrps.grpno LIKE '$v.\%'" # make it search all subgroups as well
	},

	'etyma.protogloss' => 'word',
	'etyma.grpid'	=> 'int',
	'etymologies.uid' => 'int',
);


#$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(500);

return $t;
}

1;
