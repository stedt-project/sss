package STEDT::Table::Projects;
use base STEDT::Table;
use strict;

sub new {
my ($self, $dbh, $privs, $uid) = @_;
my $t = $self->SUPER::new($dbh, 'projects', 'projects.id', $privs); # dbh, table, key, privs

$t->query_from(q|projects LEFT JOIN users ON projects.creator = users.uid|);
$t->order_by('projects.project, projects.subproject', 'projects.create_date'); # default is the key

$t->fields(
	   'projects.id',
	   'projects.project',
	   'projects.subproject',
	   #'projects.queryety',
	   'projects.querylex',
	   'projects.creator',
	   'projects.tagger',
	   'projects.proofreader',
	   'projects.approver',
	   'projects.published',
	   'projects.create_date',
	   'projects.tag_date',
	   'projects.proofread_date',
	   'projects.approve_date',
	   'projects.publish_date',
	   q|IF(ambig_reflexes, CONCAT(ROUND(100 * tagged_reflexes/count_reflexes), ' - ', ROUND(100 * (tagged_reflexes+ambig_reflexes)/count_reflexes)), ROUND(100 * tagged_reflexes/count_reflexes)) AS pct|,
	   'projects.tagged_reflexes',
	   'projects.ambig_reflexes',
	   'projects.count_reflexes',
	   'projects.count_etyma',
	   'projects.status',
	   'projects.workflow',
	   'users.username',
);
$t->searchable(
	   'projects.project',
	   'projects.subproject',
	   'projects.querylex',
	   'projects.status',
);
$t->editable(
	     'projects.project',
	     'projects.subproject',
	     #'projects.queryety',
	     'projects.querylex',
	     'projects.status',
	     'projects.creator',
	     'projects.tagger',
	     'projects.proofreader',
	     'projects.approver',
	     'projects.published',
);

# Stuff for searching
$t->search_form_items(
	'projects.status' => sub {
		my $cgi = shift;
		# get list of statuses
		my $statuses = $dbh->selectall_arrayref("SELECT DISTINCT status FROM projects");
		return $cgi->popup_menu(-name => 'projects.status', -values=>['', map {@$_} @$statuses], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'projects.project' => sub {
		my $cgi = shift;
		# get list of projects
		my $projects = $dbh->selectall_arrayref("SELECT DISTINCT project FROM projects");
		return $cgi->popup_menu(-name => 'projects.project', -values=>['', map {@$_} @$projects], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'projects.subproject' => sub {
		my $cgi = shift;
		# get list of subprojects
		my $subprojects = $dbh->selectall_arrayref("SELECT DISTINCT subproject FROM projects");
		return $cgi->popup_menu(-name => 'projects.subproject', -values=>['', map {@$_} @$subprojects], -labels=>{'0'=>'(no value)'},  -default=>'');
	}
);

$t->save_hooks(
	       'project.creator' => sub {
		 my ($id, $value) = @_;
		 my $sth = $dbh->prepare(qq{UPDATE projects SET creator=? WHERE id=?});
		 $sth->execute($uid, $id);
	       },
);


$t->wheres(
	   'projects.project' => sub {my ($k,$v) = @_; "$k LIKE '$v\%'"},
	   'projects.subproject' => sub {my ($k,$v) = @_; "$k LIKE '$v\%'"},
	   'projects.querylex'	=> 'word',
	   'projects.status'   	=> 'word',
);


$t->addable(
	   'projects.project',
	   'projects.subproject',
	   #'projects.queryety',
	   'projects.querylex',
	   #'projects.creator',
);

$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "Project name not specified!\n" unless $cgi->param('projects.project');
	$err .= "Subproject name not specified!\n" unless $cgi->param('projects.subproject');
	$err .= "No lexicon glosses to search!\n" unless $cgi->param('projects.querylex');
	return $err;
});


$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);

return $t;
}

1;
