#!/usr/bin/perl

use strict;
use warnings;

use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;
use CGI::Session qw/-ip_match/;

use Jukebox;

# yeah, this is probably stupid, but i think it might make it easier.
my %cgi_params = ();
foreach my $param (param()) {
    $cgi_params{$param} = param($param);
}

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

sub make_html_list {
    my $hashref = shift;
    my $field   = shift;

    my @list = ();
    foreach my $key (sort keys %$hashref) {
        my $id = $$hashref{$key}{id};
        my $url = "$script?type=$field&id=$id&action=list";
        my $list_item = "<a href='$url'>$key</a><br/>\n";
        push @list, $list_item;
    }
    return join('',@list);
}

sub authenticated_page {
    my $current_song    = Jukebox::get_mpd_current_song();
    my @playlist        = Jukebox::get_mpd_playlist();

    my $genre_hash  = Jukebox::get_information('genre','genres');
    my $album_hash  = Jukebox::get_information('album','albums');
    my $artist_hash = Jukebox::get_information('artist','artists');

    my $genres  = &make_html_list($genre_hash,'genre');
    my $albums  = &make_html_list($album_hash,'album');
    my $artists = &make_html_list($artist_hash,'artist');

    my $genres_link = qq{<a href="javascript:field('genres');">genres</a>};
    my $albums_link = qq{<a href="javascript:field('albums');">albums</a>};
    my $artists_link = qq{<a href="javascript:field('artists');">artists</a>};

    my $main_text = '';
    if (param('action')) {
        $main_text = &process_action(param('action'),$current_song,\@playlist);
        unless ($main_text and $main_text ne '') {
            # redirect to the main page if there was no result
            print $session->header(-location=>'index.pl');
        }
    } else {
        my $current = Jukebox::get_song_by_file($$current_song{file});
        my $url = Jukebox::linkify_song($current,$script);

        my $pls = Jukebox::convert_playlist(\@playlist);

        $main_text  = "<h2>Now Playing: $url</h2>\n";
        $main_text .= "<h4>Playlist:<h4>\n";
        $main_text .= Jukebox::html_songs_list($pls,$script);
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
                    <input type='text' name='search' value='' />
                    <input type='submit' name='action' value='search' />
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

sub process_action {
    my $action      = shift;
    my $current     = shift;
    my $playlist    = shift;

    if ($action eq 'show') {
        my $song_id = param('song_id');
        return unless ($song_id);
        my $song_info = Jukebox::get_song_by_id($song_id);

        my $genre  = Jukebox::get_name_by_id('genre',$$song_info{genre_id});
        my $album  = Jukebox::get_name_by_id('album',$$song_info{album_id});
        my $artist = Jukebox::get_name_by_id('artist',$$song_info{artist_id});

        my $date = "date:   $$song_info{date}<br/>" || '';

        my $base_url = "<a href='$script?song_id=$song_id";
        my $add_url  = "$base_url&action=add'>add it</a>";
        my $rm_url   = "$base_url&action=rm'>remove</a>";

        my $in_playlist = 0;
        foreach my $playlist_song (@$playlist) {
            next if $in_playlist;
            $in_playlist = 1 if ($$song_info{file} eq $$playlist_song{file});
        }
        my $add_or_rm = "Not currently in the playlist: $add_url ?";
        if ($in_playlist) {
            $add_or_rm = "Song is in the playlist: $rm_url ?";
        }
        if ($$song_info{file} eq $$current{file}) {
            $add_or_rm = "currently playing";
        }

        my $info = qq[
title:  $$song_info{title}<br/>
artist: $artist<br/>
album:  $album<br/>
genre:  $genre<br/>
$date
$add_or_rm<br/>
];
        return $info;
    }

    if ($action eq 'search') {
        my $query = param('query');
        return unless ($query);
        my $matches = Jukebox::search_music("$query");
        my $count = scalar(keys %$matches);
        my $result = 'results';
           $result = 'result' if ($count == 1);
        my $info = "<h2>search for '$query' yielded $count $result</h2>\n";
        if ($count > 0) {
            $info .= "<h4>Songs:</h4>\n";
            $info .= Jukebox::html_songs_list($matches,$script);
        }
        return $info;
    }

    if ($action eq 'list') {
        my $type = param('type');
        my $id   = param('id');
        return unless ($id and $type);
        my ($item,$songs) = Jukebox::get_songs_from_other($type,$id);
        return unless ((scalar(keys %$songs) > 0) and ($item));
        my $info  = "<h2>$name</h2>\n";
           $info .= Jukebox::html_songs_list($songs,$script);
        return $info;
    }
    if (($action eq 'add') or ($action eq 'rm')) {
        my $song_id = param('song_id');
        return unless ($song_id);
        my $file = Jukebox::get_file_from_id($song_id);
        if ($action eq 'add') {
            Jukebox::add_song($file);
        }
        if ($action eq 'rm') {
            Jukebox::rm_song($file);
        }
        return undef;
    }
    return undef;
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
