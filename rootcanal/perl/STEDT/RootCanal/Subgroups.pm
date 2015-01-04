package STEDT::RootCanal::Subgroups;
use strict;
use base 'STEDT::RootCanal::Base';
use utf8;
use Encode;

sub view: StartRunmode {
	my $self = shift;
	$self->require_privs(2);
	my $a = $self->dbh->selectall_arrayref("SELECT grpid, grpno, grp, COUNT(lgid) AS num_lgs, plg, genetic
		FROM languagegroups LEFT JOIN languagenames USING (grpid)
		GROUP BY grpid
		ORDER BY grp0,grp1,grp2,grp3,grp4");
	for my $row (@$a) {
		my $str = $row->[1];
		$str =~ s/\.0//g;
		my $indent_level = $str =~ tr/.//;
		if ($indent_level) {
			$row->[1] = "     $row->[1]" for (1..$indent_level);
			$row->[2] = "     $row->[2]" for (1..$indent_level);
		}
	}

	# pass to tt: searchable fields, results, addable fields, etc.
	return $self->tt_process("admin/subgroups.tt", {
		result => $a
	});
}

sub update : RunMode {
	my $self = shift;
	$self->require_privs(8);
	my $q = $self->query;
	my $fld = $q->param('field');
	die "can't edit field $fld\n" unless $fld eq 'grp' || $fld eq 'plg' || $fld eq 'genetic';

	my $id = $q->param('id');
	$id =~ s/^.*?_//;

	my $s = decode_utf8($q->param('value'));
	my $indent = '';
	($indent) = $s =~ /^(\s+)/ if $fld eq 'grp';
	$s =~ s/^(\s+)//; # trim spaces, non-breaking spaces, etc.
	$s =~ s/\s+$//;

	$self->dbh->do("UPDATE languagegroups SET `$fld`=? WHERE grpid=?", undef, $s, $id);
	return $indent . $s;
}

sub add : RunMode {
	my $self = shift;
	$self->require_privs(8);
	my $q = $self->query;
	if ($q->param("add_grpno") && $q->param("add_grp")) {

		# get group number
		my $grpno = $q->param("add_grpno");

		# verify well-formedness of grpno: digits (first char can be 'X') separated by decimal points; required to end with digit
		die "Group number must be a sequence of digits separated by periods.\n" unless $grpno =~ /^(X|\d+)(\.[\d]+)*$/;

		# split group number by periods
		my ($g0,$g1,$g2,$g3,$g4) = split /\./, $grpno;
		if ($g0 eq 'X') {
			$g0 = 255;	# support 'X' character as a top-level group by recording it as 255 in the table
		}

		my $sth = $self->dbh->prepare("INSERT languagegroups ("
			. join(',', qw|grpno grp plg genetic grp0 grp1 grp2 grp3 grp4|)
			. ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
		eval { $sth->execute($grpno, $q->param('add_grp'), $q->param('add_plg')||'', $q->param('add_genetic')||0, $g0||0, $g1||0, $g2||0, $g3||0, $g4||0) };
		if ($@) {
			my $err = "Couldn't create new languagegroup: $@";
			die $err;
		}
	} else {
		die "oops, grpno or grp was left blank!\n";
	}
	
	require CGI::Application::Plugin::Redirect;
	import CGI::Application::Plugin::Redirect;
	return $self->redirect($q->url(-absolute=>1) . "/subgroups/view");
}

1;
