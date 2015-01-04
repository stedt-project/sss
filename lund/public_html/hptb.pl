#!/usr/bin/perl

# edited by dwbruhn to use protected pm, 2010-May-16
# example of CRUD (or VEDAP - View Edit Delete Add Print)
# using our TableEdit module
# by Dominic Yu
# 2008.04.21

use strict;
use DBI;
use TableEdit;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser set_message/;
BEGIN {
        $^W = 1;
        unshift @INC, "../pm" if -e "../pm";
        CGI::Carp::set_message("Report bugs/features to stedt@socrates.berkeley.edu");
}
use STEDTUtil;

my $dbh = STEDTUtil::connectdb();

# Give it the table name and the key.
# These are used for saving/deleting and counting.
# Each table must have a key!
my $t = new TableEdit $dbh, 'hptb', 'hptbid';
$t->query_from('hptb LEFT JOIN et_hptb_hash USING (hptbid)'); # defaults to table name, override if doing a JOIN
$t->order_by('protogloss'); # default is the key

$t->fields('hptbid','protoform','protogloss','plg',
	'GROUP_CONCAT(et_hptb_hash.tag SEPARATOR ", ")',
	'mainpage','pages','tags',
	'semclass1','semclass2'
); # this list MUST include the key
$t->field_labels(
	'hptbid' => 'id',
	'plg' => 'pLg',
	'GROUP_CONCAT(et_hptb_hash.tag SEPARATOR ", ")' => 'tags',
	'mainpage' => 'main page',
	'pages' => 'HPTB pages',
	'tags'     => 'guessed tag #s',
	'semclass1' => 'semclass1',
	'semclass2' => 'semclass2',
);
$t->searchable('hptbid','protoform','protogloss','plg','pages','tags');
$t->editable('pages','mainpage');	# NB: the key is never editable
#$t->always_editable('semclass1');# these two must be mutually exclusive

# Sizes are in number of characters for text inputs (for searching).
# These values will also be used as relative table column widths
# for display.
$t->sizes(
	'hptbid' => 4,
	'protoform' => 15,
	'protogloss' => 20,
	'plg' => 4,
	'pages' => 20,
	'tags' => 20,
	mainpage => 4,
);

# Special elements in the search form.
$t->search_form_items(
	plg => sub {
		my $cgi = shift;
		# get list of proto-lgs
		my $plgs = $dbh->selectall_arrayref("SELECT DISTINCT plg FROM hptb");
		if ($plgs->[0][0] eq '') {
			# indexes 0,0 relies on sorted list of plgs.
			# allow explicit searching for empty strings
			# see 'wheres' sub, below
			$plgs->[0][0] = '0';
		}
		
		return $cgi->popup_menu(-name => 'plg', -values=>['', map {@$_} @$plgs], -labels=>{'0'=>'(no value)'},  -default=>'', -override=>1);
	}
);

# Special WHERE bits should be defined per-field here.
# Specify as perl sub which returns a string.
# The key field is assumed to be an int. Override here if necessary.
$t->wheres(
	plg	=> sub {my ($k,$v) = @_; $v = '' if $v eq '0'; "$k LIKE '$v'"},
	protogloss	=> 'word',
	tags		=> 'word',
	pages		=> 'word',
);

$t->search_by_disjunction(qw/protogloss tags/); # hopefully a rarely used option, if all of these fields are specified then do an OR search, not an AND search


# Special handling of results

$t->search_limit(100);
#$t->allow_delete(1);
$t->generate;

$dbh->disconnect;
