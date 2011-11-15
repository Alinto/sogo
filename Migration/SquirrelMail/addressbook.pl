#!/usr/bin/perl

# Copyright 2011 Inverse inc.
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html

=head1 NAME

addressbook.pl - import addressbooks from SquirrelMail

=head1 SYNOPSIS

addressbook.pl --help

addressbook.pl --config <path> [--username <username>] [--verbose=<0,1,2] <filename>

=head1 DESCRIPTION

This script imports SquirrelMail .abook files into SOGo.

=head1 AUTHOR

=over

=item Francis Lachapelle <flachapelle@inverse.ca>

=back

=head1 COPYRIGHT

Copyright (c) 2011 Inverse inc

This program is available under the GPL.

=cut

use diagnostics;
use strict;
use warnings;

use Config::Simple;
use Pod::Usage;
use Getopt::Long;
use Log::Log4perl;
use Digest::MD5 qw(md5_hex);
use HTTP::Request;
use LWP::UserAgent;
use MIME::Base64;
use XML::Simple;

$| = 1;

# Global variables
my $help = undef;
my $conffile = undef;
my $forceusername = undef;
my $username = undef;
my $pwdhash = undef;
my $folder_destination = undef;
my $logLevel = 1;
my @files = ();
my $ua = undef;

my $cardtemplate = <<EOF
BEGIN:VCARD
VERSION:3.0
PRODID:%s
UID:%s
FN:%s
NICKNAME:%s
EMAIL:%s
NOTE:%s
END:VCARD
EOF
;
my $prodid = "-//Inverse inc.//SOGo SquirrelMail Importer 1.0//EN";

GetOptions(
           "config|c:s" => \$conffile,
           "username|u:s" => \$forceusername,
           "<>" => \&addFile,
           "help|?" => \$help,
           "verbose|v:i" => \$logLevel,
          ) or pod2usage( -verbose => 1);

pod2usage( -verbose => 2) if $help;
pod2usage( -verbose => 1) unless ($conffile && scalar(@files) > 0);

if ($logLevel == 0) {
    $logLevel = 'WARN';
} elsif ($logLevel == 1) {
    $logLevel = 'INFO';
} else {
    $logLevel = 'DEBUG';
}
my $logConf = <<END;
log4perl.rootLogger = $logLevel, Logfile
log4perl.appender.Logfile = Log::Log4perl::Appender::Screen
log4perl.appender.Logfile.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Logfile.layout.ConversionPattern = %d %p> %m%n
END

Log::Log4perl->init( \$logConf );
my $logger = Log::Log4perl->get_logger('');

#
# Read preferences from file
#
my $cfg = new Config::Simple($conffile);

#
# Verify configuration paramaters
#
foreach ('sogo.url', 'sogo.username', 'sogo.password', 'addressbooks.folder_destination') {
  unless ($cfg->param($_)) {
    if (m/^(.+)\.(.+)$/) {
      $logger->error("The paramter '$2' in the block [$1] is not defined in the configuration file $conffile");
      exit 0;
    }
  }
}

# Remove last slash of URL if defined
if (substr($cfg->param('sogo.url'), -1, 1) eq '/') {
  my $url = $cfg->param('sogo.url');
  chop $url;
  $cfg->param('sogo.url', $url);
}

# Build password hash
$pwdhash = encode_base64($cfg->param('sogo.username') . ':' . $cfg->param('sogo.password'));

$username = $forceusername if ($forceusername);

$ua = LWP::UserAgent->new();
$ua->agent('Mozilla/5.0');
$ua->timeout(1800);

foreach my $filename (@files) {
  processFile($filename);
}

#
# Subroutines
#

sub addFile {
  my $filename = shift;
  
  push(@files, $filename);
}

sub processFile {
  my $filename = shift;
  my $url = undef;
  my $count = 0;
  my $err = 0;

  unless ($forceusername) {
    if ($filename =~ m/^(.+)(\.[^\.]+)$/) {
      $username = $1;
    }
    else {
      $username = undef;
    }
  }
  unless ($username) {
    $logger->warn("Can't identify owner of file $filename");
    return;
  }
  if ($url = &addressBookExists($username, $cfg->param('addressbooks.folder_destination'))) {
    $logger->warn("[$username] Addressbook \"".$cfg->param('addressbooks.folder_destination')."\" already exists ($url)");
  }
  else {
    $logger->info("[$username] Addressbook \"".$cfg->param('addressbooks.folder_destination')."\" doesn't exist");
    $url = &createAddressBook($username, $cfg->param('addressbooks.folder_destination'));
  }

  if ($url) {
    if (open (FILE, $filename)) {
      while (<FILE>) {
        chomp;
        next unless length;
        my ($nickname, $givenname, $surname, $mail, $note) = split(/\|/);
        my $uid = md5_hex($_);
        my $card = sprintf($cardtemplate, $prodid, $uid, "$surname $givenname", $nickname, $mail, $note);

        $count++;
        $err++ unless (&createContact($uid,
                                      $url . $uid . ".vcf",
                                      $card));
      }
      close FILE;
    
      $logger->info("[$username] Imported $filename: $count contacts ($err skipped)");
    }
    else {
      $logger->error("Can't open $filename: $!");
    }
  }
  else {
    $logger->error("[$username] File $filename skipped (missing destination addressbook)");
  }
}

