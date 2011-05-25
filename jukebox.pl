#!/usr/bin/perl

use strict;
use warnings;

use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;
use CGI::Session qw/-ip_match/;

use Jukebox;

my $session = Jukebox::get_session();

# redirect to the index unless we have a valid session
print $session->header(-location=>'index.pl')
        unless (Jukebox::validate_session($session));

# retrieve and clear stored error message from the session data
my $errmsg = Jukebox::get_session_errmsg($session);

my $data = Jukebox::read_session($session);


