/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <SOGo/NSCalendarDate+SOGo.h>

#import "UIxTaskEditor.h"

/* TODO: CLEAN UP */

#import "common.h"
#import <NGCards/NGCards.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <SOGoUI/SOGoDateFormatter.h>
#import <SOGo/AgenorUserManager.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoTaskObject.h>
#import "UIxComponent+Agenor.h"

@implementation UIxTaskEditor

- (void) dealloc
{
  [dueDate release];
  [super dealloc];
}

- (void) setTaskStartDate: (NSCalendarDate *) _date
{
  [self setStartDate: _date];
}

- (NSCalendarDate *) taskStartDate
{
  return [self startDate];
}

- (void) setTaskDueDate: (NSCalendarDate *) _date
{
  ASSIGN(dueDate, _date);
}

- (NSCalendarDate *) taskDueDate
{
  return dueDate;
}

/* iCal */

- (NSString *) iCalStringTemplate
{
  static NSString *iCalStringTemplate = \
    @"BEGIN:VCALENDAR\r\n"
    @"METHOD:REQUEST\r\n"
    @"PRODID://Inverse groupe conseil/SOGo 0.9\r\n"
    @"VERSION:2.0\r\n"
    @"BEGIN:VTODO\r\n"
    @"UID:%@\r\n"
    @"CLASS:PUBLIC\r\n"
    @"STATUS:NEEDS-ACTION\r\n" /* confirmed by default */
    @"PERCENT-COMPLETE:0\r\n"
    @"DTSTAMP:%@Z\r\n"
    @"SEQUENCE:1\r\n"
    @"PRIORITY:5\r\n"
    @"%@"                   /* organizer */
    @"%@"                   /* participants and resources */
    @"END:VTODO\r\n"
    @"END:VCALENDAR";

  NSCalendarDate *stamp;
  NSString *template, *s;
  unsigned minutes;

  s = [self queryParameterForKey:@"dur"];
  if(s && [s length] > 0) {
    minutes = [s intValue];
  }
  else {
    minutes = 60;
  }
  stamp = [NSCalendarDate calendarDate];
  [stamp setTimeZone: [NSTimeZone timeZoneWithName: @"GMT"]];
  
  s = [self iCalParticipantsAndResourcesStringFromQueryParameters];
  template   = [NSString stringWithFormat:iCalStringTemplate,
                         [[self clientObject] nameInContainer],
                         [stamp iCalFormattedDateTimeString],
                         [self iCalOrganizerString],
                         s];
  return template;
}

/* new */

- (id) newAction
{
  /*
    This method creates a unique ID and redirects to the "edit" method on the
    new ID.
    It is actually a folder method and should be defined on the folder.
    
    Note: 'clientObject' is the SOGoAppointmentFolder!
          Update: remember that there are group folders as well.
  */
  NSString *uri, *objectId, *method, *ps;

  objectId = [NSClassFromString(@"SOGoAppointmentFolder")
			       globallyUniqueObjectId];
  if ([objectId length] == 0) {
    return [NSException exceptionWithHTTPStatus:500 /* Internal Error */
			reason:@"could not create a unique ID"];
  }

  method = [NSString stringWithFormat:@"Calendar/%@/editAsTask", objectId];
  method = [[self userFolderPath] stringByAppendingPathComponent:method];

  /* check if participants have already been provided */
  ps     = [self queryParameterForKey:@"ps"];
//   if (ps) {
//     [self setQueryParameter:ps forKey:@"ps"];
//   }
 if (!ps
     && [[self clientObject] respondsToSelector:@selector(calendarUIDs)]) {
    AgenorUserManager *um;
    NSArray *uids;
    NSMutableArray *emails;
    unsigned i, count;

    /* add all current calendarUIDs as default participants */

    um     = [AgenorUserManager sharedUserManager];
    uids   = [[self clientObject] calendarUIDs];
    count  = [uids count];
    emails = [NSMutableArray arrayWithCapacity:count];
    
    for (i = 0; i < count; i++) {
      NSString *email;
      
      email = [um getEmailForUID:[uids objectAtIndex:i]];
      if (email)
        [emails addObject:email];
    }
    ps = [emails componentsJoinedByString:@","];
    [self setQueryParameter:ps forKey:@"ps"];
  }
  uri = [self completeHrefForMethod:method];
  return [self redirectToLocation:uri];
}

/* save */

