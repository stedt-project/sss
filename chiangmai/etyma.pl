#!/usr/bin/perl -w

  ######################################################################
  # S T E D T Project
  ######################################################################
  # This CGI script generates and presents the "nav bar"
  # for the public interface.
  #
  # It also includes the search UI for etyma, which is part of the
  # nav bar at the moment.
  #
  # copyright 1999-2010 The Regents of the University of California

use strict;
use utf8;   
use DBI;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;

use STEDTUtil;

my $SearchLimit;
my @fields;
my $names;
my @labels;
my $fmt;
my $qdata;
my $jscript;
my $sizes;

my $cgi = new CGI;
my $dbh = STEDTUtil::connectdb();

sub constants {

  # CONSTANTS
  ######################################################################
  # Both @fields and $names must be edited when the set of fields in the
  # interface changes.
  
  $SearchLimit = 200;
  
  # A hash-reference consisting of database field names
  # related to the names used in the user interface.
  $names = {
	       'etyma.tag' => 'TagNum',
	       'etyma.protoform' => 'Protoform',
	       'etyma.protogloss' => 'Protogloss',
	       'etyma.chapter' => 'Chapter',
	       'languagegroups.plg' => 'Protolanguage',
	       'COUNT(lx_et_hash.rn)' => 'Reflexes',
	      };
  
  # A list of database fields ordered by their sequence in the UI
  @fields = ('etyma.tag', 'languagegroups.plg', 'etyma.protoform', 'etyma.protogloss', 'etyma.chapter','COUNT(lx_et_hash.rn)'
	       );
  
  # A list of UI names in order.
  @labels = map {$names->{$_}} @fields;
  
  # A hash-reference designating some formatting for each field.
  $fmt = {
	     'etyma.protoform' => 'b',
	     'etyma.protogloss' => 'i',
	     'etyma.chapter' => 'tt',
	     'languagegroups.plg' => 'tt',
	     'etyma.tag' => '',
	    };
  #lx_et_hash.rn=lexicon.rn AND 
  # Query strings
  $qdata = {
	       # for the searching
	       'from' => q|etyma JOIN languagegroups using (grpid) LEFT JOIN lx_et_hash ON (lx_et_hash.tag=etyma.tag) LEFT JOIN notes ON (notes.spec = 'E' AND notes.id = etyma.tag)|,
	       'order' => 'etyma.chapter, etyma.protoform, etyma.protogloss',
	       'table' => 'etyma', # used for saving/deleting and counting
	       'key' => 'etyma.tag',
	      };
  
  # Table widths, only needed for editable and/or searchable textfields
  $sizes = {
	       'etyma.tag' => '10',
	       'etyma.protoform' => '10',
	       'etyma.protogloss' => '10',
	       'etyma.chapter' => '10',
	       'etyma.plg' => '10',
	      };
  
  
  $jscript = <<EndOfJavaScript;
function newwindow(url)
{
    window.open(url,'Etymon','width=800,height=600,resizable=yes,scrollbars=yes');
}
EndOfJavaScript
  
}
######################################################################
# DATABASE STUFF
######################################################################

# Returns an SQL query based on the parameters passed to the script.
# returns nothing if user didn't search for anything
sub get_query {
  my $cgi = shift;
  my $where = query_where($cgi) or return;
  
  my $flds = join(', ', @fields);
  my $from = $qdata->{'from'};
  my $order = $qdata->{'order'};
  my $limita = ($cgi->param('pagenum') + ($cgi->param('next') ? 1 : ($cgi->param('prev') ? -1 : 0))) * $SearchLimit;
  return
  	"SELECT $flds FROM $from WHERE $where GROUP BY etyma.tag,$order " .
  	"ORDER BY $order LIMIT $limita, $SearchLimit";
  	# should be group by etyma.tag, but this way we show for duplicate tags
}

# returns the WHERE clause for an sql query
# returns empty if user didn't search for anything
sub query_where {
  my $cgi = shift;
  my @wheres;
  my $query_ok = 0;	# will be set to 1 if the user searched for something

  foreach my $key ($cgi->param) {
    if ($names->{$key} and $cgi->param($key) ne '') {
      $query_ok = 1;
      my $val = $cgi->param($key);
      $val =~ s/'/''/g;	# security, don't let people put weird sql in here!
      my $restriction;
      if ($key eq 'etyma.tag') {
      	$restriction = $key . '=' . $val; ### why is tag a float?
      } elsif ($key eq 'etyma.plg') {
      	$val = '' if $val eq '0';
      	$restriction = $key . "='" . $val . "'";
      } elsif ($key eq 'etyma.chapter') {
		$restriction = $key . " LIKE '" . $val . "%' ";
      } else {
        $restriction = $key . " RLIKE '" . $val . "' ";
      }
      push(@wheres, $restriction);
    }
  }
  return $query_ok ? join(' AND ', @wheres) : '';
}

