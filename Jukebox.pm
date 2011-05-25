#!/usr/bin/perl
package Jukebox;

use strict;
use warnings;

use DBI;

### MySQL stuff, make this into a configuration option sometime... ###
my $sqluser     =   "jukeboxer";
my $sqlpass     =   "musicisnice";
my $sqldb       =   "mpd-jukebox";
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

1;
__END__
