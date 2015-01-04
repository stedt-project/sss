package STEDT::RootCanal::Notes;
use strict;
use base 'STEDT::RootCanal::Base', 'Exporter';
our @EXPORT = qw(xml2html xml2markup guess_num_lines collect_lex_notes);
use Encode;
use utf8;

sub add : RunMode {
	my $self = shift;
	unless ($self->has_privs(1)) {
		$self->header_add(-status => 403);
		return "User not logged in" unless $self->param('user');
		return "User not allowed to add notes!";
	}
	my $dbh = $self->dbh;
	my $q = $self->query;
	my ($spec, $id, $ord, $type, $xml, $uid, $id2) = ($q->param('spec'), $q->param('id'),
		$q->param('ord'), $q->param('notetype'),
		decode_utf8(markup2xml($q->param('xmlnote'))),
		$q->param('uid') || -1, $q->param('id2'));
	# $q->param('uid') only exists for "approvers"; if it doesn't exist it will
	# return an empty list here since it's list context, and id2 will unfortunately
	# get assigned to $uid. Hence, ||ing with -1 to give a scalar value.
	my $key = $spec eq 'L' ? 'rn' : $spec eq 'E' ? 'tag' : 'id';
	if ($uid != 8 && $uid != $self->param('uid')) {
		# force uid to be either 8 or the current user's uid
		$uid = $self->param('uid');
	}
	my $sql = "INSERT notes (spec, $key, ord, notetype, xmlnote, uid) VALUES (?,?,?,?,?,?)";
	if ($id2) {
		$sql =~ s/uid\)/uid, id\)/;
		$sql =~ s/\?\)/?,?\)/;
	}
	my $sth = $dbh->prepare($sql);
	$sth->execute($spec, $id, $ord, $type, $xml, $uid, $id2 ? $id2 : ());
	
	# get noteid for use below
	my $noteid = $dbh->selectrow_array("SELECT LAST_INSERT_ID()");
	
	# update changelog (note that oldval and newval are TEXT type fields, which cannot have default values
	# so we have to explcitly set them to the empty string)
	$self->dbh->do("INSERT changelog (uid, change_type, `table`, id, oldval, newval, time)
					VALUES (?,?,?,?,?,?,NOW())", undef,
					$self->param('uid'), 'new_rec', 'notes', $noteid, '', '');

	my $kind = $spec eq 'L' ? 'lex' : $spec eq 'C' ? 'chapter' : # special handling for comparanda
		$spec eq 'S' ? 'source' : $type eq 'F' ? 'comparanda' : $id2 ? 'et_subgroup' : 'etyma';
	my $lastmod = $dbh->selectrow_array("SELECT datetime FROM notes WHERE noteid=?", undef, $noteid);
	$self->header_add('-x-json'=>qq|{"id":"$noteid"}|);
	my @a; my $i = $q->param('fn_counter')+1;
	return join "\r", ${$self->tt_process("notes_$kind.tt", {
		n=>{noteid=>$noteid, type=>$type, lastmod=>$lastmod, 'ord'=>$ord,
			text=>xml2html($xml, $self, \@a, \$i, $spec eq 'E' ? $id : undef),
			markup=>xml2markup($xml), num_lines=>guess_num_lines($xml),
			uid=>$uid, username=>($uid==8 ? 'stedt' : $self->param('user'))
			},
		fncounter=>$q->param('fn_counter')
	})}, map {$_->{text}} @a;
}

sub delete : RunMode {
	my $self = shift;
	$self->require_privs(1);
	my $dbh = $self->dbh;
	my $q = $self->query;
	my $noteid = $q->param('noteid');
	my $lastmod = $q->param('mod');
	my ($mod_time, $note_uid) = $dbh->selectrow_array("SELECT datetime,uid FROM notes WHERE noteid=?", undef, $noteid);
	if ($self->param('uid') != $note_uid && !$self->has_privs(8)) {
		$self->header_add(-status => 403);
		return "User not allowed to delete someone else's note.";
	}
	
	$dbh->do("LOCK TABLE notes WRITE");
	if ($lastmod eq $mod_time) {
		my $sql = "DELETE FROM notes WHERE noteid=?";
		my $sth = $dbh->prepare($sql);
		$sth->execute($noteid);
	} else {
		$self->dbh->do("UNLOCK TABLES");
		$self->header_add(-status => 409);
 		return "Someone else has modified this note (since $lastmod)! The note was not deleted.";
 	}
	$self->dbh->do("UNLOCK TABLES");
	return '';
}

