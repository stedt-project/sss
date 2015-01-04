#!/usr/bin/perl
use strict;
use DBI;
use STEDTUtil;
use TableEdit;

my $dbh = STEDTUtil::connectdb();

my $t = new TableEdit $dbh, 'srcbib', 'srcbib.srcabbr';
$t->query_from('srcbib LEFT JOIN languagenames USING (srcabbr) LEFT JOIN lexicon USING (lgid)');
$t->order_by('srcbib.srcabbr, srcbib.year'); # default is the key

$t->fields(
	'srcbib.srcabbr',
	'COUNT(DISTINCT languagenames.lgid)',
	'COUNT(lexicon.rn)',
#	'srcbib.citation',	# seems kinda useless; format looks like last name + two digits of year + some kind of abbrev.
	'srcbib.author',
	'srcbib.year',
	'srcbib.title',
	'srcbib.imprint',	# this is the "rest" of the bibliography line, after author + year + title.
	'srcbib.status',	# looks important: Fix Xcripn, Incomplete, Input, Loaded, No Stack, PI only, Proof, TBEntr'd, etc.
#	'srcbib.location',	# looks useless
	'srcbib.notes',
	'srcbib.todo',		# Complete, Defer, Eval, InQueue, Refonly
#	'srcbib.dataformat',# looks useless: mostly STAK vs. TEXT
	'srcbib.format',	# Art./Monograph, Dictionary, Etymologies, Grammar, Other, Questionnaire, Synonym Sets, Wordlist, Wordlist (Computer), Wordlist (Jianzhi)
#	'srcbib.haveit',	# looks vaguely useless
#	'srcbib.proofer',	# ignoring these... for now.
#	'srcbib.inputter',
#	'srcbib.dbprep',
#	'srcbib.dbload',
#	'srcbib.dbcheck',
#	'srcbib.callnumber',
#	'srcbib.scope',
#	'srcbib.refonly',
#	'srcbib.citechk',
#	'srcbib.pi',
#	'srcbib.totalnum',
#	'srcbib.infascicle',	# added by DY

); # this list MUST include the key
$t->field_labels(
	'srcbib.srcabbr' => 'srcabbr',
	'COUNT(DISTINCT languagenames.lgid)' => 'lgs',
	'COUNT(lexicon.rn)' => 'recs',
	'srcbib.citation' => 'citation',
	'srcbib.author' => 'author',
	'srcbib.year' => 'year',
	'srcbib.imprint' => 'imprint',
	'srcbib.title' => 'title',
	'srcbib.status' => 'status',
	'srcbib.location' => 'location',
	'srcbib.notes' => 'notes',
	'srcbib.todo' => 'todo',
	'srcbib.dataformat' => 'dataformat',
	'srcbib.format' => 'format',
	'srcbib.haveit' => 'haveit',
	'srcbib.proofer' => 'proofer',
	'srcbib.inputter' => 'inputter',
);
$t->searchable(	'srcbib.srcabbr',
	'srcbib.citation',
	'srcbib.author',
	'srcbib.title',
);
$t->editable(
#	     'srcbib.citation',
	     'srcbib.author',
	     'srcbib.year',
	     'srcbib.title',
	     'srcbib.imprint',
	     'srcbib.status',
#	     'srcbib.location',
	     'srcbib.notes',
	     'srcbib.todo',
#	     'srcbib.dataformat',
	     'srcbib.format',
#	     'srcbib.haveit',
#	     'srcbib.proofer',
#	     'srcbib.inputter',
);

$t->sizes(
	'srcbib.srcabbr' => 8,
	'srcbib.citation'=> 10,
	'srcbib.author'  => 15,
	'srcbib.title'   => 15,
	'srcbib.notes'=> 20,
	'srcbib.todo' => 8,
);

# Special elements in the search form.
$t->search_form_items(
);

$t->wheres(
	'srcbib.srcabbr' => sub {my ($k,$v) = @_; "$k LIKE '$v\%'"},
	protogloss	=> 'word',
	tags		=> 'word',
	pages		=> 'word',
);

# Special handling of results

$t->update_form_items(
	'COUNT(DISTINCT languagenames.lgid)' => sub {
		my ($cgi,$n,$key) = @_;
		return $n == 0 ? 0 :
			$cgi->a({-href=>"languagenames.pl?submit=Search&languagenames.srcabbr=$key", -target=>'lgwindow'},
				"$n lg" . ($n == 1 ? '' : 's'));
	},
	'srcbib.notes' => sub {
		my ($cgi,$s,$key) = @_;
		# for tablekit editing, we need to keep the newlines in the cell.
		# however, for html rendering we need <p> and <br>'s.
		# the following substitutions will give us both
 		$s =~ s/\n\n+/\n\n<p>/g;
 		$s =~ s/(?<!\n)\n(?!\n)/\n<br>/g;
		return $s;
	},
);

$t->print_form_items(
	'COUNT(DISTINCT languagenames.lgid)' => sub {
		my ($cgi,$n,$key) = @_;
		return $n == 0 ? '' : "$n lg" . ($n == 1 ? '' : 's');
	}
);

$t->footer_extra(sub {
print q|<script type="text/javascript">
TableKit.Editable.multiLineInput('srcbib.title')
TableKit.Editable.multiLineInput('srcbib.imprint')
TableKit.Editable.multiLineInput('srcbib.notes')
</script>|
});


$t->addable(
		'srcbib.srcabbr',
#	    'srcbib.citation',
	    'srcbib.author',
	    'srcbib.year',
	    'srcbib.title',
	    'srcbib.imprint',
	    'srcbib.notes',
	    'srcbib.status',
#	    'srcbib.location',
	    'srcbib.todo',
#	    'srcbib.dataformat',
	    'srcbib.format',
#	    'srcbib.haveit',
#	    'srcbib.proofer',
#	    'srcbib.inputter',
);

$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "srcabbr not specified!\n" unless $cgi->param('srcbib.srcabbr');
	$err .= "Author not specified!\n" unless $cgi->param('srcbib.author');
	$err .= "Year name not specified!\n" unless $cgi->param('srcbib.year');
	$err .= "Title not specified!\n" unless $cgi->param('srcbib.title');
	$err .= "imprint not specified!\n" unless $cgi->param('srcbib.imprint');
	return $err;
});

$t->search_limit(200);
#$t->allow_delete(1);
$t->generate;

$dbh->disconnect;
