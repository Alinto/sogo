/* UIxCalMainActions.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
 *
 * Author: Cyril Robert <crobert@inverse.ca>
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

#import <Foundation/Foundation.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <Appointments/SOGoWebAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>

#import "UIxCalMainActions.h"

@implementation UIxCalMainActions

- (NSString *) displayNameForUrl: (NSString *) calendarURL
{
  NSString *rc, *tmp;

  tmp = [calendarURL lastPathComponent];
  if (tmp)
    {
      if ([[tmp pathExtension] caseInsensitiveCompare: @"ics"] == NSOrderedSame)
	rc = [tmp substringToIndex: [tmp length] - 4];
      else
	rc = tmp;
    }
  else
    rc = [self labelForKey: @"Web Calendar"];

  return rc;
}

- (WOResponse *) addWebCalendarAction
{
  WORequest *r;
  WOResponse *response;
  SOGoWebAppointmentFolder *folder;
  NSString *urlString, *displayName;
  NSMutableDictionary *rc;
  SOGoAppointmentFolders *folders;

  r = [context request];

  urlString = [[r formValueForKey: @"url"] stringByTrimmingSpaces];
  if ([urlString length] > 0)
    {
      folders = [self clientObject];
      displayName = [self displayNameForUrl: urlString];
      folder = [folders newWebCalendarWithName: displayName
                                         atURL: urlString];
      if (folder)
        {
          response = [self responseWithStatus: 200];
          [response setHeader: @"application/json" forKey: @"content-type"];
          
          rc = [NSMutableDictionary dictionary];
          [rc setObject: [folder displayName] forKey: @"name"];
          [rc setObject: [folder folderReference] forKey: @"folderID"];
          [response appendContentString: [rc jsonRepresentation]];
        }
      else
        response = (WOResponse *)
          [NSException exceptionWithHTTPStatus: 400
                                        reason: @"folder was not created"];
    }
  else
    response = (WOResponse *)
      [NSException exceptionWithHTTPStatus: 400
                                    reason: @"missing 'url' parameter"];
  

  return response;
}

@end
