package STEDT::Table::Chapters;
use base STEDT::Table;
use strict;

sub new {
my ($self, $dbh, $privs, $uid) = @_;
my $t = $self->SUPER::new($dbh, 'chapters', 'chapters.id', $privs); # dbh, table, key, privs

$t->query_from(q|chapters|);
$t->order_by('chapters.v, chapters.f, chapters.c, chapters.s1, chapters.s2, chapters.s3'); # semkey must be unique

$t->fields(
	'chapters.semkey',
	'chapters.chaptertitle',
	'chapters.v',
	'chapters.f',
	'chapters.c',
	'chapters.s1',
	'chapters.s2',
	'chapters.s3',
	'chapters.semcat',
	'chapters.old_chapter',
	'chapters.old_subchapter',
	'chapters.id',
	'(SELECT COUNT(*) FROM glosswords WHERE semkey=chapters.semkey) AS gloss_link'
);
$t->searchable(
	'chapters.semkey',
	'chapters.chaptertitle',
	'chapters.v',
	'chapters.f',
	'chapters.c',
	'chapters.s1',
	'chapters.s2',
	'chapters.s3',
	'chapters.semcat',
	'chapters.old_chapter',
	'chapters.old_subchapter'
);
#$t->editable(
#	'chapters.semkey',
#	'chapters.chaptertitle',
#);

$t->field_editable_privs(
	'chapters.semkey' => 8,
	'chapters.chaptertitle' => 8,
);

# Stuff for searching
$t->search_form_items(
	'chapters.v' => sub {
		my $cgi = shift;
		# get list of volumes
		my $vs = $dbh->selectall_arrayref("SELECT DISTINCT v FROM chapters");
		return $cgi->popup_menu(-name => 'chapters.v', -values=>['', map {@$_} @$vs], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'chapters.f' => sub {
		my $cgi = shift;
		# get list of fascicles
		my $fs = $dbh->selectall_arrayref("SELECT DISTINCT f FROM chapters");
		return $cgi->popup_menu(-name => 'chapters.f', -values=>['', map {@$_} @$fs], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'chapters.c' => sub {
		my $cgi = shift;
		# get list of chapters
		my $cs = $dbh->selectall_arrayref("SELECT DISTINCT c FROM chapters");
		return $cgi->popup_menu(-name => 'chapters.c', -values=>['', map {@$_} @$cs], -labels=>{'0'=>'(no value)'},  -default=>'');
	}
);

$t->save_hooks(
	'chapters.semkey' => sub {
		my ($id, $semkey) = @_;
		my ($old_semkey) = $dbh->selectrow_array('SELECT semkey FROM chapters WHERE id=?', undef, $id);

		# split by periods and convert to numbers
		my @vfcsss = map { $_ + 0 } split /\./, $semkey;
		my ($v,$f,$c,$s1,$s2,$s3) = @vfcsss;

		# convert it back now that it's all digits; make sure no zeroes creep in
		$semkey = shift @vfcsss or die("Volume must be non-zero!");
		for my $n (@vfcsss) {
			last unless $n > 0;
			$semkey .= ".$n";
		}
		my $sth = $dbh->prepare(q{UPDATE chapters SET semkey=?, v=?, f=?, c=?, s1=?, s2=?, s3=? WHERE id=?});
		$sth->execute($semkey,$v,$f || 0,$c || 0,$s1 || 0,$s2 || 0,$s3 || 0,$id);	# replace lower levels with zero if undef
		# if it fails at this point it will be because there is a UNIQUE constraint
		# on the semkey field in the database. Otherwise it is safe to go on.
		
		# update the corresponding field in etyma, lexicon, and glosswords
		$dbh->do('UPDATE etyma SET semkey=? WHERE semkey=?', undef, $semkey, $old_semkey);	# update semkey field, but glosswords program will overwrite this anyway
		$dbh->do('UPDATE etyma SET chapter=? WHERE chapter=?', undef, $semkey, $old_semkey);	# update chapter field
		$dbh->do('UPDATE lexicon SET semkey=? WHERE semkey=?', undef, $semkey, $old_semkey);
		$dbh->do('UPDATE glosswords SET semkey=? WHERE semkey=?', undef, $semkey, $old_semkey);
		return 0;
	},
);


$t->wheres(
	   'chapters.semkey' => sub {my ($k,$v) = @_; "$k LIKE '$v\%'"},
	   'chapters.chaptertitle' => sub {my ($k,$v) = @_; "$k LIKE '$v\%'"},
	   'chapters.v'	 => 'int',
	   'chapters.f'	 => 'int',
	   'chapters.c'	 => 'int',
	   'chapters.s1' => 'int',
	   'chapters.s2' => 'int',
	   'chapters.s3' => 'int',
);


$t->addable(
	   'chapters.semkey',
	   'chapters.chaptertitle'
);

$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "Semkey (v.f.c....) not specified!\n" unless $cgi->param('chapters.semkey');
	$err .= "Chaptertitle not specified!\n" unless $cgi->param('chapters.chaptertitle');
	return $err;
});


$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);

return $t;
}

1;
