package STEDT::RootCanal::Admin;
use strict;
use base 'STEDT::RootCanal::Base';
use utf8;
use Time::HiRes qw(time);
use STEDT::RootCanal::Notes;

sub main : StartRunmode {
	my $self = shift;
	$self->require_privs(2);
	
	my %h;
	if ($self->has_privs(16)) {
		$h{num_sessions} = $self->dbh->selectrow_array("SELECT COUNT(*) FROM sessions");
	}
	return $self->tt_process("admin.tt", \%h);
}

sub updatesequence : Runmode {
	my $self = shift;
	$self->require_privs(8);
	my $t0 = time();
	$self->dbh->do( 'update etyma set sequence = (select @rownum:=@rownum+1 rownum FROM (SELECT @rownum:=1000) r) where seqlocked = 0 order by protogloss;' );
	return $self->tt_process("admin/updatesequence.tt", {
		time_elapsed=>time()-$t0,
	});

}

sub bulkapproval : Runmode {
  my $self = shift;
  $self->require_privs(8);
  # takes a list of tags and "approves" all non-STEDT tags for the selected user.
  # everything is done via AJAX in the template. Nothing else to do here!
  my $users = $self->dbh->selectall_arrayref("SELECT distinct username,uid FROM lx_et_hash
  	LEFT JOIN users USING (uid)
  	WHERE uid!=8
  	ORDER BY username LIMIT 500");
  return $self->tt_process("admin/bulkapproval.tt", {users => $users });
}

sub bulktag : Runmode {
  my $self = shift;
  $self->require_privs(8);
  # takes a list of rns and a tag and tags all the specified rns for the selected user.
  # everything is done via AJAX in the template. Nothing else to do here!
  my $users = $self->dbh->selectall_arrayref("SELECT distinct username,uid FROM lx_et_hash
  	LEFT JOIN users USING (uid)
  	WHERE uid!=8
  	ORDER BY username LIMIT 500");
  return $self->tt_process("admin/bulktag.tt", {users => $users });
}

sub deletedata : Runmode {
  my $self = shift;
  $self->require_privs(16);
  my $msg;
  # Deletes the data specified
  my $srcabbrs = $self->dbh->selectall_arrayref("SELECT distinct srcabbr FROM srcbib ORDER BY srcabbr LIMIT 1000");
  my $srcabbr = $self->query->param('srcabbr');
  my $lgid = $self->query->param('lgid');
    
  if ($srcabbr) { 
    if ($lgid) {
      my $checksrcabbr = $self->dbh->selectrow_array("SELECT srcabbr FROM `languagenames` WHERE lgid=?", undef, $lgid);
      if ($checksrcabbr ne $srcabbr) {
	$msg = "Source abbreviation for lgid $lgid is '$checksrcabbr', not '$srcabbr'<br>No deleting done.";
	return $self->tt_process("admin/deletedata.tt", {srcabbrs => $srcabbrs, msg => $msg });
      }
    }
    else { #user left lgid blank
      my $checklgid = $self->dbh->selectrow_array("SELECT lgid FROM `languagenames` WHERE srcabbr=? LIMIT 1", undef, $srcabbr);
      my $checkcount = $self->dbh->selectrow_array("SELECT count(*) FROM `lexicon` WHERE lgid=?", undef, $checklgid);
      if ($lgid ne $checklgid) {
	$msg = "Language id for $srcabbr is '$checklgid' (with $checkcount lexicon records), not '$lgid'<br>No deleting done.";
	return $self->tt_process("admin/deletedata.tt", {srcabbrs => $srcabbrs, msg => $msg });
      }
    }
    my $count = $self->dbh->selectrow_array("SELECT count(*) FROM `lexicon` WHERE lgid=?", undef, $lgid);
    if ($count) { # if lexicon records exist, check for tags
      my @tagged_recs = @{$self->dbh->selectcol_arrayref("SELECT rn FROM lx_et_hash LEFT JOIN `lexicon` USING (rn) WHERE lgid=?", undef, $lgid)};
      my $num_tags = scalar @tagged_recs;
      if ($num_tags) { # if there are tags, abort the deletion
        $msg .= "No deleting done. Lgid $lgid in $srcabbr has $num_tags records tagged.<br>Please untag these records before deleting the source: ";
        $msg .= join(", ", @tagged_recs);
        return $self->tt_process("admin/deletedata.tt", {srcabbrs => $srcabbrs, msg => $msg });
      }
    }
    $msg = "Deleting source: '$srcabbr', lgid=$lgid";
    if ($lgid) { # if lgid is defined, delete its lexicon records and languagenames entry
      if ($count) { # if there are lexicon records
        $self->dbh->do("DELETE FROM lexicon WHERE lgid=?", undef, $lgid);
        $msg .= "<br>$count lexicon records associated with lgid $lgid deleted.";
      }
      $self->dbh->do("DELETE FROM languagenames WHERE lgid=?", undef, $lgid);
      $msg .= "<br>Entry for lgid $lgid deleted.";

    }
    else { # otherwise, this source doesn't have any lgid entries 
      $msg .= "<br>$srcabbr has no lgid entries to delete.";
    }
    if ($self->query->param('delsrc')) { # if user checked 'delete source bib entry'
      my $lgcount = $self->dbh->selectrow_array("SELECT count(*) FROM `languagenames` WHERE srcabbr=?", undef, $srcabbr);
      if ($lgcount == 0) {
	$msg .= '<br>Deleted source bibliography entry.';
	$self->dbh->do("DELETE FROM srcbib WHERE srcabbr=?", undef, $srcabbr);
      }
      else {
	$msg .= "<br>Source bibliography entry not deleted! $lgcount language record(s) remain which refer to this source!";
      }
    }
    else { # user didn't check 'delete source bib entry'
      $msg .= "<br>Source bibliography entry not deleted."
    }
  }
  else { # initial view, or user didn't select source abbreviation
    $msg = "Please select a source abbreviation.";
  }

  return $self->tt_process("admin/deletedata.tt", {srcabbrs => $srcabbrs, msg => $msg });
}

sub changes : Runmode {
	my $self = shift;
	$self->require_privs(1);
	my $tbl = $self->query->param('t');
	my $id = $self->query->param('id');
	my $mode = $self->query->param('mode');
	my $limit = $self->query->param('limit');
	my $where = '';
	my $comment = '';
	if ($limit !~ /^\d{1,4}$/) {
		$limit = 500;
	}
	if ($tbl && $id) {
		$where = "WHERE `table`=? AND id=?";
	} elsif ($mode eq 'admins') {
		$where = 'WHERE changelog.col != "user_an" ';
		$comment = ' (excluding user_an)';
	}
	my $sth = $self->dbh->prepare("SELECT users.username,change_type,accepted_tag,`table`,id,col,oldval,newval,
		owners.username,time FROM changelog LEFT JOIN users USING (uid)
		LEFT JOIN users AS owners ON (owner_uid=owners.uid)
		$where
		ORDER BY time DESC LIMIT $limit");
	if ($tbl && $id) {
		$sth->bind_param(1, $tbl);
		$sth->bind_param(2, $id);
	}
	$sth->execute;
	my $a = $sth->fetchall_arrayref;
	foreach (@$a) {
		@{$_}[6,7] = hilite_diffs(@{$_}[6,7,5]);
	}
	return $self->tt_process("admin/changelog.tt", {changes=>$a, comment=>$comment});
}

sub hilite_diffs {
	require Algorithm::Diff;
	my ($s1, $s2, $col) = @_;
	my $is_xml = $col eq 'xmlnote';
	# make sure any strings returned here have been html_filter'd!
	# we can't do this in the template since we add <ins|del> html tags that shouldn't be escaped.
	return html_filter($s1), html_filter($s2) if ($s1 eq '' || $s2 eq '');
	my ($t1, $t2);
	my @s1 = tokenize($s1, $is_xml);
	my @s2 = tokenize($s2, $is_xml);
	my $diff = Algorithm::Diff->new(\@s1, \@s2);
	while($diff->Next()) {
		my $bits = $diff->Diff();
		if ($bits == 0) {
			# ignore long stretches of sameness
			# if the "same" hunks are longer than 80, only show ~30 of surrounding context
			my $t = '';
			my $len = $diff->Range(1);
			if ($len < 80) {
				$t = html_filter(join '', $diff->Items(1));
			} else {
				my $context = 30;
				my $offset1 = $diff->Min(1);
				my $offset2 = $diff->Min(2);
				my $is_start = $offset1 == 0 && $offset2 == 0;
				my $is_end = ($offset1 + $len == @s1) && ($offset2 + $len == @s2);
				$t .= html_filter(join '', @s1[$offset1..($offset1+$context)]) unless $is_start;
				$t .= '<p>' unless $is_start || $is_end;
				$t .= ' . . . ';
				my $i = $offset1 + $len - 1;
				$t .= html_filter(join '', @s1[($i-$context)..$i]) unless $is_end;
			}
			$t1 .= $t;
			$t2 .= $t;
		} else {
			if ($bits & 1) {
				$t1 .= '<del>';
				$t1 .= html_filter(join '', $diff->Items(1));
				$t1 .= '</del>';
			}
			if ($bits & 2) {
				$t2 .= '<ins>';
				$t2 .= html_filter(join '', $diff->Items(2));
				$t2 .= '</ins>';
			}
		}
	}
	return $t1, $t2;
}

sub tokenize {
	my ($s, $is_xml) = @_;
	if ($is_xml) {
		# rough word diff for xmlnote
		return xml2markup($s) =~ /([A-Za-z]+|\d+|.)/g;
	} else {
		# otherwise diff each character
		return split '', $s;
	}
}

sub html_filter {
    my $text = shift;
    for ($text) {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        s/"/&quot;/g;
    }
    return $text;
}

sub updateprojects : Runmode {
	my $self = shift;
	$self->require_privs(8);
	my $t0 = time();
	require STEDT::RootCanal::stopwords;
	import STEDT::RootCanal::stopwords;

	my ($wb1, $wb2);
	if ($STEDT::RootCanal::Base::ICU_REGEX) {
		$wb1 = $wb2 = '\\\\b';
	} else {
		($wb1, $wb2) = ('[[:<:]]', '[[:>:]]');
	}
	my $a = $self->dbh->selectall_arrayref("SELECT id,project,subproject,querylex FROM projects LIMIT 500");
	# the loop below will add values for percent_done, tagged_reflexes, count_reflexes, and count_etyma

	# no need to use load_table_module and query_where to build the query string
	# because the query is so simple and it's better to optimize the regex
	# instead of using multiple OR's in the WHERE clause
	for my $row (@$a) {
		my $words = $row->[3];
		$words =~ tr/\\()//d; # remove backslashes and parens
		$words = join '|', split m|[,/] *|, $words; # split by commas and slashes, then rejoin with pipes
		my ($fulltext_words, $other_words) = mysql_fulltext_filter(split /\|/, $words);
		$fulltext_words = join ' ', @$fulltext_words;
		$other_words = join '|', @$other_words;
		if ($other_words) {
			$other_words = "($other_words)" if $other_words =~ /\|/;
			$other_words = qq#OR gloss RLIKE "$wb1$other_words$wb2"#;
		} # otherwise it's empty and doesn't affect the search
		# $row->[3] = $other_words; # debugging - see how many "left over" glosses there are
		# count a lx_et_hash record as "ambiguous" below if it's '', 'm', or if any other lx_et_hash entries with the same rn are '' or 'm'
		my $counts = $self->dbh->selectall_arrayref(
			qq#SELECT COUNT(DISTINCT rn),
				lx_et_hash.rn IS NOT NULL AS has_tags,
				tag_str='' OR tag_str='m' OR 0<(SELECT COUNT(*) FROM lx_et_hash WHERE rn=lexicon.rn AND (tag_str='' OR tag_str='m')) AS is_ambiguous
			FROM lexicon LEFT JOIN lx_et_hash USING (rn)
			WHERE MATCH(gloss) AGAINST ("$fulltext_words" IN BOOLEAN MODE)
			$other_words
			GROUP BY 2,3#);
		my ($tagged, $not_tagged, $sorta_tagged) = (0,0,0);
		foreach (@$counts) {
			my ($count, $has_tags, $is_ambiguous) = @$_;
			if (!$has_tags) { $not_tagged = $count; }
			elsif ($is_ambiguous) { $sorta_tagged = $count; }
			else { $tagged = $count; }
		}
		my $total_found = $tagged + $sorta_tagged + $not_tagged;
		
		$row->[5] = $tagged . ($sorta_tagged ? "(+$sorta_tagged)" : '');
		$row->[6] = $total_found;
		$row->[4] = $total_found
			? sprintf("%.1f", 100 * $tagged/$total_found)
				. ($sorta_tagged
						? ' - ' . sprintf("%.1f", 100 * ($tagged+$sorta_tagged)/$total_found)
						: '')
			: "0.0"; # no dividing by zero!
		
		$row->[7] = $self->dbh->selectrow_array(qq#SELECT count(*) FROM etyma WHERE protogloss RLIKE "$wb1($words)$wb2" AND status != 'DELETE'#);
		$self->dbh->do("UPDATE projects SET tagged_reflexes=?,ambig_reflexes=?,count_reflexes=?,count_etyma=? WHERE id=?", undef,
			$tagged, $sorta_tagged, $total_found, $row->[7], $row->[0]);
		shift @$row;
	}
	
	return $self->tt_process("admin/updateprojects.tt", {
		projects=>$a,
		time_elapsed=>time()-$t0,
	});
}

sub queries : Runmode {
	my $self = shift;
	$self->require_privs(1);

	my $a = $self->dbh->selectall_arrayref("SELECT `table`,form,gloss,lg,lggroup,ip,time FROM querylog ORDER BY time DESC LIMIT 500");
	return $self->tt_process("admin/querylog.tt", {queries=>$a});
}

sub deviants : Runmode {
	my $self = shift;
	$self->require_privs(8);

	# count number of records with deviant glosses
	my %conditions = ('to VERB','^to [^/(]',
			'to be VERB','^to be ',
			'be VERB','^be [^/(]',
			'a(n) NOUN','^an? [^/(]',
			'the NOUN','^the ',
			'records with curly quotes','“|”|‘|’');
	foreach my $cond (keys %conditions)
	{
		$conditions{$cond} = {count=>$self->dbh->selectrow_array("SELECT count(*) FROM `lexicon` WHERE `gloss` REGEXP '$conditions{$cond}'"),
				     regex=>$conditions{$cond}};
	}
		
	return $self->tt_process("admin/deviants.tt", {deviants=>\%conditions});
}

sub progress : Runmode {
	my $self = shift;
	$self->require_privs(1);

	my $a = $self->dbh->selectall_arrayref("SELECT username, users.uid,
			COUNT(DISTINCT tag), COUNT(DISTINCT rn)
		FROM users LEFT JOIN lx_et_hash USING (uid) LEFT JOIN etyma USING (tag)
		WHERE tag != 0 GROUP BY uid;");
	my $b = $self->dbh->selectall_arrayref("SELECT username,users.uid,
			tag, languagegroups.plg, protoform, protogloss, COUNT(DISTINCT rn) as num_recs
		FROM users LEFT JOIN lx_et_hash USING (uid) LEFT JOIN etyma USING (tag) LEFT JOIN languagegroups USING (grpid)
		WHERE users.uid !=8 AND tag != 0 GROUP BY uid,tag ORDER BY uid, num_recs DESC");
	
	# pull out "past work" from changelog and count what was done in the past, add these counts into table. Credit where credit is due!
	my %c = @{$self->dbh->selectcol_arrayref("SELECT owner_uid, COUNT(*) FROM changelog WHERE change_type='approval' GROUP BY owner_uid",
		{Columns=>[1,2]})};
	foreach my $row (@$a){
	  my $uid = $row->[1];
	  $c{$uid} ||= 0;
	  push @$row, $c{$uid}, @$row[3] + $c{$uid};
	  # add two columns: number of accepted taggings,
	  # and the total of the last two columns (reflexes + accepted)
	}
	return $self->tt_process("admin/progress.tt", {etymaused=>$a, tagging=>$b});
}

sub progress_detail : Runmode {
	my $self = shift;
	$self->require_privs(1);

	my $months = $self->dbh->selectcol_arrayref("SELECT CONCAT(YEAR(time), ' ', MONTHNAME(time)) FROM changelog WHERE change_type='approval' GROUP BY 1 ORDER BY YEAR(time) DESC, MONTH(time) DESC");
	my $a = $self->dbh->selectall_arrayref("SELECT CONCAT(YEAR(time), ' ', MONTHNAME(time)), username ,COUNT(*) FROM changelog LEFT JOIN users ON (changelog.owner_uid=users.uid) WHERE change_type='approval' GROUP BY 1,2");
	my (%u_totals, %m_totals, $grand_total);
	my %stats; # hash of month/user -> count
	foreach (@$a) {
		my ($y_m, $u, $count) = @$_;
		$stats{"$y_m"}{$u} = $count;
		$u_totals{$u} += $count;
		$m_totals{$y_m} += $count;
		$grand_total += $count;
	}
	return $self->tt_process("admin/progress_detail.tt", {
		stats=>\%stats,
		months=>$months,
		users=>[sort keys %u_totals],
		u_totals=>\%u_totals,
		m_totals=>\%m_totals,
		total => $grand_total
	});
}

sub expire_sessions : Runmode {
	my $self = shift;
	$self->require_privs(16);
	local *STDOUT; # override STDOUT since ExpireSessions stupidly prints to it
	open(STDOUT, ">", \my $tmp) or die "couldn't open memory file: $!";
	require CGI::Session::ExpireSessions;
	import CGI::Session::ExpireSessions;
	CGI::Session::ExpireSessions->new(dbh=>$self->dbh,
		delta=>2551443,
		verbose=>1)->expire_db_sessions;
	# mean length of synodic month is approximately 29.53059 days
	return "<pre>$tmp</pre>";
}

sub lg_stats : Runmode {
	# ported from lg_table.cgi
	my $self = shift;
	
	# open the language lookup table and make our hash
	open F, "<:utf8", "sil2lg.txt" or die $!;
	binmode(STDOUT, ":utf8");
	my %sil2lg;
	while (<F>) {
		my ($silcode, $lgname) = split /\t/;
		$sil2lg{$silcode} = $lgname;
	}
	close F or die $!;
	
	my $time = scalar localtime;
	my $text = "<h2 align=\"center\">STEDT Database Language Statistics</h2>
	<p align=\"center\">(as of $time)</p>";
	
	my @stats = (
	[ 'Total language entries (unique to source):', 'SELECT count(*) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid)', 'e.g. <i>Bantawa</i> from Rai (1985), <i>Bantawa</i> from Weidert (1987), and <i>Lahu</i> from Weidert (1987) are 3 separate entries' ],
	[ 'Unique ISO 639-3 codes:', 'SELECT -1 + count(distinct(silcode)) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid)', '<b>underestimates</b> the true number of languages in the database, because not all language entries have codes assigned' ],
	[ 'Unique language names:', 'SELECT count(distinct(language)) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid)', '<b>overestimates</b> the true number of languages in the database, due to variant names for the same language (e.g. <i>Darang Deng</i> and <i>Digaro</i>)' ],
	[ 'Language entries with ISO 639-3 codes:', 'SELECT count(*) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode<>""', '' ],
	[ 'Language entries without ISO 639-3 codes:', 'SELECT count(*) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode=""', '' ],
	[ 'Unique combinations of language name + ISO 639-3 code:', 'SELECT language, silcode, count(*) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode<>"" GROUP BY language, silcode', 'e.g. <i>Bai</i> [bca] and <i>Bai</i> [bfs] are 2 separate entries; <i>Ao (Chungli)</i> [njo] and <i>Ao (Mongsen)</i> [njo] are also 2 separate entries' ],
	[ 'Unique language names without ISO 639-3 codes:', 'SELECT count(distinct(language)) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode=""', '(see the <b>NO CODE</b> section of the table below)' ],
	[ 'Language names that correspond to more than one unique ISO 639-3 code:', 'SELECT language, count(language) FROM (SELECT language, silcode FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode<>"" GROUP BY language, silcode) AS table1 GROUP BY language HAVING count(*)>1', 'e.g. <i>Bai</i> [bfs, bca], <i>Chinese</i> [och, cmn], <i>Tujia</i> [tjs, tji]' ],
	[ 'ISO 639-3 codes that correspond to exactly one unique language name:', 'SELECT silcode, count(silcode) FROM (SELECT silcode, language FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode<>"" GROUP BY silcode, language) AS table1 GROUP BY silcode HAVING count(*)=1', 'e.g. [aim] => <i>Aimol</i>, [adl] => <i>Gallong</i>' ],
	[ 'ISO 639-3 codes that correspond to multiple unique language names:', 'SELECT silcode, count(silcode) FROM (SELECT silcode, language FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) AND silcode<>"" GROUP BY silcode, language) AS table1 GROUP BY silcode HAVING count(*)>1', 'e.g. [kdv] (<i>Andro</i>, <i>Ganan</i>, <i>Kadu</i>, <i>Sak</i>, <i>Sengmai</i>, etc.), [bap] (<i>Bantawa</i>, <i>Rungchangbung</i>)' ],
	);
	
	$text .= '<table border="1" align="center" cellpadding="5" cellspacing="1">';
	$text .= '<tr bgcolor="#99CCFF"><th align="left">Statistic</th><th align="left">Number</th><th align="left">Notes</th></tr>';
	
	foreach (@stats) {
		my ($desc, $query, $notes) = @$_;
		$text .= qq|<tr><td>$desc</td><td align="right">|;
		my $a = $self->dbh->selectall_arrayref($query);
		if (1 == @$a) { # if contains one row, print the value
			$text .= $a->[0][0];
		} else {
			$text .= scalar @$a;
		}
		$text .= "</td><td>$notes</td></tr>\n";
	}
	$text .= "</table>";
	
	$text .= "<br/><br/>
	<table border=\"1\" cellpadding=\"1\" cellspacing=\"0\" align=\"center\">
	 <tr align=\"left\" bgcolor=\"#99CCFF\">
	  <th>ISO 639-3 Code&nbsp;&nbsp;</th>
	  <th>Ethnologue Name</th>
	  <th>STEDT Name(s)</th>
	  <th>Sources</th>
	  <th>records</th>
	 </tr>";
	 
	# look up stuff from the database
	my $a = $self->dbh->selectall_arrayref("SELECT silcode,language,COUNT(*), SUM((SELECT COUNT(*) FROM lexicon WHERE lgid=languagenames.lgid)) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid) GROUP BY silcode,language ORDER BY silcode");
	
	# first pass: move empty silcodes to end
	while ($a->[0][0] eq '')
		# test if the silcode is empty
		# (they're sorted so the empty ones are at the top)
	{
		push @$a, shift @$a; # take the first item and tack it to the end
	}
	
	# second pass: count number of lines for each sil code
	my %sil_count;
	foreach (@$a) {
		my $silcode = $_->[0];
		$sil_count{$silcode}++;
	}
	
	# third pass: count number of lines for each sil code
	my $lastsilcode = '';
	foreach (@$a) {
		my ($silcode, $lgname, $num, $num_recs) = @$_;
		$text .= "<tr>";
		if ($silcode ne $lastsilcode) {
			my $n = $sil_count{$silcode};
			if ($silcode) {
				$text .= "<td rowspan=$n valign='middle'><a href=\"http://www.sil.org/iso639-3/documentation.asp?id=$silcode\">$silcode</a></td>";
				$text .= "<td rowspan=$n valign='middle'><a href=\"http://www.ethnologue.com/show_language.asp?code=$silcode\">$sil2lg{$silcode}</a></td>";
			} else {
				$text .= "<td rowspan=$n colspan=2 valign='top'><b>NO CODE</b></td>";
			}
			$lastsilcode = $silcode;
		}
		$num_recs =~ s/(\d)(\d{3})$/$1,$2/; # insert commas to make numbers more readable
		$text .= "<td>$lgname</td><td>$num</td><td align='right'>$num_recs</td>";
		$text .= "</tr>\n";
	}
	
	$text .= "</table>";
	
	$text .= "</html>";	
	 
 	return $self->tt_process("tt/stats.tt", {text=>$text, title=>"STEDT Database Language Statistics"});
}



sub get_stats {
	my $self = shift;

	my $sql = "show table status";
	my $sth = $self->dbh->prepare($sql);
	$sth->execute();

	my %tables = (
		      'chapters' =>  'Chapters',
		      'etyma' => 'Etyma (reconstructions)',
		      'hptb' => 'Reconstructions from HPTB',
		      'languagegroups' => 'Language Groups',
		      'languagenames' => 'Language Names',
		      'lexicon' => 'Reflexes (= "lexical items"="citations")',
		      'lx_et_hash' => 'Tagged Morphemes',
		      'notes' => 'Notes',
		      'srcbib' => 'Sources (of lexical data)'
		     ) ;

	my $result;
	while (my $row = $sth->fetchrow_hashref()) {
	  my $Name = $row->{Name};
	  my $Rows = $row->{Rows};
	  if ($tables{$Name}) {
	    my $table =  $tables{$Name} . " </td><td><a href=\"../edit/$Name\" target=\"_new\">" . $Name . "</a>" ;
	    $result .= "<tr><td>" . join("<td>",($table,$Rows));
	  }
	}
	return $result ;
}


sub db_stats : Runmode {
	# hacked from lg_stats, and some code from the so-called "chiangmai version"
	my $self = shift;
	
	my $time = scalar localtime;
	my $text = "<h2 align=\"center\">STEDT Publication Statistics (i.e. what's in the D-T)</h2>
	<p align=\"center\">(as of $time)</p>";

	my @stats = (
	[ 'Cognate sets in D-T:', 'select count(*) from (SELECT tag,count(*) FROM lx_et_hash WHERE uid=8 AND tag != 0 group by tag) as x', '(i.e. distinct tags in use)' ],
	[ 'Sequenced etyma with support:', "SELECT count(*) FROM etyma WHERE status != 'DELETE'", '(should be the same as above)' ],
	[ 'Number of supporting forms:', 'SELECT count(*) FROM lx_et_hash WHERE uid=8 AND tag != 0', '(morphemes which have been tagged, and so appear in the D-T)' ],
	[ 'Languages and dialects:', 'SELECT count(distinct(lgsort)) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid)', 'Count of "normalized" language names of supporting forms, i.e. in lgsort column' ],
	[ 'Number of "usable" Etyma:', "SELECT count(*) FROM etyma WHERE status != 'DELETE'", 'i.e. not deleted, with or without supporting forms' ],
	[ 'Weakly attested sets:', 'SELECT count(*) from (SELECT tag,count(*) as N FROM lx_et_hash WHERE uid=8 AND tag != 0 group by tag) as x WHERE n <= 5', '(5 or fewer supporting forms)' ],
	[ 'Strongly attested sets:', 'SELECT count(*) from (SELECT tag,count(*) as N FROM lx_et_hash WHERE uid=8 AND tag != 0 group by tag) as x WHERE n > 5', '(greater that 5 supporting forms)' ],
	[ 'Forms which have not been tagged', 'SELECT count(*)  FROM lexicon LEFT JOIN lx_et_hash USING (rn) WHERE tag is Null;', 'no tags at all' ],
	);
	
	$text .= '<table border="1" align="center" cellpadding="5" cellspacing="1">';
	$text .= '<tr bgcolor="#99CCFF"><th align="left">Statistic</th><th align="left">Number</th><th align="left">Notes</th></tr>';
	
	foreach (@stats) {
		my ($desc, $query, $notes) = @$_;
		$text .= qq|<tr><td>$desc</td><td align="right">|;
		my $a = $self->dbh->selectall_arrayref($query);
		if (1 == @$a) { # if contains one row, print the value
			$text .= $a->[0][0];
		} else {
			$text .= scalar @$a;
		}
		$text .= "</td><td>$notes</td></tr>\n";
	}
	$text .= "</table>";

	$text .= "<br><br><h2 align=\"center\">STEDT \"Raw\" Database Statistics (i.e. rows in tables)</h2>";

	$text .= "<table border=\"1\" cellpadding=\"1\" cellspacing=\"0\" align=\"center\">";
	$text .= '<tr bgcolor="#99CCFF"><th align="left">Table Label</th><th align="left">Table Name</th><th align="left">Rows</th></tr>';
	$text .= get_stats($self);	
	$text .= "</html>";
	$text .= "</table>";

	 
 	return $self->tt_process("tt/stats.tt", {text=>$text, title=>"STEDT Datatabase Statistics"});
}

sub raw_stats : Runmode {
	# hacked from db_stats... makes a csv version of stats suitable for further processing.
	my $self = shift;
	
	my $time = scalar localtime;
	my $text = "STEDT Database Statistics \t$time\n";

	my @stats = (
	[ 'Cognate sets in D-T:', 'select count(*) from (SELECT tag,count(*) FROM lx_et_hash WHERE uid=8 AND tag != 0 group by tag) as x', '(i.e. distinct tags in use)' ],
	[ 'Sequenced etyma with support:', "SELECT count(*) FROM etyma WHERE status != 'DELETE'", '(should be the same as above)' ],
	[ 'Number of supporting forms:', 'SELECT count(*) FROM lx_et_hash WHERE uid=8 AND tag != 0', '(morphemes which have been tagged, and so appear in the D-T)' ],
	[ 'Languages and dialects:', 'SELECT count(distinct(lgsort)) FROM `languagenames` WHERE EXISTS (SELECT * FROM `lexicon` WHERE languagenames.lgid=lexicon.lgid)', 'Count of "normalized" language names of supporting forms, i.e. in lgsort column' ],
	[ 'Number of "usable" Etyma:', "SELECT count(*) FROM etyma WHERE status != 'DELETE'", 'i.e. not soft-deleted, with or without supporting forms' ],
	[ 'Weakly attested sets:', 'SELECT count(*) from (SELECT tag,count(*) as N FROM lx_et_hash WHERE uid=8 AND tag != 0 group by tag) as x WHERE n <= 5', '(5 or fewer supporting forms)' ],
	[ 'Strongly attested sets:', 'SELECT count(*) from (SELECT tag,count(*) as N FROM lx_et_hash WHERE uid=8 AND tag != 0 group by tag) as x WHERE n > 5', '(greater that 5 supporting forms)' ],
	[ 'Forms with no tags:', 'SELECT count(*)  FROM lexicon LEFT JOIN lx_et_hash USING (rn) WHERE tag is Null;', '... at all' ],
	);
	
	$text .= "\n\nStatistic\tNumber\tNotes\t\n";
	
	foreach (@stats) {
		my ($desc, $query, $notes) = @$_;
		$text .= "$desc\t";
		my $a = $self->dbh->selectall_arrayref($query);
		if (1 == @$a) { # if contains one row, print the value
			$text .= $a->[0][0];
		} else {
			$text .= scalar @$a;
		}
		$text .= "\t$notes\n";
	}
 	return $self->tt_process("tt/rawstats.tt", {text=>$text, title=>"STEDT Database Language Statistics"});
}

1;
