#!/usr/bin/perl -wT
# edited by dwbruhn to use protected pm, 2010-December-07

use strict;
use DBI;
use CGI;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser set_message/;
BEGIN {
        $^W = 1;
        unshift @INC, "../pm" if -e "../pm";
        CGI::Carp::set_message("Report bugs/features to stedt@socrates.berkeley.edu");
}
use STEDTUtil;

# CONSTANTS
######################################################################
# Both @fields and $names must be edited when the set of fields in the
# interface changes.

# A list of database fields ordered by their sequence in the UI
my @fields = (
			  'languagegroups.grpno',
			  'languagegroups.grp',
			  'languagegroups.ord',
			  'languagegroups.grpid',
			  'languagegroups.groupabbr',
);
# A hash-reference consisting of database field names
# related to the names used in the user interface.
my $names = {
	     'languagegroups.grpno'   => 'Num',
		 'languagegroups.groupabbr'=> 'Abbr',
		 'languagegroups.grp'     => 'Group',
		 'languagegroups.grpid'   => 'id',
		 'languagegroups.ord'     => 'ord'
};
# A list of UI names in order.
my @values = map {$names->{$_}} @fields;

# A list of UI names in order.
my @labels = map {$names->{$_}} @fields;

# A hash-reference designating the fields which are editable.
my $editable = {
		 'languagegroups.ord' => 1,
		 };
# Query strings
my $qdata = {
	     'from' => q|languagegroups|,
	     'where' => '',
	     'order' => 'languagegroups.grpno',
	     'table' => 'languagegroups',
	     'key' => 'languagegroups.grpid',
};

######################################################################
# DATABASE CONNECTIVITY
######################################################################

# Returns an SQL query based on the parameters passed to the script.
sub get_query {
  my $cgi = shift;
  my $flds = join(', ', @fields);
  my $from = $qdata->{'from'};
  my $order = $qdata->{'order'};
  return "SELECT $flds FROM $from ORDER BY $order";
}

