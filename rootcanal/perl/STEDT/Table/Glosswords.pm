package STEDT::Table::Glosswords;
use base STEDT::Table;
use strict;

sub new {
my ($self, $dbh, $privs, $uid) = @_;
my $t = $self->SUPER::new($dbh, 'glosswords', 'glosswords.id', $privs); # dbh, table, key, privs

$t->query_from(q|glosswords LEFT JOIN chapters on (glosswords.semkey=chapters.semkey)|);
$t->order_by('glosswords.word, glosswords.semkey');
$t->fields(
	'glosswords.id',
	'glosswords.word',
	'glosswords.semkey',
	'chapters.chaptertitle',
	'glosswords.subcat',
	'(SELECT COUNT(*) FROM lexicon WHERE lexicon.semkey=glosswords.semkey AND lexicon.status != "HIDE" AND lexicon.status != "DELETED") AS num_recs'
);
$t->field_visible_privs(
);

$t->searchable(
	'glosswords.word',
	'glosswords.semkey',
	'glosswords.subcat'

);
$t->field_editable_privs(
	'glosswords.word' => 8,
	'glosswords.semkey' => 8,
	'glosswords.subcat' => 8
);

# Stuff for searching
$t->search_form_items(
);

$t->wheres(
	'glosswords.words'  => 'word',
	'glosswords.semkey' => 'value'
);

$t->save_hooks(
);

# Add form stuff
$t->addable(
	'glosswords.word',
	'glosswords.semkey',
	'glosswords.subcat'
);
$t->add_form_items(
);
$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "word not specified!\n" unless $cgi->param('glosswords.word');
	return $err;
});


#$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);

return $t;
}

1;
