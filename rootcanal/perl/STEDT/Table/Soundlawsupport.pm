package STEDT::Table::Soundlawsupport;
use base STEDT::Table;
use strict;

sub new {
my ($self, $dbh, $privs, $uid) = @_;
my $t = $self->SUPER::new($dbh, 'soundlawsupport', 'soundlawsupport.id', $privs); # dbh, table, key, privs

$t->query_from(q|soundlawsupport|);
$t->order_by('soundlawsupport.protolg', 'soundlawsupport.ancestor'); # default is the key

$t->fields(
	   'soundlawsupport.id',
	   'soundlawsupport.rn',
	   'soundlawsupport.slid',
	   'soundlawsupport.tag',
	   'soundlawsupport.slot',
	   'soundlawsupport.protolg',
	   'soundlawsupport.ancestor',
	   'soundlawsupport.outcome',
	   'soundlawsupport.protoform',
	   'soundlawsupport.protogloss',
	   'soundlawsupport.language',
	   'soundlawsupport.reflex',
	   'soundlawsupport.gloss',
	   #'soundlawsupport.context',
	   'soundlawsupport.lgid',
	   'soundlawsupport.srcabbr',
	   'soundlawsupport.srcid',
);
$t->searchable(
	   'soundlawsupport.id',
	   'soundlawsupport.slid',
	   'soundlawsupport.tag',
	   'soundlawsupport.slot',
	   'soundlawsupport.protolg',
	   'soundlawsupport.ancestor',
	   'soundlawsupport.outcome',
	   'soundlawsupport.language',
	   #'soundlawsupport.context',
);
$t->editable(
	   'soundlawsupport.tag',
	   'soundlawsupport.slot',
	   'soundlawsupport.protolg',
	   'soundlawsupport.ancestor',
	   'soundlawsupport.outcome',
	   'soundlawsupport.language',
	   #'soundlawsupport.context',
	   'soundlawsupport.lgid',
);

# Stuff for searching
$t->search_form_items(
	'soundlawsupport.protolg' => sub {
		my $cgi = shift;
		# get list of protolgs
		my $protolg = $dbh->selectall_arrayref("SELECT DISTINCT protolg FROM soundlawsupport");
		return $cgi->popup_menu(-name => 'soundlawsupport.protolg', -values=>['', map {@$_} @$protolg], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'soundlawsupport.ancestor' => sub {
		my $cgi = shift;
		# get list of ancestors
		my $ancestor = $dbh->selectall_arrayref("SELECT DISTINCT ancestor FROM soundlawsupport ORDER by ancestor");
		return $cgi->popup_menu(-name => 'soundlawsupport.ancestor', -values=>['', map {@$_} @$ancestor], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'soundlawsupport.slot' => sub {
		my $cgi = shift;
		# get list of slots
		my $slot = $dbh->selectall_arrayref("SELECT DISTINCT slot FROM soundlawsupport ORDER BY slot");
		return $cgi->popup_menu(-name => 'soundlawsupport.slot', -values=>['', map {@$_} @$slot], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'soundlawsupport.language' => sub {
		my $cgi = shift;
		# get list of languages
		my $language = $dbh->selectall_arrayref("SELECT DISTINCT language FROM soundlawsupport ORDER by language");
		return $cgi->popup_menu(-name => 'soundlawsupport.language', -values=>['', map {@$_} @$language], -labels=>{'0'=>'(no value)'},  -default=>'');
	}
);

$t->save_hooks(

);


$t->wheres(
	   'soundlawsupport.ancestor'	=> 'word',
	   'soundlawsupport.outcome'   => 'word',
	   'soundlawsupport.prefx' => 'value',
	   'soundlawsupport.initial' => 'value',
	   'soundlawsupport.rhyme' => 'value',
	   'soundlawsupport.tone' => 'value',
	   'soundlawsupport.lgid' => 'value',
	   'soundlawsupport.language' => sub {
		my ($k,$v) = @_;
		$v =~ s/\(/\\\(/g; # escape all parens
		$v =~ s/\)/\\\)/g;
		STEDT::Table::prep_regex $v;
		$v =~ s/(\w)/[[:<:]]$1/; # put a word boundary before the first \w char
		return "$k RLIKE '$v'";
	}
);


$t->addable(
	   'soundlawsupport.tag',
	   'soundlawsupport.slot',
	   'soundlawsupport.protolg',
	   'soundlawsupport.ancestor',
	   'soundlawsupport.outcome',
	   'soundlawsupport.language',
	   'soundlawsupport.context',
	   'soundlawsupport.lgid',

);

$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "Soundlaw ancestor cannot be empty!\n" unless $cgi->param('soundlawsupport.ancestor');
	$err .= "Subsoundlaw outcome not specified!\n" unless $cgi->param('soundlawsupport.outcome');
	$err .= "No language!\n" unless $cgi->param('soundlawsupport.language');
	return $err;
});


$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);

return $t;
}

1;
