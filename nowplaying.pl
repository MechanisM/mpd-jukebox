#!/usr/bin/perl

use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;
use Audio::MPD;

use Jukebox;

my $current_song    = Jukebox::get_mpd_current_song();
my @playlist        = Jukebox::get_mpd_playlist();

Jukebox::page_start('Current Playlist','');
print qq{    <div id='container'>
};
print "<p>playing: $$current_song{artist} - $$current_song{title}</p>\n";
foreach my $song (@playlist) {
    unless ($$song{id} eq $$current_song{id}) {
        print "<p>$$song{id}: $$song{artist} - $$song{title}</p>\n";
    }
}
print qq{
    </div>
    </body>
</html>};
exit;
