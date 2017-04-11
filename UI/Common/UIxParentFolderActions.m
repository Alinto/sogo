/* UIxParentFolderActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2016 Inverse inc.
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
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>

#import <SoObjects/SOGo/SOGoParentFolder.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserSettings.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>

#import "UIxParentFolderActions.h"

@implementation UIxParentFolderActions

/**
 * @api {post} /so/:username/:module/createFolder Create folder
 * @apiVersion 1.0.0
 * @apiName PostCreateFolder
 * @apiGroup Common
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/createFolder \
 *          -H "Content-Type: application/json" \
 *          -d '{ "name": "Business" }'
 *
 * @apiDescription Called to create a new calendar or a new address book.
 *
 * @apiParam {String} name            The display name of the new folder
 * @apiSuccess (Success 201) {String} id Folder ID
 */
- (id <WOActionResults>) createFolderAction
{
  WOResponse *response;
  NSString *name, *nameInContainer;
  NSDictionary *params, *data;
  WORequest *request;

  request = [context request];
  params = [[request contentAsString] objectFromJSONString];

  name = [params objectForKey: @"name"];
  nameInContainer = nil;

  if ([name length] > 0)
    {
      if (![[self clientObject] hasLocalSubFolderNamed: name])
        {
          response = (WOResponse *) [[self clientObject] newFolderWithName: name
                                                           nameInContainer: &nameInContainer];
          if (!response)
            {
              data = [NSDictionary dictionaryWithObjectsAndKeys: nameInContainer, @"id", nil];
              response = [self responseWithStatus: 201
                                        andString: [data jsonRepresentation]];
          }
        }
      else
        {
          data = [NSDictionary dictionaryWithObjectsAndKeys: @"That name already exists", @"error", nil];
          response = [self responseWithStatus: 409
                                    andString: [data jsonRepresentation]];
        }
    }
  else
    {
      data = [NSDictionary dictionaryWithObjectsAndKeys: @"The name is missing", @"error", nil];
      response = [self responseWithStatus: 400
                                andString: [data jsonRepresentation]];
    }

  return response;
}

- (WOResponse *) saveFoldersActivationAction
{
  NSDictionary *params;
  NSEnumerator *foldersEnumerator;
  NSMutableArray *folderSubscription;
  NSMutableDictionary *moduleSettings;
  NSString *baseFolder, *folderName;
  SOGoParentFolder *clientObject;
  SOGoUser *activeUser;
  SOGoUserSettings *us;
  WORequest *request;
  BOOL makeActive;

  request = [context request];
  params = [[request contentAsString] objectFromJSONString];
  activeUser = [context activeUser];
  clientObject = [self clientObject];
  baseFolder = [clientObject nameInContainer];
  us = [activeUser userSettings];
  moduleSettings = [us objectForKey: baseFolder];
  if (!moduleSettings)
    moduleSettings = [NSMutableDictionary dictionary];
  [us setObject: moduleSettings forKey: baseFolder];
  folderSubscription = [moduleSettings objectForKey: @"InactiveFolders"];
  if (!folderSubscription)
    {
      folderSubscription = [NSMutableArray array];
      [moduleSettings setObject: folderSubscription forKey: @"InactiveFolders"];
    }

  foldersEnumerator = [params keyEnumerator];
  while ((folderName = [foldersEnumerator nextObject]))
    {
      makeActive = [[params objectForKey: folderName] boolValue];
      if (makeActive)
        [folderSubscription removeObject: folderName];
      else
        [folderSubscription addObjectUniquely: folderName];
    }
  [us synchronize];

  return [self responseWith204];
}


@end