sub save : RunMode {
	my $self = shift;
	$self->require_privs(1);
	my $dbh = $self->dbh;
	my $q = $self->query;
	my $noteid = $q->param('noteid');
	my $lastmod = $q->param('mod');
	my ($mod_time, $note_uid) = $dbh->selectrow_array("SELECT datetime,uid FROM notes WHERE noteid=?", undef, $noteid);
	my $xml;
	my %orig_vals;	# hash to hold original values of notes table fields
	my %new_vals;	# hash to hold new values

	# allow taggers to modify only their own notes
	if ($self->param('uid') != $note_uid && !$self->has_privs(8)) {
		$self->header_add(-status => 403);
		return "User not allowed to modify someone else's note.";
	}
	
	# check mod time to ensure no one changed it before us
	$dbh->do("LOCK TABLE notes WRITE");
	if ($lastmod eq $mod_time) {

		# save original values in %orig_vals hash for changelog
		%orig_vals = %{$dbh->selectrow_hashref("SELECT * FROM notes WHERE noteid=?", undef, $noteid)};

		# get ready to write changes		
		my $sql = "UPDATE notes SET notetype=?, xmlnote=? WHERE noteid=?";
		my @args = ($q->param('notetype'), markup2xml($q->param('xmlnote')));
		if ($q->param('id')) { # actually an optional tag number, for lexicon notes
			$sql =~ s/ WHERE/, id=? WHERE/;
			push @args, $q->param('id');
		}
		if ($q->param('uid')) {
			$sql =~ s/ WHERE/, uid=? WHERE/;
			push @args, $q->param('uid');
		}

		# write changes
		my $sth = $dbh->prepare($sql);
		$sth->execute(@args, $noteid);

		# save new values in %new_vals hash
		%new_vals = %{$dbh->selectrow_hashref("SELECT * FROM notes WHERE noteid=?", undef, $noteid)};

		($xml, $lastmod) = $dbh->selectrow_array("SELECT xmlnote, datetime FROM notes WHERE noteid=?", undef, $noteid);
	} else {
		$dbh->do("UNLOCK TABLES");
		$self->header_add(-status => 409);
 		return "Someone else has modified this note! Your changes were not saved.";
 	}
	$dbh->do("UNLOCK TABLES");
	
	# if we get here, the change was successful (or nothing changed)
	# loop through changes and record each in changelog
	# just use string comparison (converts number to string where necessary)
	foreach (keys %orig_vals) {
		next if $_ eq 'datetime';	# skip recording changes in modification time
		if ($orig_vals{$_} ne $new_vals{$_}) {
			$dbh->do("INSERT changelog (uid, change_type, `table`, id, col, oldval, newval, time)
				VALUES (?,?,?,?,?,?,?,NOW())", undef,
				$self->param('uid'), '-', 'notes', $noteid, $_, $orig_vals{$_}, $new_vals{$_});
		}		
	}
					
	$self->header_add('-x-json'=>qq|{"lastmod":"$lastmod"}|);
	my @a; my $i = 1;
	return join("\r", xml2html($xml, $self, \@a, \$i), map {$_->{text}} @a);
}

sub reorder : RunMode {
	my $self = shift;
	$self->require_privs(8);
	my @ids = map {/(\d+)$/} split /\&/, $self->query->param('ids');
	# change the order, but don't update the modification time for something so minor.
	my $sth = $self->dbh->prepare("UPDATE notes SET ord=?, datetime=datetime WHERE noteid=?");
	my $i = 0;
	my $old_ord;
	foreach (@ids) {
		# save old ord value
		$old_ord = $self->dbh->selectrow_array("SELECT ord FROM notes WHERE noteid=?", undef, $_);
		
		# set new ord value (after incrementing it)
		$sth->execute(++$i, $_);
		
		# record ord change in changelog (these are MySQL TINYINTs, so okay to use numeric comparison)
		if ($old_ord != $i) {
			$self->dbh->do("INSERT changelog (uid, change_type, `table`, id, col, oldval, newval, time)
				VALUES (?,?,?,?,?,?,?,NOW())", undef,
				$self->param('uid'), '-', 'notes', $_, 'ord', $old_ord, $i);	
		}
	}
	return '';
}