# Save the data in the update form (regardless of whether it has
# changed or not)
sub save_data {
  my $cgi = shift;
  my @params = $cgi->param;
  my $dbh = STEDTUtil::connectdb();
  # Iterate over parameters
  foreach my $param (@params) {
    # Find the parameters that have a numeric suffix
    if ($param =~ m/(.+)_([0-9]+)/) {
      # Assume that the first part of the parameter is a field name
      # and that the suffix is a record number
      my ($field, $id) = ($1, $2);
      # Only allow things to change if the field is designated as
      # editable.
      if ($editable->{$field}) {
		my $value = $cgi->param($param);
		# SQL and handle for updating records in lexicon
		my $update = qq{UPDATE languagegroups SET $field=? WHERE grpid=?};
		my $update_sth = $dbh->prepare($update);
		$update_sth->execute($value, $id);
      }
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
# HTML GENERATION
######################################################################

sub make_header {
  my $stylesheet = 'styles/tagger.css';
  my $cgi = shift;
  print $cgi->header(-charset => "utf8");
  print $cgi->start_html(-head =>
			 $cgi->meta( 
				    {-http_equiv => 'Content-Type', 
				     -content => 'text/html; charset=utf8'}),
			 -encoding => 'utf-8',
			 -title=>'Edit Language Groups', 
			 -style=>{'src'=>$stylesheet},
			 -script=>[
					{ -type     => "text/javascript",
					  -src      => 'scriptaculous/lib/prototype.js'
					},
					{ -type     => "text/javascript",
					  -src      => 'fastinit.js'
					},
					{ -type     => "text/javascript",
					  -src      => 'tablekit.js'
					},
				 ]
	);
}

sub make_footer {
  my $cgi = shift;
  print $cgi->end_html;
}

sub make_update_form {
	my $cgi = shift;
	my $dbh = shift;

    my $query = get_query($cgi) or return;
  
	# now for the results/update table
	
    print $cgi->start_form(
			   {-enctype => 'multipart/form-data',
			    -method => 'POST'});
	
    my $sth = $dbh->prepare($query);
    $sth->execute();
 my %results;
    @results{@fields} = ();
    # Map the columns from the query to the hash %results
    $sth->bind_columns(map { \$results{$_} } @fields);

	print $cgi->start_table({-class=>"sortable resizable editable"});
    # print $cgi->Tr({-valign => 'top'}, [$cgi->th(\@values)] );
	print $cgi->thead($cgi->Tr({-valign => 'top'},
		(map {$cgi->th(
				($_ eq $qdata->{'key'} || $_ eq 'COUNT(notes.noteid)' || $editable->{$_} || $_ eq 'languagenames.srcabbr'
					? {-class=>'noedit'}
					: {-id=>$_}),
				$names->{$_}
			)} @fields),
		$cgi->th({-class=>'noedit'},'Delete'),
	));
	
	
    while ($sth->fetch()) {
      my $key = $results{$qdata->{'key'}};
      print "<tr valign='top' id='$key'>";

	  my $indent_level = 0;
      for my $field (@fields) {
	if ($editable->{$field}) {
	  my $fieldname = $field . '_' . $key;
	  print $cgi->td(
	  			$cgi->textfield(
					 -name => $fieldname,
					 -value => $results{$field},	# (escaping is automatically done for forms)
					 -size => 3
	                )
	  	);
	} else {
	  my $str = $cgi->escapeHTML($results{$field});
	  if ($field eq 'languagegroups.grpno') {
	  	$str =~ s/\.0//g;
	  	$indent_level = $str =~ tr/.//;
	  }
	  if ($field eq 'languagegroups.grpno' || $field eq 'languagegroups.grp') {
		  $str = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' . $str foreach 0..$indent_level;
	  }
	  print $cgi->td($str);
	  # you MUST escape the html entities!
	  # the docs say escapeHTML turns everything into HTML entities if encoding is not latin, but that can't be right...
	}
      }
      # the delete checkbox
      my $checkboxname = 'delete' . '_' . $key;
	  print $cgi->td($cgi->checkbox(-name => $checkboxname,
					  -value => 'off',
					 -label => ''));
      print "</tr>";
    }
    print $cgi->tfoot(
    	$cgi->Tr($cgi->td($cgi->submit('submit', 'Save All')),
    			$cgi->td($cgi->reset)),
		$cgi->Tr($cgi->td($cgi->submit(-name=>'submit', -value=>'Delete Selected',-onClick=>"if (confirm('Are you sure you want to delete this record?')) return true; else return false;")))
	);
	print $cgi->end_table;
    print $cgi->end_form;
	my $url = $cgi->url(-absolute=>1);
	print <<EOF;
<script type="text/javascript">
	TableKit.options.editAjaxURI = '$url';
</script>
EOF
}

sub print_data {
    my $cgi = shift;
    my $dbh = shift;
    my %results;
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
	    print "</tr>";
	}
	print $cgi->end_table;
}


my $cgi = new CGI;
my $dbh = STEDTUtil::connectdb();
if ($cgi->param('row')) {	# for TableKit AJAX magic
	print $cgi->header(-charset => "utf8");
	my ($field, $id, $value) = ($cgi->param('field'), $cgi->param('id'), $cgi->param('value'));
	my $table = $qdata->{'table'};
	my $key = $qdata->{'key'};
	my $update = qq{UPDATE $table SET $field=? WHERE $key=?};
	my $update_sth = $dbh->prepare($update);
	$update_sth->execute($value, $id);
	print $value;	## transmogrify if necessary
} else {
	make_header($cgi);
	
	if ($cgi->param('submit') eq 'Save All') {
		save_data($cgi, $dbh);
	} elsif ($cgi->param('submit') eq 'Delete Selected') {
		save_data($cgi, $dbh);
		delete_data($cgi, $dbh);
	} elsif ($cgi->param('submit') eq 'Print') {
		print_data($cgi, $dbh);
	}

	make_update_form($cgi, $dbh) unless $cgi->param('submit') eq 'Print';###
	make_footer($cgi);
}

$dbh->disconnect;
