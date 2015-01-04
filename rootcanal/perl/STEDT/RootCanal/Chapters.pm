package STEDT::RootCanal::Chapters;
use strict;
use base 'STEDT::RootCanal::Base';
use Encode;
use Time::HiRes qw(time);
use List::Util qw(first);	# used to find indices of seq num and public in etyma result array

sub browser : StartRunMode {
	my $self = shift;
	my $t0 = time();
	my $public = '';
	my $blessed = '';
	my $public_ch = '';
#	unless ($self->has_privs(1)) {
#		$public = "AND etyma.public=1";
#		$blessed = 'AND etyma.uid=8';
#		$public_ch = 'HAVING num_public OR public_notes';
#	}
	# from the chapters table
	my $chapterquery = <<SQL;
SELECT chapters.semkey, chapters.chaptertitle, 
	(SELECT COUNT(*) FROM etyma WHERE chapter=chapters.semkey AND public=1 AND etyma.status != 'DELETE' $blessed) AS num_public,
	(SELECT COUNT(*) FROM etyma WHERE chapter=chapters.semkey AND etyma.status != 'DELETE' $blessed),
	COUNT(DISTINCT notes.noteid), MAX(notes.notetype = 'G'), MAX(notes.notetype != 'I') AS public_notes,
	chapters.id, IF(chapters.f=0, 1, 0) AS isVOL, IF(chapters.c=0, 1, 0) AS isFASC, 0 AS indent
FROM chapters LEFT JOIN notes ON (notes.id=chapters.semkey)
GROUP BY 1 $public_ch ORDER BY v,f,c,s1,s2,s3
SQL
	my $chapters = $self->dbh->selectall_arrayref($chapterquery);

	# set indentation level
	foreach my $row (@$chapters) {
		my $str = $row->[0];
		$str =~ s/\.0//g;
		my $indent_level = $str =~ tr/.//;
		$row->[10] = $indent_level;
	}

	# chapters that appear in etyma but not in chapters table
	my $e_ghost_chaps = $self->dbh->selectall_arrayref(<<SQL);
SELECT etyma.chapter, SUM(etyma.public), COUNT(*)
FROM etyma LEFT JOIN chapters ON (etyma.chapter=chapters.semkey)
WHERE chapter != '' AND etyma.status != 'DELETE' $public $blessed AND chapters.chaptertitle IS NULL GROUP BY 1 ORDER BY 1
SQL
	# chapters that appear in notes but not in chapters table
	my $n_ghost_chaps = $self->dbh->selectall_arrayref(<<SQL);
SELECT notes.id, COUNT(notes.noteid), COUNT(etyma.tag)
FROM notes LEFT JOIN chapters ON (notes.id=chapters.semkey) LEFT JOIN etyma ON (etyma.chapter=chapters.semkey)
WHERE notes.spec='C' AND chapters.chaptertitle IS NULL GROUP BY 1 ORDER BY 1
SQL

	# volumes for table of contents
	my $volumes = $self->dbh->selectall_arrayref(<<SQL);
SELECT chapters.semkey, chapters.chaptertitle
FROM chapters WHERE chapters.f=0 AND chapters.v<11 ORDER BY chapters.v
SQL

	return $self->tt_process('chapter_browser.tt', {
		vols=> $volumes, ch=>$chapters, e=>$e_ghost_chaps, n=>$n_ghost_chaps, time_elapsed=>sprintf("%0.3g", time()-$t0)
	});
}

