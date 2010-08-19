#!/usr/bin/perl

use strict;
use warnings;

use Time::Local;
use Time::localtime;
use Getopt::Long qw(:config bundling);
use HTTP::Request;
use LWP::UserAgent;
use Math::BigInt;
use Digest::MD5 qw(md5_hex);
use MIME::QuotedPrint;
use MIME::Base64;
use Net::LDAP;
use Time::HiRes qw (gettimeofday tv_interval);

use constant {
    QUOTED_PRINTABLE   => 'auto',
         # 0 : never decode data
         # 1 : always decode data
         # auto : try to guess from the file headers

    OWNER => undef,
	 # undef : use event organizer as the owner
	 # <username> : force owner to be username

    DUPLICATES => 'update',
         # create : create a new entry if the UID already exists
         # ignore : don't create the event if the UID already exists
         # update : update the entry with the same UID (if deleted, stays deleted)
         # replace : if the entry exists and was deleted, resurect it
    RECURRENT => 0,
         # smart : group new events with same UID as one recurrent event

    LDAP_HOST => 'ldap://ldap.foobar.edu',
    LDAP_BIND_DN => 'uid=sogo,ou=applications,dc=foobar,dc=edu',
    LDAP_BIND_PW => 'PASSWORD',
    LDAP_BASE => 'ou=people,dc=foobar,dc=edu',
    LDAP_USERNAME => 'uid',
    LDAP_EMAIL => 'mail',
    LDAP_EMAIL_FILTER => '(|(mail=%s)(mailAlternateAddress=%s))',

    FORCE_USERNAME => undef,
    FORCE_CLOSE => 0,
    DRYRUN => 0,
    DEBUG => 1
};

$| = 1;

# Global variables
my $file;
my ($username, $email);
my $url;
my ($host, $port, $authusername, $password);
my $ua;
my $ldap;
my %duplicatedUID = ();
my $pwdhash;

my $timezone = <<_EOF;

BEGIN:VTIMEZONE
TZID:/inverse.ca/20091015_1/America/New_York
X-LIC-LOCATION:America/New_York
BEGIN:DAYLIGHT
TZOFFSETFROM:-0500
TZOFFSETTO:-0400
TZNAME:EDT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:-0400
TZOFFSETTO:-0500
TZNAME:EST
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
END:STANDARD
END:VTIMEZONE
_EOF

sub usage
{
    my $msg = shift;

    print "$msg\n" if ($msg);
    print "Usage: $0 <url> <username> <type> <filename>\n";
    print "  <url>       must have the form http[s]://[superuser]:[password]\@hostname\n";
    print "              The full URL will be build using the username.\n";
    print "  <type>      must be 'events', 'tasks' or 'rights' to specify the type of data\n";
    print "  <filename>  must have the form <type>.<username>\n";
    print "\n";
}

sub getEmailByUsername
{
    my ($ldap, $username) = @_;

    my $results = $ldap->search(base => LDAP_BASE,
				filter => '('.LDAP_USERNAME.'='.$username.')',
				attrs => [(LDAP_EMAIL)]);
    if ($results->count != 1) {
	print "Unexpected number of LDAP entries (",$results->count,") for $username\n";
	return 0;
    }
    my $entry = $results->entry(0);

    return $entry->get_value(LDAP_EMAIL);
}

my %emailToUserName;

sub getUsernameByEmail
{
    my ($ldap, $email) = @_;

    if (!defined($emailToUserName{$email})) {
	my $results = $ldap->search(base => LDAP_BASE,
				    filter => sprintf(LDAP_EMAIL_FILTER, $email, $email),
				    attrs => [(LDAP_USERNAME)]);
	if ($results->count != 1) {
	    print "Unexpected number of entries return for $email\n";
	    return 0;
	}
	my $entry = $results->entry(0);
	$emailToUserName{$email} = $entry->get_value(LDAP_USERNAME);
    }

    return $emailToUserName{$email};
}

sub calendarUrl
{
    my $username = $_[0];
    my $uid = $_[1] || "";

    return "$url/SOGo/dav/$username/Calendar/personal/$uid";
}

