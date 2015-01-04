package STEDT::Table::Languagenames;
use base STEDT::Table;
use strict;

sub new {
my ($self, $dbh, $privs) = @_;
my $t = $self->SUPER::new($dbh, 'languagenames', 'languagenames.lgid', $privs);

$t->query_from(q|languagenames NATURAL LEFT JOIN languagegroups LEFT JOIN lexicon USING (lgid)|);
$t->order_by('languagenames.lgsort');

$t->fields(
	'languagenames.lgid',
	'SUM(IF(ISNULL(lexicon.status) || lexicon.status="HIDE" || lexicon.status="DELETED",0,1)) AS num_recs',	# for each joined row from lexicon table, count record if it's not null or not hidden/deleted; replaces	COUNT(lexicon.rn)
	'languagenames.srcabbr',
	'languagenames.lgabbr',
	'languagenames.lgcode',
	'languagenames.silcode',
	'languagenames.language',
	'languagenames.lgsort',
	'languagenames.notes',
	'languagenames.srcofdata',
#	'languagenames.pinotes',
#	'languagenames.picode',
	'languagegroups.grpno',
	'languagegroups.grp',
	'languagenames.grpid',
);
$t->searchable(
	'languagenames.lgid',
	'languagenames.srcabbr',
	'languagenames.language',
#	'languagenames.lgabbr',
	'languagenames.silcode',
	'languagenames.lgcode',
#	'languagenames.lgsort',
	'languagenames.notes',
#	'languagenames.srcofdata',
#	'languagenames.pinotes',
#	'languagenames.picode',
#	'languagegroups.grpno',
	'languagegroups.grp',

);
#$t->editable(
#	'languagenames.language',
#	'languagenames.lgsort'  ,
#	'languagenames.notes'   ,
#	'languagenames.lgcode',
#	'languagenames.silcode',
#	'languagenames.srcofdata',
#	'languagenames.pinotes' ,
#	'languagenames.picode'  ,
#	'languagenames.grpid'	,
#);

$t->field_editable_privs(
	     'languagenames.language' => 8,
	     'languagenames.lgsort' => 8,
	     'languagenames.notes' => 8,
	     'languagenames.lgcode' => 8,
	     'languagenames.silcode' => 8,
	     'languagenames.srcofdata' => 8,
	     'languagenames.grpid' => 8,
);

# Stuff for searching
$t->search_form_items(
	'languagegroups.grp' => sub {
		my $cgi = shift;
		my $grps = $dbh->selectall_arrayref("SELECT grpno, CONCAT(grpno,' ',LEFT(grp,18),' (id:',grpid,')') FROM languagegroups ORDER BY grp0,grp1,grp2,grp3,grp4");
		my @grp_nos = map {$_->[0]} @$grps;
		my %grp_labels;
		@grp_labels{@grp_nos} = map {$_->[1]} @$grps;
		
		return $cgi->popup_menu(-name => 'languagegroups.grp', -values=>['',@grp_nos],
  								-default=>'', # -override=>1,
  								-labels=>\%grp_labels)
  			. '<small><input type="checkbox" name="strict_grp" id="strict_grp"'
  			. ($cgi->param('languagegroups.grp') && !$cgi->param('strict_grp') ? '' : ' checked')
  			. '><label for="strict_grp">strict</label></small>';
	}
);

$t->wheres(
	'languagenames.lgid' => 'int',
	'languagenames.lgcode' => 'int',
	'languagenames.grpid' => 'int',
	'languagenames.srcabbr' => 'beginword',
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
		if ($v =~ s/^\*/\\\*/) { # escape initial *
			STEDT::Table::prep_regex $v;
			return "$k RLIKE '^$v'";
		}
		$v =~ s/\(/\\\(/g; # escape all parens
		$v =~ s/\)/\\\)/g;
		$v =~ s/\[/\\\[/g; # escape square brackets
		$v =~ s/\]/\\\]/g;
		STEDT::Table::prep_regex $v;
		$v =~ s/(\w)/[[:<:]]$1/; # put a word boundary before the first \w char
		return "$k RLIKE '$v'";
	}
);


$t->footer_extra(sub {
print q|<script type="text/javascript">
TableKit.Editable.selectInput('languagenames.grpid', {}, [|;
# We query the database for the groups three times in this script,
# which is kinda inefficient,
# but there aren't that many groups, so it's OK.
	my $grps = $dbh->selectall_arrayref("SELECT grpid, CONCAT(grpno,' ',grp) FROM languagegroups ORDER BY grp0,grp1,grp2,grp3,grp4");
	print join ',',map {"['$_->[1]','$_->[0]']"} @$grps;
print ']);</script>
';
});


# Add form stuff
$t->addable(
	'languagenames.srcabbr',
	'languagenames.lgabbr',
	'languagenames.lgsort',
	'languagenames.language',
	'languagenames.notes',
	'languagenames.srcofdata',
	'languagenames.lgcode',
	'languagenames.silcode',
	'languagenames.grpid',
);
$t->add_form_items(
	'languagenames.srcabbr' => sub {
		my $cgi = shift;
		# list of all srcabbr's
		my $a = $dbh->selectall_arrayref("SELECT srcabbr FROM srcbib ORDER BY srcabbr");
		return $cgi->popup_menu(-name => 'languagenames.srcabbr',
			-values=>['', map {@$_} @$a],
			-labels=>{''=>'(Select...)'},
			-default=>'', -override=>1,
		);
	},
	'languagenames.grpid' => sub {
		my $cgi = shift;
		my $grps = $dbh->selectall_arrayref("SELECT grpid, CONCAT(grpno,' ',grp) FROM languagegroups ORDER BY grp0,grp1,grp2,grp3,grp4");
		my @grp_ids = map {$_->[0]} @$grps;
		my %grp_labels;
		@grp_labels{@grp_ids} = map {$_->[1]} @$grps;
		
		return $cgi->popup_menu(-name => 'languagenames.grpid', -values=>['',@grp_ids],
			-default=>'', -override=>1,
			-labels=>\%grp_labels);
	}
);
$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "srcabbr not specified!\n" unless $cgi->param('languagenames.srcabbr');
	$err .= "lgsort not specified!\n" unless $cgi->param('languagenames.lgsort');
	$err .= "Language name not specified!\n" unless $cgi->param('languagenames.language');
	$err .= "Group not specified!\n" unless $cgi->param('languagenames.grpid');
	if ($cgi->param('languagenames.lgcode') eq '') {	# set lgcode to zero if user has left it blank
		$cgi->param('languagenames.lgcode',0);
	}
	return $err;
});


$t->allow_delete(1);

return $t;
}

1;
