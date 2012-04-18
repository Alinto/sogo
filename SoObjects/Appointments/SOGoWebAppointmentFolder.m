/* SOGoWebAppointmentFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2010 Inverse inc.
 *
 * Author: Cyril Robert <crobert@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
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

#import <curl/curl.h>

#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOHTTPConnection.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGHttp/NGHttpResponse.h>

#import <NGCards/iCalCalendar.h>
#import <GDLContentStore/GCSFolder.h>
#import <SOGo/SOGoAuthenticator.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>

#import "SOGoWebAppointmentFolder.h"

@class WOHTTPURLHandle;

@implementation SOGoWebAppointmentFolder

- (void) deleteAllContent
{
  [[self ocsFolder] deleteAllContent];
}

- (NSDictionary *) _loadAuthData
{
  NSDictionary *authData;
  NSString *authValue, *userPassword;
  NSArray *parts, *keys;
  
  userPassword = [[self authenticatorInContext: context]
                   passwordInContext: context];
  if ([userPassword length] == 0)
    {
      authData = nil;
    }
  else
    {
      authValue
        = [[self folderPropertyValueInCategory: @"WebCalendarsAuthentication"]
            decryptWithKey: userPassword];
      parts = [authValue componentsSeparatedByString: @":"];
      if ([parts count] == 2)
        {
          keys = [NSArray arrayWithObjects: @"username",  @"password", nil];
          authData = [NSDictionary dictionaryWithObjects: parts
                                                 forKeys: keys];
        }
      else
        authData = nil;
    }

  return authData;
}

- (void) setUsername: (NSString *) username
         andPassword: (NSString *) password
{
  NSString *authValue, *userPassword;

  userPassword = [[self authenticatorInContext: context]
                   passwordInContext: context];
  if ([userPassword length] > 0)
    {
      if (!username)
        username = @"";
      if (!password)
        password = @"";
      authValue = [NSString stringWithFormat: @"%@:%@", username, password];
      [self setFolderPropertyValue: [authValue encryptWithKey: userPassword]
                        inCategory: @"WebCalendarsAuthentication"];
    }
}

- (NSDictionary *) loadWebCalendar
{
  NSString *location, *httpauth;
  NSDictionary *authInfos;
  NSMutableData *bodyData;
  NSURL *url;
  CURL *curl;
  CURLcode rc;
  char error[CURL_ERROR_SIZE];
  NSMutableDictionary *result;
  NSString *content, *newDisplayName;
  iCalCalendar *calendar;
  NSUInteger imported, status;

  result = [NSMutableDictionary dictionary];

  // Prepare HTTPS post using libcurl
  location = [self folderPropertyValueInCategory: @"WebCalendars"];
  [result setObject: location forKey: @"url"];

  url = [NSURL URLWithString: location];
  if (url)
    {
      curl_global_init (CURL_GLOBAL_SSL);
      curl = curl_easy_init ();
      if (curl)
        {
          curl_easy_setopt (curl, CURLOPT_URL, [location UTF8String]);
          curl_easy_setopt (curl, CURLOPT_SSL_VERIFYPEER, 0L);
          curl_easy_setopt (curl, CURLOPT_SSL_VERIFYHOST, 0L);

          authInfos = [self _loadAuthData];
          if (authInfos)
            {
              httpauth = [authInfos keysWithFormat: @"%{username}:%{password}"];
              curl_easy_setopt (curl, CURLOPT_USERPWD, [httpauth UTF8String]);
              curl_easy_setopt (curl, CURLOPT_HTTPAUTH, CURLAUTH_ANY);
            }

          bodyData = [NSMutableData data];
          size_t curlBodyFunction (void *ptr, size_t size, size_t nmemb, void *inSelf)
          {
            size_t total;

            total = size * nmemb;
            [bodyData appendBytes: ptr length: total];

            return total;
          }
          curl_easy_setopt (curl, CURLOPT_WRITEFUNCTION, curlBodyFunction);

          error[0] = 0;
          curl_easy_setopt (curl, CURLOPT_ERRORBUFFER, &error);
      
          // Perform SOAP request
          rc = curl_easy_perform (curl);
          if (rc == 0)
            {
              curl_easy_getinfo (curl, CURLINFO_RESPONSE_CODE, &status);
              [result setObject: [NSNumber numberWithUnsignedInt: status]
                         forKey: @"status"];

              if (status == 200)
                {
                  content = [[NSString alloc] initWithData: bodyData
                                                  encoding: NSUTF8StringEncoding];
                  if (!content)
                    content = [[NSString alloc] initWithData: bodyData
                                                    encoding: NSISOLatin1StringEncoding];
                  [content autorelease];
                  calendar = [iCalCalendar parseSingleFromSource: content];
                  if (calendar)
                    {
                      newDisplayName = [[calendar
                                          firstChildWithTag: @"x-wr-calname"]
                                         flattenedValuesForKey: @""];
                      if ([newDisplayName length] > 0)
                        [self setDisplayName: newDisplayName];
                      [self deleteAllContent];
                      imported = [self importCalendar: calendar];
                      [result setObject: [NSNumber numberWithInt: imported]
                                 forKey: @"imported"];
                    }
                  else
                    [result setObject: @"invalid-calendar-content" forKey: @"error"];
                }
              else
                [result setObject: @"http-error" forKey: @"error"];
            }
          else
            [result setObject: @"bad-url" forKey: @"error"];
          curl_easy_cleanup (curl);
        }
    }
  else
    [result setObject: @"invalid-url" forKey: @"error"];

  return result;
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
    {
      [self setFolderPropertyValue: nil inCategory: @"WebCalendars"];
      [self setFolderPropertyValue: nil inCategory: @"WebCalendarsAuthentication"];
    }

  return error;
}

@end /* SOGoAppointmentFolder */
