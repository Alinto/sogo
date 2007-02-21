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

#import <NGObjWeb/SoObject.h>
#import "AgenorUserManager.h"
#import "SOGoAclsFolder.h"
#import "common.h"

#import "SOGoUser.h"

@interface NSObject (SOGoRoles)

- (NSString *) roleOfUser: (NSString *) uid
                inContext: (WOContext *) context;
- (NSArray *) rolesOfUser: (NSString *) uid
                inContext: (WOContext *) context;

@end

@implementation SOGoUser

- (void)dealloc {
  [self->userDefaults release];
  [self->cn    release];
  [self->email release];
  [super dealloc];
}

/* internals */

- (AgenorUserManager *)userManager {
  static AgenorUserManager *um = nil;
  if (um == nil) um = [[AgenorUserManager sharedUserManager] retain];
  return um;
}

/* properties */

- (NSString *)email {
  if (self->email == nil)
    self->email = [[[self userManager] getEmailForUID:[self login]] copy];
  return self->email;
}

- (NSString *)cn {
  if (self->cn == nil)
    self->cn = [[[self userManager] getCNForUID:[self login]] copy];
  return self->cn;
}

- (NSString *)primaryIMAP4AccountString {
  return [[self userManager] getIMAPAccountStringForUID:[self login]];
}
- (NSString *)primaryMailServer {
  return [[self userManager] getServerForUID:[self login]];
}

- (NSArray *)additionalIMAP4AccountStrings {
  return [[self userManager]getSharedMailboxAccountStringsForUID:[self login]];
}
- (NSArray *)additionalEMailAddresses {
  return [[self userManager] getSharedMailboxEMailsForUID:[self login]];
}

- (NSDictionary *)additionalIMAP4AccountsAndEMails {
  return [[self userManager] getSharedMailboxesAndEMailsForUID:[self login]];
}

- (NSURL *)freeBusyURL {
  return [[self userManager] getFreeBusyURLForUID:[self login]];
}

/* defaults */

- (NSUserDefaults *)userDefaults {
  if (self->userDefaults == nil) {
    self->userDefaults = 
      [[[self userManager] getUserDefaultsForUID:[self login]] retain];
  }
  return self->userDefaults;
}

/* folders */

// TODO: those methods should check whether the traversal stack in the context
//       already contains proper folders to improve caching behaviour

- (id)homeFolderInContext:(id)_ctx {
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

- (id)schedulingCalendarInContext:(id)_ctx {
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
  SOGoAclsFolder *aclsFolder;
  NSArray *sogoRoles;
  NSString *role;

  rolesForObject = [NSMutableArray new];
  [rolesForObject autorelease];

  sogoRoles = [super rolesForObject: object inContext: context];
  if (sogoRoles)
    [rolesForObject addObjectsFromArray: sogoRoles];

  if ([[object ownerInContext: context] isEqualToString: [self login]])
    [rolesForObject addObject: SoRole_Owner];
  if ([object isKindOfClass: [SOGoObject class]])
    {
      aclsFolder = [SOGoAclsFolder aclsFolder];
      sogoRoles = [aclsFolder aclsForObject: (SOGoObject *) object
                              forUser: login];
      if (sogoRoles)
        [rolesForObject addObjectsFromArray: sogoRoles];
    }
  if ([object respondsToSelector: @selector (rolesOfUser:inContext:)])
    {
      sogoRoles = [object rolesOfUser: login inContext: context];
      if (sogoRoles)
        [rolesForObject addObjectsFromArray: sogoRoles];
    }
  if ([object respondsToSelector: @selector (roleOfUser:inContext:)])
    {
      role = [object roleOfUser: login inContext: context];
      if (role)
        [rolesForObject addObject: role];
    }

  return rolesForObject;
}

@end /* SOGoUser */
