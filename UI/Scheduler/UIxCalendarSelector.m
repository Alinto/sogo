/* UIxCalendarSelector.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGExtensions/NGExtensions.h>
#import <NGCards/iCalPerson.h>

#import <SOGo/SOGoUser.h>
#import <SOGoUI/UIxComponent.h>
#import <Appointments/SOGoAppointmentFolder.h>

#import "UIxCalendarSelector.h"

static inline char
darkenedColor (const char value)
{
  char newValue;

  if (value >= '0' && value <= '9')
    newValue = ((value - '0') / 2) + '0';
  else if (value >= 'a' && value <= 'f')
    newValue = ((value + 10 - 'a') / 2) + '0';
  else if (value >= 'A' && value <= 'F')
    newValue = ((value + 10 - 'A') / 2) + '0';
  else
    newValue = value;

  return newValue;
}

static inline NSString *
colorForNumber (unsigned int number)
{
  unsigned int index, currentValue;
  unsigned char colorTable[] = { 1, 1, 1 };
  NSString *color;

  if (number == 0)
    color = @"#ccf";
  else if (number == NSNotFound)
    color = @"#f00";
  else
    {
      currentValue = number;
      index = 0;
      while (currentValue)
        {
          if (currentValue & 1)
            colorTable[index]++;
          if (index == 3)
            index = 0;
          currentValue >>= 1;
          index++;
        }
      color = [NSString stringWithFormat: @"#%2x%2x%2x",
                        (255 / colorTable[2]) - 1,
                        (255 / colorTable[1]) - 1,
                        (255 / colorTable[0]) - 1];
    }

  return color;
}

@implementation UIxCalendarSelector

- (id) init
{
  if ((self = [super init]))
    {
      colors = nil;
      currentCalendarFolder = nil;
    }

  return self;
}

- (void) dealloc
{
  [currentCalendarFolder release];
  [colors release];
  [super dealloc];
}

- (NSArray *) calendarFolders
{
  NSArray *calendarFolders;
  NSEnumerator *newFolders;
  NSDictionary *currentFolder;
  unsigned int count;

  calendarFolders = [[self clientObject] calendarFolders];
  if (!colors)
    {
      colors = [NSMutableDictionary new];
      count = 0;
      newFolders = [calendarFolders objectEnumerator];
      currentFolder = [newFolders nextObject];
      while (currentFolder)
	{
	  [colors setObject: colorForNumber (count)
		  forKey: [currentFolder objectForKey: @"folder"]];
	  count++;
	  currentFolder = [newFolders nextObject];
	}
    }

  return calendarFolders;
}

- (void) setCurrentCalendarFolder: (NSDictionary *) newCurrentCalendarFolder
{
  ASSIGN (currentCalendarFolder, newCurrentCalendarFolder);
}

- (NSDictionary *) currentCalendarFolder
{
  return currentCalendarFolder;
}

- (NSString *) currentCalendarSpanBG
{
  NSString *colorKey;

  colorKey = [currentCalendarFolder objectForKey: @"folder"];

  return [colors objectForKey: colorKey];
}

- (NSString *) currentCalendarLogin
{
  NSArray *parts;

  parts = [[currentCalendarFolder objectForKey: @"folder"]
	    componentsSeparatedByString: @":"];

  return (([parts count] > 1)
	  ? [parts objectAtIndex: 0]
	  : [[context activeUser] login]);
}

- (NSString *) currentCalendarStyle
{
  NSString *color;

  color = [self currentCalendarSpanBG];

  return [NSString stringWithFormat: @"color: %@; background-color: %@;",
		   color, color];
}

@end /* UIxCalendarSelector */
