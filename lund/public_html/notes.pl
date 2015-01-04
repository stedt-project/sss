#!/usr/bin/perl
# edited by dwbruhn to use protected pm, 2010-December-07

use strict;
use utf8;
use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser set_message/;
BEGIN {
        $^W = 1;
        unshift @INC, "../pm" if -e "../pm";
        CGI::Carp::set_message("Report bugs/features to stedt@socrates.berkeley.edu");
}
use STEDTUtil;
use Encode;
use FascicleXetexUtil;

=comment
Rn (integer)        # rn from lex, 0 if etyma or chapter
tag (smallint)		# tag from etyma, 0 otherwise
Id (text)           # chapter (with dots)
Notetype (enum) # T:text I:internal N:new O:orig/source G:graphics F:final H:hptb-ref
T and N are essentially the same. Originally T was for text and N was for footnotes,
but all etyma notes are text (with embedded footnotes) and all lexicon notes
are footnotes.
O means notes from the source, which we should never modify. Copy into a new note instead.
	E: I T N F H
	C: I T N F G
	L: I N O	SELECT `notetype`, count(*) FROM `notes` WHERE `spec` = 'L' group by notetype order by 2 desc
Spec (enum)    
Order (integer)       # order of note if more than one
DateTime (datetime)
noteid               # arbitrary unique key
xmlnote              # actual note in xml, utf8; EDIT ME
=cut

######################################################################
# CONSTANTS
######################################################################
my @notetypes = qw(O T I N G F H);
my %notetypelabels;
@notetypelabels{@notetypes} = ('Orig/src-DON\'T MODIFY', qw(Text Internal New Graphic Final HPTB));
my %spec2col = (C=>'id', L=>'rn', E=>'tag');

# things that we expect when saving
my @fields = qw/notetype xmlnote/;
my @params = (qw(noteid lastmod), @fields);

# for markup2xml
my $LEFT_BRACKET = encode_utf8('⟦');
my $RIGHT_BRACKET = encode_utf8('⟧');

# params: no action => spec, id(/rn)
# edit => noteid
# add new => spec, id(/rn)

my $dbh = STEDTUtil::connectdb();
my ($sql, $sth);
$FascicleXetexUtil::tag2info = sub {
	my ($t, $s) = @_;
	my @a = $dbh->selectrow_array("SELECT tag,chapter,printseq,etyma.protoform,etyma.protogloss,hptb.mainpage FROM etyma LEFT JOIN hptb USING (hptbid) WHERE tag=$t");
	return "[ERROR! Dead etyma ref #$t!]" unless $a[0];
	my (undef, $c, $p, $form, $gloss, $hptb_page) = map {decode_utf8($_)} @a;
	if ($c =~ /^9\./ || $c eq '6.5') { # if the root is in chapter 9, then put the print ref
		$t = "($p)";
	} else {
		if ($hptb_page) {
			$t = "(H:$hptb_page)";
		} else {
			$t = "#$t";
		}
	}
	if ($s =~ /^\s+$/) { # empty space means only put the number, no protogloss
		$s = '';
	} else {
		$form =~ s/-/‑/g; # non-breaking hyphens
		$form =~ s/^/*/;
		$form =~ s/⪤ /⪤ */g;		# add a star for proto-allofams
		$form =~ s|(\*\S+)|<b>$1</b>|g; # bold the protoform but not the allofam sign or gloss
		if ($s) {			# alternative gloss, add it in
			$s = "$form $s";
		} else {
			$s = "$form $gloss"; # put protogloss if no alt given
		}
		$s = " $s" if $t; # add a space between if there's a printseq
	}
	return "<b>$t</b>$s";
};

# for AJAX
if (param('btn') =~ /^Save/) {
	foreach (@params) { die "param $_ undefined!" unless defined param($_); }
	# check mod time to ensure no one changed it before us
	$dbh->do("LOCK TABLE notes WRITE");
	if (param('lastmod') eq $dbh->selectrow_array("SELECT datetime FROM notes WHERE noteid=" . param('noteid'))) {
		my $sql = "UPDATE notes SET notetype=?, xmlnote=?, spec=?, rn=?, tag=?, id=? WHERE noteid=?";
		my $sth = $dbh->prepare($sql);
		$sth->execute(param('notetype'), markup2xml(param('xmlnote')), param('record_spec'), param('rn'), param('tag'), param('record_id'), param('noteid'));
		my $lastmod = $dbh->selectrow_array("SELECT datetime FROM notes WHERE noteid=" . param('noteid'));
		print header(-charset => "utf8", '-x-json'=>qq|{"lastmod":"$lastmod"}|);
		print p(b('Success!')," Note saved at $lastmod.");
	} else {
		print header(-charset => "utf8");
 		print p(b('Error!'), " Someone else has modified this note! Your changes were not saved.");
 	}
	$dbh->do("UNLOCK TABLES");
	print FascicleXetexUtil::xml2html(decode_utf8($dbh->selectrow_array("SELECT xmlnote FROM notes WHERE noteid=" . param('noteid'))));
	exit;
} elsif (my $s = param('ajax_sortable')) {
	my @ids = map {/(\d+)/} split /\&/, $s;
	# change the order, but don't update the modification time for something so minor.
	my $sth = $dbh->prepare("UPDATE notes SET ord=?, datetime=datetime WHERE noteid=?");
	my $i = 0;
	$sth->execute(++$i, $_) foreach @ids;
	
	print header(-charset => "utf8");
	exit;
}