sub url {
  my ($username) = @_;

  return  $cfg->param('sogo.url') . "/SOGo/dav/$username/Contacts/";
}

sub addressBookExists
{
  my ($username, $addressbook) = @_;
  
  my $result = 0;
  my $propfind = <<XML
<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <displayname/>
  </prop>
</propfind>
XML
;
  my $request = HTTP::Request->new();
  $request->method('PROPFIND');
  $request->uri(&url($username));
  $request->header('Content-Type' => 'text/xml; charset=utf8');
  $request->header('Content-Length' => length($propfind));
  $request->header('Depth' => 1);
  $request->header('Authorization' => "Basic $pwdhash");
  $request->content($propfind);
  
  my $response = &httpRequest($request, $username);
  if ($response) {
    my $xml = XMLin($response);
    foreach my $ab (@{$xml->{'D:response'}}) {
      my $displayname = $ab->{'D:propstat'}->{'D:prop'}->{'D:displayname'};
      $logger->debug("[$username] Found addressbook \"$displayname\"");
      if ($addressbook eq $displayname) {
        $result = $cfg->param('sogo.url') . $ab->{'D:href'};
        last;
      }
    }
  }
  
  return $result;
}

sub createAddressBook {
  my ($username, $addressbook) = @_;
  
  my $result = 0;
  my $uid = md5_hex(localtime);
  my $url = &url($username) . $uid;
  my $proppatch = <<XML
<?xml version="1.0" encoding="utf-8"?>
<propertyupdate xmlns="DAV:">
  <set>
    <prop>
      <displayname>%s</displayname>
    </prop>
  </set>
</propertyupdate>
XML
;

  my $request = HTTP::Request->new();
  $request->method('MKCOL');
  $request->uri($url);
  $request->header('Authorization' => "Basic $pwdhash");
  
  my $response = &httpRequest($request, $username);
  if ($response) {
    $proppatch = sprintf($proppatch, $addressbook);
    $request = HTTP::Request->new();
    $request->method('PROPPATCH');
    $request->uri($url);
    $request->header('Content-Type' => 'text/xml; charset=utf8');
    $request->header('Content-Length' => length($proppatch));
    $request->header('Depth' => 0);
    $request->header('Authorization' => "Basic $pwdhash");
    $request->content($proppatch);
  
    $response = &httpRequest($request, $username);
    if ($response) {
      $logger->info("[$username] Addressbook \"$addressbook\" created ($url)");
      $result = $url  . '/';
    }
  }
  
  return $result;  
}

sub createContact {
  my ($uid, $url, $card) = @_;

  my $request = HTTP::Request->new();
  $request->method('PUT');
  $request->uri($url);
  $request->header('Content-Type' => 'text/vcard; charset=utf-8');
  $request->header('Content-Length' => length($card));
  $request->header('Authorization' => "Basic $pwdhash");
  $request->content($card);
  
  return (&httpRequest($request, $uid));
}

sub httpRequest {
  my ($request, $uid) = @_;

  my $result = undef;
  my $i;
  for ($i = 0; $i < 30; $i++) {
    my $response = $ua->request($request);
    if ($response->is_success) {
      $logger->debug("[$username] HTTP request " . $request->method . " $uid: " . $response->status_line);
      $result = $response->decoded_content || 1;
      last;
    }
    else {
      $logger->warn("[$username] HTTP request " . $request->method . " $uid: " . $response->status_line);
      if ($response->code == 500) {
        $logger->warn("[$username] HTTP request " . $request->method . " $uid: sleeping 2 secs");
        sleep(2);
      }
      else {
        $result = 0;
        last;
      }
    }
  }
  
  if ($i == 30) {
    $logger->error("[$username] HTTP request " . $request->method . " $uid: Can't reach server for the past 60 secs - exiting.");
    exit(-4);
  }
  
  return $result;
}
