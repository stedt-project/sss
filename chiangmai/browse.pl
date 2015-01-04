#!/usr/bin/perl -w

use DBI;
use utf8;
use Encode qw/is_utf8 decode/;
use CGI qw/:standard/;
use CGI::Pretty qw( :html3 );
use CGI::Carp qw(fatalsToBrowser); #remove this later
$CGI::POST_MAX=1024 * 2;  # max 2K posts
$CGI::DISABLE_UPLOADS = 1;  # no uploads

use STEDTUtil;

# autoEscape(0);

my @fields ;
my $SearchLimit = 300;

sub setBrowse {
  my $item = shift;
  for ($item) {
    if    (/srcbib/)  {
      # select languagenames.srcabbr,count(*) from lexicon  join languagenames using (lgid) join srcbib using(srcabbr) group by srcabbr ;
      @fields = qw(count(*)  author  year  title imprint languagenames.srcabbr  citation );
      $from = " lexicon  join languagenames using (lgid) join srcbib using(srcabbr) group by srcabbr";
      return $from,@fields;

    }   
    elsif (/languagenames/)  {
      @fields = qw(count(*) language  languagenames.lgabbr languagenames.srcabbr languagegroups.grp lgsort srcofdata notes
		     pinotes  picode  lgcode  silcode lgid  grpid );
      $from = "lexicon join languagenames using (lgid)  join languagegroups using(grpid) group by lgid";
      return $from,@fields;
    } 
    elsif (/lexicon/)  {
      # select gloss,count(*) from lexicon group by gloss limit 100;
      #@fields = qw(count(*) lexicon.rn lexicon.analysis lexicon.reflex
      #	     lexicon.gloss languagenames.language languagegroups.grp
      #	     languagenames.srcabbr lexicon.srcid
      #	     lexicon.semcat COUNT(notes.noteid));
      @fields = qw(count(*) gloss);
      $from = " lexicon group by gloss";
      return $from,@fields;
    } 
    elsif (/languagegroups/)  {
      @fields = qw(count(*) grp  grpno  groupabbr  grpid  );
      $from = " lexicon join languagenames using (lgid) join languagegroups using(grpid) group by grpid";
      return $from,@fields;
    } 
    elsif (/chapters/)  {
      @fields = qw( semkey v f c chaptertitle semcat  );
      #$from = " chapters join lexicon using (semkey) group by semkey";
      $from = " chapters group by semkey order by v,f,c,s1,s2,s3";
      return $from,@fields;
    } 
    elsif (/otherchapters/)  {
      return @fields = qw( chapter heading semcat subcat cf n id);
      $from = " otherchapters order by chapter,subcat";
      return $from,@fields;
    } 
    else { 
      return ('no match' . $item);
    }  
  }
  
}


sub make_query_form {
  my $cgi = shift;
  my $dbh = shift;
  my $key = shift;
  my $header = shift;
  
  print $cgi->start_form(
			 {
			  #-enctype => 'multipart/form-data',
			  -method => 'GET'});

  print $cgi->start_table({-class=> "sortable resizable editable"});

  #print $cgi->start_form(-method => 'GET');
  #print $cgi->start_table(-border => '0');

  print $cgi->Tr($cgi->td({-align=>'center', -valign=>'middle'}, 
		 $cgi->submit("submit", "Search"),
		 $cgi->br($cgi->defaults( -value=>'Reset'))),
		 $cgi->td({-colspan=>20}, $cgi->h3("$header")));
}

