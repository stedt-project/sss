#!/usr/bin/perl
require 5.004;
use strict;
use Roots::Util;
use Roots::Template;
use CGI qw(:standard);

$Roots::Util::headers_done = 0;
my ($session, $cookie, $authname) = Roots::Util::get_session();
# get params
import_names('Q');

## ack!! with multiple submit btns, browsers like to send the first
## submit button! this defeats our hidden def_btn. argh.
my $btn  = param('btn') || param('def_btn');
$btn = "Edit" if $authname && !$btn;
my $self = script_name();


my $dbh = Roots::Util::do_connect();
my ($invalid_login, $full_name);
if ($btn eq "Login") {
	validate_login();
	my $url = Roots::Util::session_url();
	if (!$invalid_login) {
		do_login();
		print redirect($url);
		$dbh->disconnect;
		exit;
	}
}

# print headers
print header($cookie ? (-cookie=>$cookie) : ());
Roots::Template::print_head("Login",$authname,1);
$Roots::Util::headers_done = 1;
# 	<script>
# 	<!--
# 	function df() { }
# 	// -->
# 	</script>

# display stuff
print h1("Village DB Login");

my %actions = ( Login		=>\&do_login,
				New_User	=>\&do_new_user,
				Logout		=>\&do_logout,
				Edit		=>\&do_edit,
				Edit2		=>\&save_edit,
				'Forgot Password'		=>\&do_forgot1,
				'Generate New Password' =>\&do_forgot2,
			  );

my $action = $actions{$btn} || \&do_login_screen;
&$action;

# finish up
$dbh->disconnect;
print hr, qq|\n<div class="admin">|;
print "VillageDB $Roots::Util::vers by Dominic Yu.\n";
#print "session id: $session->{_session_id}";
#print qq#| <a href="about.html">About</a>#;
print "</div>";
print end_html(), "\n";


#subroutines

sub do_edit {
	print_edit();
}

sub do_login_screen {
	print_login();
	print_new_user();
}

sub do_login {
	if ($invalid_login) {
		print p("The username and/or password was invalid."), "\n";
		print_login();
	} else {
		# this happens before we redirect!
		$dbh->do("UPDATE User SET lastlogin=NOW() WHERE username=?", undef,
				 $Q::username) or bail($DBI::errstr);
		$session->{'username'} = $Q::username;
		timestamp();
		#print "You are now logged in as $full_name.";
	}
}

sub validate_login {	# called before the headers, so we know to redirect
	$invalid_login = !pwd_check($Q::username, $Q::pwd);
}

sub pwd_check {
	my ($uid, $pwd) = @_;
	return 0 if $pwd eq '';
	
	my $uid = $dbh->quote($uid);
	my $pwd = $dbh->quote($pwd);
	my ($real_pwd, $fullname) = Roots::Util::quick_query('pwd,fullname', 'User', "username=$uid");
	my $guess_pwd = Roots::Util::quick_query("PASSWORD($pwd)");
	$full_name = $fullname;	# save to file lexical
	return ($guess_pwd eq $real_pwd);
}

sub do_new_user {
	$dbh->do("LOCK TABLE User WRITE") || bail("Couldn't lock table: " . $dbh->errstr);
		# we need to lock the table before checking if the information is valid.
		# we check if the username already exists, and then add the username
		# if everything checks out. We can't let anyone sneak in in between.
	if (my $error = invalid_info()) {
		print "Error: $error";
		print_new_user();
	} else {
		my $qtd_pwd = $dbh->quote($Q::pwd);
		my $qtd_fullname = $dbh->quote($Q::fullname);
		$dbh->do("INSERT INTO User (username, pwd, fullname, email) VALUES ('$Q::username', PASSWORD($qtd_pwd), $qtd_fullname, '$Q::email', NOW())")
			|| bail("Couldn't add user to database: " . $dbh->errstr);
		$session->{'username'} = $Q::username;
		timestamp();
		print "Account created successfully. You are now logged in as $Q::username.";
	}
	$dbh->do("UNLOCK TABLES") || bail("Couldn't unlock table: " . $dbh->errstr);
}

# returns an error string if something's wrong
sub invalid_info {
	# authorization check;
	return "authorization code is invalid" if $Q::auth_code ne 'muggle';
	
	# sanity check
	return "passwords don't match" if $Q::pwd ne $Q::pwd2;
	
	return "username too long" if length $Q::username > 20;
	return "password too long" if length $Q::pwd > 20;
	return "Full Name too long" if length $Q::fullname > 60;
	return "email address too long" if length $Q::email > 60;
	
	return "no username entered" if $Q::username eq "";
	return "no password entered" if $Q::pwd eq "";
	return "no Full Name entered" if $Q::fullname eq "";
	return "no email address entered" if $Q::email eq "";
	
	return "username contains illegal characters" if $Q::username =~ /\W/;
	return "email address is invalid" if !ValidEmailAddr($Q::email);
	return "username already exists. Please choose a different username."
		if username_exists();
}

sub save_edit {
	if (my $error = edit_check()) {
		print "Error: $error";
		print_edit();
	} else {
		$dbh->do("UPDATE User SET fullname=?, email=?"
				. ($Q::pwd && ", pwd=PASSWORD(?)") . " WHERE username=?", undef,
				$Q::fullname, $Q::email, $Q::pwd || (), $authname)
			or bail("Couldn't update database: " . $dbh->errstr);
		print "Your information was updated successfully.";
	}
}

sub edit_check {
	# password check;
	return "password invalid" unless pwd_check($authname, $Q::oldpwd);
	
	# sanity check
	return "passwords don't match" if $Q::pwd ne $Q::pwd2;
	return "password too long" if length $Q::pwd > 20;
	
	return "Full Name too long" if length $Q::fullname > 60;
	return "no Full Name entered" if $Q::fullname eq "";

	return "email address too long" if length $Q::email > 60;
	return "no email address entered" if $Q::email eq "";
	return "email address is invalid" if !ValidEmailAddr($Q::email);
}

