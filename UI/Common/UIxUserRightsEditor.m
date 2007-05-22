/* UIxUserRightsEditor.m - this file is part of SOGo
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

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <SoObjects/SOGo/LDAPUserManager.h>
#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/SOGoObject.h>

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
  [super dealloc];
}

- (NSString *) uid
{
  return uid;
}

- (BOOL) userIsDefaultUser
{
  if (!defaultUserID)
    ASSIGN (defaultUserID, [[self clientObject] defaultUserID]);

  return [uid isEqualToString: defaultUserID];
}

- (NSString *) userDisplayName
{
  LDAPUserManager *um;

  um = [LDAPUserManager sharedUserManager];

  return [NSString stringWithFormat: @"%@ <%@>",
		   [um getCNForUID: uid],
		   [um getEmailForUID: uid]];
}

- (BOOL) _initRights
{
  BOOL response;
  NSString *newUID;
  LDAPUserManager *um;
  SOGoObject *clientObject;
  unsigned int count;

  response = NO;

  newUID = [[context request] formValueForKey: @"uid"];
  if ([newUID length] > 0)
    {
      if (!defaultUserID)
	ASSIGN (defaultUserID, [[self clientObject] defaultUserID]);

      um = [LDAPUserManager sharedUserManager];
      if ([newUID isEqualToString: defaultUserID]
	  || [[um getEmailForUID: newUID] length] > 0)
	{
	  ASSIGN (uid, newUID);
	  clientObject = [self clientObject];
	  [userRights addObjectsFromArray: [clientObject aclsForUser: uid]];
	  count = [userRights count];
	  if (!count || (count == 1 && [[userRights objectAtIndex: 0]
					 isEqualToString: SOGoRole_None]))
	    [userRights setArray: [clientObject defaultAclRoles]];

	  response = YES;
	}
    }

  return response;
}

- (id <WOActionResults>) defaultAction
{
  id <WOActionResults> response;

  if (![self _initRights])
    response = [NSException exceptionWithHTTPStatus: 403
			    reason: @"No such user."];
  else
    {
      [self prepareRightsForm];
      response = self;
    }

  return response;
}

- (id <WOActionResults>) saveUserRightsAction
{
  id <WOActionResults> response;

  if (![self _initRights])
    response = [NSException exceptionWithHTTPStatus: 403
			    reason: @"No such user."];
  else
    {
      [self updateRights];
      [[self clientObject] setRoles: userRights forUser: uid];
      response = [self jsCloseWithRefreshMethod: nil];
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

- (void) prepareRightsForm
{
}

- (void) updateRights
{
  [self subclassResponsibility: _cmd];
}

@end