sub httpRequest
{
    my ($request, $uid) = @_;

    my $result = 1;
    my $i;
    for ($i = 0; $i < 30; $i++) {
	my $response = $ua->request($request);
	if ($response->is_success) {
	    print $request->method, " $uid:\t", $response->status_line, "\n";
	    last;
	}
	else {
	    print STDERR "ERR ", $request->method, " $uid:\t", $response->status_line, "\n";
	    if ($response->code == 500) {
		print STDERR "INFO sleeping 2 secs\n";
		sleep(2);
	    }
	    else {
		$result = 0;
		last;
	    }
	}
    }

    if ($i == 30) {
	print STDERR "ERR ", $request->method, " $uid:\tCan't reach server for the past 60 secs - exiting.\n";
	exit(-4);
    }

    return $result;
}

sub userCalendarExists
{
    my ($username) = @_;
    my $result = 0;

    my $propfind = '<?xml version="1.0" encoding="utf-8"?><D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>';
    my $request = HTTP::Request->new();
    $request->method('PROPFIND');
    $request->uri(&calendarUrl($username));
    $request->header('Content-Type' => 'text/xml; charset=utf8');
    $request->header('Content-Length' => length($propfind));
    $request->header('Depth' => 0);
    $request->header('Authorization' => "Basic $pwdhash");
    $request->content($propfind);

    $result = &httpRequest($request, $username);

    return $result;
}

sub searchByUid
{
    my ($username, $uid) = @_;
    my $result = 0;

    my $request = HTTP::Request->new();
    $request->method('GET');
    $request->uri(&calendarUrl($username, $uid));

    $result = &httpRequest($request, $uid);

    return $result;
}

sub deleteEvent()
{
    my ($username, $uid) = @_;
    my $result = 0;

    return $result if (DRYRUN);

    my $request = HTTP::Request->new();
    $request->method('DELETE');
    $request->uri(&calendarUrl($username, $uid));

    $result = &httpRequest($request, $uid);

    return $result;
}

