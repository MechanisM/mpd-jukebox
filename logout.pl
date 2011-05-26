#!/usr/bin/perl

use strict;
use warnings;

use CGI::Session qw/-ip_match/;
use CGI::Carp qw/fatalsToBrowser/;

use Jukebox;

my $session = Jukebox::get_session();

$session->delete();
$session->flush();
print $session->header(-location=>'index.pl');

exit;
