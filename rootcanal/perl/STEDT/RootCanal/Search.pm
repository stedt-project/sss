package STEDT::RootCanal::Search;
use strict;
use base 'STEDT::RootCanal::Base';
use Encode;

sub splash : StartRunmode {
	my $self = shift;
	my $splash_info;
	
	# generate the list of language groups for the dropdown box:
	$splash_info->{grps} = $self->dbh->selectall_arrayref("SELECT grpno, grp FROM languagegroups ORDER BY grp0,grp1,grp2,grp3,grp4");
	
	return $self->tt_process("splash.tt", $splash_info);
}

sub elink : Runmode {
	my $self = shift;
	my @etyma;
	for my $t ($self->query->param('t')) { # array context, so param returns the whole list!
		next unless $t =~ /^\d+$/;
		my %e;
		@e{qw/plg chap sequence pform pgloss/} = $self->dbh->selectrow_array("SELECT languagegroups.plg, chapter, sequence, protoform, protogloss FROM etyma LEFT JOIN languagegroups USING (grpid) WHERE tag=? AND status != 'DELETE'", undef, $t);
		next unless $e{pform};
		$e{tag} = $t;
		$e{pform} =~ s/⪤ +/⪤ */g;
		$e{pform} =~ s/OR +/OR */g;
		$e{pform} =~ s/~ +/~ */g;
		$e{pform} =~ s/ = +/ = */g;
		$e{pform} = '*' . $e{pform};
		$e{mesoroots} = $self->dbh->selectall_arrayref("SELECT form,gloss,plg,grpno FROM mesoroots
			LEFT JOIN languagegroups USING (grpid) WHERE tag=$t
			ORDER BY grp0,grp1,grp2,grp3,grp4,variant", {Slice=>{}});
		$e{allofams} = $self->dbh->selectall_arrayref(
			"SELECT tag, sequence, languagegroups.plg, protoform, protogloss FROM etyma LEFT JOIN languagegroups USING (grpid)
			 WHERE chapter=? AND sequence != 0 AND FLOOR(sequence)=FLOOR(?) AND status != 'DELETE' ORDER BY sequence", {Slice=>{}},
			$e{chap}, $e{sequence});

		# format sequence number of allofams
		for (@{$e{allofams}}) {
			my $s = $_->{sequence};
			if (int($s) == $s) {
				$_->{sequence} = int $s;
				next;
			}
			$_->{sequence} =~ s/\.(\d)/chr(ord('a')-1+$1)/e;
		}
		push @etyma, \%e;
	}
	return "Error: no valid tag numbers!" unless @etyma;
	return $self->tt_process("tt/et_info.tt", {etyma=>\@etyma});
}

sub group : Runmode {
	my $self = shift;
	my $grpid = $self->param('id');
	my $lgid = $self->param('lgid');
	my ($grpno, $grpname) = $self->dbh->selectrow_array(
		"SELECT grpno, grp FROM languagegroups WHERE grpid=?", undef, $grpid);
	my $lg_list = $self->dbh->selectall_arrayref(
		"SELECT silcode, language, lgcode, srcabbr, citation, lgid, COUNT(lexicon.rn) AS num_recs, pi_page, lgabbr FROM languagenames LEFT JOIN lexicon USING (lgid) LEFT JOIN srcbib USING (srcabbr) WHERE grpid=? AND lgcode != 0 AND lexicon.status!='HIDE' AND lexicon.status!='DELETED' GROUP BY lgid HAVING num_recs > 0 ORDER BY lgcode, language", undef, $grpid);

	# do a linear search for the index of the record we're interested in
	my $i;
	if ($lgid) {
		my $max = $#$lg_list; # set this here, or else get stuck in an infinite loop if there's no matching record!
		$i = 0;
		$i++ until $lg_list->[$i][5] == $lgid || $i > $max;
		undef $i if $i > $max;
	}
	return $self->tt_process('groups.tt', {
		lg_index => $i,
		lgs=>$lg_list,
		grpid=>$grpid,
		grpno=>$grpno,
		grpname=>$grpname,
		grps => $self->dbh->selectall_arrayref("SELECT grpid, grpno, grp FROM languagegroups ORDER BY grp0,grp1,grp2,grp3,grp4")
	});
}


# this subroutine was meant to take a *single* query string
# from a uni-search field (a la google)
# and parse it into search terms in an "intelligent" way.
# now that we've added a separate search box for each field,
# this subroutine should be rethought/split into multiple subs.
sub searchresults_from_querystring {
	my ($self, $f, $s, $tbl, $lg, $lggrp, $lgcode) = @_;
	my $t = $self->load_table_module($tbl);
	my $query = $self->query->new(''); # for some reason faster than saying "new CGI"? disk was thrashing.
	
	# collapse all spaces around commas and ampersands so that boolean
	# search items remain single terms after being split by spaces below.
	# this is provided as a convenience to the searcher, and is in no way
	# meant to imply that users should attempt to do boolean searches
	# across fields (e.g. dog & *kwi will now be interpreted as an AND search
	# in the lexicon.gloss field).
	$s =~ s/\s*([,\&])\s*/$1/g;	# gloss field
	$f =~ s/\s*([,\&])\s*/$1/g;	# form field

	$f =~ s/^\*//g;			# strip initial asterisk from form field, in case anyone tries it

	# strip initial and trailing whitespace from search fields
	$s =~ s/^\s+|\s+$//g;
	$f =~ s/^\s+|\s+$//g;

	# figure out the table and the search terms
	# and make sure there's a (unicode) letter (or number, for the (proto)gloss field) in there somewhere
	if ($tbl eq 'etyma') {
		if ($s =~ /\p{Letter}|\d/) {
			$query->param('etyma.protogloss' => $s);
			# print STDERR "Etyma protogloss is $s\n";	# debugging
		}
		# allow user to enter proto-form OR single tag num in form field
		if ($f =~ /\p{Letter}/) {
			# $token =~ s/^\*//;
			$query->param('etyma.protoform' => $f);
			# print STDERR "Etyma protoform is $f\n";	# debugging
		}
		elsif ($f =~ /^\d+$/) {  # if searching by tag num, the tag num must be the sole search term
			$query->param('etyma.tag' => $f);
			# print STDERR "Etyma tag is $f\n";	# debugging
		}

# 		(commenting out these potentially-confusing random queries)
#		if (!$s && !$f) {
#			$query->param('etyma.tag' => (300,1606)[int(rand 2)]); # which came first, the chicken or the egg?
#		} elsif (!$query->param) {
#			$query->param('etyma.tag' => 2436);
#		}
	} elsif ($tbl eq 'lexicon') {
		$query->param('languagenames.language' => $lg) if $lg =~ /\p{Letter}/;
		
		# languagegroups param must start with X or positive integer and not go past 5 levels (first level is obligatory)
		$query->param('languagegroups.grp' => $lggrp) if $lggrp =~ /^(X|\d+)(\.[\d]+(\.[\d]+(\.[\d]+(\.[\d]+)?)?)?)?$/;
		
		# language code must be an integer
		if (defined($lgcode)) {		# include this test for now, since there's no js code yet to pass lgcode param via ajax
			$query->param('languagenames.lgcode' => $lgcode) if $lgcode =~ /^\d+$/;
		}

		# allow user to query reflex or analysis in form field
		# note that the analysis must be the sole search term in the field for that feature to work
		if ($f =~ /^\d+$/) {
			$query->param('analysis' => $f);
		}
		# if there's a letter in the form field anywhere, send the whole thing to the reflex field search
		elsif ($f =~ /\p{Letter}/) {
			$query->param('lexicon.reflex' => $f);
			# print STDERR "Lexicon reflex is $f\n";	# debugging
		}

		# if the gloss field has a letter or number anywhere, pass it along
		if ($s =~ /\p{Letter}|\d/) {
			$query->param('lexicon.gloss' => $s);
			# print STDERR "Lexicon gloss is $s\n";	# debugging
		}
		
# 		(commenting out these potentially-confusing random queries)
#		if (!$s && !$lg && $lggrp eq '' && !$f) {
#			$query->param('analysis'=>1764);
#			$query->param('lexicon.rn'=>344986);
#		} elsif (!$query->param) {
#			$query->param('analysis'=>5035);
#		}
	}

	# only show public etyma 
#	if ($tbl eq 'etyma' && !$self->has_privs(1)) {
#		$query->param('etyma.public' => 1);
#	}

	return $t->search($query);
}

# this runs when the user submits a search from the splash page
sub combo : Runmode {
	my $self = shift;
	my $q = $self->query;
	my $f = decode_utf8($q->param('f')) || '';	# form (i.e. lemma) parameter
	# print STDERR "COMBO: Form param is $f\n";	# debugging
	my $s = decode_utf8($q->param('t')) || '';
	my $lg = decode_utf8($q->param('lg')) || '';
	my $lg_auto = decode_utf8($q->param('as_values_lg-auto')) || '';
	$lg .= ',' . $lg_auto; $lg =~ s/,+/,/g; $lg =~ s/^,//; # consolidate $lg_auto into $lg and get rid of extra commas
	my $lggrp = decode_utf8($q->param('lggrp'));
	$lggrp = '' unless defined($lggrp);
	my $lgcode = decode_utf8($q->param('lgcode')) || '';	# note that lgcode=0 functions as if the param is blank
	# print STDERR "COMBO: Language group param is $lggrp\n";	# debugging
	my $result;

	if ($f || $s || $lg || $lggrp ne '' || $lgcode || !$q->param) {
		if ($ENV{HTTP_REFERER} && ($f || $s || $lg || $lggrp ne '')) {
			$self->dbh->do("INSERT querylog VALUES (?,?,?,?,?,?,NOW())", undef,
				'simple', $f, $s, $lg, $lggrp, $ENV{REMOTE_ADDR});	# record search in query log (put table name, form, gloss, lg, lggroup, ip in separate fields)
		}
		$result->{etyma} = $self->searchresults_from_querystring($f, $s, 'etyma');
		$result->{lexicon} = $self->searchresults_from_querystring($f, $s, 'lexicon', $lg, $lggrp, $lgcode);
	} else {
		$result->{etyma} = $self->load_table_module('etyma')->search($q);
		$result->{lexicon} = $self->load_table_module('lexicon')->search($q);
	}

	# generate the list of language groups for the dropdown box:
	$result->{grps} = $self->dbh->selectall_arrayref("SELECT grpno, grp FROM languagegroups ORDER BY grp0,grp1,grp2,grp3,grp4");

	return $self->tt_process("index.tt", $result);
}

# this runs when the user submits a search in either the lexicon or etyma section of the simple search interface
sub ajax : Runmode {
	my $self = shift;
	my $s = decode_utf8($self->query->param('s'));
	my $f = decode_utf8($self->query->param('f'));		# form (i.e. lemma) paramter
	# print STDERR "AJAX: Form param is $f\n";	# debugging
	my $lg = decode_utf8($self->query->param('lg'));
	my $lg_auto = decode_utf8($self->query->param('as_values_lg-auto')) || '';
	$lg .= ',' . $lg_auto; $lg =~ s/,+/,/g; $lg =~ s/^,//;
	my $lggrp = decode_utf8($self->query->param('lggrp'));
	$lggrp = '' unless defined($lggrp);
	my $tbl = $self->query->param('tbl');
	my $lgcode = decode_utf8($self->query->param('lgcode'));
	my $result; # hash ref for the results

	$self->dbh->do("INSERT querylog VALUES (?,?,?,?,?,?,NOW())", undef,
		$tbl, $f, $s, $lg, $lggrp, $ENV{REMOTE_ADDR}) if $s || $lg || $lggrp ne '' || $f;	# record search in query log (put table name, form, gloss, lg, lggroup, ip in separate fields)

	if (defined($s) || defined($f)) {
		if ($tbl eq 'lexicon' || $tbl eq 'etyma') {
			$result = $self->searchresults_from_querystring($f, $s, $tbl, $lg, $lggrp, $lgcode);
		} else {
			die "bad table name!";
		}
	} else { # just pass the query on
		my $t = $self->load_table_module($tbl);
		$result = $t->search($self->query);
	}

	$self->header_add('-type' => 'application/json');
	require JSON;
	return JSON::to_json($result);
}

1;
