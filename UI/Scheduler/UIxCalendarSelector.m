/* UIxCalendarSelector.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2015 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOResponse.h>

#import <SOGo/NSDictionary+Utilities.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>

#import "UIxCalendarSelector.h"

static inline unsigned int
_intValueFromHexChar (unichar hexChar)
{
  unichar base;

  if (hexChar >= '0' && hexChar <= '9')
    base = '0';
  else if (hexChar >= 'A' && hexChar <= 'F')
    base = 'A' - 10;
  else
    base = 'a' - 10;

  return (hexChar - base);
}

static inline unsigned int
_intValueFromHex (NSString *hexString)
{
  unsigned int value, count, max;

  value = 0;
  max = [hexString length];
  for (count = 0; count < max; count++)
    value = (value * 16
	     + _intValueFromHexChar([hexString characterAtIndex: count]));

  return value;
}

@implementation UIxCalendarSelector

- (id) init
{
  if ((self = [super init]))
    {
      calendars = nil;
      currentCalendar = nil;
    }

  return self;
}

- (void) dealloc
{
  [calendars release];
  [currentCalendar release];
  [super dealloc];
}

- (NSArray *) calendars
{
  NSArray *folders;
  SOGoAppointmentFolders *co;
  SOGoAppointmentFolder *folder;
  NSMutableDictionary *calendar;
  unsigned int count, max;
  NSString *folderName, *fDisplayName;
  NSNumber *isActive, *fActiveTasks;
  
  if (!calendars)
  {
    co = [self clientObject];
    folders = [co subFolders];
    max = [folders count];
    calendars = [[NSMutableArray alloc] initWithCapacity: max];
    for (count = 0; count < max; count++)
    {
      folder = [folders objectAtIndex: count];
      calendar = [NSMutableDictionary dictionary];
      folderName = [folder nameInContainer];
      fDisplayName = [folder displayName];
      if (fDisplayName == nil)
        fDisplayName = @"";
      if ([fDisplayName isEqualToString: [co defaultFolderName]])
        fDisplayName = [self labelForKey: fDisplayName];
      [calendar setObject: [NSString stringWithFormat: @"/%@", folderName]
                   forKey: @"id"];
      [calendar setObject: fDisplayName forKey: @"displayName"];
      [calendar setObject: folderName forKey: @"folder"];
      [calendar setObject: [folder calendarColor] forKey: @"color"];
      isActive = [NSNumber numberWithBool: [folder isActive]];
      [calendar setObject: isActive forKey: @"active"];
      [calendar setObject: [folder ownerInContext: context]
                   forKey: @"owner"];
      fActiveTasks = [folder activeTasks];
      if (fActiveTasks > 0)
        [calendar setObject: fActiveTasks forKey:@"activeTasks" ];
      [calendars addObject: calendar];
    }
  }
  
  return calendars;
}

- (void) setCurrentCalendar: (NSDictionary *) newCalendar
{
  ASSIGN (currentCalendar, newCalendar);
}

- (NSDictionary *) currentCalendar
{
  return currentCalendar;
}

- (NSString *) currentCalendarClass
{
  return [currentCalendar
	   keysWithFormat: @"colorBox calendarFolder%{folder}"];
}

- (NSString *) currentCalendarStyle
{
  return [currentCalendar
	   keysWithFormat: @"color: %{color}; background-color: %{color};"];
}

/* code taken from Lightning 0.7 */
- (NSString *) contrastingTextColor
{
  NSString *bgColor;
  unsigned int red, green, blue;
  float brightness;

  bgColor = [[currentCalendar objectForKey: @"color"] substringFromIndex: 1];
  red = _intValueFromHex ([bgColor substringFromRange: NSMakeRange (0, 2)]);
  green = _intValueFromHex ([bgColor substringFromRange: NSMakeRange (2, 2)]);
  blue = _intValueFromHex ([bgColor substringFromRange: NSMakeRange (4, 2)]);
  brightness = (0.299 * red) + (0.587 * green) + (0.114 * blue);

  return ((brightness < 144) ? @"white" : @"black");
}

/**
 * @api {get} /so/:username/Calendar/:calendarId/calendarslist Get calendars
 * @apiVersion 1.0.0
 * @apiName GetCalendarsList
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/calendarslist
 *
 * @apiSuccess (Success 200) {Object[]} calendars List of calendars
 * @apiSuccess (Success 200) {String} id          Calendar ID
 * @apiSuccess (Success 200) {String} displayName Human readable name
 * @apiSuccess (Success 200) {String} owner       User ID of owner
 * @apiSuccess (Success 200) {String} color       Calendar's hex color code
 * @apiSuccess (Success 200) {Number} active      1 if the calendar is enabled
 * @apiSuccess (Success 200) {Number} activeTasks Number of incompleted tasks
 */
- (WOResponse *) calendarsListAction
{
  NSDictionary *data;
  WOResponse *response;

  data = [NSDictionary dictionaryWithObject: [self calendars]
                                     forKey: @"calendars"];
  response = [self responseWithStatus: 200 andJSONRepresentation: data];

  return response;
}

@end /* UIxCalendarSelector */