print header(-charset => "utf8");
print start_html(-head =>
		 meta({-http_equiv => 'Content-Type', 
				 -content => 'text/html; charset=utf8'}),
		 -encoding => 'utf-8',
		 -title=>'STEDT Database Notes', 
		 -style=>{'src'=>'styles/tagger.css'},
		 -script=>[
		 	{-type => "text/javascript", -src  => 'scriptaculous/lib/prototype.js' },
		 	{-type => "text/javascript", -src  => 'scriptaculous/src/scriptaculous.js' },
		 ],
		 );

if (param('btn') =~ /^Delete/) {
	foreach (@params) { die "param $_ undefined!" unless defined param($_); }
	# check mod time to ensure no one changed it before us
	$dbh->do("LOCK TABLE notes WRITE");
	if (param('lastmod') eq $dbh->selectrow_array("SELECT datetime FROM notes WHERE noteid=" . param('noteid'))) {
		my $sql = "DELETE FROM notes WHERE noteid=?";
		my $sth = $dbh->prepare($sql);
		$sth->execute(param('noteid'));
	} else {
		print h1('Error'), p("Someone else has modified this note! It will not be deleted.");
	}
	$dbh->do("UNLOCK TABLES");
} elsif (param('btn') =~ /^Add/) {
	my $spec;
	foreach ('E', 'L', 'C') { $spec = $_ if param($_) };
	my ($id, $ord, $type, $xml) = (param($spec), param('ord'), param('notetype'), param('xmlnote'));
	my $key = $spec2col{$spec};
	my $sth = $dbh->prepare("INSERT notes (spec, $key, ord, notetype, xmlnote) VALUES (?,?,?,?,?)");
	$sth->execute($spec, $id, $ord, $type, markup2xml($xml));
}

