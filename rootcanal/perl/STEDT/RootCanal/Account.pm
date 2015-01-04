package STEDT::RootCanal::Account;
use strict;
use base 'STEDT::RootCanal::Base';
use CGI::Application::Plugin::Redirect;

# for creating and maintaining a personal account
sub account : StartRunmode {
	my $self = shift;
	my $errs = shift; # hash ref of errors
	my ($username, $email);
	
	# look these up so we can put it on the update form
	if (defined(my $uid = $self->param('uid'))) {
		($username, $email) = $self->dbh->selectrow_array("SELECT username, email FROM users WHERE uid=?", undef, $uid);
	}
	
	# don't let guest users edit the guest account
	if ($username eq 'guest') {
		$self->header_add(-status => 403);
		die "You do not have sufficient privileges to perform that operation.\n";
	}

	return $self->tt_process("account.tt", {
		err => $errs,
		username => $username,
		email => $email,
	});
}

sub gsarpa : Runmode {
	my $self = shift;
	if (!$self->query->cookie('stsec')) {
		return $self->tt_process("admin/https_warning.tt");
	}
	my $errs = shift;
	return $self->tt_process("admin/create_account.tt", { err => $errs });
}

my %secret_codes = (
	'tibeto-burman' => 2,		# casual user
	rhinoglottophilia => 3,		# tagger
	columbicubiculomania => 31,	# superuser with all bits set
);

# create/update account if attempting to do so
sub acct_dfv_profile {
	my $self = shift;
	my $updating = shift;
	my $flds = [qw/newuser newpwd newpwd2 email secret_code/];
	import Data::FormValidator::Constraints ':closures';
	my $p = {
		constraint_methods => {
			newuser => [FV_length_between(2,15), sub { my ($dfv, $val) = @_; $dfv->name_this('username_unique');
				return 1 if $updating && $self->param('user') eq $val;
				return 0 == $self->dbh->selectrow_array("SELECT COUNT(*) FROM users WHERE username=?", undef, $val);
			}],
			newpwd  => [FV_min_length(5), sub { my ($dfv, $val) = @_; $dfv->name_this('pwd_secure');
				return $val ne $dfv->get_filtered_data->{newuser};
			}],
			newpwd2 => FV_eq_with('newpwd'),
			email   => email(),
			secret_code => sub { my ($dfv, $val) = @_; $dfv->name_this('secret');
				return $secret_codes{$val};
			},
			oldpwd => sub { my ($dfv, $val) = @_; $dfv->name_this('password_correct');
				my ($p1, $p2) = $self->dbh->selectrow_array("SELECT password, SHA1(?) FROM users WHERE uid=?", undef, $val, $self->param('uid'));
				return $p1 eq $p2;
			},
		},
		msgs => {
			constraints => {
				username_unique => 'username is taken already, choose another one',
				length_between => 'username is too short',
				min_length => q|Password isn't long enough|,
				pwd_secure => q|Password isn't secure. Please choose a different password|,
				eq_with => q|Passwords don't match|,
				secret => 'secret code is incorrect',
				password_correct => q|Password is incorrect|,
			},
			any_errors => 'exists',
		},
	};
	if ($updating) {
		$p->{required} = [qw/oldpwd/];
		$p->{optional} = $flds;
	} else {
		$p->{required} = $flds;
	}
	return $p;
}

sub create : Runmode {
	my $self = shift;
	my $q = $self->query;
	if (!$q->cookie('stsec')) {
		return $self->tt_process("admin/https_warning.tt");
	}
	require CGI::Application::Plugin::ValidateRM;
	import CGI::Application::Plugin::ValidateRM;
	my $dfv_results = $self->check_rm('gsarpa', $self->acct_dfv_profile(),
		{target=>'acct_form', ignore_fields => ['newpwd','newpwd2']})
	|| return $self->check_rm_error_page;
		
	# success!
	my $u = $q->param('newuser');
	my $dbh = $self->dbh;
	my $sth = $dbh->prepare("INSERT users ("
		. join(',', qw|username password email privs|)
		. ") VALUES (?, SHA1(?), ?, ?)");
	my $privs = $secret_codes{$q->param('secret_code')};
	eval { $sth->execute($u, $q->param('newpwd'), $q->param('email'), $privs)	};
	if ($@) {
		my $err = "Can't create new account: $@";
		die $err; # give unexpected error page!
	}
	my $uid = $dbh->selectrow_array("SELECT LAST_INSERT_ID()");
	my $current_user = $self->param('user');
	$self->_login($uid, $u, $privs) unless $current_user;
	return $self->tt_process("admin/create_account_success.tt", {
		current => $current_user,
		msg => "Account for $u (uid:$uid) created successfully!."
	});
}

