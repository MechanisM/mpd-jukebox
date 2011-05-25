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

my @playlist = $mpd->playlist->as_items;

# Audio::MPD doesn't have this natively, yet... but we can call it!
# this will remove a track from the playlist after it has been played
$mpd->_send_command("consume 1\n");

my $current = $mpd->song;
foreach my $key (keys %$current) {
    print "$key ";
}
print "\n";

foreach my $song (@playlist) {
    print "$$song{id}: $$song{artist} - $$song{title}\n";
}