my $id;
if ($id = param('E') or $id = param('L') or $id=param('C') or $id=param('QUERY')) {
	my $spec = param('L') ? 'L' : param('E') ? 'E' : param('C') ? 'C' : 'QUERY';
	my $allow_reorder = 1;
	if ($spec eq 'E') {
		# Query for record from Etyma database
		$sql = "SELECT protoform, protogloss, chapters.chapter, chapters.chaptertitle FROM etyma LEFT JOIN chapters USING (chapter) WHERE tag=?";
		$sth = $dbh->prepare($sql);
		$sth->execute($id);
		
		my ($protoform, $protogloss, $chapter, $chaptertitle)
			= $sth->fetchrow_array; # or die "Can't get etyma info\n";
		
		$protogloss = from_utf8_to_xml_entities($protogloss);
		
		print b(($chapter ? a({-href=>"notes.pl?C=$chapter"}, "Chapter $chapter") . " $chaptertitle: " : ''), "($id) $protoform $protogloss");
	} elsif ($spec eq 'L') {
		$sql = "SELECT lexicon.analysis, lexicon.reflex, lexicon.gloss, languagenames.language, languagegroups.grp, lexicon.semcat FROM lexicon, languagenames, languagegroups WHERE lexicon.lgid=languagenames.lgid AND languagenames.grpid=languagegroups.grpid AND lexicon.rn=?";
		$sth = $dbh->prepare($sql);
		$sth->execute($id);
		
		my ($an, $lex, $gloss, $lg, $grp, $semcat)
			= $sth->fetchrow_array or die "Can't get lex info\n";
		
		$gloss = from_utf8_to_xml_entities($gloss);
		
		print b(qq|Lexicon rn $id: $lex "$gloss" [$an] $grp/$lg [$semcat]|);
	} elsif ($spec eq 'C') {
		$sql = "SELECT chapter, chaptertitle, chapterabbr FROM chapters WHERE chapter=?";
		$sth = $dbh->prepare($sql);
		$sth->execute($id);
		
		my ($n, $t, $abbr)
			= $sth->fetchrow_array or die "Can't get chapter info\n";
		print b(qq|Chapter $n: $t ($abbr)|);
	} else {
		# reordering only for E, L, C
		$allow_reorder = 0;
	}
	
	# get notes
	my ($query_where, $order_by);
	if ($spec eq 'QUERY') {
		$query_where = param('where');
		$order_by = param('order');
		$order_by = "ORDER BY $order_by" if $order_by;
	} else {
		$query_where = $spec2col{$spec} . '=?';
		$order_by = 'ORDER BY ord';
	}
	$sql = "SELECT noteid, notetype, datetime, xmlnote, spec, rn, tag, id, ord FROM notes WHERE "
		. $query_where . " $order_by";
	$sth = $dbh->prepare($sql);
	$sth->execute($spec ne 'QUERY' ? $id : ());
	my $notesequence = 0;
	my $max_ord = -1;

		$order_by = param('order'); # but save this first
	Delete_all(); # reset defaults for all forms
	my $url = url(-relative=>1);
	print "\&nbsp;",checkbox(-onClick=><<EOF, -name=>'Drag to reorder', -checked=>0) if $allow_reorder;
if (this.checked) { \$\$('.compactsort').invoke('hide');
Sortable.create('sortable_notes',{tag:'div', only:'reord', scroll:window, onUpdate:function (container) {
	new Ajax.Request('$url', {
		parameters: {ajax_sortable: Sortable.serialize('sortable_notes')},
		onSuccess: function(){
			var i = 0;
			\$\$('.renumber').each(function(obj) {obj.innerHTML = ++i});
		},
		onFailure: function(transport){ alert('Error: ' + transport.responseText) }
	});
}});
} else { Sortable.destroy('sortable_notes'); \$\$('.compactsort').invoke('show'); }
EOF
	print qq|<div id="sortable_notes">| if $allow_reorder;
	while (my @row = $sth->fetchrow_array) {
		my ($noteid, $type, $mod, $xml, $record_spec, $rn, $tag, $record_id, $ord) = @row;
		++$notesequence;
		$max_ord = $ord if $ord > $max_ord;

		my $markupd_xml = xml2markup($xml);
		print qq|<div class="reord" id="reorddiv_$noteid">| if $allow_reorder;
		print hr,
			start_form({-class=>'left'}),
			hidden($spec, $id),
			hidden('noteid', $noteid),
			hidden('where', $query_where),
			hidden('order', $order_by),
			p(b(qq|#<span class="renumber">$notesequence</span>|),span({-class=>'compactsort'},
				"notetype: ", popup_menu('notetype', \@notetypes, $type,
									\%notetypelabels),
				a({-href=>'#',-onclick=>"var n = document.getElementById('innards_$noteid').style; n['display'] = n['display'] == 'none' ? 'inline' : 'none'; return false"},
					'[+]'),
				span({-id=>"innards_$noteid", -style=>"display:" . ($spec eq 'QUERY' ? "inline" : "none")},
					"spec: ", popup_menu('record_spec', [qw(C E L)], $record_spec),
					"rn: ", textfield('rn', $rn, 6, 6),
					"tag: ", textfield('tag', $tag, 6, 6),
					"id: ", textfield('record_id', $record_id, 8, 8),
					)
				)),
			div({-class=>'compactsort'},
				p("last modified: $mod", hidden(-name=>'lastmod', -value=>$mod, -id=>'lastmod_' . $noteid), " (id:$noteid)"),
				# put in box, then edit box
				$type eq 'G' ? '' : textarea('xmlnote', $markupd_xml, guess_num_lines($markupd_xml), 72),
				br,
				submit(-name=>'btn', -value=>'Save Note',onClick=><<EOF),
new Ajax.Updater('preview_$noteid', '$url', {
	parameters: \$(this).form.serialize(true),
	onSuccess: function(t,json){ \$(lastmod_$noteid).value = json.lastmod; },
});
return false;
EOF
				submit(-name=>'btn', -value=>'Delete Note',-onClick=>"if (confirm('Are you sure you want to delete the selected records?')) return true; else return false;"),
			),
			end_form
			;
		### preserve mod time???
		# what about chapter 1.1*, E P11, etc.
		# etym 1839 - why vert bars?
		# 1839 multiple etyma entries
		
		print div({-class=>'notepreview',-id=>'preview_' . $noteid},
			$type eq 'G'
			? img({-src=>"gif/$noteid.gif", -alt=>"[semantic flowchart]"})
			: FascicleXetexUtil::xml2html(decode_utf8($xml))
		);
		print "</div>" if $allow_reorder;		
	}
	print '</div>' if $allow_reorder;
	print newnoteform($spec, $id, $max_ord+1) unless $spec eq 'QUERY';
} else {
	print h1("Notes editor");
	print pre(($dbh->selectrow_array("SHOW CREATE TABLE `notes`"))[1]);
	print "Enter your WHERE clause:";
	print start_form,
		hidden('QUERY', 1),
		textfield('where', '', 80, 200),
		br,
		'ORDER BY', textfield('order','',15,50),
		br,
		submit(-name=>'btn', -value=>'Search'),
		end_form
		;
	print p("Examples: to find tag references, search for 'xmlnote RLIKE #xxx'");
	print p("to find Chinese comparanda: spec='E' AND notetype='F'; then ORDER BY noteid");
}

