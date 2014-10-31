/* UIxUserRightsEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2014 Inverse inc.
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

#import <Foundation/NSDictionary.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoGroup.h>
#import <SOGo/SOGoObject.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserManager.h>

#import <UI/SOGoUI/SOGoACLAdvisory.h>

#import "UIxUserRightsEditor.h"

@implementation UIxUserRightsEditor

- (id) init
{
  if ((self = [super init]))
    {
      uid = nil;
      userRights = [NSMutableArray new];
      defaultUserID = nil;
    }

  return self;
}

- (void) dealloc
{
  [uid release];
  [userRights release];
  [defaultUserID release];
  [super dealloc];
}

- (NSString *) uid
{
  return uid;
}

- (NSString *) folderName
{
  id folder;
  
  folder = [context clientObject];
  
  return [folder displayName];
}

- (BOOL) userIsDefaultUser
{
  if (!defaultUserID)
    ASSIGN (defaultUserID, [[self clientObject] defaultUserID]);

  return [uid isEqualToString: defaultUserID];
}

- (BOOL) userIsAnonymousUser
{
  return [uid isEqualToString: @"anonymous"];
}

- (NSString *) userDisplayName
{
  SOGoUserManager *um;

  if ([self userIsAnonymousUser])
    {
      return [self labelForKey: @"Public Access"];
    }
  else if ([self userIsDefaultUser])
    {
      return [self labelForKey: @"Any Authenticated User"];
    }
  else
    {
      um = [SOGoUserManager sharedUserManager];
      return [NSString stringWithFormat: @"%@ <%@>",
                        [um getCNForUID: uid],
                     [um getEmailForUID: uid]];
    }
}

- (BOOL) _initRights
{
  BOOL response;
  NSString *newUID, *domain;
  SOGoUserManager *um;
  SOGoObject *clientObject;
  SOGoGroup *group;

  response = NO;

  newUID = [[context request] formValueForKey: @"uid"];
  if ([newUID length] > 0)
    {
      if (!defaultUserID)
        ASSIGN (defaultUserID, [[self clientObject] defaultUserID]);

      um = [SOGoUserManager sharedUserManager];
      if ([newUID isEqualToString: defaultUserID] 
          || [newUID isEqualToString: @"anonymous"]
          || [[um getEmailForUID: newUID] length] > 0)
        {
          if (![newUID hasPrefix: @"@"])
            {
              domain = [[context activeUser] domain];
              group = [SOGoGroup groupWithIdentifier: newUID inDomain: domain];
              if (group)
                newUID = [NSString stringWithFormat: @"@%@", newUID];
            }
          ASSIGN (uid, newUID);
          clientObject = [self clientObject];
          [userRights addObjectsFromArray: [clientObject aclsForUser: uid]];

          response = YES;
        }
    }

  return response;
}
- (BOOL) _initRightsForUserID:(NSString *) newUID
{
  BOOL response;
  NSString *domain;
  SOGoUserManager *um;
  SOGoObject *clientObject;
  SOGoGroup *group;

  response = NO;

  if ([newUID length] > 0)
    {
      if (!defaultUserID)
        ASSIGN (defaultUserID, [[self clientObject] defaultUserID]);

      um = [SOGoUserManager sharedUserManager];
      if ([newUID isEqualToString: defaultUserID] || [newUID isEqualToString: @"anonymous"]
                                                  || [[um getEmailForUID: newUID] length] > 0)
        {
          if (![newUID hasPrefix: @"@"])
            {
              domain = [[context activeUser] domain];
              group = [SOGoGroup groupWithIdentifier: newUID inDomain: domain];
              if (group)
                newUID = [NSString stringWithFormat: @"@%@", newUID];
            }
          ASSIGN (uid, newUID);
          clientObject = [self clientObject];
          [userRights addObjectsFromArray: [clientObject aclsForUser: uid]];

          response = YES;
        }
    }
  return response;
}

- (id <WOActionResults>) defaultAction
{
  id <WOActionResults> response;
  NSDictionary *jsonResponse;

  if (![self _initRights])
    {
      jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"No such user."]
                                                 forKey: @"error"];
      response = [self responseWithStatus: 403
                                andString: [jsonResponse jsonRepresentation]];
    }
  else
    {
      jsonResponse = [self userRightsForObject];
      response = [self responseWithStatus: 200
                                andString: [jsonResponse jsonRepresentation]];
    }
  return response;
}

- (void) sendACLAdvisoryTemplateForObject: (id) theObject
{
  NSString *language, *pageName;
  SOGoUserDefaults *ud;
  SOGoACLAdvisory *page;
  WOApplication *app;

  if (!([self userIsDefaultUser] || [self userIsAnonymousUser]))
    {
      ud = [[SOGoUser userWithLogin: uid roles: nil] userDefaults];
      language = [ud language];
      pageName = [NSString stringWithFormat: @"SOGoACL%@ModificationAdvisory",
                           language];

      app = [WOApplication application];
      page = [app pageWithName: pageName inContext: context];
      [page setACLObject: theObject];
      [page setRecipientUID: uid];
      [page send];
    }
}

- (id <WOActionResults>) saveUserRightsAction
{
  id <WOActionResults> response;
  WORequest *request;
  SOGoDomainDefaults *dd;
  NSArray *users;
  NSDictionary *currentUser, *jsonResponse;;
  NSEnumerator *usersList;
  NSString *currentUid;
  NSArray *o;

  request = [[self context] request];
  response = [self responseWithStatus: 200];
  users = [[request contentAsString] objectFromJSONString];
  usersList = [users objectEnumerator];

  while ((currentUser = [usersList nextObject]))
    {
      currentUid = [currentUser objectForKey: @"uid"];
      if (!([self _initRightsForUserID: currentUid]))
        {
          jsonResponse = [NSDictionary dictionaryWithObject: [self labelForKey: @"No such user."]
                                                     forKey: @"error"];
          response = [self responseWithStatus: 403
                                    andString: [jsonResponse jsonRepresentation]];
          break;
        }
      else
        {
          o = [NSArray arrayWithArray: userRights];
          [self updateRights: [currentUser objectForKey: @"rights"]];
          [[self clientObject] setRoles: userRights forUser: currentUid];

          dd = [[context activeUser] domainDefaults];
          if (![o isEqualToArray: userRights] && [dd aclSendEMailNotifications])
            [self sendACLAdvisoryTemplateForObject: [self clientObject]];
        }
    }
  return response;
}

- (void) appendRight: (NSString *) newRight
{
  if (![userRights containsObject: newRight])
    [userRights addObject: newRight];
}

- (void) removeRight: (NSString *) right
{
  if ([userRights containsObject: right])
    [userRights removeObject: right];
}

- (void) appendExclusiveRight: (NSString *) newRight
		     fromList: (NSArray *) list
{
  [userRights removeObjectsInArray: list];
  [self appendRight: newRight];
}

- (void) removeAllRightsFromList: (NSArray *) list
{
  [userRights removeObjectsInArray: list];
}

- (NSDictionary *) userRightsForObject
{
  return [self subclassResponsibility: _cmd];
}

- (void) updateRights: (NSDictionary *) newRights
{
  [self subclassResponsibility: _cmd];
}

@end