- (void) loadValuesFromTask: (iCalToDo *) _task
{
  NSTimeZone *uTZ;

  [self loadValuesFromComponent: _task];

  uTZ = [[self clientObject] userTimeZone];
  dueDate = [_task due];
//   if (!dueDate)
//     dueDate = [[self startDate] dateByAddingYears: 0 months: 0 days: 0
//                                 hours: 1 minutes: 0 seconds: 0];
  if (dueDate)
    {
      [dueDate setTimeZone: uTZ];
      [dueDate retain];
    }
}

- (void) saveValuesIntoTask: (iCalToDo *) _task
{
  /* merge in form values */
  NSArray *attendees, *lResources;
  iCalRecurrenceRule *rrule;
  NSCalendarDate *dateTime;

  if (hasStartDate)
    dateTime = [self taskStartDate];
  else
    dateTime = nil;
  [_task setStartDate: dateTime];
  if (hasDueDate)
    dateTime = [self taskDueDate];
  else
    dateTime = nil;
  [_task setDue: dateTime];

  [_task setSummary: [self title]];
  [_task setUrl: [self url]];
  [_task setLocation: [self location]];
  [_task setComment: [self comment]];
  [_task setPriority:[self priority]];
  [_task setAccessClass: [self privacy]];
  [_task setStatus: [self status]];

  [_task setCategories: [[self categories] componentsJoinedByString: @","]];
  
#if 0
  /*
    Note: bad, bad, bad!
    Organizer is no form value, thus we MUST NOT change it
  */
  [_task setOrganizer:organizer];
#endif
  attendees  = [self participants];
  lResources = [self resources];
  if ([lResources count] > 0) {
    attendees = ([attendees count] > 0)
      ? [attendees arrayByAddingObjectsFromArray:lResources]
      : lResources;
  }
  [attendees makeObjectsPerformSelector: @selector (setTag:)
             withObject: @"attendee"];
  [_task setAttendees:attendees];

  /* cycles */
  [_task removeAllRecurrenceRules];
  rrule = [self rrule];
  if (rrule)
    [_task addToRecurrenceRules: rrule];
}

- (iCalToDo *) taskFromString: (NSString *) _iCalString
{
  iCalCalendar *calendar;
  iCalToDo *task;
  SOGoTaskObject *clientObject;

  clientObject = [self clientObject];
  calendar = [iCalCalendar parseSingleFromSource: _iCalString];
  task = [clientObject firstTaskFromCalendar: calendar];

  return task;
}

/* conflict management */

- (BOOL) containsConflict: (id) _task
{
  NSArray *attendees, *uids;
  SOGoAppointmentFolder *groupCalendar;
  NSArray *infos;
  NSArray *ranges;
  id folder;

  [self logWithFormat:@"search from %@ to %@", 
	  [_task startDate], [_task due]];

  folder    = [[self clientObject] container];
  attendees = [_task attendees];
  uids      = [folder uidsFromICalPersons:attendees];
  if ([uids count] == 0) {
    [self logWithFormat:@"Note: no UIDs selected."];
    return NO;
  }

  groupCalendar = [folder lookupGroupCalendarFolderForUIDs:uids
                          inContext:[self context]];
  [self debugWithFormat:@"group calendar: %@", groupCalendar];
  
  if (![groupCalendar respondsToSelector:@selector(fetchFreebusyInfosFrom:to:)]) {
    [self errorWithFormat:@"invalid folder to run freebusy query on!"];
    return NO;
  }

  infos = [groupCalendar fetchFreebusyInfosFrom:[_task startDate]
                         to:[_task due]];
  [self debugWithFormat:@"  process: %d tasks", [infos count]];

  ranges = [infos arrayByCreatingDateRangesFromObjectsWithStartDateKey:@"startDate"
                  andEndDateKey:@"dueDate"];
  ranges = [ranges arrayByCompactingContainedDateRanges];
  [self debugWithFormat:@"  blocked ranges: %@", ranges];

  return [ranges count] != 0 ? YES : NO;
}

- (id <WOActionResults>) defaultAction
{
  NSString *ical;

  /* load iCalendar file */
  
  // TODO: can't we use [clientObject contentAsString]?
//   ical = [[self clientObject] valueForKey:@"iCalString"];
  ical = [[self clientObject] contentAsString];
  if ([ical length] == 0) /* a new task */
    ical = [self iCalStringTemplate];
  
  [self setICalString:ical];
  [self loadValuesFromTask: [self taskFromString: ical]];
  
  if (![self canEditComponent]) {
    /* TODO: we need proper ACLs */
    return [self redirectToLocation: [self completeURIForMethod: @"../view"]];
  }

  return self;
}

