use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

use DBI;
use IPC::System::Simple qw(capture system);
use Data::Munge;

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
    my $brain = Irssi::settings_get_str("brain_public_location");
    my $min_delay = Irssi::settings_get_int("public_min_delay");
    my $max_delay = Irssi::settings_get_int("public_max_delay");
    return unless (length $brain && -e $brain);

    if (!$queue{$target}) {
        # schedule a response
        my $rand_time = int(rand($max_delay - $min_delay)) + $min_delay;
        Irssi::print("Response for \x02$target\x02 scheduled for \x02$rand_time\x02 seconds.");
        my $response = generate_response($msg, $brain);
        Irssi::timeout_add_once($rand_time * 1000, "toalleitor", [$target, $response]);
        $queue{$target} = 1;
    }

    pusher("public", $nick, $address, $target, $msg);
}

sub private_handler {
    my ($server, $msg, $nick, $address) = @_;
    my $brain = Irssi::settings_get_str("brain_private_location");
    my $min_delay = Irssi::settings_get_int("private_min_delay");
    my $max_delay = Irssi::settings_get_int("private_max_delay");
    return unless (length $brain && -e $brain);

    if ($msg =~ m/http/i) {
        Irssi::print("Silencing \x02$nick\x02: they spammed me!");
        $server->command("silence +$nick!*@*");
        return;
    }

    if (!$queue{$nick} && $address !~ m/chathispano\.com$/) {
        # schedule a response
        my $rand_time = int(rand($max_delay - $min_delay)) + $min_delay;
        Irssi::print("Response for \x02$nick\x02 scheduled for \x02$rand_time\x02 seconds.");
        my $response = generate_response($msg, $brain);
        Irssi::timeout_add_once($rand_time * 1000, "toalleitor", [$nick, $response]);
        $queue{$nick} = 1;
    }

    pusher("private", $nick, $address, "", $msg);
}

sub toalleitor {
    my ($data) = @_;
    my ($target, $msg) = @$data;
    my $blacklist_channels = Irssi::settings_get_str("blacklist_channels");
    my $blacklist_words = Irssi::settings_get_str("blacklist_words");

    if (elem($target), [split(" ", $blacklist_channels)]) {
        foreach (split(" ", $blacklist_words)) {
            $msg =~ s/$_/ouch/gi;
        }
        $msg = lc $msg
    }

    $msg = clean_colours($msg);
    Irssi::active_win()->command("msg $target $msg") if (length $msg);
    delete $queue{$target};
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

# locations of brains
Irssi::settings_add_str("mumbler", "brain_public_location", "");
Irssi::settings_add_str("mumbler", "brain_private_location", "");
# channels where blacklist will be applied
Irssi::settings_add_str("mumbler", "blacklist_channels", "");
# words that cannot be said in those channels
Irssi::settings_add_str("mumbler", "blacklist_words", "");
# min/max time
Irssi::settings_add_int("mumbler", "public_min_delay", 15);
Irssi::settings_add_int("mumbler", "public_max_delay", 30);
Irssi::settings_add_int("mumbler", "private_min_delay", 5);
Irssi::settings_add_int("mumbler", "private_max_delay", 10);

Irssi::signal_add("message public", "public_handler");
Irssi::signal_add("message private", "private_handler");