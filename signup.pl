#!/usr/bin/perl

use strict;
use warnings;

use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;

use Jukebox;

my $session = Jukebox::get_session();

if (param('create')) {
    create_user_account(param('user'),param('pass0'),param('pass1'));
} else {
    sign_up_page('','');
}

sub sign_up_page {
    my $user    = shift || '';
    my $err     = shift || '';

    Jukebox::page_start('Meebo Jukebox Sign Up','');
    print qq{
    <div id='container'>
        <form method='post'>
            <p id='head'>Meebo Jukebox Sign Up:</p>
            <table id='sign_up'>
                <tr>
                    <td>username:</td>
                    <td>
                        <input type='text' name='user' size='15' value='$user'/>
                    </td>
                </tr>
                <tr>
                    <td>password:</td>
                    <td>
                        <input type='password' name='pass0' size='15' />
                    </td>
                </tr>
                <tr>
                    <td>password again:</td>
                    <td>
                        <input type='password' name='pass1' size='15' />
                    </td>
                </tr>
            </table>
            <br/>
            <input type='submit' name='create' value='ok' />
        </form>
    };
    print qq{
        <br/>
        <p><em>$err</em></p>
    } if ($err);
    print "    </div>";
    exit;
}

sub create_user_account {
    my $user    = shift;
    my $pass0   = shift;
    my $pass1   = shift;

    sign_up_page($user,'please fill in all fields') if
        (($pass0 eq '') or ($pass1 eq '') or ($user eq ''));
    sign_up_page($user,'passwords do not match') if ($pass0 ne $pass1);

    my $dbh = Jukebox::db_connect();
    my $userq = $dbh->quote($user);

    my $select = qq{ select user_id from users where username=$userq };
    my ($uid) = $dbh->selectrow_array($select);
    sign_up_page('',"username \'$user\' taken") if ($uid);

    my $salt = join '',('.','.',0..9,'A'..'Z','a'..'z')[rand 64, rand 64];
    my $crypt = crypt($pass0,$salt);
    my $cryptq = $dbh->quote($crypt);
    my $insert = qq{ insert into users (username,password)
                        values ($userq,$cryptq) };
    my $rv = $dbh->do($insert);
    $dbh->disconnect;
    sign_up_page($user,"failed to create user: \'$user\'") unless ($rv);
    Jukebox::login($user,$crypt,$session);
    exit;
}