# Save the data in the update form (regardless of whether it has
# changed or not)
sub save_data {
  my $cgi = shift;
  my $dbh = shift;
  my @params = $cgi->param;

  foreach my $param (@params) {
    if ($param =~ m/(.+)_([0-9]+)/) {
      my ($field, $id) = ($1, $2);
      my $value = $cgi->param($param);
      
      # SQL and handle for updating records in etyma table
      my $table = $qdata->{'table'};
      my $key = $qdata->{'key'};
      my $update = qq{UPDATE $table SET $field=? WHERE $key=?};
      my $update_sth = $dbh->prepare($update);
      $update_sth->execute($value, $id);
    }
  }
}

sub delete_data {
  my $cgi = shift;
  my $dbh = shift;
  my @params = $cgi->param;

  foreach my $param (@params) {
    if ($param =~ m/^delete_([0-9]+)/) {
      my $id = $1;
      my $table = $qdata->{'table'};
      my $key = $qdata->{'key'};
      my $delete = qq{DELETE FROM $table WHERE $key=$id};
      my $delete_sth = $dbh->prepare($delete);
      $delete_sth->execute();
    }
  }
}

######################################################################
# HTML GENERATION SUBS
######################################################################
  
sub make_browse {
  my $cgi = shift;

  print $cgi->start_table({-border=>'0', -cellpadding=>'2', -width=>'100%'}),$cgi->Tr($cgi->td({-width=>'40'},
      $cgi->img({-src=>'http://stedt.berkeley.edu/images/STB32x32.gif',-align=>'LEFT'})),
      $cgi->td($cgi->b('STEDT Database Online'))),       
      #$cgi->b('Electronic dissemination of Etymologies')),
      $cgi->Tr($cgi->td({-colspan=>2, -align=>'center'},$cgi->font({-size=>'-2'}, 'v0.9 1 Nov 2009 (updated 11 Sep 2012 jbl)',$cgi->br,'Lowe, Mortensen, Yu'))),
      $cgi->Tr($cgi->td({-colspan=>2},$cgi->a({-href=>"overview.pl", -target=>"reflexes"},'Overview'))),
      $cgi->Tr($cgi->td({-colspan=>2},$cgi->a({-href=>"instructions.html", -target=>"reflexes"},'Instructions'))),
      $cgi->Tr($cgi->td({-colspan=>2},$cgi->a({-href=>"tagger.pl?format=Print", -target=>"_new"},'Tagging worksheet'))),
      $cgi->Tr($cgi->td({-colspan=>2},'&nbsp;')),
      $cgi->Tr($cgi->td({-colspan=>2},$cgi->i('Searchable elements'))),

      $cgi->Tr($cgi->td({-colspan=>2},$cgi->a({-href=>"etyma.pl?command=search"},'Etyma'))),
      $cgi->Tr($cgi->td({-colspan=>2},$cgi->a({-href=>"tagger.pl", -target=>"reflexes"},'Lexicon'))),
      $cgi->Tr($cgi->td({-colspan=>2},$cgi->a({-href=>"browse.pl?command=browse&table=srcbib", -target=>"reflexes"},'Sources'))),
      $cgi->Tr($cgi->td({-colspan=>2},$cgi->a({-href=>"browse.pl?command=browse&table=languagenames", -target=>"reflexes"},'Languages'))),
      $cgi->Tr($cgi->td({-colspan=>2},$cgi->a({-href=>"browse.pl?command=browse&table=languagegroups", -target=>"reflexes"},'Language Groups'))),
      $cgi->Tr($cgi->td({-colspan=>2},$cgi->a({-href=>"browse.pl?command=browse&table=otherchapters", -target=>"reflexes"},'Sem Cats'))),
      $cgi->Tr($cgi->td({-colspan=>2},$cgi->a({-href=>"browse.pl?command=browse&table=chapters", -target=>"reflexes"},'Chapters'))),
    $cgi->end_table,"\n";
}