sub update : Runmode {
	my $self = shift;
	
	require CGI::Application::Plugin::ValidateRM;
	import CGI::Application::Plugin::ValidateRM;
	my $dfv_results = $self->check_rm('account', $self->acct_dfv_profile('update'),
		{target=>'acct_form', ignore_fields => ['newpwd','newpwd2','oldpwd']})
	|| return $self->check_rm_error_page;
		
	my $q = $self->query;
	my $dbh = $self->dbh;
	
	# everything was optional (except for the oldpassword),
	# so we only update if it's non-empty
	
	my $uid = $self->param('uid');
	my $val;
	if ($val = $q->param('newuser')) {
		$dbh->do("UPDATE users SET username=? WHERE uid=?", undef, $val, $uid)
			or die("Error updating username! $!");
	}
	if ($val = $q->param('email')) {
		$dbh->do("UPDATE users SET email=? WHERE uid=?", undef, $val, $uid)
			or die("Error updating email! $!");
	}
	if ($val = $q->param('newpwd')) {
	$dbh->do("UPDATE users SET password=SHA1(?) WHERE uid=?", undef, $val, $uid)
			or die("Error updating password! $!");
	}

	$self->param(user => $q->param('newuser'));	# update this value
	return $self->account;
}

# process logins
sub login : Runmode {
	my $self = shift;
	
	my $q = $self->query;
	# check if they're trying to log in over a non-secure connection
	# require all logins to be over https!
	if (!$q->cookie('stsec')) {
		return $self->tt_process("admin/https_warning.tt");
	}
	if ($self->param('user')) {
		return $self->redirect($q->url(-absolute=>1));
	}
	my $u = $q->param('user');
	unless ($u) {
		return $self->tt_process("login.tt", { blank => 1 });
	}
	my ($uid, $pwd, $pwd2, $privs) =
		$self->dbh->selectrow_array("SELECT uid, password, SHA1(?), privs FROM users WHERE username=?", undef, $q->param('pwd'), $u);
	if (defined($uid) && $pwd eq $pwd2) {
		# success!

		$self->_login($uid, $u, $privs);
		# redirect to the page they were trying to go to, or the main page otherwise
		return $self->redirect($self->query->param('url') || $self->query->url(-absolute=>1));
	}
	return $self->login_fail({});
}

sub login_fail : Runmode {
	my $self = shift;
	my $errs = shift;
	
	return $self->tt_process("login.tt", {
		err => $errs,
	});
}

# helper function to set params and stuff
sub _login {
	my ($self, $uid, $username, $privs) = @_;
	$self->session->param('uid', $uid);	# for authentication
	$self->user_session_init($uid, $username, $privs);
}

sub password_reset : Runmode {
	my $self = shift;
	my $dbh = $self->dbh;
	
	require CGI::Application::Plugin::ValidateRM;
	import CGI::Application::Plugin::ValidateRM;
	require Data::FormValidator::Constraints;
	import Data::FormValidator::Constraints ':closures';
	my $dfv_results = $self->check_rm('login_fail', {
		require_some => { all_empty => [1, qw/username email/]},
		constraint_methods => {
			username => sub { my ($dfv, $val) = @_; $dfv->name_this('username_exists');
				return $dbh->selectrow_array("SELECT COUNT(*) FROM users WHERE username=?", undef, $val);
			},
			email    => [email(), sub { my ($dfv, $val) = @_; $dfv->name_this('email_exists');
				return $dbh->selectrow_array("SELECT COUNT(*) FROM users WHERE email=?", undef, $val);
			}],
		},
		msgs => {
			constraints => {
				username_exists => 'username does not exist. maybe you spelled it wrong?',
				email_exists => 'email address not on file',
			},
			any_errors => 'exists',
		},
	}, {target=>'password_reset_form'}) || return $self->check_rm_error_page;

	my ($uid, $email); # the user's not logged in, so we have to look up by either username or email
	if (my $val = $self->query->param('username')) {
		($uid, $email) = $dbh->selectrow_array("SELECT uid, email FROM users WHERE username=?", undef, $val);
	} else {
		$email =  $self->query->param('email');
		$uid = $dbh->selectrow_array("SELECT uid FROM users WHERE email=? LIMIT 1", undef, $email);
		# I wonder if there will ever be multiple accounts with the same email...
	}
	die "bad email <$email> on file for user $uid!" unless ValidEmailAddr($email);
	
	my $pwd;
	$pwd .= ('A'..'Z','a'..'z',0..9)[int rand 62] for (0..8);
	
        my $loginurl = $self->query->url() . '/account/login';
	my $msg = <<End_of_Mail;

Your password has been changed.

New password: $pwd

Please log in to change it to something more memorable.

$loginurl

End_of_Mail

	my %mail = (
		    To         => $email,
		    Subject    => "STEDT Root Canal account",
		    From       => 'stedt@socrates.berkeley.edu',
		    'Reply-To' => 'stedt@socrates.berkeley.edu',
		    Message    => $msg,
		   );

	require Mail::Sendmail;
	Mail::Sendmail::sendmail(%mail) or die $Mail::Sendmail::error;

	# try to update the database AFTER you send the email. Otherwise
	# if sendmail fails, the password is changed but there's no record of it.
	$dbh->do("UPDATE users SET password=SHA1(?) WHERE uid=?", undef, $pwd, $uid) or die("Error setting new password! $!");

	return $self->tt_process("account.tt", {
		'reset' => 1,
		'message' => $Mail::Sendmail::log
	});
}

