package STEDT::Table::Notes;
use base STEDT::Table;
use strict;

sub new {
my ($self, $dbh, $privs, $uid) = @_;
my $t = $self->SUPER::new($dbh, 'notes', 'notes.noteid', $privs); # dbh, table, key, privs

$t->query_from(q|notes LEFT JOIN `users` ON notes.uid = users.uid|);
$t->default_where('');
$t->order_by('notes.noteid');
$t->fields('notes.noteid',
	'notes.spec',
	'notes.notetype',
	'notes.rn',
	'notes.tag',
	'notes.id',
	'(SELECT languagegroups.grpno from languagegroups WHERE notes.spec="E" and notes.id=languagegroups.grpid) AS grpno',
	'notes.ord',
	'notes.xmlnote',
	'users.username',
);

$t->field_visible_privs(
);

$t->searchable('notes.noteid',
	'notes.spec',
	'notes.notetype',
	'notes.rn',
	'notes.tag',
	'notes.id',
	'notes.ord',
	'notes.xmlnote',
	'notes.uid',
);
$t->field_editable_privs(
#	'notes.rn' => 16,
#	'notes.tag' => 16,
#	'notes.id' => 16,
#	'notes.notetype' => 16,
#	'notes.spec' => 16,
#	'notes.ord' => 16,
#	'notes.xmlnote' => 16,
#	'notes.uid' => 16,
);

# Stuff for searching
$t->search_form_items(
	'notes.uid' => sub {
		my $cgi = shift;
		# get list of users who own notes
		my $users = $dbh->selectall_arrayref("SELECT DISTINCT uid, username FROM notes LEFT JOIN users USING (uid) ORDER BY uid");
		my @uids = map {$_->[0]} @$users;
		my %usernames;
		@usernames{@uids} = map {$_->[1] . ' (id:' . $_->[0] . ')'} @$users;
		return $cgi->popup_menu(-name => 'notes.uid', -values=>['', @uids],
							-labels=>\%usernames,
							-default=>'');
	},
	# add dropdown boxes for spec and notetype
	'notes.spec' => sub {
		my $cgi = shift;
		my @specs = qw/L E C S/;
		my %spec_labels = (
			'L' => 'Lexicon',
			'E' => 'Etyma',
			'C' => 'Chapter',
			'S' => 'Source',
		);
		return $cgi->popup_menu(-name => 'notes.spec', -values=>['', @specs],
							-labels=>\%spec_labels,
							-default=>'');
	},
	'notes.notetype' => sub {
		my $cgi = shift;
		my @notetypes = qw/I T F H G O/;
		my %type_labels = (
			'I' => 'Internal',
			'T' => 'Text',
			'F' => 'Final',
			'H' => 'HPTB',
			'G' => 'Graphics',
			'O' => 'Orig/Src',
		);
		return $cgi->popup_menu(-name => 'notes.notetype', -values=>['', @notetypes],
							-labels=>\%type_labels,
							-default=>'');
	},
);

$t->wheres(
	'notes.noteid' => 'int',
	'notes.spec' => 'value',
	'notes.notetype' => 'value',
	'notes.rn' => 'int',
	'notes.tag' => 'int',
#	'notes.id' => 'value',
	'notes.ord' => 'int',
	'notes.uid' => 'int',
);

$t->save_hooks(
);

$t->reload_on_save(
);

#$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);

return $t;
}

1;
