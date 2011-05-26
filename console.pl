#!/usr/bin/perl
# mpd-jukebox.pl - mpd based jukebox system
# Copyright (C) 2008 Christopher P. Bills (cpbills@fauxtographer.net)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use Audio::MPD;
use Getopt::Std;

my %opts = ();
getopts('h:p:c:', \%opts);

my $host    = $opts{h} || 'localhost';
my $port    = $opts{p} || 6600;
my $command = $opts{c} || '';

my $mpd = Audio::MPD->new(host => $host, port => $port);

# Audio::MPD doesn't have this natively... but we can call it!
# this will remove a track from the playlist after it has been played
$mpd->_send_command("consume 1\n");
# update the music database...
$mpd->updatedb();

# get various information that will be useful during the course of operation
# $mpd->collection->all_songs takes a while to run, 0-10s, so we want to run
# it sparingly; processing the hash-array is fairly speedy.
my @all_songs           = $mpd->collection->all_songs;
my @current_playlist    = $mpd->playlist->as_items;
my $current_song        = $mpd->song;

# just a demo of how to get information from the collection...
#my @genres  = get_info(\@all_songs,'genre');
#my @artists = get_info(\@all_songs,'artist');
#my @titles  = get_info(\@all_songs,'title');
#my @albums  = get_info(\@all_songs,'album');

#my @songs = search_songs(\@all_songs,'artist','nine inch nails');
my @songs = search_songs(\@all_songs,'file','The Sea');
foreach my $song (@songs) {
    my $id = $song->id;
    print "$id\n";
    foreach my $key (keys %$song) {
        print "$key: $$song{$key}\n";
    }
    print "\n";
}


exit;

sub search_songs {
    my $songs   = shift;
    my $field   = shift;
    my $search  = shift;

    my @found   = ();

    foreach my $song (@$songs) {
        if ($$song{$field} and $$song{$field} =~ /$search/i) {
            push @found, $song;
        }
    }
    return @found;
}


sub get_info {
    my $songs   = shift;
    my $key     = shift;

    my %info_hash = ();
    foreach my $song (@$songs) {
        $info_hash{$$song{$key}} = 1 if ($$song{$key});
    }
    return sort keys %info_hash;
}
