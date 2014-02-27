use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

use DBI;
use IPC::System::Simple qw(capture system);

$VERSION = '1.0';
%IRSSI = (
    authors => '',
    contact => '',
    name => '',
    description => '',
    license => '',
    url => '',
);

my ($dbh, %queue);

sub initialise_db {
    $dbh = DBI->connect('dbi:mysql:dbname=terra', 'terra', 'terra');
}

sub public_handler {
    my ($server, $msg, $nick, $address, $target) = @_;

    pusher('public', $nick, $address, $target, $msg);

    return unless $target eq "#terra_chat";

    if ($msg !~ m/http/i) {
        my @args = ("-b", "/home/wodim/cobe-terra/cobe-public.brain", "learn-single", clean_colours($msg));
        eval { system("cobe", @args); }; Irssi::print("Error generating a response...") if $@;
    }
}

sub private_handler {
    my ($server, $msg, $nick, $address) = @_;

    if (!$queue{$nick} && $address !~ m/chathispano\.com$/) {
        my $rand_time = int(rand(5)) + 5;
        Irssi::print("Response for \x02$nick\x02 scheduled for \x02$rand_time\x02 seconds.");
        Irssi::timeout_add_once($rand_time * 1000, 'toalleitor', [$nick, $msg]);
        $queue{$nick} = 1;
    }

    pusher('private', $nick, $address, "", $msg);

    if ($msg !~ m/http/i) {
        my @args = ("-b", "/home/wodim/cobe-terra/cobe-private.brain", "learn-single", clean_colours($msg));
        eval { system("cobe", @args); }; Irssi::print("Error generating a response...") if $@;
    }
}

sub toalleitor {
    my ($data) = @_;
    my ($nick, $msg) = @$data;
    my $text;

    my @args = ("-b", "/home/wodim/cobe-terra/cobe-private.brain", "oneliner", "--text", clean_colours($msg));
    my $text = "";
    eval { $text = capture("cobe", @args); }; Irssi::print("Error generating a response...") if $@;

    if ($text ne "") {
        Irssi::active_win()->command('msg '.$nick.' '.clean_colours($text));
    }
    delete $queue{$nick};
}

sub pusher {
    my ($table, $nick, $address, $target, $message) = @_;

    my $sth = $dbh->prepare("
        INSERT INTO $table (nick, address, target, message, date)
        VALUES (?, ?, ?, ?, NOW())
    ");
    $sth->bind_param(1, $nick);
    $sth->bind_param(2, $address);
    $sth->bind_param(3, $target);
    $sth->bind_param(4, $message);

    if (!$sth->execute()) {
        initialise_db();
    }
}

sub clean_colours {
    my ($text) = @_;

    $text =~ s/\x02|\x1f//;
    $text =~ s/\x03\d\d?(,\d\d?)?//;

    $text;
}

initialise_db();

Irssi::signal_add('message public', 'public_handler');
Irssi::signal_add('message private', 'private_handler');