- (id <WOActionResults>) saveAction
{
  iCalToDo *task;
  iCalPerson *p;
  id <WOActionResults> result;
  NSString *content;
  NSException *ex;

  if (![self isWriteableClientObject]) {
    /* return 400 == Bad Request */
    return [NSException exceptionWithHTTPStatus:400
                        reason: @"method cannot be invoked on "
                                @"the specified object"];
  }

  task = [self taskFromString: [self iCalString]];
  if (task == nil) {
    NSString *s;
    
    s = [self labelForKey: @"Invalid iCal data!"];
    [self setErrorText: s];

    return self;
  }

  [self saveValuesIntoTask:task];
  p = [task findParticipantWithEmail:[self emailForUser]];
  if (p) {
    [p setParticipationStatus:iCalPersonPartStatAccepted];
  }

  if ([self checkForConflicts]) {
    if ([self containsConflict:task]) {
      NSString *s;
      
      s = [self labelForKey:@"Conflicts found!"];
      [self setErrorText:s];

      return self;
    }
  }
  content = [[task parent] versitString];
//   [task release]; task = nil;
  
  if (content == nil) {
    NSString *s;
    
    s = [self labelForKey: @"Could not create iCal data!"];
    [self setErrorText: s];
    return self;
  }
  
  ex = [[self clientObject] saveContentString:content];
  if (ex != nil) {
    [self setErrorText:[ex reason]];
    return self;
  }

  if ([[[[self context] request] formValueForKey: @"nojs"] intValue])
    result = [self redirectToLocation: [self applicationPath]];
  else
    result = [self jsCloseWithRefreshMethod: @"refreshTasks()"];

  return result;
}

- (id) changeStatusAction
{
  iCalToDo *task;
  SOGoTaskObject *taskObject;
  NSString *content;
  id ex;
  int newStatus;

  newStatus = [[self queryParameterForKey: @"status"] intValue];

  taskObject = [self clientObject];
  task = [taskObject task];
  switch (newStatus)
    {
    case 1:
      [task setCompleted: [NSCalendarDate calendarDate]];
      break;
    case 2:
      [task setStatus: @"IN-PROCESS"];
      break;
    case 3:
      [task setStatus: @"CANCELLED"];
      break;
    default:
      [task setStatus: @"NEEDS-ACTION"];
    }

  content = [[task parent] versitString];
  ex = [[self clientObject] saveContentString: content];
  if (ex != nil) {
    [self setErrorText:[ex reason]];
    return self;
  }
  
  return [self redirectToLocation: [self completeURIForMethod: @".."]];
}

- (id)acceptAction {
  return [self acceptOrDeclineAction:YES];
}

- (id)declineAction {
  return [self acceptOrDeclineAction:NO];
}

- (NSString *) saveUrl
{
  return [NSString stringWithFormat: @"%@/saveAsTask",
                   [[self clientObject] baseURL]];
}

// TODO: add tentatively

- (id)acceptOrDeclineAction:(BOOL)_accept {
  // TODO: this should live in the SoObjects
  NSException *ex;

  if ((ex = [self validateObjectForStatusChange]) != nil)
    return ex;
  
  ex = [[self clientObject] changeParticipationStatus:
                              _accept ? @"ACCEPTED" : @"DECLINED"
                            inContext:[self context]];
  if (ex != nil) return ex;
  
  return [self redirectToLocation: [self completeURIForMethod:@"../view"]];
}

- (void) setHasStartDate: (BOOL) aBool
{
  hasStartDate = aBool;
}

- (BOOL) hasStartDate
{
  return ([self taskStartDate] != nil);
}

- (BOOL) startDateDisabled
{
  return ![self hasStartDate];
}

- (void) setHasDueDate: (BOOL) aBool
{
  hasDueDate = aBool;
}

- (BOOL) hasDueDate
{
  return ([self taskDueDate] != nil);
}

- (BOOL) dueDateDisabled
{
  return ![self hasDueDate];
}

- (void) setDueDateDisabled: (BOOL) aBool
{
}

- (void) setStartDateDisabled: (BOOL) aBool
{
}

@end /* UIxTaskEditor */