sub make_query_form {
  my ($cgi, $dbh, $table) = @_;


  my %browseable = ( 'srcbib' => 'Sources of Information', 'etyma' => 'Etyma (Reconstructions)',
		   'semcat' => 'Semantic Grid', 
		   'languagenames' => 'Language Names', 'languagegroups' => 'Language Groups',
		   'lexicon'=> 'Lexicon (lexical entries)');
  
  
  $cgi->delete_all() if $cgi->param('reset');# eq 'Reset';
  
  print $cgi->start_form(-method => 'GET');
  print $cgi->start_table({-border => '0', -width=>"100%"});
  print $cgi->Tr($cgi->td({-colspan=>2},"<h2>$browseable{$table}</h2>"));

  # get list of proto-lgs
  my $plgs = $dbh->selectall_arrayref("SELECT DISTINCT plg FROM languagegroups");
  if ($plgs->[0][0] eq '') {
  	# indexes 0,0 relies on sorted list of plgs.
  	# allow explicit searching for empty strings
  	$plgs->[0][0] = '0';
  }
  foreach my $field (@fields) {
      print
        $cgi->Tr(
        (
        $cgi->td($cgi->b($names->{$field}))
        ,
        $cgi->td($cgi->textfield(-name => $field, -size => $sizes->{$field}))
        ))
    	unless $field =~ /^COUNT/;
  }
  print "</tr>";
  print $cgi->Tr({-valign => 'top'}, $cgi->td({-colspan => 2},
        $cgi->submit("submit", "Search"),$cgi->submit('reset', 'Clear')));
  print $cgi->end_table;
  print $cgi->end_form;
}