sub username_exists {
	my $qtd_name = $dbh->quote($Q::username);
	my $n = Roots::Util::quick_query('COUNT(*)', 'User', "username=$qtd_name");
	return $n;
}

sub do_logout {
	delete $session->{'username'};
	timestamp();
	
	print p("You are now logged out.");
	print p("Back to ", a({-href=>Roots::Util::session_url()}, "the database"), ".");
	print_login();
}

sub timestamp() {
	my $x = tied %$session;
	#$x->make_modified;
	$x->save;
}

sub print_login {
	print <<EOF;
<form method="POST" action="$self">
<p>Log in here:</p>

<table>
	<tr>
		<th>username:</th>
		<td><input type="text" name="username" size="20" maxlength="20" value="$Q::username"></td>
	</tr>
	<tr>
		<th>password:</th>
		<td><input type="password" name="pwd" size="20" maxlength="20"></td>
	</tr>
	<tr><td colspan="2" align="center">
		<input type="hidden" name="def_btn" value="Login">
		<input type="submit" name="btn" value="Login" style="width: 12em">
		<input type="submit" name="btn" value="Forgot Password">
	</td></tr>
</table>
</form>
EOF
}

sub print_new_user {
	print <<EOF;
<p>
Create a new account:
</p>
<form method="post" action="$self">
<table>
	<tr>
		<th>username:</th>
		<td><input type="text" name="username" size="20" maxlength="20" value="$Q::username"></td>
	</tr>
	<tr>
		<th>password:</th>
		<td><input type="password" name="pwd" size="20" maxlength="20"></td>
	</tr>
	<tr>
		<th>confirm password:</th>
		<td><input type="password" name="pwd2" size="20" maxlength="20"></td>
	</tr>
	<tr>
		<th>Full Name:</th>
		<td><input type="text" name="fullname" size="40" maxlength="60" value="$Q::fullname"></td>
	</tr>
	<tr>
		<th>Email:</th>
		<td><input type="text" name="email" size="40" maxlength="60" value="$Q::email"></td>
	</tr>
	<tr>
		<th>Authorization Code:</th>
		<td><input type="password" name="auth_code" size="20" maxlength="20"></td>
	</tr>
	<tr><td colspan="2" align="center">
		<input type="hidden" name="btn" value="New_User">
		<input type="submit" value="Create Account">
	</td></tr>
</table>
</form>
EOF
}

sub print_edit {
	my $qtd_name = $dbh->quote($authname);
	my ($fullname,$email) = Roots::Util::quick_query('fullname,email', 'User', "username=$qtd_name");
	print <<EOF;
<p>
Edit account information for '$authname':
</p>
<form method="post" action="$self">
<table>
	<tr>
		<th>old password:</th>
		<td><input type="password" name="oldpwd" size="20" maxlength="20"> (required)</td>
	</tr>
	<tr>
		<th>new password:</th>
		<td><input type="password" name="pwd" size="20" maxlength="20"></td>
	</tr>
	<tr>
		<th>confirm password:</th>
		<td><input type="password" name="pwd2" size="20" maxlength="20"></td>
	</tr>
	<tr>
		<th>Full Name:</th>
		<td><input type="text" name="fullname" size="40" maxlength="60" value="$fullname"></td>
	</tr>
	<tr>
		<th>Email:</th>
		<td><input type="text" name="email" size="40" maxlength="60" value="$email"></td>
	</tr>
	<tr><td colspan="2" align="center">
		<input type="hidden" name="btn" value="Edit2">
		<input type="submit" value="Submit">
	</td></tr>
</table>
</form>
EOF
}

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

sub do_forgot1 {
	if ($Q::username eq '' || !username_exists()) {
		print "Please enter a valid username";
		print_login();
		return;
	}
print <<EOF;
<form method="POST" action="$self">
<table>
	<tr>
		<td>Did you really forget your password?
If so, click below and you'll get a new random password sent to the
email address we have on file for the account named '$Q::username'.
(If your email has changed since you created your account,
this won't work. Email the database administrator who'll get things sorted
out for you.)
		</td>
	</tr>
	<tr><td align="center">
		<input type="hidden" name="username" value="$Q::username">
		<input type="submit" name="btn" value="Generate New Password">
	</td></tr>
</table>
</form>
EOF
}

sub do_forgot2 {
	my $qtd_name = $dbh->quote($Q::username);
	my ($email) = Roots::Util::quick_query('email', 'User', "username=$qtd_name");
	
	unless (ValidEmailAddr($email)) {
		print "Error: the email address we have is invalid!!";
		return;	
	}
	
	my $pwd; $pwd .= ('A'..'Z','a'..'z',0..9)[int rand 62] for (0..8);
#	print $pwd; return;
	
	open (SENDMAIL, "| /usr/sbin/sendmail -t -n") or bail("couldn't sendmail: $!");
	print SENDMAIL <<End_of_Mail;
From: Village DB <dominic\@apexusa.com>
To: $email
Reply-To: dominic\@apexusa.com
Subject: Village DB account

new password: $pwd

log in to http://apexusa.com/~dominic/login.cgi
to change it to something more memorable
End_of_Mail
	close SENDMAIL or bail("couldn't sendmail: $! - $?");

	my $rows = $dbh->do("UPDATE User SET pwd=PASSWORD(?) WHERE username=?", undef,
						$pwd, $Q::username);
	unless ($rows) {
		print "Error setting new password!";
		return;
	}
	
	print p("Random password generated and sent!"), "\n";
}

