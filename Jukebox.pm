#!/usr/bin/perl
package Jukebox;

use strict;
use warnings;

use DBI;
use URI::Escape;
use CGI::Session qw/-ip_match/;
use Audio::MPD;

my $name        =   'Meebo Jukebox';
my $cgi_session =   'MPDJukebox';
### MySQL stuff, make this into a configuration option sometime... ###
my $sqluser     =   "jukeboxer";
my $sqlpass     =   "musicisgood";
my $sqldb       =   "mpd_jukebox";
my $sqlhost     =   "localhost";
### end db config ###

# also need to configurize this...
my %mpd_options = ();
$mpd_options{host}      = 'localhost';
$mpd_options{port}      = '6600';
$mpd_options{password}  = '';


sub read_config {
    my $config_file = shift;

    my %config = ();
    if (!-e $config_file) {
        print STDERR "configuration file $config_file: $!\n";
        exit 1;
    }
    if (open FILE,'<',$config_file) {
        while (<FILE>) {
            my $line = $_;
            next if ($line =~ /^\s*$/);
            next if ($line =~ /^\s*#/);
            my ($param,$value) = split(/=/,$line);
            $param =~ s/^\s*//g;
            $param =~ s/\s*$//g;
            $value =~ s/^\s*//g;
            $value =~ s/\s*$//g;
            $config{$param} = $value;
        }
    }
    return %config;
}

sub db_connect {
    my $dsn = "dbi:mysql:database=$sqldb;host=$sqlhost";
    my $dbh = DBI->connect($dsn,$sqluser,$sqlpass,{ RaiseError => 1 });
    return $dbh;
}

sub mpd_connect {
    my $mpd = Audio::MPD->new( \%mpd_options );
    return $mpd;
}

sub get_name {
    return $name;
}

sub get_mpd_collection {
    # returns an array of 'song items'
    # this takes a short while to process, call sparingly
    my $mpd = mpd_connect();
    return $mpd->collection->all_songs;
}

sub get_mpd_playlist {
    # returns an array of song items
    my $mpd = mpd_connect();
    return $mpd->playlist->as_items;
}

sub get_mpd_current_song {
    my $mpd = mpd_connect();
    return $mpd->song;
}

sub search_songs {
    # takes an array-reference of mpd song items, the field you want to search
    # (artist, title, genre, etc) and the query text as arguments...
    # returns an array of song items matching the query... very simple...
    my $songs   = shift;
    my $field   = shift;
    my $query   = shift;

    my @found = ();

    foreach my $song (@$songs) {
        if ($$song{$field} and $$song{$field} =~ /$query/i) {
            push @found, $song;
        }
    }
    return @found;
}

sub search_music {
    my $query   = shift;

    my $dbh = &db_connect();
    $query = $dbh->quote($query);

    my @songs = ();

    foreach my $type ('album', 'artist', 'song') {
        my $select = qq[ select ${type}_id from ${type}s
                        where $type like '%$query%' ];
        my $ids = $dbh->selectcol_arrayref($select);
        foreach my $id (@$ids) {
            my $select = qq[ select song_id from songs
                        where ${type}_id=$id ];
            my $song_ids = $dbh->selectcol_arrayref($select);
            foreach my $id (@$song_ids) {
                push @songs, $id;
            }
        }
    }
    my $song_hash = '';
    if (scalar(@songs) > 0) {
        my $select  = "select * from songs where song_id=";
           $select .= join(' or song_id=',@songs);
        $song_hash = $dbh->selectall_hashref($select,'song_id');
    }
    $dbh->disconnect;
    return $song_hash;
}

sub get_songs_from_other {
    my $type    = shift;
    my $id      = shift;

    return unless ($type =~ /(genre|album|artist)/);

    my $dbh = &db_connect();
    $id = $dbh->quote($id);
    my $select = qq{ select * from songs where ${type}_id=$id };
    my $songs_ref = $dbh->selectall_hashref($select,'song_id');
    my $info = '';
    if ($type =~ /album/) {
        my $select = "select album,artist_id from albums where album_id=$id";
        my ($album,$artist_id) = $dbh->selectrow_array($select);
        $id = $artist_id;
        $type = 'artist';
        $info = "$album by ";
    }
    $select = qq[ select $type from ${type}s where ${type}_id=$id ];
    my ($name) = $dbh->selectrow_array($select);

    return "$info$name",$songs_ref;
}

sub get_all_song_info {
    my $dbh = &db_connect();
    my $select = qq{ select * from songs };
    my $songs = $dbh->selectall_hashref($select,'song_id');
    $dbh->disconnect;
    return $songs;
} 

sub convert_playlist {
    my $playlist = shift;

    my %songs = ();
    foreach my $song (@$playlist) {
        my $song_hash = &get_song_by_file($$song{file});
        $songs{$$song_hash{song_id}} = $song_hash;
    }
    return \%songs;
}

sub get_song_by_id {
    my $song_id = shift;

    my $dbh = &db_connect();
    $song_id = $dbh->quote($song_id);
    my $select = qq{ select * from songs where song_id=$song_id };
    my $song_hash = $dbh->selectrow_hashref($select);
    $dbh->disconnect;
    return $song_hash;
}

sub get_song_by_file {
    my $file = shift;

    my $dbh = &db_connect();
    $file = $dbh->quote($file);
    my $select = qq{ select * from songs where file=$file };
    my $song_hash = $dbh->selectrow_hashref($select);
    $dbh->disconnect;
    return $song_hash;
}

sub get_name_by_id {
    my $type    = shift;
    my $id      = shift;

    my $dbh = &db_connect();
    my $select = qq[ select $type from ${type}s where ${type}_id=$id ];
    my ($name) = $dbh->selectrow_array($select);
    $dbh->disconnect;
    return $name;
}

sub get_information {
    my $key     = shift;
    my $table   = shift;

    # this causes duplicate data, hopefully memory doesn't become an issue
    # if it does... this could be a small memory extravagance.
    my $keyid = "${key}_id";
    my $dbh = &db_connect();
    my $select = qq{ select *,$keyid as id from $table };
    my $hashref = $dbh->selectall_hashref($select,$key);
    $dbh->disconnect;
    return $hashref;
}

sub get_file_from_id {
    my $song_id = shift;

    my $dbh = &db_connect();
    $song_id = $dbh->quote($song_id);
    my $select = qq{ select file from songs where song_id=$song_id };
    my ($file) = $dbh->selectrow_array($select);
    $dbh->disconnect;
    return $file;
} 

sub rm_song {
    my $file = shift;

    my $mpd = mpd_connect();
    my @playlist = $mpd->playlist->as_items;
    my $pos = -1;
    foreach my $song (@playlist) {
        $pos = $$song{pos} if ($$song{file} eq $file);
    }
    if ($pos != -1) {
        $mpd->playlist->delete($pos);
    }
    return undef;
}

sub add_song {
    my $file = shift;

    my $mpd = &mpd_connect();
    $mpd->playlist->add("$file");
    $mpd->play;
    # enable consume mode; track is removed from playlist after playing
    $mpd->_send_command("consume 1\n");
    return undef;
}

sub get_music_info {
    # takes an array-ref of song items, and finds all the unique entries for the
    # query. ideally you call it with a collection and 'genre' or 'artist' as
    # the query field to get all the different genres or artists in a collection
    # (or playlist, and any other sub-array of songs you might have...)
    my $songs   = shift;
    my $query   = shift;

    my %info_hash = ();
    foreach my $song (@$songs) {
        $info_hash{$$song{$query}} = 1 if ($$song{$query});
    }
    return sort keys %info_hash;
}

sub make_html_list {
    my $script  = shift;
    my $songs   = shift;
    my $field   = shift;

    my @items = get_music_info($songs,$field);
    
    my @list    = ();
    foreach my $item (@items) {
        my $url_item = uri_escape($item);
        my $url = "$script?field=$field&item=$url_item&action=list_songs";
        my $list_item = "<a href='$url'>$item</a><br/>\n";
        push @list, $list_item;
    }
    return join('',@list);
}

sub html_playlist {
    # quick, dirty hack to get an ordered playlist
    my $script = shift;

    my @links = ();
    my $mpd = &mpd_connect();
    my @playlist = $mpd->playlist->as_items;
    foreach my $song (@playlist) {
        my $song_hash = &get_song_by_file($$song{file});
        push @links, linkify_song($song_hash,$script);
    }
    return join('',@links);
}
        

sub html_songs_list {
    # hash reference
    my $songs   = shift;
    my $script  = shift;

    my @links = ();

    foreach my $song_id (keys %$songs) {
        my $song = $$songs{$song_id};
        push @links, linkify_song($song,$script);
    }
    return join('',@links);
}

sub linkify_song {
    my $song    = shift;
    my $script  = shift;

    my $dbh = &db_connect();
    my $select = "select artist from artists where artist_id=$$song{artist_id}";
    my ($artist) = $dbh->selectrow_array($select);
    $dbh->disconnect;

    my $url = "$script?action=show&song_id=$$song{song_id}";
    return "<a href='$url'>$artist - $$song{title}</a><br/>\n";
}
    
sub read_session {
    my $session = shift;

    my %data = ();
    foreach my $key ($session->param()) {
        $data{$key} = $session->param($key);
    }
    return \%data;
}

sub save_session {
    my $session = shift;
    my $data    = shift;

    foreach my $key (keys %$data) {
        $session->param($key,$$data{$key});
    }
    $session->flush();
}

sub validate_session {
    my $session = shift;

    my $user = $session->param('username') || '';
    my $hash = $session->param('password') || '';
    if ($user and $hash) {
        my $dbh = db_connect();
        my $userq = $dbh->quote($user);
        my $select = 'select password from users where username=' . $userq;
        my ($pass) = $dbh->selectrow_array($select);
        $dbh->disconnect;
        if ($pass and ($pass eq $hash)) {
            return 1;
        }
    }
    $session->delete();
    $session->flush();
    return 0;
}

sub get_session_errmsg {
    # method of passing error messages between pages
    # invalid options called for page X, redirect to
    # page Y after setting the session errmsg param
    my $session = shift;

    my $errmsg = '';
    if ($session->param('errmsg')) {
        $errmsg = '<p>error: ' . $session->param('errmsg') . '</p>';
        $session->clear('errmsg');
        $session->flush();
    }
    return $errmsg;
}

sub fisher_yates_shuffle {
    my $array = shift;
    my $i;
    return if (@$array < 2);
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
}

sub reset_session {
    my $session = shift;

    my %data = ();
    foreach my $key ($session->param()) {
        $data{$key} = $session->param($key);
    }

    $session->clear();
    $session->param('username',$data{username});
    $session->param('password',$data{password});
    $session->param('_SESSION_ID',$data{_SESSION_ID});
    $session->param('_SESSION_ATIME',$data{_SESSION_ATIME});
    $session->param('_SESSION_REMOTE_ADDR',$data{_SESSION_REMOTE_ADDR});
    $session->param('_SESSION_EXPIRE_LIST',$data{_SESSION_EXPIRE_LIST});
    $session->param('_SESSION_CTIME',$data{_SESSION_CTIME});
    $session->flush();
}

sub page_start {
    my $title = shift;
    my $extraheaders = shift;
    $extraheaders = "" unless ($extraheaders);

    print <<ENDL;
Content-Type: text/html; charset=ISO-8859-1
Cache-Control: no-cache, no-store, must-revalidate
$extraheaders

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0;">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black">
    <title>$title</title>
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
    <link rel="icon" href="mpd.ico" type="image/x-icon">
    <link rel="shortcut icon" href="mpd.ico" type="image/x-icon">
    <script type='text/javascript' src='jukebox.js'></script>
    <style type="text/css">\@import "style.css";</style>
  </head>
  <body>
ENDL
}

sub get_session {
    CGI::Session->name($cgi_session);
    return CGI::Session->load();
}

sub login {
    my $user = shift;
    my $hash = shift;
    my $session = shift;

    $session = $session->new() or die $session->errstr;
    $session->param('username', $user);
    $session->param('password', $hash);
    $session->expire('~logged-in', '30m');
    $session->flush();
    my $cgi = CGI->new;
    my $cookie = $cgi->cookie(-name=>$session->name,-value=>$session->id);
    print $session->header(-location=>'index.pl',-cookie=>$cookie);
}

1;
__END__
