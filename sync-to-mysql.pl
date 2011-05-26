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

print "done with sql shit...\n";

my $select = qq{ select file from songs };
my $files = $dbh->selectcol_arrayref($select);

# double looping = TERRIBLE... but it is faster than querying MPDs db with
# $mpd->collection->song($file); 30s vs 17s for 5010 files.
foreach my $file (@$files) {
    my $found = 0;
    foreach my $song (@all_songs) {
        next if $found;
        if ($$song{file} eq $file) {
            $found = 1;
        }
    }
    if ($found == 0) {
        print "no mpd entry for $file, purging mysql\n";
        my $fileq = $dbh->quote($file);
        my $select = qq{ select song_id from songs where file=$fileq };
        my ($song_id) = $dbh->selectrow_array($select);
        if ($song_id) {
            my $delete = qq{ delete from songs where song_id=$song_id };
            my $rv = $dbh->do($delete);
            if ($rv != 1) {
                print STDERR "failed to delete song_id: $song_id ($file)\n";
                # exit may seem harsh, but ... i don't always trust my code.
                exit 1;
            }
        } else {
            print STDERR "unable to find song_id for '$file'\n";
            exit 1;
        }
    }
}

# now that we have potentially purged some songs, let's make sure there are
# no orphaned albums, artists or genres...
sub purge_records {
    my $table   = shift;
    my $type    = shift;
    my $type_id = shift;

    my $select = qq{ select $type_id from $table };
    my $ids = $dbh->selectcol_arrayref($select);
    foreach my $id (@$ids) {
        my $select = qq{ select song_id from songs where $type_id=$id limit 1 };
        my ($song_id) = $dbh->selectrow_array($select);
        if ($song_id) {
            next;
        } else {
            my $select = qq{ select $type from $table where $type_id=$id };
            my ($name) = $dbh->selectrow_array($select);
            if ($name) {
                print "no songs found for $type_id: $id ($name), purging\n";
                my $delete = qq{ delete from $table where $type_id=$id };
                my $rv = $dbh->do($delete);
                if ($rv != 1) {
                    print STDERR "failed to delete $type_id: $id ($name)\n";
                    exit 1;
                }
            } else {
                print STDERR "could not find $type_id: $id in database\n";
                exit 1;
            }
        }
    }
}
purge_records('albums','album','album_id');
purge_records('artists','artist','artist_id');
purge_records('genres','genre','genre_id');