sub xml2markup {
	local $_ = $_[0];
	s|^<par>||;
	s|</par>$||;
	s|</par><par>|\n\n|g;
	s|<br />|\n|g;
	s|<sup>(.*?)</sup>|[[^$1]]|g;
	s|<sub>(.*?)</sub>|[[_$1]]|g;
	s|<emph>(.*?)</emph>|[[~$1]]|g;
	s|<strong>(.*?)</strong>|[[\@$1]]|g;
	s|<gloss>(.*?)</gloss>|[[:$1]]|g;
	s|<reconstruction>\*(.*?)</reconstruction>|[[*$1]]|g;
	s|<xref ref="(\d+)">#\1(.*?)</xref>|[[#$1$2]]|g;
	s|<a href="(.*?)">(.*?)</a>|[[!$1 $2]]|g;
	s|<footnote>(.*?)</footnote>|{{%$1}}|g;
	s|<hanform>(.*?)</hanform>|[[$1]]|g;
	s|<latinform>(.*?)</latinform>|[[+$1]]|g;
	s|<plainlatinform>(.*?)</plainlatinform>|[[$1]]|g;
	s|<unicode>(.*?)</unicode>|[[=$1]]|g;
	s/&amp;/&/g;
	s/&lt;/</g;
	s/&gt;/>/g;
	s/&apos;/'/g;
	s/&quot;/"/g;
	return $_;
}

sub guess_num_lines {
	use integer;
	my $n = length($_[0])/70;
	return $n < 3 ? 3 : $n;
}

