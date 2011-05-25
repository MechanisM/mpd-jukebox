#!/usr/bin/perl
package Jukebox;

use strict;
use warnings;

use DBI;

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

1;
__END__
