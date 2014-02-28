use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

use DBI;
use IPC::System::Simple qw(capture system);

$VERSION = "1.0";
%IRSSI = (
    authors => "",
    contact => "",
    name => "",
    description => "",
    license => "",
    url => "",
);

my ($dbh, %queue);

sub initialise_db {
    Irssi::print("Connecting to the database...");
    eval {
        $dbh = DBI->connect("dbi:mysql:dbname=terra", "terra", "terra");
    };
    if ($@) {
        Irssi::print("Alright, I couldn't...");
    }
}

sub public_handler {
    my ($server, $msg, $nick, $address, $target) = @_;

    pusher("public", $nick, $address, $target, $msg);

    return unless $target eq "#terra_chat";

    if ($msg !~ m/http/i) {
        my @args = ("-b", "/home/wodim/cobe-terra/cobe-public.brain", "learn-single", clean_colours($msg));
        eval { system("cobe", @args); }; Irssi::print("Error learning from a public message: $msg") if $@;
    }
}

sub private_handler {
    my ($server, $msg, $nick, $address) = @_;

    if ($msg =~ m/http/i) {
        Irssi::print("Silencing \x02$nick\x02: they spammed me!");
        $server->command("silence +$nick!*@*");
        return;
    }

    if (!$queue{$nick} && $address !~ m/chathispano\.com$/) {
        # schedule a response
        my $rand_time = int(rand(5)) + 5;
        Irssi::print("Response for \x02$nick\x02 scheduled for \x02$rand_time\x02 seconds.");
        my $first_response = generate_response($msg, "/home/wodim/cobe-terra/cobe-private.brain");
        Irssi::timeout_add_once($rand_time * 1000, "toalleitor", [$nick, $first_response]);

        # possible second response
        my $response_duo = int(rand(100));
        if ($response_duo < 20) { # ~20%
            my $rand_time_duo = int(rand(3)) + 1;
            Irssi::print("Response (duo) for \x02$nick\x02 scheduled for \x02+$rand_time_duo\x02 seconds.");
            my $response = generate_response($msg, "/home/wodim/cobe-terra/cobe-private.brain");
            if ($response eq $first_response) { # dont repeat yourself
                Irssi::print("Response (duo) for \x02$nick\x02 unscheduled (duplicate)");
            } else {
                Irssi::timeout_add_once(($rand_time + $rand_time_duo) * 1000, "toalleitor", [$nick, $response]);
            }
        }
        $queue{$nick} = 1;
    }

    pusher("private", $nick, $address, "", $msg);

    if ($msg !~ m/http/i) {
        my @args = ("-b", "/home/wodim/cobe-terra/cobe-private.brain", "learn-single", clean_colours($msg));
        eval { system("cobe", @args); }; Irssi::print("Error learning from a private message: $msg") if $@;
    }
}

sub toalleitor {
    my ($data) = @_;
    my ($nick, $msg) = @$data;

    if ($msg ne "") {
        Irssi::active_win()->command("msg $nick ".clean_colours($msg));
    }
    delete $queue{$nick};
}

sub pusher {
    my ($table, $nick, $address, $target, $message) = @_;

    eval {
        my $sth = $dbh->prepare("
            INSERT INTO $table (nick, address, target, message, date)
            VALUES (?, ?, ?, ?, NOW())
        ");
        $sth->bind_param(1, $nick);
        $sth->bind_param(2, $address);
        $sth->bind_param(3, $target);
        $sth->bind_param(4, $message);
        $sth->execute();
    };
    if ($@) {
        Irssi::print("Bad luck. I can't push to the database. I will try to reconnect...");
        initialise_db();
    }
}

sub clean_colours {
    my ($text) = @_;

    $text =~ s/\x02|\x1f//g;
    $text =~ s/\x03\d\d?(,\d\d?)?//g;

    $text;
}

sub generate_response {
    my ($text, $brain) = @_;

    my @args = ("-b", $brain, "oneliner", "--text", clean_colours($text));
    my $response = "";
    eval {
        $response = capture("cobe", @args);
    };
    if ($@) {
        Irssi::print("Error generating a response...");
    }

    $response;
}

initialise_db();

Irssi::signal_add("message public", "public_handler");
Irssi::signal_add("message private", "private_handler");