# markup2xml returns encoded (binary) utf8, you may need to decode
my $LEFT_BRACKET = encode_utf8('⟦');
my $RIGHT_BRACKET = encode_utf8('⟧');
sub markup2xml {
	my $s = shift;
	$s =~ s/&/&amp;/g;
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;
	$s =~ s/'/&apos;/g;
	$s =~ s/"/&quot;/g;
	$s =~ s/(?<!\[)\[([^\[\]]*)\]/$LEFT_BRACKET$1$RIGHT_BRACKET/g;
		# take out matching single square brackets
		# note that this only matches a single level
		# of embedded pairs of single square brackets inside
		# other square brackets. To match more levels from
		# the inside out, repeat several times.
	$s =~ s/\[\[([^\[\]]*?)\]\]/_markup2xml($1)/ge foreach (1..2);
		# no recursion (embedded square brackets);
		# if needed eventually, run multiple times
		#	while ($s =~ s/\[\[([^\[\]]*?)\]\]/_markup2xml($1)/ge) {}
	$s =~ s/$LEFT_BRACKET/[/go; # restore single square brackets
	$s =~ s/$RIGHT_BRACKET/]/go;
	$s =~ s|{{%(.*?)}}|<footnote>$1</footnote>|g;
	$s =~ s|^[\r\n]+||g;
	$s =~ s|[\r\n]+$||g;
	$s =~ s#(\r\n){2,}|\r{2,}|\n{2,}#</par><par>#g;
	$s =~ s#\r\n|\r|\n#<br />#g;
	return "<par>$s</par>";
}

sub _markup2xml {
	my $s = shift;
	my ($code, $s2) = $s =~ /^(.)(.*)/;
	if ($code =~ /[_^~:*+@]/) {
		my %sym2x = qw(_ sub ^ sup ~ emph : gloss * reconstruction @ strong + latinform);
		$s2 = $s if $code eq '*';
		return "<$sym2x{$code}>$s2</$sym2x{$code}>";
	}
	if ($code eq '#') {
		my ($num, $s3) = $s2 =~ /^(\d+)(.*)/;
		return qq|<xref ref="$num">#$num$s3</xref>|;
	}
	if ($code eq '!') {	#if it's a link, pull out the URL and the link text, and make the xml look similar to the <xref> category
		my ($url, $delim, $ltext) = $s2 =~ /^(.+?)( |$)(.*)/;		#matches url followed by space, space+text, or end of line
		if (!$ltext) {	#if the user left the link text blank, make it = url
			$ltext = $url;
		}
		return qq|<a href="$url">$ltext</a>|;
	}
	if ($code eq '=') {	# hex unicode code point
		return "<unicode>$s2</unicode>";
	}
	my $u = ord decode_utf8($s); ### oops, it hasn't been decoded from utf8 yet
	if (($u >= 0x3400 && $u <= 0x4dbf) || ($u >= 0x4e00 && $u <= 0x9fff)
		|| ($u >= 0x20000 && $u <= 0x2a6df)) {
		return "<hanform>$s</hanform>";
	}
	return "<plainlatinform>$s</plainlatinform>";
}

sub _tag2info {
	my ($t, $s, $c) = @_;
	my ($form, $gloss, $plg) = $c->dbh->selectrow_array("SELECT etyma.protoform,etyma.protogloss,languagegroups.plg
		FROM etyma LEFT JOIN languagegroups USING (grpid) WHERE etyma.tag=? AND etyma.status != 'DELETE'", undef, $t);
	return "[ERROR! Dead etyma ref #$t!]" unless $form;
	$form =~ s/-/‑/g; # non-breaking hyphens
	$form =~ s/^/*/;
	$form =~ s/⪤ /⪤ */g;		# add a star for proto-allofams
	$form =~ s|(\*\S+)|<b>$1</b>|g; # bold the protoform but not the allofam sign or gloss
	if ($s) {			# alternative gloss, add it in
		$s = "$plg $form</a> $s";
		$s =~ s/\s+$//;	# remove any trailing whitespace (from blank alt gloss designed to suppress default gloss)
	} else {
		$s = "$plg $form</a> $gloss"; # put protogloss if no alt given
	}
	my $u = $c->query->url(-absolute=>1);
	return qq|<a href="$u/etymon/$t">#$t $s|;
}

sub _nonbreak_hyphens {
	my $s = $_[0];
	$s =~ s/-/‑/g;
	return $s;
}

my @italicize_abbrevs =
qw|GSR GSTC STC HPTB TBRS LTSR TSR AHD VSTB TBT HCT LTBA BSOAS CSDPN TIL OED|;

# this sub is used so that apostrophes in forms are not educated into "smart quotes"
# We need to substitute an obscure unicode char, then switch it back to "&apos;" later.
# Here we use the "full width" variants used in CJK fonts.
sub _qtd {
	my $s = $_[0];
	$s =~ s/&apos;/＇/g;
	$s =~ s/&quot;/＂/g;
	return $s;
}

# returns the note in html; an array of footnotes is added to if there are
# footnotes in the note text.
# The footnotes array is only relevant to notes (e.g. etyma notes, chapter notes)
# that can have footnotes inside them; lexicon notes should not contain footnotes,
# since they are inherently footnotes! However, the $footnotes and $i arguments
# are still obligatory.
#
# first arg: xml to be converted.
# $c: the CGI::App object, so we can pass context info when necessary.
# $footnotes: array ref, to add the converted footnotes, etc. to.
# $i: ref to a footnote number counter, to be incremented for each footnote. Should be initialized to 1.
# $super_id: the note id of the note, to be embedded in the footnote data.

sub xml2html {
	local $_ = shift;
	my ($c, $footnotes, $i, $super_id) = @_;
	s|<par>|<p>|g;
	s|</par>|</p>|g;
	s|<emph>|<i>|g;
	s|</emph>|</i>|g;
	s|<gloss>(.*?)</gloss>|$1|g;	# no formatting?
	s|<reconstruction>\*(.*?)</reconstruction>|"<b>*" . _nonbreak_hyphens($1) . "</b>"|ge;
	s|<xref ref="(\d+)">#\1(.*?)</xref>|_tag2info($1,$2,$c)|ge;
	s|<hanform>(.*?)</hanform>|$1|g;
	s|<latinform>(.*?)</latinform>|"<b>" . _nonbreak_hyphens(_qtd($1)) . "</b>"|ge;
	s|<plainlatinform>(.*?)</plainlatinform>|_qtd($1)|ge;
	s|<unicode>(.*?)</unicode>|&#x$1;|g;	# convert hex unicode codepoint to html numeric character reference

	s/(\S)&apos;/$1’/g; # smart quotes
	s/&apos;/‘/g;
	s/&quot;(?=[\w'])/“/g;
	s/&quot;/”/g;  # or $_[0] =~ s/(?<!\s)"/&#8221;/g; $_[0] =~ s/(\A|\s)"/$1&#8220;/g;
	
	s/＇/&apos;/g; # switch back the "dumb" quotes
	s/＂/&quot;/g;
	
	# italicize certain abbreviations
	for my $abbrev (@italicize_abbrevs) {
		s|\b($abbrev)\b|<i>$1</i>|g;
	}
	### specify STEDTU here?

	s/&lt;-+&gt;/⟷/g; # convert double-headed arrows
	s/-+&gt;/→/g; # convert right arrows
	s/&lt;-+/←/g; # convert left arrows
	s/&lt; /< /g; # no-break space after "comes from" sign
	
	s|<footnote>(.*?)</footnote>|push @$footnotes,{text=>$1,super=>$super_id}; qq(<a href="#foot$$i" id="toof$$i" class="footlink"><sup>) . $$i++ . "</sup></a>"|ge;
	s/^<p>//; # get rid of the first pair of (not the surrounding) <p> tags.
	s|</p>||;
	return $_;
}

sub notes_for_rn : Runmode {
	my $self = shift;
	my $rn = $self->query->param('rn');
	return 'Error: not a number' unless $rn =~ /^\d+$/;
	
	my $INTERNAL_NOTES = $self->has_privs(2); # only registered users can see internal notes
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I'" unless $INTERNAL_NOTES;

	my $notes = $self->dbh->selectall_arrayref("SELECT xmlnote,uid,username FROM notes LEFT JOIN users USING (uid) WHERE rn=? $internal_note_search", undef, $rn);
	my @notes;
	my (@dummy, $dummy);
	for (@$notes) {
		 my $xml = $_->[0];
		 my $uid = $_->[1];
		 $xml .= " [$_->[2]]" unless ($uid == 8 || !$self->has_privs(2)); # append the username unless note author is stedt or user is public
		 push @notes, xml2html($xml, $self, \@dummy, \$dummy);
	}
	return join '<p>', @notes;
}

# this sub is tacked on here and exposed (via Exporter) so other modules can use it.
# $c: CGI::App obj
# $r: arrayref of arrayrefs (a result set from a lexicon table SQL query)
# $internal: whether or not to show internal notes
# $a, $i: an array ref and a scalar ref. see xml2html for these.
# $tag: tag number if we're restricting notes to those associated with a particular etymon/rn pair.
sub collect_lex_notes {
	my ($c, $r, $internal, $a, $i, $tag) = @_;
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I'" unless $internal;
	my $tag_search = '';
	$tag_search = "AND (`id`=$tag OR `id`='')" if $tag;
	for my $rec (@$r) {
		if ($rec->[-1]) { # if there are any notes...
			# only select notes which are generic (empty id) OR those that have specifically been marked as belonging to this etymon/reflex combination
			my @results = @{$c->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, id, uid, username FROM notes LEFT JOIN users USING (uid) "
					. "WHERE notes.rn=? AND notes.spec='L' $tag_search $internal_note_search ORDER BY ord",
					undef, $rec->[0])};
			$rec->[-1] = '';
			# NB: these are footnotes, and they don't have footnotes inside them!
			foreach (@results) {
				my ($noteid, $notetype, $lastmod, $note, $id, $uid, $username) = @$_;
				my $xml = $note;
				$note = xml2html($xml, $c, $a, $i);
				if ($notetype eq 'I') {
					$note =~ s/^/[Internal] <i>/;
					$note =~ s|$|</i>|;
				}
				$note =~ s/^/[Source note] / if $notetype eq 'O';
				push @$a, {noteid=>$noteid, type=>$notetype, lastmod=>$lastmod,
					text=>$note, id=>$id, # id is for lex notes specific to particular etyma.
					markup=>xml2markup($xml), num_lines=>guess_num_lines($xml),
					uid=>$uid, username=>$username
				};
				$rec->[-1] .= ' ' . $$i++;
			}
		}
		$rec->[-1] ||= '0';
	}
}

1;
