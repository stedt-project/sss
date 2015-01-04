
sub validateContribution {
  my $fh = shift;
  my @messages;
  my %results;
  my $lines;
  my $show_stopper = 0;
  my $header_length;
  my $row_length;
  my @header; 
  my %headerindex;
  while ( <$fh> ) {
    chomp;
    $lines++;
    # check header
    if ($lines == 1) {
      @header = split "\t";
      for (my $i = 0; $i < scalar @header; $i++) {
        if ($header[$i] !~ /(gloss|reflex|pos)/) {
	  $show_stopper = 1;
	  push(@messages, $header[$i]. ' unexpected header column found.');
	}
	else {
	  push(@messages, $header[$i]. " header column found: $i");
	}
        $headerindex{$header[$i]} = $i;
      }
    }
    # So in the case of the test files, $headerindex{'gloss'} is 1.
    # Now you can test the columns in the rest of the file:
    
    # check for missing values
    my @columns = split "\t";
    for (my $i = 0; $i < scalar @header; $i++) {
      my $column = $columns[$i];
      if ($i == $headerindex{'gloss'}) {
        print "@columns[$i]\n";
	# do gloss tests 
		# check well-formedness of gloss --- right now, checks for non-word characters in gloss; perhaps can be refined later
        if ($columns[$i] =~ /\W/) {
          push(@messages, "unusual character in column 'gloss', line $lines");
          $show_stopper = 1 ;
          }
	# check if gloss exists
	if ($column eq '') {
	  push(@messages, "no gloss, line $lines");
	  $show_stopper = 1 ;
	}
      }
      if ($i == $headerindex{'reflex'}) {
	# do reflex tests
	# check if reflex exists
	    if ($column eq '') {
	      push(@messages, "no reflex, line $lines");
	      $show_stopper = 1 ;
	}
        if ($columns[$i] =~ /[m]/) {
          push(@messages, "unusual entry in column 'reflex', line $lines");
          $show_stopper = 1;
        }
      }
      if ($i == $headerindex{'pos'}) {
	# do pos tests
	# it is OK if pos field is empty!
      }
      # check POS if present
    }
  }
  push(@messages, $lines . ' lines read, including header');
  $results{'status'}   = $show_stopper ? "Sorry, your file doesn't meet standards." : "File content OK!";
  $results{'messages'} = \@messages;
  seek($fh,0,0);
  return %results;
}

sub validateMetadata {
  my (%metadata) = @_;
  my @messages;
  my %results;
  my $lines;
  my $show_stopper = 0;
  foreach my $key (keys %metadata) {
    #check metadata elements
    print STDERR "$key:  $metadata{$key}\n";
    #$show_stopper = 1;
    $lines++;
  }
  push(@messages, $lines . ' parameters seen');
  $results{'status'}   = $show_stopper ? "Sorry, metadata insufficient." : "Metadata OK!";
  $results{'messages'} = \@messages;
  return %results;
}

my $file = shift @ARGV;
open(my $fh, "<:encoding(UTF-8)",$file) || die "no file given!\n";
 
my %results = validateContribution($fh);
print 'x' x 80;
print "\nchecking $file\n";
print 'x' x 80;
print "\nstatus: " . $results{'status'} . "\n";
foreach my $r (@{$results{'messages'}}) {
  print "$r\n";
}
