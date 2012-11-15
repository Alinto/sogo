/* SOGoComponentOccurence.m - this file is part of SOGo
 * 
 * Copyright (C) 2008-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
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

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalRepeatableEntityObject.h>

#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoDomainDefaults.h>

#import "SOGoAppointmentObject.h"
#import "SOGoCalendarComponent.h"

#import "SOGoComponentOccurence.h"

@interface SOGoCalendarComponent (OccurenceExtensions)

- (void) prepareDeleteOccurence: (iCalRepeatableEntityObject *) component;

@end

@implementation SOGoComponentOccurence

+ (id) occurenceWithComponent: (iCalRepeatableEntityObject *) newComponent
	  withMasterComponent: (iCalRepeatableEntityObject *) newMaster
		  inContainer: (SOGoCalendarComponent *) newContainer
{
  SOGoComponentOccurence *occurence;
  NSTimeInterval seconds;
  NSString *newName;

  if (newComponent == newMaster)
    newName = @"master";
  else
    {
      seconds = [[newComponent recurrenceId] timeIntervalSince1970];
      newName = [NSString stringWithFormat: @"occurence%d", (int) seconds];
    }
  occurence = [self objectWithName: newName inContainer: newContainer];
  [occurence setComponent: newComponent];
  [occurence setMasterComponent: newMaster];

  return occurence;
}

- (id) init
{
  if ((self = [super init]))
    {
      parentCalendar = nil;
      component = nil;
      master = nil;
      isNew = NO;
    }

  return self;
}

- (void) setIsNew: (BOOL) newIsNew
{
  isNew = newIsNew;
}

- (BOOL) isNew
{
  return isNew;
}

- (void) dealloc
{
  [parentCalendar release];
  [super dealloc];
}

/* SOGoObject overrides */

- (BOOL) isFolderish
{
  return NO;
}

- (NSString *) contentAsString
{
  return [component versitString];
}

- (NSString *) davContentLength
{
  unsigned int length;

  length = [[self contentAsString]
	     lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
  
  return [NSString stringWithFormat: @"%u", length];
}

/* /SOGoObject overrides */

- (void) setComponent: (iCalRepeatableEntityObject *) newComponent
{
  component = newComponent;
  ASSIGN (parentCalendar, [component parent]);
}

- (void) setMasterComponent: (iCalRepeatableEntityObject *) newMaster
{
  master = newMaster;
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  return [container aclsForUser: uid];
}

/* SOGoComponentOccurence protocol */

- (iCalRepeatableEntityObject *) occurence
{
  return component;
}

- (NSException *) prepareDelete
{
  NSArray *occurences;
  NSCalendarDate *recurrenceId, *currentId;
  NSException *error;
  NSString *newContent;
  NSTimeZone *timeZone;
  iCalCalendar *calendar;
  iCalEntityObject *currentOccurence;
  SOGoUserDefaults *ud;
  int max, count;

  if (component == master)
    error = [container delete];
  else
    {
      if ([container respondsToSelector: @selector (prepareDeleteOccurence:)])
	[container prepareDeleteOccurence: component];

      recurrenceId = [component recurrenceId];

      // Remove the specified occurence within the repeating vEvent.
      calendar = [master parent];      
      occurences = [calendar events];
      max = [occurences count];
      count = 1;
      while (count < max)
	{
	  currentOccurence = [occurences objectAtIndex: count];
	  currentId = [currentOccurence recurrenceId];
	  if ([currentId compare: recurrenceId] == NSOrderedSame)
	    {
	      [[calendar children] removeObject: currentOccurence];
	      break;
	    }
	  count++;
	}
      
      // Add an date exception
      if ([master respondsToSelector: @selector (isAllDay)] && [(iCalEvent *)master isAllDay])
        {
          // We're deleting an occurrence of an all-day event; adjust the recurrence id
          // to the user's timezone.
          ud = [[context activeUser] userDefaults];
          timeZone = [ud timeZone];
          [recurrenceId setTimeZone: timeZone];
        }      
      [master addToExceptionDates: recurrenceId];
      [master increaseSequence];

      // We generate the updated iCalendar file and we save it
      // in the database.
      newContent = [calendar versitString];
      error = [container saveContentString: newContent];
    }

  return error;
}

- (NSException *) saveComponent: (iCalRepeatableEntityObject *) newObject
{
  return [container saveComponent: newObject];
}

#warning most of SOGoCalendarComponent and SOGoComponentOccurence share the same external interface... \
  they should be siblings or SOGoComponentOccurence the parent class of SOGoCalendarComponent...
- (NSException *) changeParticipationStatus: (NSString *) newStatus
                               withDelegate: (iCalPerson *) delegate
{
  NSCalendarDate *date;

  date = [component recurrenceId];

  return [container changeParticipationStatus: newStatus
                                 withDelegate: delegate
                              forRecurrenceId: date];
}

@end
