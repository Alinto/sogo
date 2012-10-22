/*
  Copyright (C) 2006-2012 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of SOGo

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSValue.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGCards/iCalCalendar.h>

#import <SOGo/NSDictionary+Utilities.h>

#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoWebAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolderICS.h>

#import "UIxCalFolderActions.h"

@implementation UIxCalFolderActions

- (WOResponse *) exportAction
{
  WOResponse *response;
  SOGoAppointmentFolderICS *folderICS;
  NSString *disposition;

  folderICS = [self clientObject];
  response = [self responseWithStatus: 200
                            andString: [folderICS contentAsString]];
  [response setHeader: @"text/calendar; charset=utf-8" 
               forKey: @"content-type"];
  disposition = [NSString stringWithFormat: @"attachment; filename=\"%@.ics\"",
                          [folderICS displayName]];
  [response setHeader: disposition forKey: @"Content-Disposition"];

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
      if (fileContent == nil)
        fileContent = [[NSString alloc] initWithData: (NSData *) data 
                                            encoding: NSISOLatin1StringEncoding];
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

/* These methods are only available on instance of SOGoWebAppointmentFolder. */
- (WOResponse *) reloadAction
{
  WOResponse *response;
  NSDictionary *results;

  response = [self responseWithStatus: 200];
  [response setHeader: @"application/json" forKey: @"content-type"];
  results = [[self clientObject] loadWebCalendar];
  [response appendContentString: [results jsonRepresentation]];

  return response;
}

- (WOResponse *) setCredentialsAction
{
  WORequest *request;
  WOResponse *response;
  NSString *username, *password;

  request = [context request];

  username = [[request formValueForKey: @"username"] stringByTrimmingSpaces];
  password = [[request formValueForKey: @"password"] stringByTrimmingSpaces];
  if ([username length] > 0 && [password length] > 0)
    {
      [[self clientObject] setUsername: username
                           andPassword: password];
      response = [self responseWith204];
    }
  else
    response
      = (WOResponse *) [NSException exceptionWithHTTPStatus: 400
                                    reason: @"missing 'username' and/or"
                                    @" 'password' parameters"];

  return response;
}

@end /* UIxCalFolderActions */
