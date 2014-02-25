use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

use DBI;

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
    
    return unless $target eq "#terra_chat" or $target eq "#irc-hispano";
    pusher('public', $nick, $address, $target, $msg);
}

sub private_handler {
    my ($server, $msg, $nick, $address, $target) = @_;
    
    if (!$queue{$nick} && $address !~ m/chathispano\.com$/) {
        my $rand_time = int(rand(10)) + 5;
        Irssi::timeout_add_once($rand_time * 1000, 'toalleitor', $nick);
        $queue{$nick} = 1;
    }
    # pusher('private', $nick, $address, $target, $msg);
}

sub toalleitor {
    my ($nick) = @_;
    my $text;
    
    do {
        open(f, '/home/wodim/.irssi/scripts/toalla.txt') or Irssi::print "Error: no se pudo leer el archivo, fail.";
        srand;
        rand($.) < 1 && ($text = $_) while <f>;
        close(f);
    } while(length($text) < 1 || $text =~ m/NICK|CHAN|NETWORK|BBBBB|CCCCC|DDDDD|EEEEE/);

    $nick =~ s/\s+$//;
    $text =~ s/\\o/SALUDONAZI/g;
    $text =~ s/\\%1%/, /g;
    $text =~ s/\\/, /g;
    $text =~ s/SALUDONAZI/\\o/g;
    $text =~ s/^(%1%|AAAAA)\s//g;
    $text =~ s/%1%|AAAAA/$nick/g;

    Irssi::active_win()->command('msg '.$nick.' '.$text);
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

initialise_db();

Irssi::signal_add('message public', 'public_handler');
Irssi::signal_add('message private', 'private_handler');