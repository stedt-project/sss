package STEDTUser;
use strict;
use DBI;

# Returns a read-only database connection
sub connectdb {
  my $host = 'localhost';
  my $db = 'stedt';
  my $db_user = 'stedtuser';
  my $db_password = '';

  my $dbh = DBI->connect("dbi:mysql:$db:$host", "$db_user",
			 "$db_password",
			 {RaiseError => 1,AutoCommit => 1})
    || die "Can't connect to the database. $DBI::errstr\n";
  # This makes the database connection unicode aware
  $dbh->do(qq{SET NAMES 'utf8';});
  return $dbh;
}

1;