sub make_update_form {
  my $cgi = shift;
  my $dbh = shift;
  my %results;
  my $query = get_query($cgi) or return;
  
  
  # print $query;
  
  my $sth = $dbh->prepare($query);
  $sth->execute();
  
  my $where = query_where($cgi);
  my $numrows = $sth->rows;
  
  if ($numrows > 0) {
    # separate form for printing, target in new window
    print $cgi->start_form({-target=>'stedtprint'}, -method => 'POST');
  }
  #print "$numrows found.<br>" ; # print "(WHERE $where)";
  if ($numrows > 0) {
    #	foreach my $field (@fields) {
    #		if ($cgi->param($field)) {
    #			print $cgi->hidden($field);
    #		}
    #	}
    #	print $cgi->submit('submit', 'Print');
    print $cgi->end_form;
  } else {
    return;
  }
  
  
  @results{@fields} = ();
  $sth->bind_columns(map { \$results{$_} } @fields);
  print $cgi->start_form(
			 {-enctype => 'multipart/form-data',
			  -method => 'POST'});
  foreach my $field (@fields) {	# this saves state for the search form inside the edit form
    if ($cgi->param($field)) {
      print $cgi->hidden( -name => $field, 
			  -default => $cgi->param($field));
    }
  }
  
  #if ($numrows > $SearchLimit) {
  my $n = $cgi->param('pagenum') + ($cgi->param('next') ? 1 : ($cgi->param('prev') ? -1 : 0));
			# dupe code, maybe stick this further up, before calling get_query?
  my $a = $n*$SearchLimit + 1;
  my $b = $a + $SearchLimit - 1;
  $b = $numrows if $numrows < $b;
  
  $cgi->param('pagenum', $n); # set it to the new, correct page number
  print $cgi->hidden('pagenum');
  print $cgi->submit('prev', 'Previous') unless $n == 0;
  print $cgi->hr;
  print " Items $a-$b of $numrows. ";
  print $cgi->submit('next', 'Next') unless $numrows == $b;
  print $cgi->hr;
  #}
  
  print $cgi->start_table;
  print $cgi->Tr($cgi->th('Tag'),$cgi->th('Count'),$cgi->th('Etymon & Gloss'));
  #unshift @labels, 'Select';
  #print $cgi->Tr({-valign => 'top'}, [$cgi->th(\@labels)] );
  my $counter = 0;
  while ($sth->fetch()) {
    last if ($counter++ > $SearchLimit);
    my $key = $results{$qdata->{'key'}};
    my $numresults = $results{'COUNT(lx_et_hash.rn)'};
    print "<tr valign='top'><td>";
    for my $field (@fields) {
      my $fieldname = $field . '_' . $key;
      my $fmtstart = $fmt->{$field} ? '<' .  $fmt->{$field} . '>' : '';
      my $fmtend   = $fmt->{$field} ? '</' . $fmt->{$field} . '>' : '';
      if ($field eq 'etyma.tag') {
	if ($numresults > 0) {
	  print $cgi->a({-href=>"tagger.pl?submit=Search+Lexicon&lexicon.analysis=$key",
			 -target=>'reflexes'},
			$fmtstart . $cgi->escapeHTML("$results{$field}") . $fmtend) . ' ' .
			  '</td><td>' . $cgi->a({-href=>"etymology.pl?tag=$key",
						 -target=>'reflexes'}, 
						"$numresults") .
						  '</td><td>';
	}
	else {
	  print $fmtstart . $cgi->escapeHTML("$results{$field}") . $fmtend . ' ' .
	    '</td><td>' . 'none ' . '</td><td>';
	}
      }
      else {
	if ($field ne 'COUNT(lx_et_hash.rn)') {
	  print $fmtstart . $cgi->escapeHTML("$results{$field}") . $fmtend . '&nbsp;';
	}
      }   
    }
    print "</td></tr>";
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
  print $cgi->Tr({-valign => 'top'}, [$cgi->th(\@labels)] );
  while ($sth->fetch()) {
    my $key = $results{$qdata->{'key'}};
    print "<tr valign='top'>";
    for my $field (@fields) {
      if ($field eq 'COUNT(notes.noteid)') {
	my $n = $results{$field};
	print $cgi->td("$results{$field} note" . ($n == 1 ? '' : 's'));
      } else {
	my $fieldname = $field . '_' . $key;
	print $cgi->td($results{$field});
      }
    }
    print "</tr>";
  }
  print $cgi->end_table;
}
  
sub browseDB {

    my ($cgi,$dbh,$fields,$query,$tbl) = @_;

#    my $fields = 'protoform,protogloss,tag';
#    my $query  = "protogloss = 'foot'";
    
    my $sql = "select $fields from $tbl where $query limit 1,10;";
    
    print "$sql\n\n";
    
    my $set_names = qq{SET NAMES 'utf8';};
    $dbh->do($set_names);
    
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    
#my ($etymon,$protogloss);
#$sth->bind_columns( undef, \$etymon,\$protogloss);
    
#    my ($analysis, $reflex, $gloss, $gfn, $language, $grp, $srcabbr, $srcid);
#    $sth->bind_columns( undef, \$analysis, \$reflex, \$gloss, \$gfn, \$language, \$grp, \$srcabbr, \$srcid );
    
    my $tablehead = "<table border=1>\n<thead>\n<tr>\n";
    foreach (split ',',$fields) {
	$tablehead .= "<th class=\"$_\">$_</th>";
    }
    $tablehead .= "</tr>\n</thead>\n<tbody>\n";
    print $tablehead;
    
    while (my @row = $sth->fetchrow_array()) {
	#next if ($reflex eq '' or $reflex eq '*');
	#$analysis = process_analysis($analysis);
	print "<tr><td>" . join("<td>",@row) . "\n";
    }
    
    print "</tbody>\n</table>\n";
    
}

######################################################################
# MAIN LINE CODE
######################################################################

constants();
STEDTUtil::make_header($cgi,'STEDT Database Navigation');
make_browse($cgi);

if ($cgi->param('submit') || $cgi->param('next') || $cgi->param('prev') || $cgi->param('command') ) {
  if ($cgi->param('submit') eq 'Save All') {
    #save_data($cgi, $dbh);
    #} elsif ($cgi->param('submit') eq 'Delete Selected') {
    #  delete_data($cgi, $dbh);
  } elsif ($cgi->param('submit') eq 'Print') {
    print_data($cgi, $dbh);
  } elsif ($cgi->param('command') eq 'browse') {
    print_data($cgi, $dbh);
  } elsif ($cgi->param('command') eq 'search') {
    make_query_form($cgi, $dbh,$cgi->param('table')) unless $cgi->param('submit') eq 'Print';###
    make_update_form($cgi, $dbh) unless $cgi->param('submit') eq 'Print';###
  } else {
    make_update_form($cgi, $dbh) unless $cgi->param('submit') eq 'Print';###
  }
}

$dbh->disconnect;
STEDTUtil::make_footer($cgi);
