/* UIxContactFolderProperties.m - this file is part of SOGo
 *
 * Copyright (C) 2015-2018 Inverse inc.
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
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WORequest.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoSystemDefaults.h>

#import <Contacts/SOGoContactGCSFolder.h>

#import "UIxContactFolderProperties.h"

@implementation UIxContactFolderProperties

- (id) init
{
  if ((self = [super init]))
    {
      addressbook = [self clientObject];
    }

  return self;
}

- (void) dealloc
{
  [super dealloc];
}

/**
 * @api {post} /so/:username/Contacts/:addressbookId/save Save addressbook
 * @apiDescription Save an addressbook's properties.
 * @apiVersion 1.0.0
 * @apiName PostSaveProperties
 * @apiGroup AddressBook
 *
 * @apiParam {String} name                Human readable name
 * @apiParam {Number} synchronize         1 if we enable EAS synchronization for this addressbook
 */
- (WOResponse *) savePropertiesAction
{
  WORequest *request;
  WOResponse *response;
  NSDictionary *params, *message;
  id o;

  request = [context request];
  params = [[request contentAsString] objectFromJSONString];
  response = [self responseWith204];

  NS_DURING
    {
      o = [params objectForKey: @"name"];
      if ([o isKindOfClass: [NSString class]])
        [addressbook renameTo: o];

      o = [params objectForKey: @"synchronize"];
      if ([o isKindOfClass: [NSNumber class]])
        [addressbook setSynchronize: [o boolValue]];
    }
  NS_HANDLER
    {
      message = [NSDictionary dictionaryWithObject: [localException reason] forKey: @"message"];
      response = [self responseWithStatus: 400 /* Bad Request */
                                andString: [message jsonRepresentation]];

    }
  NS_ENDHANDLER;

  return response;
}

- (BOOL) isEasUIEnabled
{
  return ![[SOGoSystemDefaults sharedSystemDefaults] isEasUIDisabled];
}

@end