# this was meant to be a way to manipulate the semtree, but
# for now it means "show all the glosswords and not the other columns"
sub tweak : RunMode {
	my $self = shift;
	$self->require_privs(2);
	my $t0 = time();
	my $public = '';
	my $blessed = '';
	my $public_ch = '';
#	unless ($self->has_privs(1)) {
#		$public = "AND etyma.public=1";
#		$blessed = 'AND etyma.uid=8';
#		$public_ch = 'HAVING num_public OR public_notes';
#	}
	my %semkeycounts = @{$self->dbh->selectcol_arrayref("select semkey,count(*) from (SELECT distinct rn,semkey FROM lexicon JOIN lx_et_hash USING (rn) WHERE  lexicon.status != 'HIDE' AND lexicon.status != 'DELETED') as sel group by semkey",{Columns=>[1,2]})};
	my $chapterquery = <<SQL;
SELECT chapters.semkey, chapters.chaptertitle, 
	(SELECT COUNT(*) FROM etyma WHERE chapter=chapters.semkey AND public=1 AND etyma.status != 'DELETE' $blessed) AS num_public,
	(SELECT COUNT(*) FROM etyma WHERE chapter=chapters.semkey AND etyma.status != 'DELETE' $blessed) AS etycount,
	COUNT(DISTINCT notes.noteid) AS notecount, MAX(notes.notetype = 'G') AS haschart, MAX(notes.notetype != 'I') AS public_notes,
	chapters.semcat, chapters.old_chapter, chapters.old_subchapter, chapters.id,
	COUNT(DISTINCT glosswords.word),
	GROUP_CONCAT(DISTINCT glosswords.word SEPARATOR '; ') AS some_glosswords,
	(SELECT COUNT(*) FROM lexicon WHERE lexicon.semkey=chapters.semkey AND lexicon.status != "HIDE" AND lexicon.status != "DELETED") AS wcount,
	IF(chapters.f=0, 1, 0) AS isVOL, IF(chapters.c=0, 1, 0) AS isFASC
FROM chapters LEFT JOIN notes ON (notes.id=chapters.semkey) LEFT JOIN glosswords ON (chapters.semkey=glosswords.semkey)
GROUP BY 1 $public_ch ORDER BY v,f,c,s1,s2,s3
SQL
	# allow long GROUP_CONCAT's.
	my (undef, $max_len) = $self->dbh->selectrow_array("SHOW VARIABLES WHERE Variable_name='max_allowed_packet'");
	die "oops couldn't get max_allowed_packet from mysql" unless $max_len;
	$self->dbh->do("SET SESSION group_concat_max_len = $max_len");
	my $chapters = $self->dbh->selectall_arrayref($chapterquery);

	# volumes for table of contents
	my $volumes = $self->dbh->selectall_arrayref(<<SQL);
SELECT chapters.semkey, chapters.chaptertitle
FROM chapters WHERE chapters.f=0 AND chapters.v<11 ORDER BY chapters.v
SQL
	foreach my $row (@$chapters){
	  my $semkey = $row->[0];
	  my $denominator = $row->[13] + 0.00;
	  my $result = 0.00;
	  if ($denominator > 0) { 
	    my $numerator = $semkeycounts{$semkey} + 0.00;
	    $result =  $numerator /  $denominator 
	  }
	  $result = int($result * 100);
	  #print STDERR "$semkey:  $semkeycounts{$semkey}\n";
	  push @$row, $semkeycounts{$semkey}, $result;
	}
	
	# set indentation level
	foreach my $row (@$chapters) {
		my $str = $row->[0];
		$str =~ s/\.0//g;
		my $indent_level = $str =~ tr/.//;
		push @$row, $indent_level;
	}

	return $self->tt_process('chapter_tweaker.tt', {
		vols=> $volumes, ch=>$chapters, time_elapsed=>sprintf("%0.3g", time()-$t0)
	});
}

sub grid : RunMode {
	my $self = shift;
	$self->require_privs(2);
	my $chapterquery = <<SQL;
SELECT v,f,
	(SELECT chaptertitle FROM chapters WHERE v=chaps.v AND f=chaps.f AND c=0 AND s1=0 AND s2=0 AND s3=0 ) AS title,
	(SELECT COUNT(*) FROM etyma WHERE (chapter=CONCAT(v,'.',f) OR chapter LIKE CONCAT(v,'.',f,'.%')) AND etyma.status != 'DELETE') AS num_etyma,
	COUNT(*) AS num_chapters
FROM chapters AS chaps
WHERE v<=10 AND f>0
GROUP BY f,v
SQL
	# order by fascicle 1st, so we can output a table easily.
	my $chapters = $self->dbh->selectall_arrayref($chapterquery);
	my $volumes = $self->dbh->selectcol_arrayref("SELECT chaptertitle FROM chapters WHERE v<=10 AND f=0 AND c=0 AND s1=0 AND s2=0 AND s3=0 ORDER BY v");
	return $self->tt_process('semantic_grid.tt', {
		ch => $chapters,
		vols => $volumes,
	});
}

sub chapter : RunMode {
	my $self = shift;
	my $tag = $self->param('tag');
	my $chap = $self->param('chap');
	my $title = $self->dbh->selectrow_array("SELECT chaptertitle FROM chapters WHERE semkey=?", undef, $chap);
	$title ||= '[chapter does not exist in chapters table!]';
	
	my $INTERNAL_NOTES = $self->has_privs(2);
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I'" unless $INTERNAL_NOTES;
	my (@notes, @footnotes);
	my $footnote_index = 1;
	require STEDT::RootCanal::Notes;
	import STEDT::RootCanal::Notes;
	foreach (@{$self->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, ord, uid, username FROM notes LEFT JOIN users USING (uid)"
			. "WHERE spec='C' AND id=? $internal_note_search ORDER BY ord", undef, $chap)}) {
		my $xml = $_->[3];
		push @notes, { noteid=>$_->[0], type=>$_->[1], lastmod=>$_->[2], 'ord'=>$_->[4],
			text=>xml2html($xml, $self, \@footnotes, \$footnote_index, $_->[0]),
			markup=>xml2markup($xml), num_lines=>guess_num_lines($xml),
			uid=>$_->[5], username=>$_->[6]
		};
	}
	
	my $t = $self->load_table_module('etyma');
	my $q = $self->query->new('');
	$q->param('etyma.chapter'=>$chap);
	$q->param('sortkey'=>'etyma.sequence');	# this should speed up the sort further down
