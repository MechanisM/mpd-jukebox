#!/usr/bin/perl
package Jukebox;

use strict;
use warnings;

use DBI;
use CGI::Session qw/-ip_match/;

my $cgi_session =   'MPDJukebox';
### MySQL stuff, make this into a configuration option sometime... ###
my $sqluser     =   "jukeboxer";
my $sqlpass     =   "musicisgood";
my $sqldb       =   "mpd_jukebox";
my $sqlhost     =   "localhost";
### end db config ###

sub db_connect {
    my $dsn = "dbi:mysql:database=$sqldb;host=$sqlhost";
    my $dbh = DBI->connect($dsn,$sqluser,$sqlpass,{ RaiseError => 1 });
    return $dbh;
}

sub read_session {
    my $session = shift;

    my %data = ();
    foreach my $key ($session->param()) {
        $data{$key} = $session->param($key);
    }
    return \%data;
}

sub save_session {
    my $session = shift;
    my $data    = shift;

    foreach my $key (keys %$data) {
        $session->param($key,$$data{$key});
    }
    $session->flush();
}

sub fisher_yates_shuffle {
    my $array = shift;
    my $i;
    return if (@$array < 2);
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
}

sub reset_session {
    my $session = shift;

    my %data = ();
    foreach my $key ($session->param()) {
        $data{$key} = $session->param($key);
    }

    $session->clear();
    $session->param('username',$data{username});
    $session->param('password',$data{password});
    $session->param('_SESSION_ID',$data{_SESSION_ID});
    $session->param('_SESSION_ATIME',$data{_SESSION_ATIME});
    $session->param('_SESSION_REMOTE_ADDR',$data{_SESSION_REMOTE_ADDR});
    $session->param('_SESSION_EXPIRE_LIST',$data{_SESSION_EXPIRE_LIST});
    $session->param('_SESSION_CTIME',$data{_SESSION_CTIME});
    $session->flush();
}

sub page_start {
    my $title = shift;
    my $extraheaders = shift;
    $extraheaders = "" unless ($extraheaders);

    print <<ENDL;
Content-Type: text/html; charset=ISO-8859-1
Cache-Control: no-cache, no-store, must-revalidate
$extraheaders

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0;">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black">
    <title>$title</title>
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
    <link rel="icon" href="mpd.ico" type="image/x-icon">
    <link rel="shortcut icon" href="mpd.ico" type="image/x-icon">
    <style type="text/css">\@import "style.css";</style>
  </head>
  <body>
ENDL
}

sub get_session {
    CGI::Session->name($cgi_session);
    return CGI::Session->load();
}

sub login {
    my $user = shift;
    my $hash = shift;
    my $session = shift;

    $session = $session->new() or die $session->errstr;
    $session->param('username', $user);
    $session->param('password', $hash);
    $session->expire('~logged-in', '30m');
    $session->flush();
    my $cgi = CGI->new;
    my $cookie = $cgi->cookie(-name=>$session->name,-value=>$session->id);
    print $session->header(-location=>'start.pl',-cookie=>$cookie);
}

1;
__END__
