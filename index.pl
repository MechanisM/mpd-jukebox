#!/usr/bin/perl

use strict;
use warnings;

use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;
use CGI::Session qw/-ip_match/;

use Jukebox;

my $script = $ENV{SCRIPT_NAME};

my $name = Jukebox::get_name();
my $session = Jukebox::get_session();

my $data = Jukebox::read_session($session);
Jukebox::save_session($session,$data);

if ($session->is_expired) {
    login_page('your session has expired');
} elsif ($session->is_empty) {
    if (param('action') and (param('action') eq 'login')) {
        authenticate();
    } else {
        login_page();
    }
} elsif (Jukebox::validate_session($session)) {
    authenticated_page();
} else {
    login_page('invalid session');
}

sub login_page {
    my $error = shift || '';
    $error = "<p><em>$error</em></p>" if ($error ne '');

    Jukebox::page_start("$name Login Page",'');
    print qq{
    <div id='container'>
    <div id='login_page'>
        <form method='post'>
            <h4>$name Login</h4>
            <table id='login'>
                <tr>
                    <td>username:</td>
                    <td><input type='text' name='username' size='15' /></td>
                </tr><tr>
                    <td>password:</td>
                    <td><input type='password' name='password' size='15'/></td>
                </tr><tr>
                    <td></td>
                    <td style='text-align: right; font-size: 6pt;'>
                        <a href='signup.pl'>sign up</a>
                    </td>
                </tr>
            </table>
            <input type='submit' name='action' value='login' />
        </form>
        <br/>
        $error
    </div>
    </div>
    </body>
</html>};
    exit;
}

sub authenticated_page {

    # this takes 2-5s to do... with a small collection...
    my @collection = Jukebox::get_mpd_collection();

    my $current_song = Jukebox::get_mpd_current_song();
    my @playlist = Jukebox::get_mpd_playlist();

    my $genres = Jukebox::make_html_list($script,\@collection,'genre');
    my $artists = Jukebox::make_html_list($script,\@collection,'artist');
    my $albums = Jukebox::make_html_list($script,\@collection,'album');

    my $genres_link = qq{<a href="javascript:field('genres');">genres</a>};
    my $albums_link = qq{<a href="javascript:field('albums');">albums</a>};
    my $artists_link = qq{<a href="javascript:field('artists');">artists</a>};

    my $main_text = "";

    if (param('action')) {
        my $action = param('action');
        if ($action eq 'show') {
            if (param('song')) {
                my $filename = param('song');
                my $in_playlist = 0;
                my ($song) = Jukebox::search_songs(\@collection,'file',$filename);
                foreach my $playlist_song (@playlist) {
                    $in_playlist = 1 if ($$song{file} eq $$playlist_song{file});
                }
                $main_text = "$$song{artist} - $$song{title} from $$song{album}";
                $main_text .= "<br/>\n";
                if ($$current_song{file} eq $$song{file}) {
                    $main_text .= "currently playing<br/>\n";
                } else {
                    if ($in_playlist) {
                        my $url = Jukebox::linkify_song($script,$song,'rm');
                        $main_text .= "remove: $url\n";
                    } else {
                        my $url = Jukebox::linkify_song($script,$song,'add');
                        $main_text .= "add: $url\n";
                    }
                }
            }
        }
        if ($action eq 'list_songs') {
            if (param('field') and param('item')) {
                my $field   = param('field');
                my $item    = param('item');
                my @songs = Jukebox::search_songs(\@collection,$field,$item);
                $main_text = "<h3>$field: $item<h3><h4>Songs:</h4>\n";
                foreach my $song (@songs) {
                    my $url = Jukebox::linkify_song($script,$song,'show');
                    $main_text .= "$url<br/>\n";
                }
            }
        }
        if ($action eq 'add') {
            if (param('song')) {
                my $filename = param('song');
                Jukebox::add_song($filename);
                print $session->header(-location=>'index.pl');
            }
        }
        if ($action eq 'rm') {
            if (param('song')) {
                my $filename = param('song');
                Jukebox::rm_song(\@playlist,$filename);
                print $session->header(-location=>'index.pl');
            }
        }
    } else {
        my $url = Jukebox::linkify_song($script,$current_song,'show');

        $main_text = "<h3>Now Playing: $url</h3><h4>Playlist:<h4>\n";
        foreach my $song (@playlist) {
            next if ($$song{id} eq $$current_song{id});
            my $url = Jukebox::linkify_song($script,$song,'show');
            $main_text .= "$url<br/>\n";
        }
    }
    Jukebox::page_start("$name",'');
    print qq{
    <div id='container'>
        <div id='header'>
            <div id='title'>
                <a href='$script'>$name</a>
            </div>
            <div id='search'>
                <form method='post'>
                    <input type='text' name='criteria' value='' />
                    <input type='submit' name='search' value='search' />
                </form>
                <span id='logout'>
                    <a href='logout.pl'>log out</a>
                </span>
            </div>
        </div>
        <div id='midpage'>
            <div id='sidebar'>
                <div id='sidebar_head'>
                    $artists_link - $albums_link - $genres_link
                </div>
                <div id='genres'>
                    $genres
                </div>
                <div id='artists'>
                    $artists
                </div>
                <div id='albums'>
                    $albums
                </div>
            </div>
            <div id='main'>
                <a href='$script'>Main Page</a><br/><br/>
                $main_text
            </div>
        </div>
    </div>
</body>
</html>
};
    exit;
}

sub authenticate {
    my $user = param('username');
    my $pass = param('password');
    my $dbh = Jukebox::db_connect();

    my $userq = $dbh->quote($user);
    my $select = 'select password from users where username=' . $userq;
    my ($hash) = $dbh->selectrow_array($select);
    if ($hash and (crypt($pass,$hash) eq $hash)) {
        Jukebox::login($user,$hash,$session);
    }
    login_page('username or password incorrect');
}
