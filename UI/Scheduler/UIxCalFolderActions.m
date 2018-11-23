/*
  Copyright (C) 2006-2016 Inverse inc.

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
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSValue.h>

#import <NGHttp/NGHttpRequest.h>
#import <NGObjWeb/NSException+HTTP.h>
#define COMPILING_NGOBJWEB 1 /* httpRequest is needed in
                                importAction */
#import <NGObjWeb/WORequest.h>
#undef COMPILING_NGOBJWEB
#import <NGObjWeb/WOResponse.h>
#import <NGMime/NGMimeMultipartBody.h>

#import <NGCards/iCalCalendar.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>

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
                          [[folderICS displayName] asQPSubjectString: @"utf-8"]];
  [response setHeader: disposition forKey: @"Content-Disposition"];

  return response;
}

- (WOResponse *) importAction
{
  SOGoAppointmentFolder *folder;
  NSMutableDictionary *rc;
  iCalCalendar *additions;
  NSString *fileContent;
  WOResponse *response;
  WORequest *request;
  NSArray *cals;
  id data;

  int i, imported;

  imported = 0;
  rc = [NSMutableDictionary dictionary];
  request = [context request];
  folder = [self clientObject];
  data = [[request httpRequest] body];

  // We got an exception, that means the file upload limit
  // has been reached.
  if ([data isKindOfClass: [NSException class]])
    {
      response = [self responseWithStatus: 507];
      return response;
    }

  data = [[[data parts] lastObject] body];

  fileContent = [[NSString alloc] initWithData: (NSData *) data 
                                      encoding: NSUTF8StringEncoding];
  if (fileContent == nil)
    fileContent = [[NSString alloc] initWithData: (NSData *) data 
                                        encoding: NSISOLatin1StringEncoding];
  [fileContent autorelease];

  if (fileContent && [fileContent length] 
      && [fileContent hasPrefix: @"BEGIN:"])
    {
      cals = [iCalCalendar parseFromSource: fileContent];

      for (i = 0; i < [cals count]; i++)
        {
          additions = [cals objectAtIndex: i];
          imported += [folder importCalendar: additions];
        }
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

/**
 * @api {get} /so/:username/Scheduler/:calendarId/reload Load Web calendar
 * @apiVersion 1.0.0
 * @apiName PostReloadWebCalendar
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/5B30-55419180-7-6B687280/reload
 *
 * @apiDescription Load and parse the events from a remote Web calendar (.ics)
 *
 * @apiSuccess (Success 200) {Number} status     The HTTP code received when accessing the remote URL
 * @apiSuccess (Success 200) {String} [imported] The number of imported events in case of success
 * @apiError   (Error 500)   {String} [error]    The error type in case of a failure
 */
- (WOResponse *) reloadAction
{
  NSDictionary *results;
  unsigned int httpCode;

  httpCode = 200;
  results = [[self clientObject] loadWebCalendar];

  if ([results objectForKey: @"status"])
    httpCode = [[results objectForKey: @"status"] intValue];

  return [self responseWithStatus: httpCode andJSONRepresentation: results];
}

- (WOResponse *) setCredentialsAction
{
  NSDictionary *params;
  NSString *username, *password;
  WORequest *request;
  WOResponse *response;

  request = [context request];
  params = [[request contentAsString] objectFromJSONString];

  username = [[params objectForKey: @"username"] stringByTrimmingSpaces];
  password = [[params objectForKey: @"password"] stringByTrimmingSpaces];
  if ([username length] > 0 && [password length] > 0)
    {
      [[self clientObject] setUsername: username
                           andPassword: password];
      response = [self responseWith204];
    }
  else
    response = [self responseWithStatus: 400
                  andJSONRepresentation: [NSDictionary dictionaryWithObject: @"missing 'username' and/or"
                                                       @" 'password' parameters"
                                                                     forKey: @"message"]];

  return response;
}

@end /* UIxCalFolderActions */
