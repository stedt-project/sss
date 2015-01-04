package STEDT::RootCanal::Sources;
use strict;
use base 'STEDT::RootCanal::Base';
use Encode;

sub source : StartRunmode {
	my $self = shift;
	my $srcabbr = $self->param('srcabbr');
	return $self->all_sources unless $srcabbr;
	
	my ($author, $year, $title, $imprint)
		= $self->dbh->selectrow_array("SELECT author, year, title, imprint FROM srcbib WHERE srcabbr=?", undef, $srcabbr);
	if (!defined($author)) {
		$self->header_add(-status => 400);
		return "Error: No source '$srcabbr' found";
	}

	my $lg_list = $self->dbh->selectall_arrayref(
		"SELECT silcode, language, lgcode, grpid, grpno, grp, COUNT(lexicon.rn), lgid AS num_recs, pi_page, lgabbr FROM languagenames NATURAL LEFT JOIN languagegroups LEFT JOIN lexicon USING (lgid) WHERE srcabbr=? AND lgcode!=0 AND lexicon.status!='HIDE' AND lexicon.status!='DELETED' GROUP BY lgid HAVING num_recs > 0 ORDER BY lgcode, language", undef, $srcabbr);

	require STEDT::RootCanal::Notes;
	my $INTERNAL_NOTES = $self->has_privs(2);
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I'" unless $INTERNAL_NOTES;
	my (@notes, @footnotes);
	my $footnote_index = 1;
	foreach (@{$self->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, ord, uid, username FROM notes LEFT JOIN users USING (uid)"
			. "WHERE spec='S' AND id=? $internal_note_search ORDER BY ord", undef, $srcabbr)}) {
		my $xml = $_->[3];
		push @notes, { noteid=>$_->[0], type=>$_->[1], lastmod=>$_->[2], 'ord'=>$_->[4],
			text=>STEDT::RootCanal::Notes::xml2html($xml, $self, \@footnotes, \$footnote_index, $_->[0]),
			markup=>STEDT::RootCanal::Notes::xml2markup($xml), num_lines=>STEDT::RootCanal::Notes::guess_num_lines($xml),
			uid=>$_->[5], username=>$_->[6]
		};
	}


	return $self->tt_process("source.tt", {
		author=>$author, year=>$year, doc_title=>$title, imprint=>$imprint,
		lgs  => $lg_list, srcabbr => $srcabbr, notes => \@notes, footnotes => \@footnotes
	});
}

sub all_sources {
	my $self = shift;
	my $a = $self->dbh->selectall_arrayref("SELECT srcabbr, COUNT(DISTINCT languagenames.lgid) AS num_lgs,
		COUNT(lexicon.rn) AS num_recs, citation, author, year, title, imprint
		FROM srcbib LEFT JOIN languagenames USING (srcabbr) LEFT JOIN lexicon USING (lgid)
		WHERE lexicon.status!='HIDE' AND lexicon.status!='DELETED'
		GROUP BY srcabbr
		HAVING num_recs > 0
		ORDER BY citation", {Slice=>{}});
	return $self->tt_process("tt/all_sources.tt", { sources=>$a });
}

sub srcabbr : Runmode {
	my $self = shift;
	my $a = $self->dbh->selectall_arrayref("SELECT srcabbr, COUNT(DISTINCT languagenames.lgid) AS num_lgs,
		COUNT(lexicon.rn) AS num_recs, citation, author, year, title, imprint
		FROM srcbib LEFT JOIN languagenames USING (srcabbr) LEFT JOIN lexicon USING (lgid)
		WHERE lexicon.status!='HIDE' AND lexicon.status!='DELETED'
		GROUP BY srcabbr
		HAVING num_recs > 0
		ORDER BY srcabbr", {Slice=>{}});
	return $self->tt_process("tt/all_sources_by_srcabbr.tt", { sources=>$a });
}

sub refonly : Runmode {
	my $self = shift;
	my $a = $self->dbh->selectall_arrayref("SELECT srcabbr,
		COUNT(lexicon.rn) AS num_recs, author, year, title, imprint
		FROM srcbib LEFT JOIN languagenames USING (srcabbr) LEFT JOIN lexicon USING (lgid)
		GROUP BY srcabbr
		HAVING num_recs = 0
		ORDER BY author,year", {Slice=>{}});
	return $self->tt_process("tt/ref_only.tt", { sources=>$a });
}

# runmode for downloaded all data from a source.
# must have priv "2" - i.e. must have an account, but need not be a tagger
sub ddata : Runmode {
	my $self = shift;
	$self->require_privs(2);
	my $srcabbr = $self->query->param('srcabbr');
	if (!defined($srcabbr)) {
		$self->header_add(-status => 400);
		return "Error: No source specified";
	}
	my $a = $self->dbh->selectall_arrayref("SELECT rn, reflex, gloss, gfn, srcabbr, lgid, language, srcid
		FROM lexicon LEFT JOIN languagenames USING (lgid) LEFT JOIN languagegroups USING (grpid)
		WHERE languagenames.srcabbr=?", undef, $srcabbr);
	unless (@$a) {
		$self->header_add(-status => 400);
		return "Error: No records for source $srcabbr";
	}
	my $result = join("\t", qw|rn reflex gloss gfn srcabbr lgid language srcid|) . "\n";
	for my $row (@$a) {
		$result .= join("\t", @$row) . "\n";
	}
	$self->header_add(-type => 'text/csv',
		-attachment => "$srcabbr.csv",
		-Content_length => length(encode_utf8($result)));
	return $result;
}

1;
