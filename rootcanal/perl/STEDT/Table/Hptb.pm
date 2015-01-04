package STEDT::Table::Hptb;
use base STEDT::Table;
use strict;

sub new {
my ($self, $dbh, $privs) = @_;
my $t = $self->SUPER::new($dbh, 'hptb', 'hptb.hptbid', $privs);

$t->query_from('hptb LEFT JOIN et_hptb_hash USING (hptbid)');
$t->order_by('hptb.protogloss'); # default is the key

$t->fields(
	'hptb.hptbid',
	'hptb.protoform',
	'hptb.protogloss',
	'hptb.plg',
	'GROUP_CONCAT(et_hptb_hash.tag SEPARATOR ", ") AS tags',	# these are the real tags as determiend by the et_hptb_hash table
	'hptb.mainpage',
	'hptb.pages',
	'hptb.tags',	# these are the guessed tags
	'hptb.semclass1',
	'hptb.semclass2'
);  # this list MUST include the key

$t->searchable(
	'hptb.hptbid',
	'hptb.protoform',
	'hptb.protogloss',
	'hptb.plg',
	'hptb.pages',
	'hptb.tags'
);

#$t->editable(
#	'hptb.pages',
#	'hptb.mainpage'
#); # NB: the key is never editable

$t->field_editable_privs(
	'hptb.pages' => 16,
	'hptb.mainpage' => 16,
);

# Stuff for searching
$t->search_form_items(
	'hptb.plg' => sub {
		my $cgi = shift;
		# get list of proto-lgs
		my $plgs = $dbh->selectall_arrayref("SELECT DISTINCT plg FROM hptb");
		if ($plgs->[0][0] eq '') {
			# indexes 0,0 relies on sorted list of plgs.
			# allow explicit searching for empty strings
			# see 'wheres' sub, below
			$plgs->[0][0] = '0';
		}
		
		return $cgi->popup_menu(-name => 'hptb.plg', -values=>['', map {@$_} @$plgs], -labels=>{'0'=>'(no value)'},  -default=>'');
	}
);

# Special WHERE bits should be defined per-field here.
# Specify as perl sub which returns a string.
# The key field is assumed to be an int. Override here if necessary.
$t->wheres(
	'hptb.plg'	=> sub {my ($k,$v) = @_; $v = '' if $v eq '0'; "$k LIKE '$v'"},
	'hptb.protogloss'	=> 'word',
	'hptb.tags'	=> 'word',
	'hptb.pages'	=> 'word',
);


$t->search_by_disjunction('hptb.protogloss', 'hptb.tags'); # hopefully a rarely used option, if all of these fields are specified then do an OR search, not an AND search


return $t;
}

1;
