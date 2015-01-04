package STEDT::RootCanal::Autosuggest;
use strict;
use base 'STEDT::RootCanal::Base';
use JSON;
use Encode;

sub dummy : Startrunmode {
	my $self = shift;
	$self->header_add('-type' => 'application/json');
	return to_json({hi=>5});
}

sub lgs : Runmode {
	my $self = shift;
	my $q = '[[:<:]]' . decode_utf8($self->query->param('q'));
	my $result = $self->dbh->selectall_arrayref("SELECT DISTINCT language AS s, CONCAT('=', language) AS v FROM languagenames WHERE language RLIKE ?", {Slice=>{}}, $q);
	$self->header_add('-type' => 'application/json');
	return to_json($result);
}

sub trunc {
	# a little helper function to truncate and add dots if necessary
	my ($s, $len) = @_;
	return $s if length($s) <= $len;
	return substr($s,0,$len) . '...';
}

sub tags : Runmode {
	my $self = shift;
	my $s = $self->query->param('newtag');
	my $skip = $self->query->param('ignore');
	if ($skip =~ /^\d+$/) {
		$skip = "AND tag != $skip";
	} else {
		$skip = '';
	}
	my $a;
	if ($s =~ /^\d+$/) {
		$a = $self->dbh->selectall_arrayref("SELECT tag, protogloss, CONCAT('*',protoform) FROM etyma WHERE tag RLIKE '^$s' AND status != 'DELETE' $skip ORDER BY tag LIMIT 11");
	} else {
		$s =~ s/(?<!\\)((?:\\\\)*)\\('|$)/$1$2/g;
		$s =~ s/'/''/g;
		$s =~ s/\\/\\\\/g;
		$a = $self->dbh->selectall_arrayref("SELECT tag, protogloss, CONCAT('*',protoform) FROM etyma WHERE protogloss RLIKE '[[:<:]]$s' AND status != 'DELETE' $skip ORDER BY tag LIMIT 30");
		unless (@$a) {
			$a = $self->dbh->selectall_arrayref("SELECT tag, protogloss, CONCAT('*',protoform) FROM etyma WHERE protoform RLIKE '$s' AND status != 'DELETE' $skip ORDER BY tag LIMIT 30");
		}
	}
	return '<ul>' . join('', map {"<li>$_->[0] - " . trunc($_->[1],20) . " <b>$_->[2]</b></li>"} @$a) . '</ul>';
}

1;