sub logout : Runmode {
	my $self = shift;
	
	$self->session->clear('uid');
	return $self->redirect($self->query->url(-absolute=>1));
}

# code for examining and updating users en masse
# eventually we should leverage the validation code, but for now it's OK.

sub users : Runmode {
	my $self = shift;
	$self->require_privs(1);
	
	my $a = $self->dbh->selectall_arrayref("SELECT username,uid,email,
privs&2,privs&1,privs&8,privs&16
FROM users
ORDER BY username");
	return $self->tt_process("admin/users.tt", {users=>$a});
}

sub update_all : Runmode {
	my $self = shift;
	$self->require_privs(16);
	my $q = $self->query;
	die "runmode update_all called with no params!" unless $q->param;
	my $uids = $self->dbh->selectcol_arrayref("SELECT uid FROM users");
	for my $uid (@$uids) {
		my ($password) = ($q->param("password_$uid"));
		my $privs = 0;
		$privs += 2 if $q->param("priv2_$uid");
		# print STDERR "Bit 2 checkbox for uid $uid is: " . $q->param("priv2_$uid") . "\n";
		$privs += 1 if $q->param("priv1_$uid");
		$privs += 8 if $q->param("priv8_$uid");
		$privs += 16 if $q->param("priv16_$uid");
		$self->dbh->do("UPDATE users SET privs=? WHERE uid=?", undef, $privs, $uid);
		if ($password) {
			$self->dbh->do("UPDATE users SET password=SHA1(?) WHERE uid=?", undef, $password, $uid);
		}
	}
	if ($q->param("username_00") && $q->param("email_00") && $q->param("password_00")) {
		my $sth = $self->dbh->prepare("INSERT users ("
			. join(',', qw|username password email privs|)
			. ") VALUES (?, SHA1(?), ?, ?)");
		my $privs = 0;
		$privs += 2 if $q->param("priv2_00");
		$privs += 1 if $q->param("priv1_00");
		$privs += 8 if $q->param("priv8_00");
		$privs += 16 if $q->param("priv16_00");
		eval { $sth->execute($q->param('username_00'), $q->param('password_00'), $q->param('email_00'), $privs)	};
		if ($@) {
			my $err = "Can't create new account: $@";
			die $err; # give unexpected error page!
		}
	}
	
	return $self->redirect($q->url(-absolute=>1) . "/account/users");
}


# helper functions
sub ValidEmailAddr { #check if e-mail address format is valid
  my $mail = shift;                                                  #in form name@host
  return 0 if ( $mail !~ /^[0-9a-zA-Z\.\-\_]+\@[0-9a-zA-Z\.\-]+$/ ); #characters allowed on name: 0-9a-Z-._ on host: 0-9a-Z-. on between: @
  return 0 if ( $mail =~ /^[^0-9a-zA-Z]|[^0-9a-zA-Z]$/);             #must start or end with alpha or num
  return 0 if ( $mail !~ /([0-9a-zA-Z]{1})\@./ );                    #name must end with alpha or num
  return 0 if ( $mail !~ /.\@([0-9a-zA-Z]{1})/ );                    #host must start with alpha or num
  return 0 if ( $mail =~ /.\.\-.|.\-\..|.\.\..|.\-\-./g );           #pair .- or -. or -- or .. not allowed
  return 0 if ( $mail =~ /.\.\_.|.\-\_.|.\_\..|.\_\-.|.\_\_./g );    #pair ._ or -_ or _. or _- or __ not allowed
  return 0 if ( $mail !~ /\.([a-zA-Z]{2,4})$/ );                     #host must end with '.' plus 2-4 alpha for TopLevelDomain (MUST be modified in future!)
  return 1;
}

1;
