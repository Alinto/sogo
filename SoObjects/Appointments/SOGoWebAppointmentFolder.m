/* SOGoWebAppointmentFolder.m - this file is part of SOGo
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
#import <NGCards/iCalCalendar.h>
#import <GDLContentStore/GCSFolder.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserSettings.h>

#import "SOGoWebAppointmentFolder.h"

@implementation SOGoWebAppointmentFolder

- (void) deleteAllContent
{
  [[self ocsFolder] deleteAllContent];
}

- (int) loadWebCalendar
{
  NSURL *url;
  NSData *data;
  NSString *location, *contents;
  iCalCalendar *calendar;
  int imported = 0;

  location = [self folderPropertyValueInCategory: @"WebCalendars"];
  url = [NSURL URLWithString: location];
  if (url)
    {
      data = [url resourceDataUsingCache: NO];

      if (!data && [[location lowercaseString] hasPrefix: @"https"]) 
	{
	  NSLog(@"WARNING: Your GNUstep installation might not have SSL support.");
	  return -1;
	}

      contents = [[NSString alloc] initWithData: data 
                                       encoding: NSUTF8StringEncoding];
      [contents autorelease];
      calendar = [iCalCalendar parseSingleFromSource: contents];
      if (calendar)
        {
          [self deleteAllContent];
          imported = [self importCalendar: calendar];
        }
      else
        {
          imported = -1;
        }
    }
  
  return imported;
}

- (void) setReloadOnLogin: (BOOL) newReloadOnLogin
{
  [self setFolderPropertyValue: [NSNumber numberWithBool: newReloadOnLogin]
                    inCategory: @"AutoReloadedWebCalendars"];
}

- (BOOL) reloadOnLogin
{
  return [[self folderPropertyValueInCategory: @"AutoReloadedWebCalendars"]
           boolValue];
}

- (NSException *) delete
{
  NSException *error;

  error = [super delete];
  if (!error)
    [self setFolderPropertyValue: nil inCategory: @"WebCalendars"];

  return error;
}

@end /* SOGoAppointmentFolder */