sub putEvent(\%)
{
    my (%vevent) = %{(shift)};
    my $count = shift;

    my $uid = $vevent{'uid'};

    # decode data
    $vevent{'data'} =~ s/\r//g;
    $vevent{'data'} =~ s/([^=])\n /$1/g;
    if (QUOTED_PRINTABLE eq '1' || 
	(QUOTED_PRINTABLE eq 'auto' && $vevent{'encoding'} && $vevent{'encoding'} =~ m/quoted-printable/)) {
	$vevent{'data'} = decode_qp($vevent{'data'});
    }

    # for "notes", we need to add one day to the DTEND
    my $oracleEventType;
    if ($vevent{'data'} =~ /X-ORACLE-EVENTTYPE:(.*)/) {
	$oracleEventType = $1;
    } else {
	$oracleEventType = "unknown";
    }
    if ($oracleEventType eq 'DAILY NOTE') {
#	if ($vevent{'data'} =~ /DTEND;VALUE=DATE:(\d{4})(\d{2})(\d{2})/) {
#	    my ($mday,$mon,$year) = ($3, $2, $1);
#	    my $seconds = timelocal(0, 0, 0, $mday, $mon - 1, $year - 1900);
#	    $seconds += 86400;
#	    # we specify "CORE::" because we expect an array instead of a
#	    # magical hash
#	    my @newLocalTime = CORE::localtime($seconds);
#	    $mday = $newLocalTime[3];
#	    $mon = $newLocalTime[4] + 1;
#	    $year = $newLocalTime[5] + 1900;
#	    my $newEndDate = sprintf("%.4d%.2d%.2d", $year, $mon, $mday);
#	    my $dtEndPrefix = "DTEND;VALUE=DATE:";
#	    my $dtEndIndex = index $vevent{'data'}, $dtEndPrefix;
#	    if ($dtEndIndex > -1) {
#		my $partLength = $dtEndIndex + length($dtEndPrefix);
#		$vevent{'data'} = sprintf("%s%s%s",
#					  substr($vevent{'data'}, 0, $partLength),
#					  $newEndDate,
#					  substr($vevent{'data'}, $partLength + 8));
#	    }
#	}

	# we set a timezone for dates in all day events to ensure that SOGo
	# does not put them in UTC
	$vevent{'data'} =~ s@BEGIN:VEVENT@${timezone}BEGIN:VEVENT@;
	$vevent{'data'} =~ s@DTSTART;VALUE=DATE:@DTSTART;VALUE=DATE;TZID=/inverse.ca/20091015_1/America/New_York:@;
	$vevent{'data'} =~ s@DTEND;VALUE=DATE:@DTEND;VALUE=DATE;TZID=/inverse.ca/20091015_1/America/New_York:@;
    }

    # parse attendees
    my $hasAttendees = 0;
    while ($vevent{'data'} =~ m/ATTENDEE;(.+)$/gm) {
	my @parameters = split(';', $1);
	$vevent{'attendees'} = [] unless ($vevent{'attendees'});
	my %attendee = ();
	foreach (@parameters) {
	    #print $_,"\n";
	    if (m/^(\S+)=(.+)$/) {
		print "\t$1 => $2\n";
		$attendee{$1} = $2;
		if ($1 eq 'CN' && $2 =~ m/mailto:(\S+)$/) {
		    $attendee{'CN'} = $1;
		    $attendee{'username'} = &getUsernameByEmail($ldap, $1);
		    $hasAttendees = 1 if ($1 ne $email); # Attendee is not the owner
		}
	    }
	}
	push(@{$vevent{'attendees'}}, \%attendee);
    }

    # handle duplicated UID within file
    if ($duplicatedUID{$uid}) {
	$uid .= $duplicatedUID{$uid};
	$duplicatedUID{$vevent{'uid'}}++;
    }
    else {
	$duplicatedUID{$uid} = 1;
    }

    unless (DUPLICATES eq 'update') {
	if (&searchByUid($username, $uid)) {
	    print STDERR "Event with UID '$uid' already exists\n";
	    return 0 if (DUPLICATES eq 'ignore');

	    if (DUPLICATES eq 'replace') {
		&deleteEvent($username, $uid);
	    }
#	    elsif ($hasAttendees) {
#		print STDERR "UID collision (",$uid,") for an event with attendee(s); ignoring it\n";
#		return 0;
#	    }
	    else {
		# Make sure UID is unique (DUPLICATES eq 'create')
		my $i = ($duplicatedUID{$vevent{'uid'}})?$duplicatedUID{$vevent{'uid'}}:1;
		for ($uid .= $i;
		     &searchByUid($username, $uid) == 1;
		     print STDERR "Event with UID '$uid' already exists\n", 
		     $uid = $vevent{'uid'} . $i, 
		     $i++)
		{};
		$duplicatedUID{$vevent{'uid'}} = $i + 1;
	    }
	}
    }

    # If UID already exists, change it in the VEVENT
    if ($uid ne $vevent{'uid'}) {
	$vevent{'data'} =~ s/^UID:\S+$/UID:$uid/m;
    }

    if ($vevent{'data'} =~ m/^SUMMARY:[;\s]*$/m) {
	$vevent{'data'} =~ s#^(BEGIN:VEVENT)#$1\nSUMMARY: (untitled event)#m;
    }

    if ($vevent{'recurrent'}) {
	$vevent{'data'} =~ s#^(BEGIN:VEVENT)#$1\nRRULE:FREQ=DAILY;COUNT=1;INTERVAL=1#m;
    }

    $vevent{'data'} = 
	"BEGIN:VCALENDAR\n" .
	"VERSION:2.0\n" .
	"PRODID:Oracle/Oracle Calendar Server 10.1.2.3.3\n" .
	$vevent{'data'} .
	"END:VCALENDAR";

    if (DEBUG) {
	foreach my $key (keys %vevent) {
	    if (ref($vevent{$key}) eq 'ARRAY') {
		print "$key =>\n";
		foreach (@{$vevent{$key}}) {
		    my %hash = %{$_};
		    print " =>";
		    foreach (keys %hash) {
			print "\t$_ => $hash{$_}\n";
		    }
		}
	    }
	    else {
		print "$key = \n\t", $vevent{$key},"\n";# unless ($key eq 'data');
	    }
	}
    }
    print "PUT ",&calendarUrl($username, $uid),"\n";

    return 0 if (DRYRUN);

    my $request = HTTP::Request->new();

    $request->method('PUT');
    $request->uri(&calendarUrl($username, $uid));

    $request->header('Authorization' => "Basic $pwdhash");

    #$request->header('Accept-Charset' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7');
    #$request->header('Accept-Language' => 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3');
    #$request->header('Content-Type' => 'text/plain; charset=utf-8');
    $request->header('Content-Type' => 'text/calendar; charset=utf-8');
    $request->header('Content-Length' => length($vevent{'data'}));
    $request->header('x-sogo-mode' => 'M');
    #$request->header('Connection' => 'TE');
    if (FORCE_CLOSE && ($count % FORCE_CLOSE) == 0) {
	print "Force connection close (no keepalive)\n";
	$request->header('Connection' => 'close');
    }
    #$request->header('TE' => 'trailers');
    #$request->header('Depth' => 1);
    #$request->header('Accept-Charset' => 'utf-8');
    #$request->header('Accept' => 'text/plain');
    $request->content($vevent{'data'});


    return &httpRequest($request, $uid);
#    my $i;
#    for ($i = 0; $i < 30; $i++) {
#	my $response = $ua->request($request);
#	if ($response->is_success) {
#	    print "PUT $uid:\t", $response->status_line, "\n";
#	    last;
#	}
#	else {
#	    print STDERR "ERR PUT $uid:\t", $response->status_line, "\n";
#	    sleep(2);
#	}
#    }
#
#    if ($i == 30) {
#	print STDERR "ERR PUT $uid:\tCan't reach server for the past 60 secs - exiting.\n";
#	exit(-4);
#    }
}

