/* UIxObjectActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse inc.
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
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <SoObjects/SOGo/SOGoObject.h>
#import <SoObjects/SOGo/SOGoPermissions.h>

#import "WODirectAction+SOGo.h"

#import "UIxObjectActions.h"

@implementation UIxObjectActions

- (WOResponse *) addUserInAclsAction
{
  WOResponse *response;
  NSString *uid;
  unsigned int code;

  uid = [[context request] formValueForKey: @"uid"];
  if ([[self clientObject] addUserInAcls: uid])
    code = 204;
  else
    code = 403;

  response = [context response];
  [response setStatus: code];

  return response;
}

- (WOResponse *) removeUserFromAclsAction
{
  WOResponse *response;
  NSString *uid;
  unsigned int code;

  uid = [[context request] formValueForKey: @"uid"];
  if ([[self clientObject] removeUserFromAcls: uid])
    code = 204;
  else
    code = 403;

  response = [context response];
  [response setStatus: code];

  return response;
}

- (WOResponse *) deleteAction
{
  WOResponse *response;

  response = (WOResponse *) [[self clientObject] delete];
  if (!response)
    response = [self responseWithStatus: 204];

  return response;
}

@end
