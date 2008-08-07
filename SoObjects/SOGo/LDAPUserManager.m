/* LDAPUserManager.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>
#import <NGExtensions/NSObject+Logs.h>

#import "NSArray+Utilities.h"
#import "LDAPSource.h"
#import "LDAPUserManager.h"

static NSString *defaultMailDomain = nil;
static BOOL defaultMailDomainIsConfigured = NO;
static BOOL forceImapLoginWithEmail = NO;

@implementation LDAPUserManager

+ (void) initialize
{
  NSUserDefaults *ud;

  ud = [NSUserDefaults standardUserDefaults];
  if (!defaultMailDomain)
    {
      defaultMailDomain = [ud stringForKey: @"SOGoDefaultMailDomain"];
      [defaultMailDomain retain];
      defaultMailDomainIsConfigured = YES;
    }
  if (!defaultMailDomain)
    {
      [self warnWithFormat:
	      @"no domain specified for SOGoDefaultMailDomain,"
	    @" value set to 'localhost'"];
      defaultMailDomain = @"localhost";
    }
  if (!forceImapLoginWithEmail)
    forceImapLoginWithEmail = [ud boolForKey: @"SOGoForceIMAPLoginWithEmail"];
}

+ (BOOL) defaultMailDomainIsConfigured
{
  return defaultMailDomainIsConfigured;
}

+ (id) sharedUserManager
{
  static id sharedUserManager = nil;

  if (!sharedUserManager)
    sharedUserManager = [self new];

  return sharedUserManager;
}

- (void) _registerSource: (NSDictionary *) udSource
{
  NSMutableDictionary *metadata;
  LDAPSource *ldapSource;
  NSString *sourceID, *value;
  
  sourceID = [udSource objectForKey: @"id"];
  ldapSource = [LDAPSource sourceFromUDSource: udSource];
  if (sourceID)
    [sources setObject: ldapSource forKey: sourceID];
  else
    NSLog(@"LDAPUserManager.m: WARNING: id field missing in a LDAP source, check the SOGoLDAPSources default");
  metadata = [NSMutableDictionary dictionary];
  value = [udSource objectForKey: @"canAuthenticate"];
  if (value)
    [metadata setObject: value forKey: @"canAuthenticate"];
  value = [udSource objectForKey: @"isAddressBook"];
  if (value)
    [metadata setObject: value forKey: @"isAddressBook"];
  value = [udSource objectForKey: @"displayName"];
  if (value)
    [metadata setObject: value forKey: @"displayName"];
  value = [udSource objectForKey: @"MailFieldNames"];
  if (value)
    [metadata setObject: value forKey: @"MailFieldNames"];
  [sourcesMetadata setObject: metadata forKey: sourceID];
}

- (void) _prepareLDAPSourcesWithDefaults: (NSUserDefaults *) ud
{
  NSArray *udSources;
  unsigned int count, max;

  sources = [NSMutableDictionary new];
  sourcesMetadata = [NSMutableDictionary new];

  udSources = [ud arrayForKey: @"SOGoLDAPSources"];
  max = [udSources count];
  for (count = 0; count < max; count++)
    [self _registerSource: [udSources objectAtIndex: count]];
}

- (id) init
{
  NSUserDefaults *ud;

  if ((self = [super init]))
    {
      ud = [NSUserDefaults standardUserDefaults];

      sources = nil;
      sourcesMetadata = nil;
      users = [NSMutableDictionary new];
      cleanupInterval
	= [ud integerForKey: @"SOGOLDAPUserManagerCleanupInterval"];
      if (cleanupInterval)
	cleanupTimer = [NSTimer timerWithTimeInterval: cleanupInterval
				target: self
				selector: @selector (cleanupUsers)
				userInfo: nil
				repeats: YES];
      [self _prepareLDAPSourcesWithDefaults: ud];
    }

  return self;
}

- (void) dealloc
{
  [sources release];
  [users release];
  [super dealloc];
}

- (NSArray *) sourceIDs
{
  return [sources allKeys];
}

- (NSArray *) _sourcesOfType: (NSString *) sourceType
{
  NSMutableArray *sourceIDs;
  NSEnumerator *allIDs;
  NSString *currentID;
  NSNumber *canAuthenticate;

  sourceIDs = [NSMutableArray array];
  allIDs = [[sources allKeys] objectEnumerator];
  while ((currentID = [allIDs nextObject])) 
    {
      canAuthenticate = [[sourcesMetadata objectForKey: currentID]
			  objectForKey: sourceType];
      if ([canAuthenticate boolValue])
	[sourceIDs addObject: currentID];
    }

  return sourceIDs;
}

- (NSDictionary *) metadataForSourceID: (NSString *) sourceID
{
  return [sourcesMetadata objectForKey: sourceID];
}

- (NSArray *) authenticationSourceIDs
{
  return [self _sourcesOfType: @"canAuthenticate"];
}

- (NSArray *) addressBookSourceIDs
{
  return [self _sourcesOfType: @"isAddressBook"];
}

- (LDAPSource *) sourceWithID: (NSString *) sourceID
{
  return [sources objectForKey: sourceID];
}

- (NSString *) displayNameForSourceWithID: (NSString *) sourceID
{
  NSDictionary *metadata;

  metadata = [sourcesMetadata objectForKey: sourceID];

  return [metadata objectForKey: @"displayName"];
}

- (NSString *) getCNForUID: (NSString *) uid
{
  NSDictionary *contactInfos;

//   NSLog (@"getCNForUID: %@", uid);
  contactInfos = [self contactInfosForUserWithUIDorEmail: uid];

  return [contactInfos objectForKey: @"cn"];
}

- (NSString *) getEmailForUID: (NSString *) uid
{
  NSDictionary *contactInfos;

//   NSLog (@"getEmailForUID: %@", uid);
  contactInfos = [self contactInfosForUserWithUIDorEmail: uid];

  return [contactInfos objectForKey: @"c_email"];
}

- (NSString *) getFullEmailForUID: (NSString *) uid
{
  NSDictionary *contactInfos;

  contactInfos = [self contactInfosForUserWithUIDorEmail: uid];

  return [NSString stringWithFormat: @"%@ <%@>",
		   [contactInfos objectForKey: @"cn"],
		   [contactInfos objectForKey: @"c_email"]];
}

- (NSString *) getImapLoginForUID: (NSString *) uid
{
  return ((forceImapLoginWithEmail) ? [self getEmailForUID: uid] : uid);
}

- (NSString *) getUIDForEmail: (NSString *) email
{
  NSDictionary *contactInfos;

//   NSLog (@"getUIDForEmail: %@", email);
  contactInfos = [self contactInfosForUserWithUIDorEmail: email];

  return [contactInfos objectForKey: @"c_uid"];
}

- (BOOL) _ldapCheckLogin: (NSString *) login
	     andPassword: (NSString *) password
{ 
  BOOL checkOK;
  LDAPSource *ldapSource;
  NSEnumerator *authIDs;
  NSString *currentID;

  checkOK = NO;

  authIDs = [[self authenticationSourceIDs] objectEnumerator];
  while (!checkOK && (currentID = [authIDs nextObject]))
    {
      ldapSource = [sources objectForKey: currentID];
      checkOK = [ldapSource checkLogin: login andPassword: password];
    }

  return checkOK;
}

- (BOOL) checkLogin: (NSString *) login
	andPassword: (NSString *) password
{
  BOOL checkOK;
  NSDate *cleanupDate;
  NSMutableDictionary *currentUser;
  NSString *dictPassword;

  currentUser = [users objectForKey: login];
  dictPassword = [currentUser objectForKey: @"password"];
  if (currentUser && dictPassword)
    checkOK = ([dictPassword isEqualToString: password]);
  else if ([self _ldapCheckLogin: login andPassword: password])
    {
      checkOK = YES;
      if (!currentUser)
	{
	  currentUser = [NSMutableDictionary dictionary];
	  [users setObject: currentUser forKey: login];
	}
      [currentUser setObject: password forKey: @"password"];
    }
  else
    checkOK = NO;

  if (cleanupInterval)
    {
      cleanupDate = [[NSDate date] addTimeInterval: cleanupInterval];
      [currentUser setObject: cleanupDate forKey: @"cleanupDate"];
    }

  return checkOK;
}

- (void) _fillContactMailRecords: (NSMutableDictionary *) contact
{
  NSMutableArray *emails;
  NSString *uid, *systemEmail;

  emails = [contact objectForKey: @"emails"];
  uid = [contact objectForKey: @"c_uid"];
  systemEmail = [NSString stringWithFormat: @"%@@%@", uid, defaultMailDomain];
  [emails addObjectUniquely: systemEmail];
  [contact setObject: [emails objectAtIndex: 0] forKey: @"c_email"];
}

- (void) _fillContactInfosForUser: (NSMutableDictionary *) currentUser
		   withUIDorEmail: (NSString *) uid
{
  NSMutableArray *emails;
  NSDictionary *userEntry;
  NSEnumerator *ldapSources;
  LDAPSource *currentSource;
  NSString *cn, *c_uid;
  NSArray *c_emails;
  BOOL access;

  emails = [NSMutableArray array];
  cn = nil;
  c_uid = nil;

  [currentUser setObject: [NSNumber numberWithBool: YES]
	       forKey: @"CalendarAccess"];
  [currentUser setObject: [NSNumber numberWithBool: YES]
	       forKey: @"MailAccess"];

  ldapSources = [sources objectEnumerator];
  while ((currentSource = [ldapSources nextObject]))
    {
      userEntry = [currentSource lookupContactEntryWithUIDorEmail: uid];
      if (userEntry)
	{
	  if (!cn)
	    cn = [userEntry objectForKey: @"c_cn"];
	  if (!c_uid)
	    c_uid = [userEntry objectForKey: @"c_uid"];
	  c_emails = [userEntry objectForKey: @"c_emails"];
	  if ([c_emails count])
	    [emails addObjectsFromArray: c_emails];
	  access = [[userEntry objectForKey: @"CalendarAccess"] boolValue];
	  if (!access)
	    [currentUser setObject: [NSNumber numberWithBool: NO]
			 forKey: @"CalendarAccess"];
	  access = [[userEntry objectForKey: @"MailAccess"] boolValue];
	  if (!access)
	    [currentUser setObject: [NSNumber numberWithBool: NO]
			 forKey: @"MailAccess"];
	}
    }

  if (!cn)
    cn = @"";
  if (!c_uid)
    c_uid = @"";

  [currentUser setObject: emails forKey: @"emails"];
  [currentUser setObject: cn forKey: @"cn"];
  [currentUser setObject: c_uid forKey: @"c_uid"];

  // If our LDAP queries gave us nothing, we add at least one default
  // email address based on the default domain.
  [self _fillContactMailRecords: currentUser];
}

- (void) _retainUser: (NSDictionary *) newUser
{
  NSString *key;
  NSEnumerator *emails;

  key = [newUser objectForKey: @"c_uid"];
  if (key)
    [users setObject: newUser forKey: key];
  emails = [[newUser objectForKey: @"emails"] objectEnumerator];
  key = [emails nextObject];
  while (key)
    {
      [users setObject: newUser forKey: key];
      key = [emails nextObject];
    }
}

- (NSDictionary *) contactInfosForUserWithUIDorEmail: (NSString *) uid
{
  NSMutableDictionary *currentUser, *contactInfos;
  NSDate *cleanupDate;
  BOOL newUser;

  if ([uid length] > 0)
    {
      contactInfos = [NSMutableDictionary dictionary];
      currentUser = [users objectForKey: uid];
      if (!([currentUser objectForKey: @"emails"]
	    && [currentUser objectForKey: @"cn"]))
	{
	  if (!currentUser)
	    {
	      newUser = YES;
	      currentUser = [NSMutableDictionary dictionary];
	    }
	  else
	    newUser = NO;
	  [self _fillContactInfosForUser: currentUser
		withUIDorEmail: uid];
	  if (newUser)
	    {
	      if ([[currentUser objectForKey: @"c_uid"] length] > 0)
		[self _retainUser: currentUser];
	      else
		currentUser = nil;
	    }
	}

      if (cleanupInterval && currentUser)
	{
	  cleanupDate = [[NSDate date] addTimeInterval: cleanupInterval];
	  [currentUser setObject: cleanupDate forKey: @"cleanupDate"];
	}
    }
  else
    currentUser = nil;

  return currentUser;
}

- (void) _fillContactsMailRecords: (NSEnumerator *) contacts
{
  NSMutableDictionary *currentContact;

  currentContact = [contacts nextObject];
  while (currentContact)
    {
      [self _fillContactMailRecords: currentContact];
      currentContact = [contacts nextObject];
    }
}

- (NSArray *) _compactAndCompleteContacts: (NSEnumerator *) contacts
{
  NSMutableDictionary *compactContacts, *returnContact;
  NSDictionary *userEntry;
  NSArray *newContacts;
  NSMutableArray *emails;
  NSString *uid, *email;

  compactContacts = [NSMutableDictionary dictionary];
  userEntry = [contacts nextObject];
  while (userEntry)
    {
      uid = [userEntry objectForKey: @"c_uid"];
      if ([uid length])
	{
	  returnContact = [compactContacts objectForKey: uid];
	  if (!returnContact)
	    {
	      returnContact = [NSMutableDictionary dictionary];
	      [returnContact setObject: uid forKey: @"c_uid"];
	      [compactContacts setObject: returnContact forKey: uid];
	    }
	  if (![[returnContact objectForKey: @"c_name"] length])
	    [returnContact setObject: [userEntry objectForKey: @"c_name"]
			   forKey: @"c_name"];
	  if (![[returnContact objectForKey: @"cn"] length])
	    [returnContact setObject: [userEntry objectForKey: @"c_cn"]
			   forKey: @"cn"];
	  emails = [returnContact objectForKey: @"emails"];
	  if (!emails)
	    {
	      emails = [NSMutableArray array];
	      [returnContact setObject: emails forKey: @"emails"];
	    }
	  email = [userEntry objectForKey: @"mail"];
	  if (email && ![emails containsObject: email])
	    [emails addObject: email];
	  email = [userEntry objectForKey: @"mozillaSecondEmail"];
	  if (email && ![emails containsObject: email])
	    [emails addObject: email];
	  email = [userEntry objectForKey: @"xmozillasecondemail"];
	  if (email && ![emails containsObject: email])
	    [emails addObject: email];
	}

      userEntry = [contacts nextObject];
    }
  newContacts = [compactContacts allValues];
  [self _fillContactsMailRecords: [newContacts objectEnumerator]];

  return newContacts;
}

- (NSArray *) _fetchEntriesInSources: (NSArray *) sourcesList
			    matching: (NSString *) filter
{
  NSMutableArray *contacts;
  NSEnumerator *ldapSources;
  NSString *sourceID;
  LDAPSource *currentSource;

  contacts = [NSMutableArray array];
  ldapSources = [sourcesList objectEnumerator];
  while ((sourceID = [ldapSources nextObject]))
    {
      currentSource = [sources objectForKey: sourceID];
      [contacts addObjectsFromArray:
		  [currentSource fetchContactsMatching: filter]];
    }

  return [self _compactAndCompleteContacts: [contacts objectEnumerator]];
}

- (NSArray *) fetchContactsMatching: (NSString *) filter
{
  return [self _fetchEntriesInSources: [self addressBookSourceIDs]
	       matching: filter];
}

- (NSArray *) fetchUsersMatching: (NSString *) filter
{
  return [self _fetchEntriesInSources: [self authenticationSourceIDs]
	       matching: filter];
}

- (void) cleanupSources
{
  NSEnumerator *userIDs;
  NSString *currentID;
  NSDictionary *currentUser;
  NSDate *now;

  now = [NSDate date];
  userIDs = [[users allKeys] objectEnumerator];
  currentID = [userIDs nextObject];
  while (currentID)
    {
      currentUser = [users objectForKey: currentID];
      if ([now earlierDate:
		 [currentUser objectForKey: @"cleanupDate"]] == now)
	[users removeObjectForKey: currentID];
      currentID = [userIDs nextObject];
    }
}

@end
