package STEDT::RootCanal::Contribution;
use strict;
use base 'STEDT::RootCanal::Base';
use utf8;

my @messages;
my $show_stopper = 0;
my @header; 
my %headerindex;

sub contribution : StartRunMode {
  # "contribution wizard" has 3 steps:
  # upload file - uses standard CGI file upload
  # metadata - if file validates, ask user for metadata
  # thanks - if metadata is ok, do the right thing with all the data, thank user
  # (file|metadata)failure - send user back a step if there is a problem.
  my $self = shift;
  $self->require_privs(8);
  my $step = $self->query->param('step');
  my $filename = $self->query->param('filename');
  my $file = $self->query->param('contribution');
  my $lgid;
  my $srcabbrsave;
  my $upload_dir = '/tmp';
  my $metadatafields = ['language', 'lgabbr', 'srcabbr', 'author', 'year', 'title', 'citation', 'contributor', 'email'];
  my %metadata;
  my %results;
  my @validation;
  if ($step eq 'thanks') {
    $srcabbrsave = $self->query->param('srcabbrsave');
    $lgid = $self->query->param('lgid');
    # ...but no thanks; if we are here, user must want to delete their data..
    $self->dbh->do("DELETE FROM lexicon WHERE lgid=?", undef, $lgid);
    $self->dbh->do("DELETE FROM srcbib WHERE srcabbr=?", undef, $srcabbrsave);
    $self->dbh->do("DELETE FROM languagenames WHERE lgid=?", undef, $lgid);
    $step = 'upload';
  }
  elsif ($step eq 'upload') {
    if ($file) {
      # upload file
      my $fh = $self->query->upload('contribution');
      $filename = $file;
      uploadFile($file,$fh,$upload_dir);
      # validate it
      %results = validateContribution($fh);
      @validation = @{$results{'messages'}};
      if ($results{'status'} =~ /Sorry/) {
	# oops try again!
	$step = 'filefailure';
      }
      else {
	# on to metadata!
	$step = 'metadata';
      }
    }
    else {
      # user did not give us a file. keep asking!
      $step = 'upload';
      $results{'status'} = 'No file provided!';
    }
  }
  elsif ($step eq 'metadata') {
    # process & validate metadata
    foreach my $element ($self->query->param) {
      next if $element =~ /^(btn|step)$/; # skip these
      $metadata{$element} = $self->query->param($element) if $self->query->param($element);
    }
    my @m;
    foreach my $f (@$metadatafields) {
      if ($metadata{$f}) {
	push @m,$metadata{$f};
	print STDERR "$f:  $metadata{$f}\n";
      }
      else {
	push @m,'';
	print STDERR "$f:  empty\n";
      }
    }
    push @m,$metadata{'grpid'};
    # check metadata
    %results = validateMetadata(\%metadata,$metadatafields);
    @validation = @{$results{'messages'}};
    if ($results{'status'} =~ /Sorry/) {
      # oops try again!
      $step = 'metadatafailure';
    }
    else {
      # load to database
      %results = load2db($filename,$self->dbh,$upload_dir,@m);
      $lgid = $results{'language id'};
      $srcabbrsave = $results{'source abbr'};
      @validation = @{$results{'messages'}};
      $step = 'thanks';
    }
  }
  else {
    # $step not set, must be first pass through: set current step to upload.
    $step = 'upload';
  }

  foreach my $v (@validation) {
    print STDERR "contribution INFO:  $v\n";
  }

 my $grpids = $self->dbh->selectall_arrayref("SELECT grpid,grpno,grp FROM languagegroups ORDER BY grp0,grp1,grp2,grp3,grp4 LIMIT 200");

  return $self->tt_process("admin/contribution.tt", {
		step=>$step,
		filename=>$filename,
		file=>$file,				     
		lgid=>$lgid,			     
		srcabbrsave=>$srcabbrsave,
		grpids=>$grpids,
		messages=>$results{'status'},
		provided=>\%metadata,
		validation=>\@validation,
		metadata=> $metadatafields
		});
		
}

sub uploadFile {
  my ($file,$fh,$upload_dir) = @_;

  open (UPLOADFILE, ">$upload_dir/$file") or die "$!";
  binmode UPLOADFILE;
  
  while ( <$fh> )
    {
      print UPLOADFILE;
    } 
  close UPLOADFILE;
  seek($fh,0,0);
}

sub getheader {
      $_ = shift;
      @header = split "\t";
      for (my $i = 0; $i < scalar @header; $i++) {
        if ($header[$i] !~ /\b(gloss|reflex|pos|id)\b/) {
	  # $show_stopper = 1;
	  push(@messages, $header[$i]. ': this header value is not used; column will be ignored.');
	}
	else {
	  push(@messages, $header[$i]. " header column found: $i");
	}
        $headerindex{$header[$i]} = $i;
      }
}

sub validateMetadata {
  my $metaref = shift;
  my %metadata = %{$metaref};
  my @metatadatafields = shift;
  foreach my $f (keys %metadata) {
	print STDERR "$f:  $metadata{$f}\n";
  }
  my @m;
  my %results;
  my @messages;
    push(@messages, ' everything is fine for now');
  my $show_stopper = 1;
  $results{'status'}   = $show_stopper ? "Metadata OK!" : "Sorry, your metadata has some problems." ;
  $results{'messages'} = \@messages;
  $results{'metadata'} = \@m;
  return %results;
  }

