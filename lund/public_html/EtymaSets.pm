package EtymaSets;
use strict;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw();

use Encode;

=pod

Basic processing for making etyma sets from the STEDT database.
Right now there's one function, which creates a hash mapping from group numbers to group names.

=cut

# returns the elements of a hash to give a group name
# from a group ord number, e.g. 10 => "1.0 Kamarupan"
sub groupno2name {
	my $dbh = shift;
	my %o2s; # ord to string
	for (@{$dbh->selectall_arrayref("SELECT ord, grpno, grp from languagegroups ORDER BY grpno")}) {
		my ($ord,$grpno,$grp) = map {decode_utf8($_)} @$_;
		$grpno =~ s/(\.0)+$//;
		$o2s{$ord} = "$grpno. $grp" unless $o2s{$ord}; # only do this if it's the first one
	}
	return %o2s;
}

1;
