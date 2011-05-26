#!/usr/bin/perl

use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;

use Jukebox;

my $current_song    = Jukebox::get_mpd_current_song();
my @playlist        = Jukebox::get_mpd_playlist();
my $stream          = 'http://elise.corp.meebo.com:8000/music.ogg';

Jukebox::page_start('Current Playlist','');
print qq{
    <div id='container' style='text-align: center;'>
        <h3>Now Playing: $$current_song{artist} - $$current_song{title}</h3>
        <h4><a href='$stream'>Tune In</a></h4>
        <table align='center'>
            <tr>
                <td></td>
                <td>Artist</td>
                <td>Title</td>
            </tr>
};
my $count = 1;
foreach my $song (@playlist) {
    next if ($$song{id} eq $$current_song{id});
    print qq{
            <tr>
                <td align='left' width='30px'>$count</td>
                <td align='left'>$$song{artist}</td>
                <td align='right'>$$song{title}</td>
            </tr>};
    $count++;
}
    
print qq{
        </table>
    </div>
    </body>
</html>};
exit;
