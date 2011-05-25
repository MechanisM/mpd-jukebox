#!/usr/bin/perl

use strict;
use warnings;

use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;
use CGI::Session qw/-ip_match/;

use Jukebox;

my $session = Jukebox::get_session();

my $data = Jukebox::read_session($session);
Jukebox::save_session($session,$data);


if ($session->is_expired) {
    login_page('your session has expired');
} elsif ($session->is_empty) {
    if (param('action') and (param('action') eq 'login')) {
        authenticate();
    } else {
        login_page();
    }
} elsif (validate_session($session)) {
    print $session->header(-location=>'start.pl');
} else {
    login_page('invalid session');
}

sub login_page {
    my $error = shift || '';
    my $dev   = $$data{dev} || 0;
    $error = "<p><em>$error</em></p>" if ($error ne '');

    Jukebox::page_start('Meebo Jukebox Login Page','');
    print qq{
    <div id='container'>
        <form method='post'>
            <h4>Meebo Jukebox Login</h4>
            <table id='login'>
                <tr>
                    <td>username:</td>
                    <td><input type='text' name='username' size='15' /></td>
                </tr><tr>
                    <td>password:</td>
                    <td><input type='password' name='password' size='15'/></td>
                </tr><tr>
                    <td></td>
                    <td style='text-align: right; font-size: 6pt;'>
                        <a href='signup.pl'>sign up</a>
                    </td>
                </tr>
            </table>
            <input type='hidden' name='dev' value='$dev' />
            <input type='submit' name='action' value='login' />
        </form>
        <br/>
        $error
    </div>
    </body>
</html>};
    exit;
}

sub authenticate {
    my $user = param('username');
    my $pass = param('password');
    my $dbh = Jukebox::db_connect();

    my $userq = $dbh->quote($user);
    my $select = 'select password from users where username=' . $userq;
    my ($hash) = $dbh->selectrow_array($select);
    if ($hash and (crypt($pass,$hash) eq $hash)) {
        login($user,$hash,$session);
    }
    login_page('username or password incorrect');
}
