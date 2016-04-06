/* CardElement+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2014-2016 Inverse inc.
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import "SOGoUser.h"
#import "SOGoUserDefaults.h"
#import "NSDictionary+Utilities.h"
#import "CardElement+SOGo.h"


@implementation CardElement (SOGoExtensions)

/**
 * From [UIxDatePicker takeValuesFromRequest:inContext:]
 */
- (NSCalendarDate *) dateFromString: (NSString *) dateString
                          inContext: (WOContext *) context
{
  NSInteger dateTZOffset, userTZOffset;
  NSTimeZone *systemTZ, *userTZ;
  SOGoUserDefaults *ud;
  NSCalendarDate *date;

  date = [NSCalendarDate dateWithString: dateString
                         calendarFormat: @"%Y-%m-%d"];
  if (!date)
    [self warnWithFormat: @"Could not parse dateString: '%@'", dateString];

  // We must adjust the date timezone because "dateWithString:..." uses the
  // system timezone, which can be different from the user's. */
  ud = [[context activeUser] userDefaults];
  systemTZ = [date timeZone];
  dateTZOffset = [systemTZ secondsFromGMTForDate: date];
  userTZ = [ud timeZone];
  userTZOffset = [userTZ secondsFromGMTForDate: date];
  if (dateTZOffset != userTZOffset)
    date = [date dateByAddingYears: 0 months: 0 days: 0
                             hours: 0 minutes: 0
                           seconds: (dateTZOffset - userTZOffset)];
  [date setTimeZone: userTZ];

  return date;
}

/**
 * Return the JSON representation of the element as a dictionary with two keys:
 *  - type: the type of the card element, if it exists;
 *  - value: the value of the card element.
 * @return a JSON string representation of the element.
 */
- (NSString *) jsonRepresentation
{
  NSString *v;
  NSMutableDictionary *attrs;

  attrs = [NSMutableDictionary dictionary];

  v = [self value: 0 ofAttribute: @"type"];
  if ([v length])
    [attrs setObject: v
              forKey: @"type"];
  [attrs setObject: [self flattenedValuesForKey: @""]
            forKey: @"value"];

  return [attrs jsonRepresentation];
}

@end /* NGVCard */