$dbh->disconnect;
print hr,a({-href=>url(-relative=>1)},"[Advanced Search]");
print end_html;


########## SUBS

sub xml2markup {
	local $_ = $_[0];
	s|^<par>||;
	s|</par>$||;
	s|</par><par>|\n\n|g;
	s|<br />|\n|g;
	s|<sub>(.*?)</sub>|[[_$1]]|g;
	s|<emph>(.*?)</emph>|[[~$1]]|g;
	s|<strong>(.*?)</strong>|[[\@$1]]|g;
	s|<gloss>(.*?)</gloss>|[[:$1]]|g;
	s|<reconstruction>\*(.*?)</reconstruction>|[[*$1]]|g;
	s|<xref ref="(\d+)">#\1(.*?)</xref>|[[#$1$2]]|g;
	s|<footnote>(.*?)</footnote>|{{%$1}}|g;
	s|<hanform>(.*?)</hanform>|[[$1]]|g;
	s|<latinform>(.*?)</latinform>|[[+$1]]|g;
	s|<plainlatinform>(.*?)</plainlatinform>|[[$1]]|g;
	s/&amp;/&/g;
	s/&lt;/</g;
	s/&gt;/>/g;
	s/&apos;/'/g;
	s/&quot;/"/g;
	return $_;
}

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
	if ($code =~ /[_~:*+@]/) {
		my %sym2x = qw(_ sub ~ emph : gloss * reconstruction @ strong + latinform);
		$s2 = $s if $code eq '*';
		return "<$sym2x{$code}>$s2</$sym2x{$code}>";
	}
	if ($code eq '#') {
		my ($num, $s3) = $s2 =~ /^(\d+)(.*)/;
		return qq|<xref ref="$num">#$num$s3</xref>|;
	}
	my $u = ord decode_utf8($s); ### oops, it hasn't been decoded from utf8 yet
	if (($u >= 0x3400 && $u <= 0x4dbf) || ($u >= 0x4e00 && $u <= 0x9fff)
		|| ($u >= 0x20000 && $u <= 0x2a6df)) {
		return "<hanform>$s</hanform>";
	}
	return "<plainlatinform>$s</plainlatinform>";
}

sub newnoteform {
	my ($spec, $id, $ord) = @_;
	return hr,
		span({-class=>'compactsort'},
		start_form,
		hidden($spec, $id),
		hidden('ord', $ord),	# order new note after all the others
		h1("New Note"),
		p("The following markup codes will be converted to XML tags:"),
		pre(from_utf8_to_xml_entities(<<'EOF')),
<return><return> - paragraph break
<return> - line break
[[_subscript]]
[[~emphasis]] (italic)
[[@strong]] (bold)
[[:gloss]] (deprecated)
[[*reconstruction]]
[[#76 ALT GLOSS]] (tag reference)
[[漢字]]
[[stɛt ⪤ fɑnt]] (plain)
[[+stɛt ⪤ fɑnt]] (bold)
{{%footnote}}
EOF
		p("notetype: ", popup_menu('notetype', \@notetypes, $spec eq 'L' ? 'N' : 'T',
								\%notetypelabels)),
		textarea('xmlnote', '', 10, 72),
		br,
		submit('btn', 'Add Note'),
		end_form
	);
}

sub guess_num_lines {
	use integer;
	my $n = length($_[0])/64;
	return $n < 5 ? 5 : $n+1;
}


### subs copied from etymology.pl

sub from_utf8_to_xml_entities {
    my $string = shift;
    my @subst = (
	['&', '&amp;'],
	['<', '&lt;'],
	['>', '&gt;'],
	["'", '&apos;'],
	['"', '&quot;']);
    for my $pair (@subst) {
	my ($symbol, $entity) = @$pair;
	$string =~ s($symbol)($entity)g;
    }
    return $string;
}
