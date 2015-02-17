package STEDTUtil;
use strict;
use DBI;

# Returns a database connection
sub connectdb {
  my $host = 'localhost';
  my $db = 'stedt';
  my $db_user = 'root';
  my $db_password = '';

  my $dbh = DBI->connect("dbi:mysql:$db:$host", "$db_user",
			 "$db_password",
			 {RaiseError => 1,AutoCommit => 1})
    || die "Can't connect to the database. $DBI::errstr\n";
  # This makes the database connection unicode aware
  $dbh->do(qq{SET NAMES 'utf8';});
  return $dbh;
}

sub make_header {
  my $cgi = shift;
  print $cgi->header(-charset => "utf8");
  print $cgi->start_html(-head =>
                         $cgi->meta(
                                    {-http_equiv => 'Content-Type',
                                     -content => 'text/html; charset=utf8'}),
                         -encoding => 'utf-8',
                         -title=>'STEDT Database',
                         #-script => { -src =>  'js/tablekit.js' },
                         -style  => { -src => ['styles/tagger.css',
                         		       'styles/taggerextra.css'], -type=>"text/css" },
        );
}

sub make_footer {
  my $cgi = shift;
  print $cgi->end_html;
}

sub process_analysis {
    my $ana = shift;
    $ana =~ s{([0-9]+)}
      {<a href="etymology.pl?tag=$1">$1</a>}xg;
    return ($ana);
}

1;
