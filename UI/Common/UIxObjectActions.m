/* UIxObjectActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2016 Inverse inc.
 *
 * Author: Inverse <info@inverse.ca>
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
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <SoObjects/SOGo/SOGoContentObject.h>

#import <SOGo/NSDictionary+Utilities.h>

#import "UIxObjectActions.h"

@implementation UIxObjectActions

/**
 * @api {get} /so/:username/:folderPath/addUserInAcls?uid=:uid Add user to ACLs
 * @apiVersion 1.0.0
 * @apiName GetAddUserInAcls
 * @apiGroup Common
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/addUserInAcls?uid=sogo2
 *
 * @apiParam {String} uid User ID
 */
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

/**
 * @api {get} /so/:username/:folderPath/removeUserFromAcls?uid=:uid Remove user from ACLs
 * @apiVersion 1.0.0
 * @apiName GetRemoveUserFromAcls
 * @apiGroup Common
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/removeUserInAcls?uid=sogo2
 *
 * @apiParam {String} uid User ID
 */
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
  NSDictionary *data;
  SOGoContentObject *deleteObject;

  deleteObject = [self clientObject];
  if ([deleteObject respondsToSelector: @selector (prepareDelete)])
    [deleteObject prepareDelete];
  response = (WOResponse *) [deleteObject delete];

  if (response)
    {
      data = [NSDictionary dictionaryWithObjectsAndKeys: [(NSException *) response reason], @"message", nil];
      response = [self responseWithStatus: 403
                    andJSONRepresentation: data];
    }
  else
    {
      response = [self responseWithStatus: 204];
    }

  return response;
}

@end
