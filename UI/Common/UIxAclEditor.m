/* UIxAclEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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
#import <Foundation/NSKeyValueCoding.h>
#import <NGObjWeb/SoUser.h>
#import <NGObjWeb/WORequest.h>
#import <NGCards/iCalPerson.h>
#import <SoObjects/SOGo/AgenorUserManager.h>
#import <SoObjects/SOGo/SOGoAclsFolder.h>
#import <SoObjects/SOGo/SOGoPermissions.h>

#import "UIxAclEditor.h"

@implementation UIxAclEditor

- (id) init
{
  if ((self = [super init]))
    {
      acls = nil;
      prepared = NO;
      publishInFreeBusy = NO;
      users = [NSMutableArray new];
      delegates = [NSMutableArray new];
      assistants = [NSMutableArray new];
      ownerCN = nil;
    }

  return self;
}

- (void) dealloc
{
  [users release];
  [delegates release];
  [assistants release];
  if (ownerCN)
    [ownerCN release];
  [super dealloc];
}

- (NSArray *) aclsForFolder
{
  SOGoAclsFolder *folder;

  if (!acls)
    {
      folder = [SOGoAclsFolder aclsFolder];
      acls = [folder aclsForObject: [self clientObject]];
    }

  return acls;
}

- (NSString *) ownerCN
{
  if (!ownerCN)
    {
      ownerCN = [[self clientObject] ownerInContext: context];
      [ownerCN retain];
    }

  return ownerCN;
}

- (void) _prepareUsers
{
  NSEnumerator *aclsEnum;
  AgenorUserManager *um;
  NSDictionary *currentAcl;
  iCalPerson *currentUser;
  NSString *currentUID;

  aclsEnum = [[self aclsForFolder] objectEnumerator];
  um = [AgenorUserManager sharedUserManager];
  currentAcl = [aclsEnum nextObject];
  while (currentAcl)
    {
      currentUID = [currentAcl objectForKey: @"c_uid"];
      if ([currentUID isEqualToString: @"freebusy"])
        publishInFreeBusy = YES;
      else
        {
          currentUser = [um iCalPersonWithUid: currentUID];
          if (![[currentUser cn] isEqualToString: [self ownerCN]])
            {
              if ([[currentAcl objectForKey: @"c_role"]
                    isEqualToString: SOGoRole_Delegate])
                [delegates addObject: [currentUser cn]];
              else
                [assistants addObject: [currentUser cn]];
              [users addObject: currentUser];
            }
        }
      currentAcl = [aclsEnum nextObject];

      prepared = YES;
    }
}

- (NSArray *) usersForFolder
{
  if (!prepared)
    [self _prepareUsers];

  return users;
}

- (NSArray *) delegates
{
  if (!prepared)
    [self _prepareUsers];

  return delegates;
}

- (NSString *) assistantsValue
{
  if (!prepared)
    [self _prepareUsers];

  return [assistants componentsJoinedByString: @","];
}

- (NSString *) delegatesValue
{
  if (!prepared)
    [self _prepareUsers];

  return [delegates componentsJoinedByString: @","];
}

- (BOOL) publishInFreeBusy
{
  if (!prepared)
    [self _prepareUsers];

  return publishInFreeBusy;
}

- (NSString *) toolbar
{
  return (([[self ownerCN] isEqualToString: [[context activeUser] login]])
          ? @"SOGoAclOwner.toolbar" : @"SOGoAclAssistant.toolbar");
}

- (BOOL) clientIsCalendar
{
  return [NSStringFromClass ([[self clientObject] class])
                            isEqualToString: @"SOGoAppointmentFolder"];
}

- (id) saveAclsAction
{
  NSString *uids;
  NSArray *fbUsers;
  WORequest *request;
  SOGoAclsFolder *folder;
  SOGoObject *clientObject;

  folder = [SOGoAclsFolder aclsFolder];
  request = [context request];
  clientObject = [self clientObject];
  uids = [request formValueForKey: @"delegates"];
  [folder setRoleForObject: clientObject
          forUsers: [uids componentsSeparatedByString: @","]
          to: SOGoRole_Delegate];
  uids = [request formValueForKey: @"assistants"];
  [folder setRoleForObject: clientObject
          forUsers: [uids componentsSeparatedByString: @","]
          to: SOGoRole_Assistant];
  if ([self clientIsCalendar]) {
    if ([[request formValueForKey: @"freebusy"] intValue])
      fbUsers = [NSArray arrayWithObject: @"freebusy"];
    else
      fbUsers = nil;
    [folder setRoleForObject: clientObject
            forUsers: fbUsers
            to: SOGoRole_FreeBusy];
  }

  return [self jsCloseWithRefreshMethod: nil];
}

@end