#	$q->param('etyma.sequence'=>'>0'); # hide non-sequenced items from the chapter view
#	$q->param('etyma.public'=>1) unless $self->has_privs(1);
	my $result = $t->search($q);
	
	# grab the indices of the etyma.sequence and etyma.public fields
	# because they're different for public vs. logged-in users
	my $seq_idx = first { $result->{fields}[$_] eq 'etyma.sequence' } 0..$#{$result->{fields}};
	my $pub_idx = first { $result->{fields}[$_] eq 'etyma.public' } 0..$#{$result->{fields}};
	
	# sort the etyma in place by sequence number first (moving 0's to the end), then by reverse public value (1 first)
	# involves de-referencing the array of etyma records (themselves arrays), sorting, and and reassigning the result
	@{$result->{data}} = sort {
			# if one of etyma under comparison has seq=0, move it to the end
			if ($a->[$seq_idx] == 0 && $b->[$seq_idx] != 0) {
				return 1;	# a comes after
			}
			elsif ($b->[$seq_idx] == 0 && $a->[$seq_idx] != 0) {
				return -1; 	# b comes after
			}
			else {
				# otherwise, sort by seq number ([$seq_idx]) then by reverse public value ([$pub_idx])
				return ($a->[$seq_idx] <=> $b->[$seq_idx] || $b->[$pub_idx] <=> $a->[$pub_idx]);
			}
		} @{$result->{data}};
	
	return $self->tt_process("chapter.tt", {
		chap => $chap, chaptitle=>$title,
		notes  => \@notes,
		footnotes => \@footnotes,
		result => $result
	});
}

sub save_seq {
	my $self = shift;
	my $t = $self->load_table_module('etyma');
	require JSON;
	my $seqs = JSON::from_json($_[0]);
	for my $i (0..$#{$seqs}) {
		my $etyma = $seqs->[$i];
		my $num_etyma = @$etyma;
		my $is_paf;
		my $j = 1;
		for my $tag (@$etyma) {
			if ($tag eq 'P') {
				$is_paf = 1;
				next;
			}
			my $s;
			if ($is_paf || $num_etyma == 1) {
				$s = $i;
				$is_paf = 0;
			} elsif ($i == 0) {
				$s = 0;
			} else {
				$s = "$i.$j";
				$j++;
				$j = 9 if $j > 9;
			}
			my $oldval = $t->get_value('etyma.sequence', $tag);
			
			if ($oldval != $s) {
				$t->save_value('etyma.sequence', $s, $tag);
				my $seqlocked =  ($s == 0) ? 0 : 1; # lock or unlock the sequence number, as needed
				$t->save_value('etyma.seqlocked', $seqlocked, $tag);
				$self->dbh->do("INSERT changelog (uid, `table`, id, col, oldval, newval, time)
								VALUES (?,?,?,?,?,?,NOW())", undef,
					$self->param('uid'), 'etyma', $tag, 'sequence', $oldval || '', $s);
			}
		}
	}
}

sub seq : Runmode {
	my $self = shift;
	$self->require_privs(8);
	my $chap = $self->query->param('c');
	return "no chapter specified!" unless $chap;

	my $msg;
	if ($self->query->param('seqs')) {
		$self->save_seq($self->query->param('seqs'));
		$msg = "Success!";
	}

	my $a = $self->dbh->selectall_arrayref("SELECT etyma.tag, plg, protoform, protogloss, sequence, COUNT(DISTINCT rn) AS num_recs
		FROM etyma
		LEFT JOIN languagegroups USING (grpid)
		LEFT JOIN lx_et_hash ON (etyma.tag=lx_et_hash.tag AND lx_et_hash.uid=8)
		WHERE chapter=? AND status != 'DELETE'
		GROUP BY tag
		ORDER BY sequence", undef, $chap);
	
	# run through results and group allofams
	my @fams;
	my $last_seq = 0;
	push @fams, {seq=>0, allofams=>[]}; # always have a #0 for unsequenced tags
	foreach (@$a) {
		my %e;

		# prettify protoform
		@e{qw/tag plg form gloss seq num_recs/} = @$_;
		$e{form} =~ s/⪤ +/⪤ */g;
		$e{form} =~ s/OR +/OR */g;
		$e{form} =~ s/~ +/~ */g;
		$e{form} =~ s/ = +/ = */g;
		$e{form} = '*' . $e{form};

		# transmogrify sequence number
		my $seq = int $e{seq}; # truncate the sequence number
		$e{seq} =~ s/^\d+\.//;
		$e{seq} =~ s/0+$//;
		if ($e{seq}) {
			$e{seq} =~s/(\d)/$1 ? chr(96+$1) : '-'/e;
		}
		
		if ($seq != $last_seq) {
			push @fams, {seq=>$seq, allofams=>[\%e]};
			$last_seq = $seq;
		} else {
			push @{$fams[-1]{allofams}}, \%e;
		}
	}
	# de-allofam
	# make PAF

	return $self->tt_process("admin/sequencer.tt", {fams=>\@fams, msg=>$msg});
}

1;
