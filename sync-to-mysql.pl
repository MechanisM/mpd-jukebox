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
    my $select = '';

    # i like lowercase, and it keeps things matched up...
    $date   = $$song{date}      if ($$song{date});
    $track  = $$song{track}     if ($$song{track});
    $album  = lc($$song{album}) if ($$song{album});
    $genre  = lc($$song{genre}) if ($$song{genre});
    $title  = lc($$song{title}) if ($$song{title});
    $artist = lc($$song{artist}) if ($$song{artist});

    # special cases:
    # in the scobbler db, u.n.k.l.e. is unkle *shrug*
    $artist = 'unkle' if ($artist =~ /u.n.k.l.e/);
    $genre  = 'trip-hop' if ($genre =~ /trip.hop/);

    $date   = $dbh->quote($date);
    $track  = $dbh->quote($track);
    $album  = $dbh->quote($album);
    $genre  = $dbh->quote($genre);
    $title  = $dbh->quote($title);
    $artist = $dbh->quote($artist);

    $select = qq{ select artist_id from artists where artist=$artist };
    my ($artist_id) = $dbh->selectrow_array($select);
    unless ($artist_id) {
        my $insert = qq{ insert into artists (artist) values ($artist) };
        my $rv = $dbh->do($insert);
        if ($rv != 1) {
            print STDERR "failed to add artist: $artist\n";
            exit 1;
        }
        ($artist_id) = $dbh->selectrow_array($select);
        unless ($artist_id) {
            print STDERR "failed to get artist_id for $artist\n";
            exit 1;
        }
    }

    # yes, i could functionalize this, but i'm only doing it twice...
    # famous last words, right?
    $select = qq{ select genre_id from genres where genre=$genre };
    my ($genre_id) = $dbh->selectrow_array($select);
    unless ($genre_id) {
        my $insert = qq{ insert into genres (genre) values ($genre) };
        my $rv = $dbh->do($insert);
        if ($rv != 1) {
            print STDERR "failed to add genre: $genre\n";
            exit 1;
        }
        ($genre_id) = $dbh->selectrow_array($select);
        unless ($genre_id) {
            print STDERR "failed to get genre_id for $genre\n";
            exit 1;
        }
    }

    $select = qq{ select album_id from albums
                        where artist_id=$artist_id and album=$album };
    my ($album_id) = $dbh->selectrow_array($select);
    unless ($album_id) {
        my $insert = qq{ insert into albums (album,artist_id)
                            values ($album,$artist_id) };
        my $rv = $dbh->do($insert);
        if ($rv != 1) {
            print STDERR "failed to add album: $artist - $album\n";
            exit 1;
        }
        ($album_id) = $dbh->selectrow_array($select);
        unless ($album_id) {
            print STDERR "failed to get album_id for $artist - $album\n";
            exit 1;
        }
    }

    $select = qq{ select song_id from songs where file=$fileq };
    my ($song_id) = $dbh->selectrow_array($select);
    unless ($song_id) {
        my $insert = qq{ insert into songs
                (title,file,date,track,artist_id,album_id,genre_id)
                    values
                ($title,$fileq,$date,$track,$artist_id,$album_id,$genre_id) };
        my $rv = $dbh->do($insert);
        if ($rv != 1) {
            print STDERR "failed to add $song\n";
            exit 1;
        }
        ($song_id) = $dbh->selectrow_array($select);
        unless ($song_id) {
            print STDERR "failed to get song_id for $song\n";
            exit 1;
        }
    }
}
