/* iCalCalendar+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2012-2014 Inverse inc
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalRepeatableEntityObject.h>

#import "iCalCalendar+SOGo.h"
#import "iCalEntityObject+SOGo.h"

@implementation iCalCalendar (SOGoExtensions)

- (id) _occurrence: (NSString *) recID
           inArray: (NSArray *) components
{
  id occurrence;
  iCalRepeatableEntityObject *component;
  NSUInteger count, max, seconds, recSeconds;

  occurrence = nil;

  seconds = [recID intValue];

  max = [components count];

  /* master occurrence */
  component = [components objectAtIndex: 0];

  if ([component hasRecurrenceRules])
    {
      count = 1; // skip master event
      while (!occurrence && count < max)
	{
	  component = [components objectAtIndex: count];
          recSeconds = [[component recurrenceId] timeIntervalSince1970];
	  if (recSeconds == seconds)
	    occurrence = component;
	  else
	    count++;
	}
    }
  else
    {
      /* The "master" event could be that occurrence. */
      recSeconds = [[component recurrenceId] timeIntervalSince1970];
      if (recSeconds == seconds)
        occurrence = component;
    }

  return occurrence;
}

- (iCalEvent *) eventWithRecurrenceID: (NSString *) recID
{
  return [self _occurrence: recID inArray: [self events]];
}

- (iCalToDo *) todoWithRecurrenceID: (NSString *) recID;
{
  return [self _occurrence: recID inArray: [self todos]];
}

- (NSMutableDictionary *) quickRecordFromContent: (NSString *) theContent
				       container: (id) theContainer
				 nameInContainer: (NSString *) nameInContainer
{
  CardGroup *element;
  NSArray *elements;
  
  unsigned int count;
 
  elements = [self allObjects];
  count = [elements count];
  if (count)
    element = [elements objectAtIndex: 0];
  else
    {
      //NSLog(@"ERROR: given calendar contains no elements: %@", self);
      element = nil;
    }

  return [(id)element quickRecordFromContent: theContent  container: theContainer  nameInContainer: nameInContainer];
}

@end
