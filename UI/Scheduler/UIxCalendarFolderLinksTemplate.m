/* UIxCalendarFolderLinksTemplate.m - this file is part of SOGo
 *
 * Copyright (C) 2015 Inverse inc.
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

#import <Foundation/NSURL.h>

#import <SOGo/SOGoSystemDefaults.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoWebAppointmentFolder.h>

#import "UIxCalendarFolderLinksTemplate.h"

@implementation UIxCalendarFolderLinksTemplate

- (id) init
{
  if ((self = [super init]))
    {
      calendar = [self clientObject];
      baseCalDAVURL = nil;
      basePublicCalDAVURL = nil;
    }

  return self;
}

- (void) dealloc
{
  [baseCalDAVURL release];
  [basePublicCalDAVURL release];
  [super dealloc];
}

- (NSString *) _baseCalDAVURL
{
  NSString *davURL;

  if (!baseCalDAVURL)
    {
      davURL = [[calendar realDavURL] absoluteString];
      if ([davURL hasSuffix: @"/"])
        baseCalDAVURL = [davURL substringToIndex: [davURL length] - 1];
      else
        baseCalDAVURL = davURL;
      [baseCalDAVURL retain];
    }

  return baseCalDAVURL;
}

- (NSString *) calDavURL
{
  return [NSString stringWithFormat: @"%@/", [self _baseCalDAVURL]];
}

- (NSString *) webDavICSURL
{
  return [calendar webDavICSURL];
}

- (NSString *) webDavXMLURL
{
  return [calendar webDavXMLURL];
}

- (NSString *) _basePublicCalDAVURL
{
  NSString *davURL;
  
  if (!basePublicCalDAVURL)
    {
      davURL = [[calendar publicDavURL] absoluteString];
      if ([davURL hasSuffix: @"/"])
        basePublicCalDAVURL = [davURL substringToIndex: [davURL length] - 1];
      else
        basePublicCalDAVURL = davURL;
      [basePublicCalDAVURL retain];
    }
  
  return basePublicCalDAVURL;
}

- (NSString *) publicCalDavURL
{
  return [NSString stringWithFormat: @"%@/", [self _basePublicCalDAVURL]];
}

- (NSString *) publicWebDavICSURL
{
  return [calendar publicWebDavICSURL];
}

- (NSString *) publicWebDavXMLURL
{
  return [calendar publicWebDavXMLURL];
}

- (BOOL) isPublicAccessEnabled
{
  // NOTE: This method is the same found in Common/UIxAclEditor.m
  return [[SOGoSystemDefaults sharedSystemDefaults]
           enablePublicAccess];
}

- (BOOL) isWebCalendar
{
  return ([calendar isKindOfClass: [SOGoWebAppointmentFolder class]]);
}

- (NSString *) webCalendarURL
{
  return [calendar folderPropertyValueInCategory: @"WebCalendars"];
}

@end
