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

#import <Foundation/NSValue.h>

#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoGCSFolder.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>

#import "UIxAclEditor.h"

@implementation UIxAclEditor

- (id) init
{
  if ((self = [super init]))
    {
      aclUsers = nil;
      prepared = NO;
      publishInFreeBusy = NO;
      users = [NSMutableDictionary new];
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

- (BOOL) canSubscribeUsers
{
  return [[self clientObject]
           respondsToSelector: @selector (subscribeUserOrGroup:reallyDo:response:)];
}

/**
 * @api {get} /so/:username/:folderPath/acls List users with rights
 * @apiVersion 1.0.0
 * @apiName GetAcls
 * @apiGroup Common
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/acls
 *
 * @apiSuccess (Success 200) {Object[]} users             List of users with ACL for the folder
 * @apiSuccess (Success 200) {String} users.uid           User ID
 * @apiSuccess (Success 200) {String} users.userClass     Either 'normal-user', 'normal-group' or 'public-access'
 * @apiSuccess (Success 200) {Number} users.isSubscribed  1 if the user is subscribed to the folder
 * @apiSuccess (Success 200) {String} [users.cn]          User fullname
 * @apiSuccess (Success 200) {String} [users.c_email]     User main email address
 */
- (id <WOActionResults>) aclsAction
{
  NSString *currentUID, *ownerLogin, *info;
  NSDictionary *currentUserInfos;
  NSMutableDictionary *userData;
  id <WOActionResults> result;
  NSEnumerator *aclsEnum;

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

                  // Build the object associated to the current UID
                  currentUserInfos = [self currentUserInfos];
                  userData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             currentUser, @"uid",
                                           [self currentUserClass], @"userClass",
                                           [NSNumber numberWithBool: [self currentUserIsSubscribed]], @"isSubscribed",
                                           nil];
                  if ([currentUserInfos count] == 0)
                    {
                      [userData setObject: [NSNumber numberWithBool: YES] forKey: @"inactive"];
                    }
                  else
                    {
                      if ((info = [currentUserInfos objectForKey: @"cn"]) && [info length])
                        [userData setObject: info forKey: @"cn"];
                      if ((info = [currentUserInfos objectForKey: @"c_email"]) && [info length])
                        [userData setObject: info forKey: @"c_email"];
                    }
                  [users setObject: userData forKey: currentUID];
            }
        }

      // Add the 'Any authenticated' user
      if (defaultUserID)
      {
          userData = [NSDictionary dictionaryWithObjectsAndKeys:
                                     defaultUserID, @"uid",
                                   [self labelForKey: @"Any Authenticated User"], @"cn",
                                   @"public-user", @"userClass",
                                   nil];
          [users setObject: userData forKey: defaultUserID];
      }

      if ([self canSubscribeUsers] && [self isPublicAccessEnabled])
        {
          // Add the 'public access' user
          userData = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"anonymous", @"uid",
                                   [self labelForKey: @"Public Access"], @"cn",
                                   @"public-user", @"userClass",
                                   nil];
          [users setObject: userData forKey: @"anonymous"];
        }

      prepared = YES;
    }

  result = [self responseWithStatus: 200
              andJSONRepresentation: [NSDictionary dictionaryWithObject: users forKey: @"users"]];

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
  NSDictionary *infos;
  NSString *uid;
  SOGoUserManager *um;

  um = [SOGoUserManager sharedUserManager];
  uid = [self currentUser];
  infos = [um contactInfosForUserWithUIDorEmail: uid inDomain: [[context activeUser] domain]];
  if (infos)
    {
      return [NSString stringWithFormat: @"%@ <%@>",
                    [infos objectForKey: @"cn"],
                    [infos objectForKey: @"c_email"]];
    }
  else
    return uid;
}

- (NSDictionary *) currentUserInfos
{
  SOGoUserManager *um;

  um = [SOGoUserManager sharedUserManager];

  return [um contactInfosForUserWithUIDorEmail: [self currentUser]];
}

- (BOOL) currentUserIsSubscribed
{
  SOGoGCSFolder *folder;

  folder = [self clientObject];

  return ([folder respondsToSelector: @selector (userIsSubscriber:)]
          && [folder userIsSubscriber: currentUser]);
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
      [users removeObjectForKey: currentUID];
  [clientObject removeAclsForUsers: [users allKeys]];

  return [self jsCloseWithRefreshMethod: nil];
}

- (BOOL) isPublicAccessEnabled
{
  return [[SOGoSystemDefaults sharedSystemDefaults] enablePublicAccess];
}

@end
