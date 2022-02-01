/*
  Copyright (C) 2006-2014-2021 Inverse inc.

  This file is part of SOGo.

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

#import <Foundation/NSCalendarDate.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalToDo.h>


#import "iCalCalendar+SOGo.h"
#import "NSArray+Appointments.h"
#import "SOGoTaskOccurence.h"

#import "SOGoTaskObject.h"

@implementation SOGoTaskObject

- (NSString *) componentTag
{
  return @"vtodo";
}

- (iCalRepeatableEntityObject *) lookupOccurrence: (NSString *) recID
{
  return [[self calendar: NO secure: NO] todoWithRecurrenceID: recID];
}

- (SOGoComponentOccurence *) occurence: (iCalRepeatableEntityObject *) occ
{
  NSArray *allTodos;

  allTodos = [[occ parent] todos];

  return [SOGoTaskOccurence occurenceWithComponent: occ
			    withMasterComponent: [allTodos objectAtIndex: 0]
			    inContainer: self];
}

#warning this code should be put in SOGoCalendarComponent once the UID hack\
  in SOGoAppointmentObject is resolved
- (NSException *) saveComponent: (id) theComponent
                    baseVersion: (unsigned int) newVersion
{
  NSException *ex;
  iCalToDo *todo;

  todo = (iCalToDo*)[theComponent firstChildWithTag: [self componentTag]];
  [self sendReceiptEmailForObject: todo
                   addedAttendees: nil
                 deletedAttendees: nil
                 updatedAttendees: nil
                        operation: [self isNew] ? TaskCreated : TaskUpdated];

  ex = [super saveComponent: theComponent baseVersion: newVersion];
  [fullCalendar release];
  fullCalendar = nil;
  [safeCalendar release];
  safeCalendar = nil;
  [originalCalendar release];
  originalCalendar = nil;

  return ex;
}

- (iCalRepeatableEntityObject *) newOccurenceWithID: (NSString *) theRecurrenceID
{
  iCalToDo *newOccurence, *master;
  NSCalendarDate *date, *firstDate;
  NSTimeInterval interval;

  newOccurence = (iCalToDo *) [super newOccurenceWithID: theRecurrenceID];
  date = [newOccurence recurrenceId];
  [newOccurence setStartDate: date];

  master = [self component: NO secure: NO];

  if ([master due])
    {
      firstDate = [master startDate];
      interval = [[master due]
                   timeIntervalSinceDate: (NSDate *)firstDate];
  
      [newOccurence setDue: [date addYear: 0
                                    month: 0
                                      day: 0
                                     hour: 0
                                   minute: 0
                                   second: interval]];
    }

  return newOccurence;
}

- (void) prepareDeleteOccurence: (iCalToDo *) occurence
{

}

- (NSException *) prepareDelete
{
  iCalToDo *todo = [self component: NO secure: NO];

  [self sendReceiptEmailForObject: todo
                   addedAttendees: nil
                 deletedAttendees: nil
                 updatedAttendees: nil
                        operation: TaskDeleted];

  return [super prepareDelete];
}

- (id) PUTAction: (WOContext *) _ctx
{
  iCalCalendar *rqCalendar;
  WORequest *rq;

  rq = [_ctx request];
  rqCalendar = [iCalCalendar parseSingleFromSource: [rq contentAsString]];

  // We are unable to parse the received calendar, we return right away
  // with a 400 error code.
  if (!rqCalendar)
    {
      return [NSException exceptionWithDAVStatus: 400
                                          reason: @"Unable to parse task."];
    }

  [self adjustClassificationInRequestCalendar: rqCalendar];
  [rq setContent: [[rqCalendar versitString] dataUsingEncoding: [rq contentEncoding]]];

  return [super PUTAction: _ctx];
}

@end /* SOGoTaskObject */
