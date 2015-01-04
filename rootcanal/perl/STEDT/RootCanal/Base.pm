package STEDT::RootCanal::Base;
use strict;
use base 'CGI::Application';
use CGI::Application::Plugin::TT;
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::AutoRunmode;
use CGI::Application::Plugin::DBH qw/dbh_config dbh/;
use CGI::Application::Plugin::ConfigAuto qw/cfg/;

sub dummy : StartRunMode {'This space intentionally left blank.'} # do nothing instead of generating an error

# This is the base class for different STEDT::RootCanal modules.
# It handles
# (1) connecting to the database
# (2) checking if the user has/hasn't logged in.

# In addition to modules used directly in this file
# (Session, AutoRunmode, ConfigAuto, DBH),
# we also load various perl modules (TT, ValidateRM)
# which our subclasses will use.

# If the user has authenticated, we retrieve the user id and save it to
# $self->param('uid'), and the username to $self->param('user'),
# so that our subclasses/template files can read them easily.

sub cgiapp_init {
	my $self = shift;
	
	# read our login info from the config file
	# then set up a database connection
	$self->dbh_config("dbi:mysql:database=stedt", $self->cfg('login'), $self->cfg('pass'),
		{RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1 });

	# set the database connection to use unicode, or you'll be sorry
	$self->dbh->do("SET NAMES 'utf8';");
	
	# this tells CGI::App to set the HTTP headers correctly
	$self->header_props(-charset => 'UTF-8');

	# this tells perl to expect everything passed to it to be utf8
	binmode STDOUT, ':utf8';
	# there's no point doing this for STDIN because CGI receives %-encoded strings. You need to do decode_utf8 on individual CGI params as necessary.

	# a rough test to see if we're running over SSL
	# if we are, send a different session id over the secure connection
	# for testing purposes, we can ignore presence of secure connection
	my $secure = $self->cfg('ignore_ssl') ? 1: ($self->query->cookie('stsec') ? 1 : 0);
	$self->param('https'=>$secure);

	# set up the session, telling it to use the above database connection
	# to store the session info.
	$self->session_config(
		CGI_SESSION_OPTIONS => ["driver:mysql",
								$self->query,
								{ Handle  => $self->dbh },
								$secure ? { name => 'CGISECID' } : undef],
		COOKIE_PARAMS => {	-name=> ($secure ? 'CGISECID' : CGI::Session->name),
							-secure => $self->cfg('ignore_ssl') ? 0 : $secure,
							-httponly => 1 }
	);
}

# check for authenticated user, every time
sub cgiapp_prerun {
	my $self = shift;
	my $uid = $self->session->param('uid');
	if (defined $uid) {
		$self->user_session_init($uid,
			$self->dbh->selectrow_array("SELECT username, privs FROM users WHERE uid=?", undef, $uid));
	}
	# additional cookie to test for a secure connection on the next HTTP request
	$self->header_add(-cookie=>
		[$self->query->cookie(-name=>'stsec',-value=>1,-secure=>$self->cfg('ignore_ssl') ? 0 : 1,-expires=>'+1y')]);
}

# save username, etc. for access by the template, etc.
sub user_session_init {
	my ($self, $uid, $username, $privs) = @_;
	$self->param(uid => $uid);
	$self->param(user => $username);
	$self->param(userprivs => $privs);

	# also set/reset session expiration
	$self->session->expire("1y");
}

# using C::A::P::AutoRunmode, we set this to be called in the event of an error
sub unable_to_comply : ErrorRunmode {
	my ($self, $err) = @_;
	$self->header_add(-status => 500) unless {$self->header_props()}->{'-status'}; # 500 server error
	return $err; # just the text, ma'am (it might show up in a javascript alert)
}

# helper method to load the relevant module
# optionally pass in a specific uid (or two).
# It is not recommended to select the same user for both columns,
# since you will be confused when you edit one column and the other
# column doesn't update with the new value. But nothing stops you
# from following a course of action that confuses yourself right now.
sub load_table_module {
	my ($self, $tbl, $uid2, $uid1) = @_;
	$tbl or die "no table specified!";
	$tbl =~ /\W/ and die "table name contained illegal characters!"; # prevent sneaky injection attacks
	$tbl =~ s/^(.)/\u$1/; # uppercase the first char
	my $tbl_class = "STEDT::Table::$tbl";
	eval "require $tbl_class" or die $@;
	
	# a bit turgid, but what is happening is that 2 uids can be optionally passed in
	# to select which tagging is to be displayed in the analysis and user_an columns in Lexicon.
	# the initial settings are stedt for analysis and the current user for user_an
	$uid2 = $self->param('uid') unless defined($uid2);
	$uid1 = 8 unless defined($uid1);
	return $tbl_class->new($self->dbh, $self->param('userprivs'), $uid2, $uid1);
}

# helper methods for authentication

# check if the user has the right privilege bits set.
# return error page if not secure.
sub require_privs {
	no warnings 'uninitialized';
	my ($self, $privs) = @_;
	return if ($self->param('userprivs') & $privs);
	$self->header_add(-status => 403);
	die $self->tt_process("admin/https_warning.tt") unless $self->param('user');
	die 'You do not have sufficient privileges to perform that operation, required by '
		. caller() . '::' . $self->get_current_runmode() . ".\n";
		# trailing newline suppresses the file and line number in die's $@ error message
}

sub has_privs {
	no warnings 'uninitialized';
	my ($self, $privs) = @_;
	return $self->param('userprivs') & $privs;
}

1;
