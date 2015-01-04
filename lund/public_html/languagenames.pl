#!/usr/bin/perl
# edited by dwbruhn to use protected pm, 2010-December-07

use strict;
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
my $t = new TableEdit $dbh, 'languagenames', 'languagenames.lgid';	# table, key
$t->query_from(q|languagenames NATURAL LEFT JOIN languagegroups LEFT JOIN lexicon USING (lgid)|);
	# IMPORTANT: we can ignore spec='L' here because rn is only used for lexicon entries
$t->order_by('languagenames.lgsort');

$t->fields(
	'languagenames.lgid',
	'COUNT(lexicon.rn)',
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
$t->field_labels(
	'COUNT(lexicon.rn)' => 'recs',
);
$t->searchable(
#	'languagenames.lgid',
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
	'languagenames.grpid',

);
$t->editable(
	'languagenames.language',
	'languagenames.lgsort'  ,
	'languagenames.notes'   ,
	'languagenames.lgcode',
	'languagenames.srcofdata',
#	'languagenames.pinotes' ,
#	'languagenames.picode'  ,
	'languagenames.grpid'	,
);
$t->always_editable('languagenames.silcode');

# Sizes are in number of characters for text inputs (for searching).
# These values will also be used as relative table column widths
# for display.
$t->sizes(
	'languagenames.lgid'     => 4,
	'languagenames.srcabbr'  => 7,
	'languagenames.lgabbr'   => 5,
	'languagenames.lgcode'   => 3,
	'languagenames.silcode'	 => 4,
	'languagenames.language' => 15,
	'languagenames.lgsort'   => 15,
	'languagenames.notes'    => 20,
	'languagenames.srcofdata'=> 10,
#	'languagenames.pinotes'  => 10,
#	'languagenames.picode'   => 10,
	'languagenames.grpid'	=> 3,
);

# Stuff for searching
$t->search_form_items(
	'languagegroups.grp' => sub {
		my $cgi = shift;
		my $grps = $dbh->selectall_arrayref("SELECT grpno, CONCAT(grpno,' ',LEFT(grp,15),' (id:',grpid,')') FROM languagegroups");
		my @grp_nos = map {$_->[0]} @$grps;
		my %grp_labels;
		@grp_labels{@grp_nos} = map {$_->[1]} @$grps;
		
		return $cgi->popup_menu(-name => 'languagegroups.grp', -values=>['',@grp_nos],
  								-default=>'', -override=>1,
  								-labels=>\%grp_labels);
	}
);

$t->wheres(
	'languagenames.lgid' => 'int',
	'languagenames.lgcode' => 'int',
	'languagenames.grpid' => 'int',
	'languagenames.srcabbr' => sub {my ($k,$v) = @_; "$k LIKE '$v\%'"},
	'languagegroups.grp' => sub {my ($k,$v) = @_; $v =~ s/(\.0)+$//; "languagegroups.grpno LIKE '$v\%'"},
		# make it search all subgroups as well
	'languagenames.language' => sub { my ($k,$v) = @_; "$k RLIKE '[[:<:]]$v'"; },
);


# Special handling of results
$t->update_form_items(
	'languagenames.srcabbr' => sub {
		my ($cgi,$s,$key) = @_;
		return $s =~ /^[?-]/ ? $s : $cgi->a({-href=>"srcbib.pl?submit=Search&srcbib.srcabbr=$s", -target=>'srcbib'},
						$s);
	},
	'COUNT(lexicon.rn)' =>  sub {
		my ($cgi,$n,$key) = @_;
		return $n == 0 ? 0 :
			$cgi->a({-href=>"tagger2.pl?submit=Search&lexicon.lgid=$key"},"$n");
	}
);
$t->footer_extra(sub {
print q|<script type="text/javascript">
TableKit.Editable.selectInput('languagenames.grpid', {}, [|;
# We query the database for the groups three times in this script,
# which is kinda inefficient,
# but there aren't that many groups, so it's OK.
	my $grps = $dbh->selectall_arrayref("SELECT grpid, CONCAT(grpno,' ',grp) FROM languagegroups");
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
		my $grps = $dbh->selectall_arrayref("SELECT grpid, CONCAT(grpno,' ',grp) FROM languagegroups");
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
	return $err;
});


$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);
$t->generate;

$dbh->disconnect;