sub validateContribution {
  my $fh = shift;
  my %results;
  my $lines;
  my $header_length;
  my $row_length;
  my $problems = 0;
  while ( <$fh> ) {
    s/\r//g;
    chomp;
    $lines++;
    # check header
    if ($lines == 1) {
      getheader($_);
    }
    # So in the case of the test files, $headerindex{'gloss'} is 1.
    # Now you can test the columns in the rest of the file:
    
    # check for missing values
    my @columns = split "\t";
    for (my $i = 0; $i < scalar @header; $i++) {
      my $column = $columns[$i];
      if ($i == $headerindex{'gloss'}) {
        #print "@columns[$i]\n";
	# do gloss tests 
	# check well-formedness of gloss --- right now, checks for non-word characters in gloss; perhaps can be refined later
        if ($columns[$i] =~ /[^\w\s;\,\(\)\.\'\"\/\-\!\:\[\]\?]/) {
          push(@messages, "unusual character(s) in column 'gloss' <i>$columns[$i]</i>, line $lines");
          $show_stopper = 1 ;
	  $problems++;
          }
	# check if gloss exists
	if ($column eq '') {
	  push(@messages, "no gloss, line $lines");
	  $show_stopper = 1 ;
	  $problems++;
	}
      }
      if ($i == $headerindex{'reflex'}) {
	# do reflex tests
	# check if reflex exists
	    if ($column eq '') {
	      push(@messages, "no reflex, line $lines");
	      $show_stopper = 1 ;
	      $problems++;
	}
        if ($columns[$i] =~ /[";.\?]/) {
          push(@messages, "unusual characters in column 'reflex' ($columns[$i]), line $lines");
          $show_stopper = 1;
	  $problems++;
        }
      }
      if ($i == $headerindex{'pos'}) {
	# do part-of-speech tests
	# it is OK if pos field is empty!
      }
      if ($i == $headerindex{'id'}) {
	# check ID
	# it is OK if ID field is empty!
      }
    }
  }
  push(@messages, $lines . ' lines read, including header. ' . $problems . ' problems identified.');
  $results{'status'}   = $show_stopper ? "Sorry, your file doesn't meet standards." : "File content OK!";
  $results{'messages'} = \@messages;
  seek($fh,0,0);
  return %results;
}

sub load2db {
  my ($file,$dbh,$upload_dir,@m) = @_;
  
  #print STDERR 'file', $file;

  open (INPUTFILE, "<:encoding(UTF-8)", "$upload_dir/$file" ) or die "$!";
  binmode INPUTFILE;

  my %results;
  my $lines;
  my $header_length;
  my $row_length;
  my @messages;
  # create new language names and source bib records
  my $lgsort = $m[0];
  $lgsort =~ tr/a-z/A-Z/;
  $lgsort =~ s/ //g;
  my $srcabbrExists = $dbh->selectrow_array("SELECT COUNT(*) FROM srcbib WHERE srcabbr=?", undef, $m[2]);
  if ($srcabbrExists) {
    push(@messages, '<span style="color:red">The srcabbr "' . $m[2] . '" already exists! Undo if this is not what you want!</span>');
  }
  else {
    $dbh->do("INSERT srcbib (srcabbr, author, year, title, citation) values (?,?,?,?,?)", undef, $m[2],$m[3],$m[4],$m[5],$m[6]);
  }
  # find the lgcode value, if one exists. if not, make one up.
  my $lgcode;
  $lgcode= $dbh->selectrow_array("SELECT lgcode FROM languagenames WHERE lgsort=?", undef, $lgsort);
  unless ($lgcode) {
     $lgcode = $dbh->selectrow_array("select max(lgcode) from languagenames");
     $lgcode += 1;
  }
  print STDERR 'lgcode: ' . $lgcode . ' lgsort: ' . $lgsort . ' grpid: ' . $m[9];
  $dbh->do("INSERT languagenames (language, lgabbr, lgsort, srcabbr, lgcode, grpid) values (?,?,?,?,?,?)", undef, $m[0],$m[1],$lgsort,$m[2],$lgcode, $m[9]);
  my $lgid = $dbh->selectrow_array("SELECT LAST_INSERT_ID();");
  while (<INPUTFILE> ) {
    s/\r//g;
    chomp;
    $lines++;
    # check header
    if ($lines == 1) {
      getheader($_);
      next;
    }
    my @columns = split "\t";
    my $gloss  = @columns[ $headerindex{'gloss'} ];
    my $reflex = @columns[ $headerindex{'reflex'} ];
    my $srcid  = @columns[ $headerindex{'id'} ] || '';
    my $pos    = @columns[ $headerindex{'pos'} ] || '';
    my $semkey = '';
    $dbh->do("INSERT lexicon (reflex, gloss, gfn, lgid, semkey, srcid) values (?,?,?,?,?,?)", undef, $reflex,$gloss,$pos,$lgid,$semkey,$srcid);
    #print STDERR "$lines lines read :: $reflex,$gloss,$pos,$lgid,$semkey,$srcid\n";
  }
  push(@messages, $lines-1 . ' lines loaded');
  #print STDERR  $lines-1 . ' lines loaded';
  $results{'status'} = "name of file is: $file";
  $results{'language id'} = $lgid;
  $results{'source abbr'} = $m[2];
  $results{'messages'} = \@messages;
  return %results;
}

1;