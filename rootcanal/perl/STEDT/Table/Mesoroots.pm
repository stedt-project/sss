package STEDT::Table::Mesoroots;
use base STEDT::Table;
use strict;

sub new {
my ($self, $dbh, $privs, $uid) = @_;
my $t = $self->SUPER::new($dbh, 'mesoroots', 'mesoroots.id', $privs); # dbh, table, key, privs

$t->query_from(q|mesoroots LEFT JOIN `users` ON mesoroots.uid = users.uid LEFT JOIN languagegroups ON mesoroots.grpid=languagegroups.grpid|);
$t->default_where('');
$t->order_by('mesoroots.tag');
$t->fields('mesoroots.id',
	'mesoroots.tag',
	'mesoroots.form',
	'mesoroots.gloss',
	'mesoroots.grpid',
	'languagegroups.plg',
	'languagegroups.grpno',
	'mesoroots.old_tag',
	'mesoroots.old_note',
	'mesoroots.variant',
	'users.username',
);
$t->field_visible_privs(
	'users.username' => 1,
);
$t->searchable('mesoroots.id',
	'mesoroots.tag',
	'mesoroots.form',
	'mesoroots.gloss',
	'mesoroots.grpid',
	'mesoroots.uid',
);
$t->field_editable_privs(
	# none are editable: can edit them using the etymon view or (if admin) single-record view
);

# Stuff for searching
$t->search_form_items(
	'mesoroots.grpid' => sub {
		my $cgi = shift;
		my $a = $dbh->selectall_arrayref("SELECT CONCAT(grpno, ' - ', plg), grpid FROM languagegroups WHERE plg != '' ORDER BY grp0,grp1,grp2,grp3,grp4");
		unshift @$a, ['', ''];
		push @$a, ['(undefined)', 0];
		my @ids = map {$_->[1]} @$a;
		my %labels;
		@labels{@ids} = map {$_->[0]} @$a;
		return $cgi->popup_menu(-name => 'mesoroots.grpid', -values=>[@ids],
  								-default=>'',
  								-labels=>\%labels);
	},
	'mesoroots.uid' => sub {
		my $cgi = shift;
		# get list of users who own mesoroots
		my $users = $dbh->selectall_arrayref("SELECT DISTINCT uid, username FROM mesoroots LEFT JOIN users USING (uid) ORDER BY uid");
		my @uids = map {$_->[0]} @$users;
		my %usernames;
		@usernames{@uids} = map {$_->[1] . ' (id:' . $_->[0] . ')'} @$users;
		return $cgi->popup_menu(-name => 'mesoroots.uid', -values=>['', @uids],
							-labels=>\%usernames,
							-default=>'');
	},
);

$t->wheres(
	'mesoroots.tag' => sub {my ($k,$v) = @_;
		return STEDT::Table::where_int($k,$v);
	},
	'mesoroots.grpid' => 'int',
	'mesoroots.gloss' => 'word',
	'mesoroots.uid' => 'int',
);

$t->save_hooks(
);

$t->reload_on_save(
	'mesoroots.grpid'
);

#$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);

return $t;
}

1;
