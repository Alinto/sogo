#!/usr/bin/env perl

use strict;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP;
use Email::Simple;
use Email::Simple::Creator;
use MIME::QuotedPrint;

my $to = '<users@sogo.nu>';
my $from = '"SOGo Reporter" <smizrahi@alinto.eu>';
my $file = 'mail.html';

my $version;
my @lines;
my $body;
my $email;
my $transport;

# Check command-line arguments
unless (@ARGV > 0) {
    print "\nUsage: $0 <version> [<recipient>]\n";
    exit 0;
}
$version = $ARGV[0];
$to = '<' . $ARGV[1] . '>' if ($ARGV[1]);
# Load HTML file
open(HTML, $file) or die;
@lines = <HTML>;
chomp @lines;
$body = join("", @lines);
close(HTML);

# Send mail
$email = Email::Simple->create(
    header => [
        To                          => $to,
        From                        => $from,
        Subject                     => "ANN: SOGo v$version released!",
        'Content-Type'              => 'text/html',
        'Content-Transfer-Encoding' => 'quoted-printable'
    ],
    body => encode_qp($body)
);
#sendmail($email);
$transport = Email::Sender::Transport::SMTP->new({
  host => '192.168.32.89',
  port => 25,
});
sendmail($email, { transport => $transport });
