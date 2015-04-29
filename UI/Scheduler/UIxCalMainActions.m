/* UIxCalMainActions.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2015 Inverse inc.
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
#import <SOGo/NSString+Utilities.h>
#import <Appointments/SOGoWebAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>

#import "UIxCalMainActions.h"

@implementation UIxCalMainActions

- (WOResponse *) addWebCalendarAction
{
  NSDictionary *params;
  NSException *ex;
  NSMutableDictionary *jsonResponse;
  NSString *urlString;
  SOGoAppointmentFolders *folders;
  SOGoWebAppointmentFolder *folder;
  WORequest *request;
  unsigned int httpStatus;

  ex = nil;
  request = [context request];
  params = [[request contentAsString] objectFromJSONString];

  urlString = [[params objectForKey: @"url"] stringByTrimmingSpaces];
  if ([urlString length] > 0)
    {
      folders = [self clientObject];
      folder = [folders newWebCalendarWithURL: urlString
			      nameInContainer: nil];
      
      if (folder)
        {
          jsonResponse = [NSMutableDictionary dictionary];
          [jsonResponse setObject: [folder displayName] forKey: @"name"];
          [jsonResponse setObject: [folder name] forKey: @"id"];
        }
      else
        ex = [NSException exceptionWithName: @"newWebCalendarWithURLException"
                                     reason: @"Can't subscribe to Web calendar"
                                   userInfo: nil];
    }
  else
    ex = [NSException exceptionWithName: @"missingParameterException"
                                 reason: @"Missing 'url' parameter"
                               userInfo: nil];

  if (ex)
    {
      httpStatus = 500;
      jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"failure", @"status",
                                   [ex reason], @"message",
                                   nil];
    }
  else
    httpStatus = 200;

  return [self responseWithStatus: httpStatus
            andJSONRepresentation: jsonResponse];
}

@end