sub parseEventsFile
{
    my $file = shift;

    my %vevent = ();
    my %last_vevent = ();
# data
# uid
# encoding
# organizer
# username
# recurrent

    my $count = 0;
    my $count_created = 0;
    my $bytes_count = 0;
    my $elapsed_time = [gettimeofday];

    while (my $line = <CAL>) {
	$line =~ s/\r$//; # remove dos linebreaks
	if ($line =~ m/^BEGIN:VEVENT$/) {
	    $vevent{'data'} = $line;
	}
	elsif ($line =~ m/^END:VEVENT$/) {
	    $vevent{'data'} .= $line;
	    #if ($vevent{'organizer'} eq $email) {
	    $count++;
	    $bytes_count += length($vevent{'data'});

	    if (RECURRENT eq 'smart') {
		if (%last_vevent) { 
		    if ($last_vevent{'uid'} eq $vevent{'uid'}) {
			$last_vevent{'data'} .= $vevent{'data'};
			$last_vevent{'recurrent'} = 1;
			if ($last_vevent{'username'} ne $vevent{'username'}) {
			    print "ERR: Matching UID with different organizers!\n";   
			}
		    }
		    else {
			$count_created += &putEvent(\%last_vevent, $count);
			%last_vevent = %vevent;
		    }
		}
		else {
		    %last_vevent = %vevent;
		}
	    }
#	    elsif ($vevent{'rdate'}) {
#	      # Ignore event with RDATE attributes -- they are not currently
#	      # supported in SOGo (web)
#	      $vevent{'rdate'} = undef;
#	      print "Event with RDATE -- ignored\n";
#	    }
	    else {
		$count_created += &putEvent(\%vevent, $count);
	    }
	    #$last_data = $vevent{'data'};
	    #last;
	    #}
	    #else {
	    #print $vevent{'uid'},": $email ($username) NOT organizer ",$vevent{'organizer'}," (",$vevent{'username'},"); verify event\n";
	    #}
	    $vevent{'data'} = undef;
	    #last;
	}
	elsif ($vevent{'data'}) {
	    if ($line !~ m/^$/
		&& $line !~ m/^RECURRENCE-ID/
		&& $line !~ m/^RDATE:/) {
		if ($line =~ m/UID:\s*(\S+)$/) {
		    $vevent{'uid'} = $1;
		    $vevent{'uid'} =~ s/[#&\/]/-/g;
		    $vevent{'uid'} =~ s/\.//g;
		    $line =~ s/^(UID:).*$/$1$vevent{'uid'}/;
		}
		elsif ($line =~ m/^ORGANIZER:(?:mailto:)?(\S+)$/) {
		    $vevent{'organizer'} = $1;
		    $vevent{'username'} = &getUsernameByEmail($ldap, $1);
		}
#		elsif ($line =~ m/^RDATE:/) {
#		  $vevent{'rdate'} = 1;
#		}
		$vevent{'data'} .= $line unless ();
	    }
	    else {
		print "ignored: '$line'\n";
	    }
	}
	elsif ($line =~ m/Content-Transfer-Encoding: (\S+)$/) {
	    $vevent{'encoding'} = $1;
	}
    }

    if (%last_vevent) {
	$count_created += &putEvent(\%last_vevent, $count);
    }

    printf "\nParsed %i events, %i new: %.1f KB in %.1f seconds\n",
	$count, $count_created, ($bytes_count/1024), tv_interval($elapsed_time);

    return 1;
}

sub gmtTime {
  my $time = localtime(shift);
  #my ($second,$minute,$hour,$dayofmonth,$month,$year,$weekday,$dayofyear,$isdst) = localtime($time);

  #$year  += 1900;
  #$month++;
  #$hour -= $isdst;

  return sprintf("%04d%02d%02dT%02d%02d%02dZ",
		 $time->year+1900,
		 $time->mon+1,
		 $time->mday,
		 $time->hour-$time->isdst,
		 $time->min,
		 $time->isdst);
}

sub putTask(\%) {
  my (%task) = %{(shift)};
  my $count = shift;
  my $bytes_count_ref = shift;

  return 0 unless ($task{'summary'});

  my $now = &gmtTime(time);
  my $uid = md5_hex(%task);
  my $data = <<'VCAL';
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Inverse inc.//SOGo 0.9//EN
BEGIN:VTODO
UID:%s
SUMMARY:%s
LOCATION:
VCAL

  $data = sprintf($data, uc($uid), $task{'summary'});
  $data .= "PRIORITY:" . $task{'priority'} . "\n" if ($task{'priority'});
  $data .= "CREATED:$now\n";
  $data .= "DTSTAMP:$now\n";
  $data .= "LAST-MODIFIED:$now\n";
  $data .= "DTSTART:" . &gmtTime($task{'start'}) . "\n" if ($task{'start'});
  $data .= "DUE:" . &gmtTime($task{'end'}) . "\n" if ($task{'end'});
  if (defined($task{'completion'})) {
    if (scalar($task{'completion'}) < 100) {
      $data .= "STATUS:IN-PROCESS\n";
    }
    else {
      $data .= "STATUS:COMPLETED\n";
    }
    $data .= "PERCENT-COMPLETE:" . $task{'completion'} . "\n";
  }
  $data .= "DESCRIPTION:" . join("\\r\\n", @{$task{'description'}}) . "\n" if ($task{'description'});
  $data .= "END:VTODO\n";
  $data .= "END:VCALENDAR\n";

  $$bytes_count_ref += length($data);

  print $data if (DEBUG);
  print "PUT ",&calendarUrl($username, $uid),"\n";

  return 0 if (DRYRUN);

  my $request = HTTP::Request->new();

  $request->method('PUT');
  $request->uri(&calendarUrl($username, $uid));
  $request->header('Authorization' => "Basic $pwdhash");
  $request->header('Content-Type' => 'text/calendar; charset=utf-8');
  $request->header('Content-Length' => length($data));
  $request->header('x-sogo-mode' => 'M');
  if (FORCE_CLOSE && ($count % FORCE_CLOSE) == 0) {
    print "Force connection close (no keepalive)\n";
    $request->header('Connection' => 'close');
  }
  $request->content($data);

  return &httpRequest($request, $uid);
}

sub parseTasksFile {
# S 9265740
# D 9266220
# T task august 13th 
# R 1
# L 100
# M bar foo
# W bar foo 
# C task august 13th 2008
# C line 2 description
# C line 3
# O

# BEGIN:VCALENDAR
# VERSION:2.0
# PRODID:-//Inverse inc.//SOGo 0.9//EN
# BEGIN:VTODO
# UID:26A-4979F880-1-B72F03D0
# SUMMARY:this is a task
# LOCATION:there
# PRIORITY:1
# STATUS:IN-PROCESS
# CREATED:20090123T170443Z
# DTSTAMP:20090123T170443Z
# LAST-MODIFIED:20090123T170443Z
# DTSTART:20090123T171500Z
# DUE:20090124T181500Z
# PERCENT-COMPLETE:40
# DESCRIPTION:foo
# END:VTODO
# END:VCALENDAR

  #my $file = $_[0];
  my $count = 0;
  my $count_created = 0;
  my $bytes_count = 0;
  my $elapsed_time = [gettimeofday];
  my %task = ();
  # Start and due times are computed in minutes since since Jan 1 1991
  my $basetime = timelocal(0, 0, 0, 1, 0, 91);
#   my $tm = localtime($basetime);
#   printf("Base date: %04d/%02d/%02d %02d:%02d:%02d\n",
# 	 $tm->year+1900, $tm->mon+1, $tm->mday,
# 	 $tm->hour, $tm->min, $tm->sec);

#   open (my $tasksfile, $file)
#     or die "Cannot open tasks file '$file'";

#   while ($line = <$tasksfile>) {
  while (my $line = <CAL>) {
    #$line =~ s/\n$//;
    chomp $line;
    if ($line =~ m/^O/) {
      if (%task) {
	$count++;
	$count_created += &putTask(\%task, $count, \$bytes_count);
	%task = ();
      }
    }
    elsif ($line =~ m/^T (.+)/) {
      $task{'summary'} = $1;
    }
    elsif ($line =~ m/^S (\d+)/ && $1) {
      $task{'start'} = $1*60 + $basetime;
    }
    elsif ($line =~ m/^D (\d+)/ && $1) {
      # End time (number of minutes since Jan 1 1991)
      $task{'end'} = $1*60 + $basetime;
#       $tm = localtime($task{'end'});
#       printf("End date: %04d/%02d/%02d %02d:%02d:%02d\n",
# 	     $tm->year+1900, $tm->mon+1, $tm->mday,
# 	     $tm->hour, $tm->min, $tm->sec);
    }
    elsif ($line =~ m/^R (\w+)/) {
      $task{'priority'} = $1;
    }
    elsif ($line =~ m/^L (\w+)/) {
      $task{'completion'} = $1;
    }
    elsif ($line =~ m/^C (.+)/) {
      $task{'description'} = () unless ($task{'description'});
      push(@{$task{'description'}}, $1);
    }
  }

  #close ($tasksfile);
  close (CAL);

  printf "\nParsed %i tasks, %i new: %.1f KB in %.1f seconds\n",
    $count, $count_created, ($bytes_count/1024), tv_interval($elapsed_time);

  return 1;
}

sub parseRightsFile
{
    my $file = $_[0];

    open (my $rightsfile, $file)
      or die "Cannot open rights file '$file'";

    my $line = <$rightsfile>;
    $line =~ s/\n$//;
#line:---procuration, username, foo.bar@foo.edu
    my $user;
    if ($line =~ m@^\-\-\-procuration, ([^,]+),@) {
	$user = $1;
	print "rights for user's calendar: $user\n";
    }
    else {
	die "Could not parse procuration line: $line";
    }

    my $next = 0; # 0 = Grantee, 1 = Designate right
    my $grantee;
    my $rights;

    while ($line = <$rightsfile>) {
	$line =~ s/\n$//;
	if ($next == 0) {
	    if ($line =~ m@^Grantee:\ S=[^/]+/G=[^/]+/UID=([^/]+)/ID=[^/]+/NODE\-ID=[^/]+$@) {
		$grantee = $1;
	    }
	    else {
		die "Expected or mal-formed 'Grantee' line: $line";
	    }
	    $next = 1;
	}
	elsif ($next == 1) {
	    if ($line =~ m@^Designate\ Right:\ (.*)$@) {
		my $oracleRights = $1;
		$rights = &convertOracleRights($oracleRights);
	    }
	    else {
		die "Expected or mal-formed 'Designate Right' line: $line";
	    }
	    &grantUserRights($grantee, $rights, $user);
	    $next = 0;
	}
    }

    close ($rightsfile);
}

#line:Designate Right: CONFIDENTIALEVENT=NONE/CONFIDENTIALTASK=NONE/NORMALEVENT=MODIFY/NORMALTASK=MODIFY/PERSONALEVENT=VIEWTIME/PERSONALTASK=NONE/PUBLICEVENT=MODIFY/PUBLICTASK=MODIF
sub convertOracleRights()
{
    my $oracleRights = $_[0];
    my %keyMapping = ( 'CONFIDENTIAL' => 'Confidential',
		       'NORMAL' => 'Public',
		       'PUBLIC' => 'Public',
		       'PERSONAL' => 'Private' );
    my %valueMapping = ( 'VIEW' => 'Viewer', # à confirmer
			 'VIEWTIME' => 'DAndTViewer',
			 'MODIFY' => 'Modifier',
			 'REPLY' => 'Responder' );

    my %rights = ();

    my @parsedRights = split('/', $oracleRights);
    foreach my $parsedRight (@parsedRights) {
	my ($key, $value) = split('=', $parsedRight);
	if ($key =~ /(.*)EVENT$/ && $value ne 'NONE') {
	    $key = $1;
	    die "No mapping found for key '$key'"
	      unless defined $keyMapping{$key};
	    die "No mapping found for value '$value'"
	      unless defined $valueMapping{$value};
	    $rights{$keyMapping{$key}.$valueMapping{$value}} = 1;
	}
    }

    return [keys %rights];
}

sub grantUserRights()
{
    my ($grantee, $rights, $user) = @_;

    die "No grantee specified"
      unless defined $grantee;
    die "No rights specified"
      unless defined $rights;
    die "No user specified"
      unless defined $user;

    my $xmlRights = "";

    foreach my $right (@$rights) {
	$xmlRights .= "<$right/>";
    }
    my $content = ( '<?xml version="1.0" encoding="UTF-8"?>' . "\n"
		    . '<acl-query xmlns="urn:inverse:params:xml:ns:inverse-dav"><set-roles user='
		    . '"' . $user . '">' . $xmlRights . '</set-roles></acl-query>' );

    my $request = HTTP::Request->new();
    $request->method('POST');
    $request->uri(&calendarUrl($user));
    $request->header('Authorization' => "Basic $pwdhash"); 
    $request->header('Content-Type' => 'application/xml');
    $request->header('Content-Length' => length($content));
    $request->content($content);

    my $result = &httpRequest($request, $username);

    my $response = $ua->request($request);
}

##
## MAIN
##

if ($#ARGV < 3) {
    &usage();
    exit(-1);
}

$url = $ARGV[0];
$username = $ARGV[1];
my $type = $ARGV[2];
$file = $ARGV[3];

if ($type ne 'events' && $type ne 'tasks' && $type ne 'rights') {
    usage("The argument 'type' does not have a proper value: '$type'");
    exit(-1);
}

# Prepare LDAP connection
$ldap = new Net::LDAP(LDAP_HOST) or die "Can't connect to LDAP server: $@.\n";
my $msg = $ldap->bind(LDAP_BIND_DN, password => LDAP_BIND_PW);
if ($msg->is_error()) {
    die "Can't bind to LDAP server: ".$msg->error()."\n";
}

# Verify file name format; extract username
#if ($file =~ m/^(?!.+?\W)?events\.(\d{8}|invite\d+)$/) {
#if ($file =~ m/^(?:.+\/)?(events|tasks|rights)\.(\d{8}|invite\d+|[a-z]+)(\.test\d?)?$/) {
#    $username = $2;
$email = &getEmailByUsername($ldap, $username);
print "$username = $email\n";

if (FORCE_USERNAME) {
    $username = FORCE_USERNAME;
    print "Force username to $username\n";
}

# Open iCalendar file
open (CAL, $file) or die "Can't open file $file: $!\n";

# Prepare HTTP query
if ($url =~ m#^(https?://)(?:([^:]+):([^@]+)@)?([^/]+)#) {
    ($authusername, $password, $host) = ($2, $3, $4);
    $url = $1.$4;
    if ($host =~ m/:(\d+)/) {
	$port = $1;
    }
    elsif ($url =~ m/^https/) {
	$port = '443';
	$host .= ":$port";
    }
    else {
	$port = '80';
	$host .= ":$port";
    }
#    print "host = $host, auth = $authusername\n";
}
else {
    &usage("The URL doesn't have the proper format.");
    exit(-3);
}

$pwdhash = encode_base64($authusername . ':' . $password);

$ua = LWP::UserAgent->new();
$ua->agent('Mozilla/5.0');
$ua->timeout(1800);

# Verify is user personal calendar exists (or can be automatically created)
die "Can't access personal calendar of username $username\n"  unless (&userCalendarExists($username));

my $parsers = { 'events' => \&parseEventsFile,
		'tasks' => \&parseTasksFile,
		'rights' => \&parseRightsFile };
$parsers->{$type}($file);

exit;
