/* UIxCalendarProperties.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2018 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WORequest.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>

#import <Appointments/SOGoWebAppointmentFolder.h>

#import "UIxCalendarProperties.h"

@implementation UIxCalendarProperties

- (id) init
{
  if ((self = [super init]))
    {
      calendar = [self clientObject];
    }

  return self;
}

- (void) dealloc
{
  [super dealloc];
}

/**
 * @api {post} /so/:username/Calendar/:calendarId/save Save calendar
 * @apiDescription Save a calendar's properties.
 * @apiVersion 1.0.0
 * @apiName PostSaveProperties
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/personal/save \
 *          -H "Content-Type: application/json" \
 *          -d '{"name": "Personal Calendar", "notifications": {"notifyOnPersonalModifications": true}}'
 *
 * @apiParam {String} name                Human readable name
 * @apiParam {String} color               Calendar's hex color code
 * @apiParam {Number} includeInFreeBusy   1 if calendar must be include in freebusy
 * @apiParam {Number} showCalendarAlarms  1 if alarms must be enabled
 * @apiParam {Number} showCalendarTasks   1 if tasks must be enabled
 * @apiParam {Number} synchronize         1 if we enable EAS synchronization for this calendar
 * @apiParam {Number} reloadOnLogin       1 if calendar is a Web calendar that must be reload when user logins
 * @apiParam {Object} [notifications]     Notification (if active user is the calendar's owner)
 * @apiParam {Number} notifications.notifyOnPersonalModifications 1 if a mail is sent for each modification made by the owner
 * @apiParam {Number} notifications.notifyOnExternalModifications 1 if a mail is sent for each modification made by someone else
 * @apiParam {Number} notifications.notifyUserOnPersonalModifications 1 if a mail is sent to an external address for modification made by the owner
 * @apiParam {String} [notifications.notifiedUserOnPersonalModifications] Email address to notify changes
 */
- (WOResponse *) savePropertiesAction
{
  WORequest *request;
  WOResponse *response;
  NSDictionary *params, *message;
  id o, values;

  request = [context request];
  params = [[request contentAsString] objectFromJSONString];
  response = [self responseWith204];

  NS_DURING
    {
      o = [params objectForKey: @"name"];
      if ([o isKindOfClass: [NSString class]] && ![o isEqualToString: [calendar displayName]])
        [calendar renameTo: o];

      o = [params objectForKey: @"color"];
      if ([o isKindOfClass: [NSString class]])
        [calendar setCalendarColor: o];

      o = [params objectForKey: @"includeInFreeBusy"];
      if ([o isKindOfClass: [NSNumber class]])
        [calendar setIncludeInFreeBusy: [o boolValue]];

      o = [params objectForKey: @"showCalendarAlarms"];
      if ([o isKindOfClass: [NSNumber class]])
        [calendar setShowCalendarAlarms: [o boolValue]];

      o = [params objectForKey: @"showCalendarTasks"];
      if ([o isKindOfClass: [NSNumber class]])
        [calendar setShowCalendarTasks: [o boolValue]];

      o = [params objectForKey: @"showCalendarTasks"];
      if ([o isKindOfClass: [NSNumber class]])
        [calendar setShowCalendarTasks: [o boolValue]];

      o = [params objectForKey: @"synchronize"];
      if ([o isKindOfClass: [NSNumber class]])
        [calendar setSynchronize: [o boolValue]];

      o = [params objectForKey: @"reloadOnLogin"];
      if ([o isKindOfClass: [NSNumber class]] && [calendar isKindOfClass: [SOGoWebAppointmentFolder class]])
        [(SOGoWebAppointmentFolder *) calendar setReloadOnLogin: [o boolValue]];

      values = [params objectForKey: @"notifications"];
      if ([values isKindOfClass: [NSDictionary class]])
        {
          o = [values objectForKey: @"notifyOnPersonalModifications"];
          if ([o isKindOfClass: [NSNumber class]])
            [calendar setNotifyOnPersonalModifications: [o boolValue]];

          o = [values objectForKey: @"notifyOnExternalModifications"];
          if ([o isKindOfClass: [NSNumber class]])
            [calendar setNotifyOnExternalModifications: [o boolValue]];

          o = [values objectForKey: @"notifyUserOnPersonalModifications"];
          if ([o isKindOfClass: [NSNumber class]])
            [calendar setNotifyUserOnPersonalModifications: [o boolValue]];
        }

      o = [params objectForKey: @"notifiedUserOnPersonalModifications"];
      if ([o isKindOfClass: [NSString class]])
        [calendar setNotifiedUserOnPersonalModifications: o];
    }
  NS_HANDLER
    {
      message = [NSDictionary dictionaryWithObject: [localException reason] forKey: @"message"];
      response = [self responseWithStatus: 400 /* Bad Request */
                                andString: [message jsonRepresentation]];

    }
  NS_ENDHANDLER;

  return response;
}

@end
