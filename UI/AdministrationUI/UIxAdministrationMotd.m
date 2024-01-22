/* UIxAdministrationMotd.m - this file is part of SOGo
 *
 * Copyright (C) 2023 Alinto
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

#import "UIxAdministrationMotd.h"

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoAdmin.h>

@implementation UIxAdministrationMotd

- (id) init
{
  if ((self = [super init]))
    {
      
    }

  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (WOResponse *) getAction
{
  WOResponse *response;
  SOGoAdmin *admin;
  NSDictionary *jsonResponse;

  admin = [SOGoAdmin sharedInstance];
  if ([admin isConfigured]) {
    jsonResponse = [NSDictionary dictionaryWithObject: nil != [admin getMotd] ? [admin getMotd] : @""
                                                 forKey: @"motd"];
    response = [self responseWithStatus: 200
                    andJSONRepresentation: jsonResponse];
  } else {
    response = [self responseWithStatus: 500
                            andString: @"Missing folder configuration"];
  }

  return response;
}

- (WOResponse *) saveAction
{
  WORequest *request;
  WOResponse *response;
  SOGoUser *user;
  NSException *error;
  NSDictionary *data;
  SOGoAdmin *admin;

  error = nil;
  admin = [SOGoAdmin sharedInstance];
  user = [context activeUser];

  if ([user isSuperUser]) {
    if ([admin isConfigured]) {
      data = [[[context request] contentAsString] objectFromJSONString];
      if ([data objectForKey: @"motd"] 
          && [[data objectForKey: @"motd"] isKindOfClass: [NSString class]]
          && [[data objectForKey: @"motd"] length] > 0) {
            error = [admin saveMotd: [data objectForKey: @"motd"]];
      } else {
        error = [admin deleteMotd];
      }
      
      if (!error) {
        response = [self responseWithStatus: 200
                              andString: @"OK"];
      } else {
        response = [self responseWithStatus: 500
                              andString: @"Error while storing information"];
      }
      
    } else {
      response = [self responseWithStatus: 500
                              andString: @"Missing folder configuration"];
    }
  } else {
    response = [self responseWithStatus: 503
                              andString: @"Forbidden"];
  }

  response = [self responseWithStatus: 200
                              andString: @"OK"];

  return response;
}

@end
