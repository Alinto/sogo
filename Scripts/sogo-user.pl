#/usr/bin/perl

# TODO:
# - partial delete: appointment tables only, contact tables only
# - stats: nb of calendars, nb of events, nb of events with
#   participants, nb of recurrent events, nb of contacts, nb of
#   addressbooks, nb of contacts, etc

=head1 NAME

sogo-user

=head1 SYNOPSIS

create-ldap-fburl [options] username ...

 Options:
    -help                  brief help message
    -c, --config=FILE      read configuration from FILE
    -i, --info             show information on the user
    --delete               delete user from SOGo databases
    --fburl                update Free-Busy URL in LDAP directory
    -v, --verbose          be verbose

=head1 DESCRIPTION

Apply various operations on a user with respect to her/his
SOGo environment.

=head1 AUTHOR

=over

=item Francis Lachapelle <flachapelle@inverse.ca>

=head1 COPYRIGHT

Copyright (c) 2007 Inverse groupe conseil

This program is available under the GPL.

=cut

#use diagnostics;
use strict;
use warnings;

use Config::IniFiles;
#use Data::Dumper;
use DBI;
use Getopt::Long qw(:config bundling);
#use Log::Log4perl;
use Net::LDAP;
use Pod::Usage;

use constant {
    CONF_FILE => "sogo.conf"
 };

my $help = '';
my $configfile = CONF_FILE;
my $info = '';
my $delete = '';
my $fburl = '';
my $verbose = '';

GetOptions(
	   "help|?" => \$help,
	   "config|c=s" => \$configfile,
	   "info|i" => \$info,
	   "delete" => \$delete,
	   "fburl" => \$fburl,
	   "verbose|v" => \$verbose
) or pod2usage( -verbose => 1);

