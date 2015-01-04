#!/usr/bin/perl
use strict;
use DBI;
use STEDTUtil;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;

my @fields = (
	'srcbib.srcabbr',
	'srcbib.citation',
	'srcbib.author',
	'srcbib.year',
	'srcbib.title',
	'srcbib.imprint',	# this is the "rest" of the bibliography line, after author + year + title.
#	'srcbib.location',	# looks useless
	'srcbib.notes',
#	'srcbib.dataformat',# looks useless: mostly STAK vs. TEXT
	'srcbib.format',	# Art./Monograph, Dictionary, Etymologies, Grammar, Other, Questionnaire, Synonym Sets, Wordlist, Wordlist (Computer), Wordlist (Jianzhi)
#	'srcbib.haveit',	# looks vaguely useless
#	'srcbib.proofer',	# ignoring these... for now.
#	'srcbib.inputter',
#	'srcbib.dbprep',
#	'srcbib.dbload',
#	'srcbib.dbcheck',
	'srcbib.callnumber',
#	'srcbib.scope',
#	'srcbib.refonly',
#	'srcbib.citechk',
	'srcbib.pi',
#	'srcbib.totalnum',
#	'srcbib.infascicle',	# added by DY
	'srcbib.todo',		# Complete, Defer, Eval, InQueue, Refonly
	'srcbib.status',	# looks important: Fix Xcripn, Incomplete, Input, Loaded, No Stack, PI only, Proof, TBEntr'd, etc.
	'COUNT(DISTINCT languagenames.lgid)',
	'COUNT(lexicon.rn)',

);

my $names = {
	'srcbib.srcabbr' => 'STEDT abbr',
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
	'COUNT(DISTINCT languagenames.lgid)' => 'languages cited',
	'COUNT(lexicon.rn)' => 'total reflexes',
	'srcbib.citation' => 'short citation',
	'srcbib.todo' => 'workflow location',
	'srcbib.status' => 'workflow status',
	'srcbib.citation'=> 'short citation',
	'srcbib.pi'=> 'PhonInv',
	'srcbib.callnumber' => 'UCB call number',
};

my @sizes = (
	'srcbib.srcabbr' => 8,
	'srcbib.citation'=> 10,
	'srcbib.author'  => 15,
	'srcbib.title'   => 15,
	'srcbib.notes'=> 20,
	'srcbib.todo' => 8,
);

# Special handling of results

my $update_form_items = {
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
};

my $cgi = new CGI;
STEDTUtil::make_header($cgi,'Display Bibliographic Citation');

my $dbh = STEDTUtil::connectdb();

my $from = 'srcbib LEFT JOIN languagenames USING (srcabbr) LEFT JOIN lexicon USING (lgid)';
my $order = 'srcbib.srcabbr, srcbib.year';
my $flds = join(', ', @fields);
#my $limita = ($cgi->param('pagenum') + ($cgi->param('next') ? 1 : ($cgi->param('prev') ? -1 : 0))) * $SearchLimit;
my $where;

my @terms;
foreach my $key ($cgi->param) {
  #print "debug ".$cgi->param($key);
  if ($names->{$key} and $cgi->param($key) ne '') {
    my $value = $cgi->param($key);
    $value =~ s/'/''/g;	# security, don't let people put weird sql in here!
    $value =~ s/\\/\\\\/g;
    my $term = $key . '=' . "\"$value\"";
    push @terms, $term;
  }
}
my $where = "(" . join(" AND ", @terms) .")";
  
#$where = "srcbib.srcabbr='STC'";

my $query = 
  "SELECT DISTINCT $flds FROM $from WHERE $where GROUP by srcbib.srcabbr ORDER BY $order;";

#print $query, $cgi->br(); 

my $sth = $dbh->prepare($query);
$sth->execute();
my $numrows = $sth->rows;

#print "$numrows found. Ordering by ",$order;

my %results;
@results{@fields} = ();
$sth->bind_columns(map { \$results{$_} } @fields);
print $cgi->start_table;
print $cgi->TR($cgi->th({-colspan=>'2'},'<h2>Bibliographic Citation</h2>'));
while ($sth->fetch()) {
  for my $field (@fields) {
    if ($results{$field}) {
      print $cgi->Tr({-valign => 'top'},
		     $cgi->td({-width=>"130"}, $cgi->i($names->{$field})),
		     $cgi->td("$results{$field}")
		    );
    }
  }
  print "</tr>";
}

$dbh->disconnect;
STEDTUtil::make_footer($cgi);
