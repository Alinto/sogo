/* UIxAclEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2014 Inverse inc.
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
#import <Foundation/NSValue.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSKeyValueCoding.h>

#import <NGObjWeb/SoUser.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGCards/iCalPerson.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoContentObject.h>
#import <SOGo/SOGoGCSFolder.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoUser.h>

#import "UIxAclEditor.h"

@implementation UIxAclEditor

- (id) init
{
  if ((self = [super init]))
    {
      aclUsers = nil;
      prepared = NO;
      publishInFreeBusy = NO;
      users = [NSMutableArray new];
      currentUser = nil;
      defaultUserID = nil;
      savedUIDs = nil;
    }

  return self;
}

- (void) dealloc
{
  [savedUIDs release];
  [users release];
  [currentUser release];
  [defaultUserID release];
  [super dealloc];
}

- (NSArray *) aclsForObject
{
  if (!aclUsers)
    aclUsers = [[self clientObject] aclUsers];

  return aclUsers;
}

- (NSString *) defaultUserID
{
  if (!defaultUserID)
    ASSIGN (defaultUserID, [[self clientObject] defaultUserID]);

  return defaultUserID;
}

- (id <WOActionResults>) usersForObjectAction
{
  id <WOActionResults> result;
  NSEnumerator *aclsEnum;
  NSString *currentUID, *ownerLogin;
  NSDictionary *object;

  if (!prepared)
    {
      ownerLogin = [[self clientObject] ownerInContext: context];
      if (!defaultUserID)
        ASSIGN (defaultUserID, [[self clientObject] defaultUserID]);

      aclsEnum = [[self aclsForObject] objectEnumerator];
      while ((currentUID = [aclsEnum nextObject]))
        {
          if (!([currentUID isEqualToString: ownerLogin]
                || [currentUID isEqualToString: defaultUserID]
                || [currentUID isEqualToString: @"anonymous"])) 
            {
                  // Set the current user in order to get information associated with it
                  [self setCurrentUser: currentUID];

                  // Build the object associated with the key; currentUID
                  object = [NSDictionary dictionaryWithObjectsAndKeys: currentUser, @"UID",
                                                                      [self currentUserClass], @"userClass",
                                                                      [self currentUserDisplayName], @"displayName",
                                                                      [NSNumber numberWithBool:[self currentUserIsSubscribed]], @"isSubscribed", nil];
                  [users addObject:object];
            }
        }
      // Adding the Any authenticated user and the public access
      [users addObject:[NSDictionary dictionaryWithObjectsAndKeys: @"<default>", @"UID", @"Any authenticated user", @"displayName", @"public-user", @"userClass", nil]];
      if ([self isPublicAccessEnabled])
        [users addObject:[NSDictionary dictionaryWithObjectsAndKeys: @"anonymous", @"UID", @"Public access", @"displayName", @"public-user", @"userClass", nil]];
      prepared = YES;
    }

  result = [self responseWithStatus: 200
                          andString: [users jsonRepresentation]];

  return result;
}

- (void) setCurrentUser: (NSString *) newCurrentUser
{
  ASSIGN (currentUser, newCurrentUser);
}

- (NSString *) currentUser
{
  return ([currentUser hasPrefix: @"@"]
          ? [currentUser substringFromIndex: 1]
          : currentUser);
}

- (NSString *) currentUserClass
{
  return ([currentUser hasPrefix: @"@"]
          ? @"normal-group"
          : @"normal-user");
}

- (NSString *) currentUserDisplayName
{
  SOGoUserManager *um;

  um = [SOGoUserManager sharedUserManager];

  return [um getFullEmailForUID: [self currentUser]];
}

- (BOOL) currentUserIsSubscribed
{
  SOGoGCSFolder *folder;

  folder = [self clientObject];

  return ([folder respondsToSelector: @selector (userIsSubscriber:)] && [folder userIsSubscriber: currentUser]);
}

- (void) setUserUIDS: (NSString *) retainedUsers
{
  if ([retainedUsers length] > 0)
    {
      savedUIDs = [retainedUsers componentsSeparatedByString: @","];
      [savedUIDs retain];
    }
  else
    savedUIDs = [NSArray new];
}

- (NSString *) folderID
{
  return [[self clientObject] nameInContainer];
}

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
                           inContext: (WOContext *) context
{
  return ([[request method] isEqualToString: @"POST"]);
}

- (id <WOActionResults>) saveAclsAction
{
  NSEnumerator *aclsEnum;
  SOGoObject *clientObject;
  NSString *currentUID, *ownerLogin;

  clientObject = [self clientObject];
  ownerLogin = [clientObject ownerInContext: context];
  aclsEnum = [[self aclsForObject] objectEnumerator];
  while ((currentUID = [[aclsEnum nextObject] objectForKey: @"c_uid"]))
    if ([currentUID isEqualToString: ownerLogin]
        || [savedUIDs containsObject: currentUID])
      [users removeObject: currentUID];
  [clientObject removeAclsForUsers: users];

  return [self jsCloseWithRefreshMethod: nil];
}

- (BOOL) isPublicAccessEnabled
{
  return [[SOGoSystemDefaults sharedSystemDefaults]
           enablePublicAccess];
}

@end
