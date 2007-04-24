/*
  Copyright (C) 2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSUserDefaults.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/SoObject.h>
#import <NGExtensions/NSNull+misc.h>

#import "AgenorUserManager.h"
#import "SOGoContentObject.h"
#import "SOGoUser.h"
#import "SOGoPermissions.h"

static NSTimeZone *serverTimeZone = nil;

@interface NSObject (SOGoRoles)

- (NSArray *) rolesOfUser: (NSString *) uid;

@end

@implementation SOGoUser

+ (void) initialize
{
  NSString *tzName;

  if (!serverTimeZone)
    {
      tzName = [[NSUserDefaults standardUserDefaults]
		 stringForKey: @"SOGoServerTimeZone"];
      if (!tzName)
        tzName = @"Canada/Eastern";
      serverTimeZone = [NSTimeZone timeZoneWithName: tzName];
      [serverTimeZone retain];
    }
}

+ (SOGoUser *) userWithLogin: (NSString *) login
		    andRoles: (NSArray *) roles
{
  SOGoUser *user;

  user = [[self alloc] initWithLogin: login roles: roles];
  [user autorelease];

  return user;
}

- (id) init
{
  if ((self = [super init]))
    {
      userDefaults = nil;
      userSettings = nil;
    }

  return self;
}

- (void) dealloc
{
  [userDefaults release];
  [userSettings release];
  [cn    release];
  [email release];
  [super dealloc];
}

/* internals */

- (AgenorUserManager *) userManager
{
  static AgenorUserManager *um = nil;
  if (um == nil) um = [[AgenorUserManager sharedUserManager] retain];

  return um;
}

/* properties */

- (NSString *) email
{
  if (email == nil)
    {
      email = [[self userManager] getEmailForUID: [self login]];
      [email retain];
    }

  return email;
}

- (NSString *) cn
{
  if (cn == nil)
    {
      cn = [[self userManager] getCNForUID: [self login]];
      [cn retain];
    }

  return cn;
}

- (NSString *) primaryIMAP4AccountString
{
  return [[self userManager] getIMAPAccountStringForUID: [self login]];
}

- (NSString *) primaryMailServer
{
  return [[self userManager] getServerForUID: [self login]];
}

- (NSArray *) additionalIMAP4AccountStrings
{
  return [[self userManager]getSharedMailboxAccountStringsForUID: [self login]];
}

- (NSArray *) additionalEMailAddresses
{
  return [[self userManager] getSharedMailboxEMailsForUID: [self login]];
}

- (NSDictionary *) additionalIMAP4AccountsAndEMails
{
  return [[self userManager] getSharedMailboxesAndEMailsForUID: [self login]];
}

- (NSURL *) freeBusyURL
{
  return [[self userManager] getFreeBusyURLForUID: [self login]];
}

/* defaults */

- (NSUserDefaults *) userDefaults
{
  if (!userDefaults)
    {
      userDefaults = [[self userManager] getUserDefaultsForUID: [self login]];
      [userDefaults retain];
    }

  return userDefaults;
}

- (NSUserDefaults *) userSettings
{
  if (!userSettings)
    {
      userSettings = [[self userManager] getUserSettingsForUID: [self login]];
      [userSettings retain];
    }

  return userSettings;
}

- (NSTimeZone *) timeZone
{
  NSString *timeZoneName;

  if (!userTimeZone)
    {
      timeZoneName = [[self userDefaults] stringForKey: @"TimeZone"];
      if ([timeZoneName length] > 0)
	userTimeZone = [NSTimeZone timeZoneWithName: timeZoneName];
      else
	userTimeZone = nil;
      if (!userTimeZone)
	userTimeZone = [self serverTimeZone];
      [userTimeZone retain];
    }

  return userTimeZone;
}

- (NSTimeZone *) serverTimeZone
{
  return serverTimeZone;
}

/* folders */

// TODO: those methods should check whether the traversal stack in the context
//       already contains proper folders to improve caching behaviour

- (id) homeFolderInContext: (id) _ctx
{
  /* Note: watch out for cyclic references */
  // TODO: maybe we should add an [activeUser reset] method to SOPE
  id folder;
  
  folder = [(WOContext *)_ctx objectForKey:@"ActiveUserHomeFolder"];
  if (folder != nil)
    return [folder isNotNull] ? folder : nil;
  
  folder = [[WOApplication application] lookupName:[self login]
					inContext:_ctx acquire:NO];
  if ([folder isKindOfClass:[NSException class]])
    return folder;
  
  [(WOContext *)_ctx setObject:folder ? folder : [NSNull null] 
                forKey: @"ActiveUserHomeFolder"];
  return folder;
}

- (id) schedulingCalendarInContext: (id) _ctx
{
  /* Note: watch out for cyclic references */
  id folder;

  folder = [(WOContext *)_ctx objectForKey:@"ActiveUserCalendar"];
  if (folder != nil)
    return [folder isNotNull] ? folder : nil;

  folder = [self homeFolderInContext:_ctx];
  if ([folder isKindOfClass:[NSException class]])
    return folder;
  
  folder = [folder lookupName:@"Calendar" inContext:_ctx acquire:NO];
  if ([folder isKindOfClass:[NSException class]])
    return folder;
  
  [(WOContext *)_ctx setObject:folder ? folder : [NSNull null] 
                forKey:@"ActiveUserCalendar"];
  return folder;
}

- (NSArray *) rolesForObject: (NSObject *) object
                   inContext: (WOContext *) context
{
  NSMutableArray *rolesForObject;
  NSArray *sogoRoles;

  rolesForObject = [NSMutableArray new];
  [rolesForObject autorelease];

  sogoRoles = [super rolesForObject: object inContext: context];
  if (sogoRoles)
    [rolesForObject addObjectsFromArray: sogoRoles];

  if ([[object ownerInContext: context] isEqualToString: [self login]])
    [rolesForObject addObject: SoRole_Owner];
  if ([object isKindOfClass: [SOGoObject class]])
    {
      sogoRoles = [(SOGoObject *) object aclsForUser: login];
      if (sogoRoles)
        [rolesForObject addObjectsFromArray: sogoRoles];
    }
  if ([object respondsToSelector: @selector (rolesOfUser:)])
    {
      sogoRoles = [object rolesOfUser: login];
      if (sogoRoles)
        [rolesForObject addObjectsFromArray: sogoRoles];
    }

  return rolesForObject;
}

@end /* SOGoUser */
