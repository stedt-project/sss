package STEDT::Table::Soundlaws;
use base STEDT::Table;
use strict;

sub new {
my ($self, $dbh, $privs, $uid) = @_;
my $t = $self->SUPER::new($dbh, 'soundlaws', 'soundlaws.id', $privs); # dbh, table, key, privs

$t->query_from(q|soundlaws|);
$t->order_by('soundlaws.protolg', 'soundlaws.ancestor'); # default is the key

$t->fields(
	   'soundlaws.id',
	   'soundlaws.slid',
	   'soundlaws.slot',
	   'soundlaws.protolg',
	   'soundlaws.ancestor',
	   'soundlaws.outcome',
	   'soundlaws.language',
	   'soundlaws.context',
	   'soundlaws.n',
);
$t->searchable(
	   'soundlaws.id',
	   'soundlaws.slid',
	   'soundlaws.slot',
	   'soundlaws.protolg',
	   'soundlaws.ancestor',
	   'soundlaws.outcome',
	   'soundlaws.language',
	   'soundlaws.context',
);
$t->editable(
	   'soundlaws.slot',
	   'soundlaws.protolg',
	   'soundlaws.ancestor',
	   'soundlaws.outcome',
	   'soundlaws.language',
	   'soundlaws.context',
);

# Stuff for searching
$t->search_form_items(
	'soundlaws.protolg' => sub {
		my $cgi = shift;
		# get list of protolgs
		my $protolg = $dbh->selectall_arrayref("SELECT DISTINCT protolg FROM soundlaws");
		return $cgi->popup_menu(-name => 'soundlaws.protolg', -values=>['', map {@$_} @$protolg], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'soundlaws.ancestor' => sub {
		my $cgi = shift;
		# get list of ancestors
		my $ancestor = $dbh->selectall_arrayref("SELECT DISTINCT ancestor FROM soundlaws ORDER by ancestor");
		return $cgi->popup_menu(-name => 'soundlaws.ancestor', -values=>['', map {@$_} @$ancestor], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'soundlaws.slot' => sub {
		my $cgi = shift;
		# get list of slots
		my $slot = $dbh->selectall_arrayref("SELECT DISTINCT slot FROM soundlaws ORDER BY slot");
		return $cgi->popup_menu(-name => 'soundlaws.slot', -values=>['', map {@$_} @$slot], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'soundlaws.language' => sub {
		my $cgi = shift;
		# get list of languages
		my $language = $dbh->selectall_arrayref("SELECT DISTINCT language FROM soundlaws ORDER by language");
		return $cgi->popup_menu(-name => 'soundlaws.language', -values=>['', map {@$_} @$language], -labels=>{'0'=>'(no value)'},  -default=>'');
	}
);

$t->save_hooks(

);


$t->wheres(
	   'soundlaws.ancestor'	=> 'word',
	   'soundlaws.outcome'   => 'word',
	   'soundlaws.prefx' => 'value',
	   'soundlaws.initial' => 'value',
	   'soundlaws.rhyme' => 'value',
	   'soundlaws.tone' => 'value',
	   'soundlaws.language' => sub {
		my ($k,$v) = @_;
		$v =~ s/\(/\\\(/g; # escape all parens
		$v =~ s/\)/\\\)/g;
		STEDT::Table::prep_regex $v;
		$v =~ s/(\w)/[[:<:]]$1/; # put a word boundary before the first \w char
		return "$k RLIKE '$v'";
	}
);


$t->addable(
	   'soundlaws.slot',
	   'soundlaws.protolg',
	   'soundlaws.ancestor',
	   'soundlaws.outcome',
	   'soundlaws.language',
	   'soundlaws.context',
);

$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "Soundlaw ancestor cannot be empty!\n" unless $cgi->param('soundlaws.ancestor');
	$err .= "Subsoundlaw outcome not specified!\n" unless $cgi->param('soundlaws.outcome');
	$err .= "No language!\n" unless $cgi->param('soundlaws.language');
	return $err;
});


$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);

return $t;
}

1;