pod2usage( -verbose => 2) if $help;
pod2usage( -verbose => 1) unless ($help || $info || $delete || $fburl);
pod2usage( -verbose => 1) if ($#ARGV < 0);

my $config;
my $dbh;
my $ldap;

$config = new Config::IniFiles( -file => $configfile, -nocase => 1);
die "ERROR: Can't read configuration file $configfile: $!\n" unless $config;

die "ERROR: Missing \"url\" in section [sogo]\n" unless ($config->val('sogo', 'url'));

# Verify LDAP parameters
foreach ('host', 'port', 'binddn', 'password', 'searchbase', 'uid_attr', 'mail_attr', 'fburl_attr') {
    unless ($config->val('ldap', $_)) {
	die "ERROR: Missing value for parameter \"$_\" in section [ldap].\n";
    }
}

# Verify DB parameters
foreach ('uri', 'username', 'password') {
    unless ($config->val('database', $_)) {
	die "ERROR: Missing value for parameter \"$_\" in section [database].\n";
    }
}

##
# Functions

sub initDatabase
{
    $dbh = DBI->connect($config->val('database', 'uri'),
			$config->val('database', 'username'),
			$config->val('database', 'password'),
			{ AutoCommit => 1, PrintError => 0 }) or die "ERROR: Can't connect to database: $DBI::errstr\n";
}

sub initLdap
{
    $ldap = new Net::LDAP($config->val('ldap', 'host'))
	or die "ERROR: Can't connect to ldap: $@\n";
    
    my $msg = $ldap->bind($config->val('ldap', 'binddn'),
			  password => $config->val('ldap', 'password'));
    if ($msg->is_error()) {
	die "ERROR: Can't bind to ldap: ".$msg->error()."\n";
    }
}

sub info
{
    my $username = shift;
    my $results;
    my @entries;
    my $hash_ref;

    &initLdap() unless $ldap;
    &initDatabase() unless $dbh;

    # Fetch LDAP attributes
    $results = $ldap->search(base => $config->val('ldap', 'searchbase'),
			     scope => 'sub',
			     attrs => [$config->val('ldap', 'uid_attr'),
				       $config->val('ldap', 'mail_attr'),
				       $config->val('ldap', 'fburl_attr')],
			     filter => sprintf('(%s=%s)', $config->val('ldap', 'uid_attr'), $username));
    if ($results->is_error()) {
	die "ERROR: Can't perform ldap search: ",$results->error(),"\n";
    }
    @entries = $results->entries;
    die "ERROR: Unknown user $username\n" if ($#entries < 0);
    foreach my $entry (@entries) {
	print "Username: ", $entry->get_value( $config->val('ldap', 'uid_attr') ), "\n";
	print "Mail: ", $entry->get_value( $config->val('ldap', 'mail_attr') ), "\n";
	print "Freebusy URL: ", $entry->get_value( $config->val('ldap', 'fburl_attr') ) || "(undefined)", "\n";
    }

    # Retrive database tables information
    $hash_ref = $dbh->selectall_hashref("select c_folder_id, c_folder_type, c_location, c_quick_location, c_acl_location from sogo_folder_info where c_path2 = ?", ($config->val('database', 'uri') =~ /^dbi:Pg/)?'c_folder_id':'C_FOLDER_ID', undef, ($username))
	or die "Can't execute select statement: $DBI::errstr\n";

    print "Tables:\n";
    foreach my $id (keys %{$hash_ref}) {
	print "\tType ", ($hash_ref->{$id}->{'C_FOLDER_TYPE'} || $hash_ref->{$id}->{'c_folder_type'})
	    , ", ID ", $id, "\n";
	foreach my $col ('C_LOCATION', 'C_QUICK_LOCATION', 'C_ACL_LOCATION') {
	    print "\t\t", ($hash_ref->{$id}->{$col} || $hash_ref->{$id}->{lc($col)}), "\n";
	}
    }
    print "\t(no table found)\n" unless (%{$hash_ref});
}

sub delete
{
    my $username = shift;
    my $hash_ref;

    &initDatabase() unless $dbh;

    # Select entries from sogo_folder_info 
    $hash_ref = $dbh->selectall_hashref("select C_UID from sogo_user_profile where C_UID = ?", 
					   ($config->val('database', 'uri') =~ /^dbi:Pg/)?'c_uid':'C_UID', 
					   undef, ($username))
	or die "ERROR: Can't execute select statement: $DBI::errstr\n";
    
    if (%{$hash_ref}) {
	# Delete entries from sogo_user_profile
	$dbh->do("delete from sogo_user_profile where c_uid = ?", undef, ($username))
	    or die "ERROR: Can't delete entries from sogo_user_profile: $DBI::errstr\n";
    }
    else {
	warn "No entries in sogo_user_profile\n";
    }

    # Select entries from sogo_folder_info
    $hash_ref = $dbh->selectall_hashref("select c_folder_id, c_folder_type, c_location, c_quick_location, c_acl_location from sogo_folder_info where c_path2 = ?", ($config->val('database', 'uri') =~ /^dbi:Pg/)?'c_folder_id':'C_FOLDER_ID', undef, ($username))
	or die "Can't execute select statement: $DBI::errstr\n";
    
    if (%{$hash_ref}) {
	# Delete entries from sogo_folder_info
	$dbh->do("delete from sogo_folder_info where c_path2 = ?", undef, ($username))
	    or die "Can't delete entries from sogo_info_folder: $DBI::errstr\n";
    }
    else {
	die "No entries in sogo_folder_info\n";
    }

    # Drop tables
    foreach my $id (keys %{$hash_ref}) {
	print "Folder ID $id, type ",($hash_ref->{$id}->{'C_FOLDER_TYPE'} || $hash_ref->{$id}->{'c_folder_type'}),"\n";
	foreach my $col ('C_LOCATION', 'C_QUICK_LOCATION', 'C_ACL_LOCATION') {
	    $col = lc($col) unless ($hash_ref->{$id}->{$col});
	    
	    if ($hash_ref->{$id}->{$col} =~ m#([^:]+)://([^:]+):([^@]+)@([^:]+):([^/]+)/([^/]+)/([^/]+)#) {
		my ($type, $username, $password, $host, $port, $db, $table) = ($1, $2, $3, $4, $5, $6, $7);
		my $uri;
		print "Dropping ",$hash_ref->{$id}->{$col},"\n";
		$uri = 'dbi:Pg:host=%s;port=%s;dbname=%s' if ($type eq 'http');
		$uri = 'dbi:Oracle:host=%s;port=%s;sid=%s' if ($type eq 'oracle');
		my $s = DBI->connect(sprintf($uri, $host, $port, $db), $username, $password, { AutoCommit => 1, PrintError => 0 }) or die "\tCan't connect: $!\n";
		$s->do("drop table $table") or warn "\tERROR: Can't drop table $table: $DBI::errstr\n";
		$s->disconnect();
	    }
	}
    }
}

sub fburl
{
    my $username = shift;
    my $results;
    my @entries;
    my $modified = '';
    
    &initLdap() unless $ldap;

    $results = $ldap->search(base => $config->val('ldap', 'searchbase'),
			     scope => 'sub',
			     attrs => ['objectClass', 
				       $config->val('ldap', 'uid_attr'),
				       $config->val('ldap', 'mail_attr'),
				       $config->val('ldap', 'fburl_attr')],
			     filter => sprintf('(%s=%s)', $config->val('ldap', 'uid_attr'), $username));
    if ($results->is_error()) {
	die "ERROR: Can't perform ldap search: ",$results->error(),"\n";
    }
    @entries = $results->entries;
    die "ERROR: Unknown user $username\n" if ($#entries < 0);
    foreach my $entry (@entries) {
	my $caldav_objectclass = $config->val('ldap', 'caldav_objectclass');
	if (length($caldav_objectclass) > 0) {
	    # Add objectClass if not present
	    my @objectClasses = $entry->get_value('objectClass');
	    #print "classes = ", join(", ", @objectClasses), "\n";
	    unless (grep {/^$caldav_objectclass$/} @objectClasses) {
		print "Adding objectClass ", $caldav_objectclass,"\n";
		$entry->add('objectClass' => $caldav_objectclass);
		$modified = 1;
	    }
	}
	# Add Freebusy URL if not present
	my $fburl_attr = $config->val('ldap', 'fburl_attr');
	if ($entry->get_value($fburl_attr)) {
	    print "Freebusy URL already defined (",$entry->get_value($fburl_attr),")\n";
	}
	else {
	    my $fburl = $config->val('sogo', 'url') . "/SOGo/dav/$username/freebusy.ifb";
	    print "Adding attribute ", $fburl_attr, " with value ", $fburl, "\n";
	    $entry->add($fburl_attr => $fburl);
	    $modified = 1;
	}
	if ($modified) {
	    # Perform update
	    my $msg = $entry->update($ldap);
	    if ($msg->is_error()) {
		print "ERROR: Can't update entry: \n";
		print $entry->dump();
		print $msg->error(),"\n";
	    }
	}
    }
}

##
# Main

foreach my $username (@ARGV) {
    #print $username,"\n";
    
    &info($username) if $info;
    &delete($username) if $delete;
    &fburl($username) if $fburl;
}

$dbh->disconnect if $dbh;
$ldap->unbind if $ldap;
