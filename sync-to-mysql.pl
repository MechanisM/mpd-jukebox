#!/usr/bin/perl

use strict;
use warnings;

use Audio::MPD;
use DBI;

use Jukebox;

my $mpd = Jukebox::mpd_connect();
my $dbh = Jukebox::db_connect();

my @all_songs = $mpd->collection->all_songs;
my $not_ready = 1;

while ($not_ready) {
    $mpd->updatedb;
    sleep 5;
    my @songs = $mpd->collection->all_songs;
    $not_ready = 0 if (scalar(@songs) == scalar(@all_songs));
    @all_songs = @songs;
}

foreach my $song (@all_songs) {
    foreach my $key (keys %$song) {
        print "$key: $$song{$key}\n";
    }
    exit;
}

foreach my $song (@all_songs) {
    # 'safe' defaults.
    my $date    = 0;
    my $track   = 0;
    my $album   = 'none';
    my $genre   = 'none';
    my $title   = 'none';
    my $artist  = 'none';

    # skip it, if we don't have a file. shouldn't happen.
    # actually, we may want to throw a warning if this does happen...
    unless ($$song{file}) {
        # should be interpreted as a string because of the object...
        print STDERR "$song doesn't have a file?\n";
        next;
    }
    my $file = $$song{file};
    my $fileq = $dbh->quote($file);
    my $select = qq{ select song_id from songs where file=$fileq };
    my ($song_id) = $dbh->selectrow_array($select);
    if ($song_id) {
        print "$song already in sql...\n";
        next;
    }

    $date   = $$song{date}      if ($$song{date});
    $track  = $$song{track}     if ($$song{track});
    $album  = $$song{album}     if ($$song{album});
    $genre  = $$song{genre}     if ($$song{genre});
    $title  = $$song{title}     if ($$song{title});
    $artist = $$song{artist}    if ($$song{artist});

    $date   = $dbh->quote($date);
    $track  = $dbh->quote($track);
    $album  = $dbh->quote($album);
    $genre  = $dbh->quote($genre);
    $title  = $dbh->quote($title);
    $artist = $dbh->quote($artist);

    my $insert = qq{
        insert into songs (date,track,album,genre,title,artist,file)
            values ($date,$track,$album,$genre,$title,$artist,$fileq) };
    my $rv = $dbh->do($insert);
    if ($rv != 1) {
        print STDERR "failed to insert $song;\n$insert\n";
        exit 1;
    }
}
