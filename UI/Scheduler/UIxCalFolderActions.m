/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/Foundation.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/SOGo/NSString+Utilities.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSNull+misc.h>

#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentObject.h>
#import <GDLContentStore/GCSFolder.h>
#import <NGCards/iCalCalendar.h>

#import "UIxCalFolderActions.h"

@implementation UIxCalFolderActions

- (WOResponse *) exportAction
{
  WOResponse *response;
  SOGoAppointmentFolder *folder;
  SOGoAppointmentObject *appt;
  NSArray *array, *values, *fields;
  NSMutableString *rc;
  NSString *filename;
  iCalCalendar *calendar, *component;
  int i, count;

  fields = [NSArray arrayWithObjects: @"c_name", @"c_content", nil];
  rc = [NSMutableString string];

  response = [context response];

  folder = [self clientObject];
  calendar = [iCalCalendar groupWithTag: @"vcalendar"];

  array = [folder bareFetchFields: fields
                             from: nil
                               to: nil
                            title: nil
                        component: nil
                additionalFilters: nil];
  count = [array count];
  for (i = 0; i < count; i++)
    {
      appt = [folder lookupName: [[array objectAtIndex: i] objectForKey: @"c_name"]
                      inContext: [self context]
                        acquire: NO];

      component = [appt calendar: NO secure: NO];
      values = [component events];
      if (values && [values count])
        [calendar addChildren: values];
      values = [component todos];
      if (values && [values count])
        [calendar addChildren: values];
      values = [component journals];
      if (values && [values count])
        [calendar addChildren: values];
      values = [component freeBusys];
      if (values && [values count])
        [calendar addChildren: values];
      values = [component childrenWithTag: @"vtimezone"];
      if (values && [values count])
        [calendar addChildren: values];
    }
  
  filename = [NSString stringWithFormat: @"attachment;filename=\"%@.ics\"",
              [folder displayName]];
  [response setHeader: @"text/calendar; charset=utf-8" 
               forKey:@"content-type"];
  [response setHeader: filename 
               forKey: @"Content-Disposition"];
  [response setContent: [[calendar versitString] dataUsingEncoding: NSUTF8StringEncoding]];
  
  return response;
}

- (WOResponse *) importAction
{
  SOGoAppointmentFolder *folder;
  NSMutableDictionary *rc;
  WORequest *request;
  WOResponse *response;
  NSString *fileContent;
  id data;
  iCalCalendar *additions;
  int imported;

  imported = 0;
  rc = [NSMutableDictionary dictionary];
  request = [context request];
  folder = [self clientObject];
  data = [request formValueForKey: @"calendarFile"];
  if ([data respondsToSelector: @selector(isEqualToString:)])
    fileContent = (NSString *) data;
  else
    {
      fileContent = [[NSString alloc] initWithData: (NSData *) data 
                                          encoding: NSUTF8StringEncoding];
      [fileContent autorelease];
    }

  if (fileContent && [fileContent length] 
      && [fileContent hasPrefix: @"BEGIN:"])
    {
      additions = [iCalCalendar parseSingleFromSource: fileContent];
      imported = [folder importCalendar: additions];
    }

  [rc setObject: [NSNumber numberWithInt: imported]
         forKey: @"imported"];

  response = [self responseWithStatus: 200];
  [response setHeader: @"text/html" 
               forKey: @"content-type"];
  [(WOResponse*)response appendContentString: [rc jsonRepresentation]];
  return response;
}


@end /* UIxCalFolderActions */
