/* UIxUserRightsEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2009 Inverse inc.
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
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <SoObjects/SOGo/SOGoUserManager.h>
#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/SOGoObject.h>
#import <SoObjects/SOGo/SOGoGroup.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <UI/SOGoUI/SOGoACLAdvisory.h>
#import <Foundation/NSUserDefaults.h>

#import "UIxUserRightsEditor.h"

static BOOL sendACLAdvisories = NO;

@implementation UIxUserRightsEditor

+ (void) initialize
{
  NSUserDefaults *ud;

  ud = [NSUserDefaults standardUserDefaults];
  sendACLAdvisories = [ud boolForKey: @"SOGoACLsSendEMailNotifications"];
}

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

- (BOOL) userIsDefaultUser
{
  if (!defaultUserID)
    ASSIGN (defaultUserID, [[self clientObject] defaultUserID]);

  return [uid isEqualToString: defaultUserID];
}

- (NSString *) userDisplayName
{
  SOGoUserManager *um;

  um = [SOGoUserManager sharedUserManager];

  return [NSString stringWithFormat: @"%@ <%@>",
		   [um getCNForUID: uid],
		   [um getEmailForUID: uid]];
}

- (BOOL) _initRights
{
  BOOL response;
  NSString *newUID;
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
	  || [[um getEmailForUID: newUID] length] > 0)
	{
	  if (![newUID hasPrefix: @"@"])
	    {
	      group = [SOGoGroup groupWithIdentifier: newUID];
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

- (void) sendACLAdvisoryTemplateForObject: (id) theObject
{
  NSString *language, *pageName;
  SOGoUser *user;
  SOGoACLAdvisory *page;
  WOApplication *app;

  user = [SOGoUser userWithLogin: uid roles: nil];
  language = [user language];
  pageName = [NSString stringWithFormat: @"SOGoACL%@ModificationAdvisory",
		       language];

  app = [WOApplication application];
  page = [app pageWithName: pageName inContext: context];
  [page setACLObject: theObject];
  [page setRecipientUID: uid];
  [page send];
}

- (id <WOActionResults>) saveUserRightsAction
{
  id <WOActionResults> response;

  if (![self _initRights])
    response = [NSException exceptionWithHTTPStatus: 403
			    reason: @"No such user."];
  else
    {
      NSArray *o;

      o = [NSArray arrayWithArray: userRights];

      [self updateRights];
      [[self clientObject] setRoles: userRights forUser: uid];

      if (![o isEqualToArray: userRights] && sendACLAdvisories)
	{
	  [self sendACLAdvisoryTemplateForObject: [self clientObject]];
	} 
      
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
