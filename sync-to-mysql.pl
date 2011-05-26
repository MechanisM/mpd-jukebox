#!/usr/bin/perl

use strict;
use warnings;

use Audio::MPD;
use DBI;

use Jukebox;

my $mpd = Jukebox::mpd_connect();

my @all_songs = $mpd->collection->all_songs;
my $not_ready = 1;

while ($not_ready) {
    $mpd->updatedb;
    sleep 5;
    my @songs = $mpd->collection->all_songs;
    $not_ready = 0 if (scalar(@songs) == scalar(@all_songs));
    @all_songs = @songs;
}

my %albums = ();
my %artists = ();
my %genres = ();

foreach my $song (@all_songs) {
    if ($$song{artist}) {
        $artists{$$song{artist}} = 1;
        if ($$song{album}) {
            $albums{$$song{artist}}{$$song{album}} = 1;
        }
    }
    $genres{$$song{genre}} = 1 if ($$song{genre});
}

foreach my $key (keys %artists) {
    print "$key\n";
} 