sub make_update_form {
  my $cgi = shift;
  my $dbh = shift;
  my $key = shift;
  my $header = shift;
  
  my @fields = setBrowse($key);

  $table = shift @fields;

  $fields = join(', ',@fields);
  $fields =~ s/,$/ /;
  my $query = 'select ' . $fields . ' from ' . $table ;

  my @restrictions;
  foreach my $field (@fields) {
    if ($cgi->param($field)) {
      my $value = $cgi->param($field);
      my $restriction = $field . " LIKE '" . $value . "' ";
      #print "<br/>$restriction";
      push @restrictions, $restriction;
    }
  }
  
  if (scalar @restrictions > 0) {
    my $where .= " where " . join(" AND ",@restrictions);
    $where =~ s/AND $/ /;
    $query =~ s/group by/$where group by/i; # ack! hack!
  }
  
  # sort by a separate key if specified
  my $sortkey = $cgi->param('sortkey');
  if ($sortkey && $sortkey ne 'languagegroups.grp') { 
  	$query .= " ORDER BY $sortkey";
      }
  
  #print $query, $cgi->br();#return;

  my $sth = $dbh->prepare($query);
  $sth->execute();
  my $numrows = $sth->rows;
  
  # remember certain parameters
  print $cgi->hidden( -name => 'table',
		      -default => $cgi->param('table'));
  foreach my $field (@fields, 'sortkey', 'table', $key) {
    if ($cgi->param($field) && $cgi->param($field) ne '') {
      #print $cgi->hidden( -name => $field,
      #			  -default => $cgi->param($field));
    }
  }
  
  return unless ($numrows > 0);
  
  # implement our paging algorithm
  my $manual_paging = 1;
  if ($numrows > $SearchLimit) {
    my $n = $cgi->param('pagenum') + ($cgi->param('next') ? 1 : ($cgi->param('prev') ? -1 : 0));
    # dupe code, maybe stick this further up, before calling get_query?
    my $a = $n*$SearchLimit + 1;
    my $b = $a + $SearchLimit - 1;
    $b = $numrows if $numrows < $b;
    
    $cgi->param('pagenum', $n); # set it to the new, correct page number
    print $cgi->Tr($cgi->td({-colspan=>20},
			    $cgi->hidden('pagenum'),
			    ($n == 0 ? '' : $cgi->submit('prev', 'Previous Page')),
			    "Displaying items $a-$b of $numrows.",
			    ($numrows == $b ? '' : $cgi->submit('next', 'Next Page')), 
			    $cgi->submit('submit', 'Print')
			   ));
  }
  else {
    print $cgi->Tr($cgi->td({-colspan=>20}, "$numrows items found."));
  }

  print $cgi->param('sortkey') ? $cgi->hidden( -name => 'sortkey',
					     -default => $cgi->param('sortkey')) : '';

  # create links to be placed in <TH> for sorting
  my $fakeq = CGI->new;
  $fakeq->delete_all();
  foreach my $field ('table','command') {
    $fakeq->param($field, $cgi->param($field)) if ($cgi->param($field));
    #print "<br/>field ",$field,":",$cgi->param($field);
  }
  my @sortlinks;
  @values = @fields;
  for (0..(scalar @values - 1)) {
    $fakeq->param('sortkey',$fields[$_]);
    push @sortlinks, $fakeq->a({-href=>$fakeq->self_url},$values[$_]);
  }

  # use js sorting only if we're not paging
  # print $cgi->Tr({-valign => 'top'}, [$cgi->th(\@values)] );
  print $cgi->Tr({-valign => 'top'}, [$cgi->th(\@sortlinks)] );

  foreach my $field (@fields) {
    if ($field =~ /COUNT\(/i) {
      # do nothing
      print $cgi->td("");
    } else {
      print $cgi->td($cgi->textfield(-name => $field,
				     -size=>'10%'));
    }
  }
  
  my %results;
  @results{@fields} = ();
  # Map the columns from the query to the hash %results
  $sth->bind_columns(map { \$results{$_} } @fields);

  while ($sth->fetch()) {
    my $key = $results{$qdata->{'key'}};
    print "<tr valign='top' id='$key'>";
    for my $field (@fields) {
      if ($field eq 'lexicon.analysis' && $results{$field}) {
	my @f = split(",",$results{$field});
	my $analysis;
	foreach my $tag (@f) {
	  if ($tag =~ /^\d+$/) {
	    $analysis .= $cgi->a({-href=>"etyma.pl?submit=search&etyma.tag=$tag",-target=>'etyma_detail'},
				 $tag) . "+";
	  }
	  else {
	    $analysis .= $tag . "+";
	  }
	}
	$analysis =~ s/\+$//;
	print $cgi->td($analysis);
      } elsif ($field eq 'languagenames.srcabbr') {
	print $cgi->td($cgi->a({-href=>"rendersource.pl?submit=search&srcbib.srcabbr=$results{$field}"},
			       $results{$field}));
      } elsif ($field eq 'lexicon.semcat') {
	print $cgi->td($cgi->a({-href=>"tagger.pl?submit=search&lexicon.semcat=$results{$field}"},
			       $results{$field}));
      } elsif ($field eq 'COUNT(notes.noteid)') {
	my $n = $results{$field};
	print $cgi->td($cgi->a({-href=>"notes.pl?L=$key", -target=>'noteswindow'},
			       $n == 0 ? "" : "$results{$field} note" . ($n == 1 ? '' : 's')));
      } elsif ($field eq 'lexicon.rn') {
	print $cgi->td($results{$field});
      } else {
	print $cgi->td($cgi->escapeHTML($results{$field}));
	# you MUST escape the html entities!
	# the docs say escapeHTML turns everything into HTML entities if encoding is not latin, but that can't be right...
      }
    }
    # the delete checkbox
    #my $checkboxname = 'delete' . '_' . $key;
    #print $cgi->td($cgi->checkbox(-name => $checkboxname,
				 # -value => 'off',
				 # -label => ''));
  }
  print $cgi->end_table;
  print $cgi->end_form;
}

sub print_data {
    my $cgi = shift;
    my $dbh = shift;
    my %results;
    $SearchLimit = 2000;	# set this higher for printing
    my $query = get_query($cgi) or return;
				 
	my $sth = $dbh->prepare($query);
	$sth->execute();
	@results{@fields} = ();
	$sth->bind_columns(map { \$results{$_} } @fields);
	print $cgi->start_table;
	print $cgi->Tr({-valign => 'top'}, [$cgi->th(@fields)] );
	while ($sth->fetch()) {
	    my $key = $results{$qdata->{'key'}};
	    print "<tr valign='top'>";
	    for my $field (@fields) {
		if ($editable->{$field}) {
		    my $fieldname = $field . '_' . $key;
		    print $cgi->td($results{$field});
		} elsif ($field eq 'COUNT(notes.noteid)') {
			my $n = $results{$field};
			print $cgi->td("$results{$field} note" . ($n == 1 ? '' : 's'));
		} else {
		    print $cgi->td("$results{$field}");
	        }
	    }
	}
	print $cgi->end_table;
}

my $cgi = new CGI;
my $dbh = STEDTUtil::connectdb();

%browseable = ( 'srcbib' => 'Sources of Information', 'languagenames' => 'Language Names', 'languagegroups' => 'Language Groups',
	      'lexicon'=> 'Lexicon', 'chapters' => 'Chapters', 'otherchapters' => 'Sem Cats');

STEDTUtil::make_header($cgi,'Browse STEDT Database');

my $table = $cgi->param('table');
#print $p,' ',$cgi->param($p);
if ($browseable{$cgi->param('table')}) {
  make_query_form($cgi, $dbh, $table, $browseable{$table});
  make_update_form($cgi, $dbh, $table, $browseable{$table});
}

$dbh->disconnect;
STEDTUtil::make_footer($cgi);
