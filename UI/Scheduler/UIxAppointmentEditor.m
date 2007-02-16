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

#import <NGCards/NSString+NGCards.h>
#import <NGCards/NSCalendarDate+NGCards.h>

#import <SOGo/AgenorUserManager.h>
#import <SOGo/NSCalendarDate+SOGo.h>

#import "common.h"
#import <NGCards/NGCards.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <SOGoUI/SOGoDateFormatter.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentObject.h>
#import "UIxComponent+Agenor.h"

#import "UIxAppointmentEditor.h"

/* TODO: CLEAN UP */

@implementation UIxAppointmentEditor

+ (int)version {
  return [super version] + 0 /* v2 */;
}

+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (void) dealloc
{
  [endDate release];
  [super dealloc];
}

/* accessors */

- (void) setAptStartDate: (NSCalendarDate *)_date
{
  [self setStartDate: _date];
}

- (NSCalendarDate *) aptStartDate
{
  return [self startDate];
}

- (void) setAptEndDate: (NSCalendarDate *) _date
{
  ASSIGN(endDate, _date);
}

- (NSCalendarDate *) aptEndDate
{
  return endDate;
}

/* transparency */

- (NSString *) transparency
{
  return @"OPAQUE";
}

/* iCal */

- (NSString *)iCalStringTemplate {
  static NSString *iCalStringTemplate = \
    @"BEGIN:VCALENDAR\r\n"
    @"METHOD:REQUEST\r\n"
    @"PRODID://Inverse groupe conseil/SOGo 0.9\r\n"
    @"VERSION:2.0\r\n"
    @"BEGIN:VEVENT\r\n"
    @"UID:%@\r\n"
    @"CLASS:PUBLIC\r\n"
    @"STATUS:CONFIRMED\r\n" /* confirmed by default */
    @"DTSTAMP:%@Z\r\n"
    @"DTSTART:%@Z\r\n"
    @"DTEND:%@Z\r\n"
    @"TRANSP:%@\r\n"
    @"SEQUENCE:1\r\n"
    @"PRIORITY:5\r\n"
    @"%@"                   /* organizer */
    @"%@"                   /* participants and resources */
    @"END:VEVENT\r\n"
    @"END:VCALENDAR";

  NSTimeZone *utc;
  NSCalendarDate *lStartDate, *lEndDate, *stamp;
  NSString *template, *s;
  unsigned minutes;

  s = [self queryParameterForKey:@"dur"];
  if ([s length] > 0)
    minutes = [s intValue];
  else
    minutes = 60;

  utc = [NSTimeZone timeZoneWithName: @"GMT"];
  lStartDate = [self newStartDate];
  [lStartDate setTimeZone: utc];
  lEndDate = [lStartDate dateByAddingYears: 0 months: 0 days: 0
                         hours: 0 minutes: minutes seconds: 0];

  stamp = [NSCalendarDate calendarDate];
  [stamp setTimeZone: utc];

  s          = [self iCalParticipantsAndResourcesStringFromQueryParameters];
  template   = [NSString stringWithFormat: iCalStringTemplate,
                         [[self clientObject] nameInContainer],
                         [stamp iCalFormattedDateTimeString],
                         [lStartDate iCalFormattedDateTimeString],
                         [lEndDate iCalFormattedDateTimeString],
                         [self transparency],
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

  method = [NSString stringWithFormat:@"Calendar/%@/editAsAppointment", objectId];
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

- (void) loadValuesFromAppointment: (iCalEvent *) appointment
{
  NSTimeZone *uTZ;

  [self loadValuesFromComponent: appointment];

  uTZ = [[self clientObject] userTimeZone];
  endDate = [appointment endDate];
  if (!endDate)
    endDate = [[self startDate] dateByAddingYears: 0 months: 0 days: 0
                                hours: 1 minutes: 0 seconds: 0];

  [endDate setTimeZone: uTZ];
  [endDate retain];
}

- (void) saveValuesIntoAppointment: (iCalEvent *) _appointment
{
  /* merge in form values */
  NSArray *attendees, *lResources;
  iCalRecurrenceRule *rrule;
  
  [_appointment setStartDate:[self aptStartDate]];
  [_appointment setEndDate:[self aptEndDate]];

  [_appointment setSummary: [self title]];
  [_appointment setUrl: [self url]];
  [_appointment setLocation: [self location]];
  [_appointment setComment: [self comment]];
  [_appointment setPriority:[self priority]];
  [_appointment setAccessClass: [self privacy]];
  [_appointment setStatus: [self status]];

//   [_appointment setCategories: [[self categories] componentsJoinedByString: @","]];

  [_appointment setTransparency: [self transparency]];

#if 0
  /*
    Note: bad, bad, bad!
    Organizer is no form value, thus we MUST NOT change it
  */
  [_appointment setOrganizer:organizer];
#endif
  attendees  = [self participants];
  lResources = [self resources];
  if ([lResources count] > 0) {
    attendees = ([attendees count] > 0)
      ? [attendees arrayByAddingObjectsFromArray: lResources]
      : lResources;
  }
  [attendees makeObjectsPerformSelector: @selector (setTag:)
             withObject: @"attendee"];
  [_appointment setAttendees: attendees];

  /* cycles */
  [_appointment removeAllRecurrenceRules];
  rrule = [self rrule];
  if (rrule)
    [_appointment addToRecurrenceRules: rrule];
}

- (iCalEvent *) appointmentFromString: (NSString *) _iCalString
{
  iCalCalendar *calendar;
  iCalEvent *appointment;

  calendar = [iCalCalendar parseSingleFromSource: _iCalString];
  appointment = (iCalEvent *) [calendar firstChildWithTag: @"vevent"];

  return appointment;
}

/* conflict management */

- (BOOL) containsConflict: (id) _apt
{
  NSArray *attendees, *uids;
  SOGoAppointmentFolder *groupCalendar;
  NSArray *infos;
  NSArray *ranges;
  id folder;

  [self logWithFormat:@"search from %@ to %@", 
	  [_apt startDate], [_apt endDate]];

  folder    = [[self clientObject] container];
  attendees = [_apt attendees];
  uids      = [folder uidsFromICalPersons:attendees];
  if ([uids count] == 0) {
    [self logWithFormat:@"Note: no UIDs selected."];
    return NO;
  }

  groupCalendar = [folder lookupGroupCalendarFolderForUIDs:uids
                          inContext:[self context]];
  [self debugWithFormat:@"group calendar: %@", groupCalendar];
  
  if (![groupCalendar respondsToSelector:@selector(fetchFreeBusyInfosFrom:to:)]) {
    [self errorWithFormat:@"invalid folder to run freebusy query on!"];
    return NO;
  }

  infos = [groupCalendar fetchFreeBusyInfosFrom:[_apt startDate]
                         to:[_apt endDate]];
  [self debugWithFormat:@"  process: %d events", [infos count]];

  ranges = [infos arrayByCreatingDateRangesFromObjectsWithStartDateKey: @"startDate"
                  andEndDateKey: @"endDate"];
  ranges = [ranges arrayByCompactingContainedDateRanges];
  [self debugWithFormat:@"  blocked ranges: %@", ranges];

  return [ranges count] != 0 ? YES : NO;
}

/* actions */

- (id) testAction
{
  /* for testing only */
  WORequest *req;
  iCalEvent *apt;
  NSString *content;

  req = [[self context] request];
  apt = [self appointmentFromString: [self iCalString]];
  [self saveValuesIntoAppointment:apt];
  content = [[apt parent] versitString];
  [self logWithFormat:@"%s -- iCal:\n%@",
    __PRETTY_FUNCTION__,
    content];

  return self;
}

- (id<WOActionResults>) defaultAction
{
  NSString *ical;
  
  /* load iCalendar file */
  
  // TODO: can't we use [clientObject contentAsString]?
//   ical = [[self clientObject] valueForKey:@"iCalString"];
  ical = [[self clientObject] contentAsString];
  if ([ical length] == 0) /* a new appointment */
    ical = [self iCalStringTemplate];

  [self setICalString:ical];
  [self loadValuesFromAppointment: [self appointmentFromString: ical]];

//   if (![self canEditComponent]) {
//     /* TODO: we need proper ACLs */
//     return [self redirectToLocation: [self completeURIForMethod: @"../view"]];
//   }
  return self;
}

- (id <WOActionResults>) saveAction
{
  iCalEvent *apt;
  iCalPerson *p;
  id <WOActionResults> result;
  NSString *content;
  NSException *ex;

  if (![self isWriteableClientObject]) {
    /* return 400 == Bad Request */
    return [NSException exceptionWithHTTPStatus:400
                        reason:@"method cannot be invoked on "
                               @"the specified object"];
  }
  
  apt = [self appointmentFromString: [self iCalString]];
  if (apt == nil) {
    NSString *s;
    
    s = [self labelForKey:@"Invalid iCal data!"];
    [self setErrorText:s];
    return self;
  }
  
  [self saveValuesIntoAppointment:apt];
  p = [apt findParticipantWithEmail:[self emailForUser]];
  if (p) {
    [p setParticipationStatus:iCalPersonPartStatAccepted];
  }

  if ([self checkForConflicts]) {
    if ([self containsConflict:apt]) {
      NSString *s;
      
      s = [self labelForKey:@"Conflicts found!"];
      [self setErrorText:s];

      return self;
    }
  }
  content = [[apt parent] versitString];
//   [apt release]; apt = nil;
  
  if (content == nil) {
    NSString *s;
    
    s = [self labelForKey:@"Could not create iCal data!"];
    [self setErrorText:s];
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
    result = [self jsCloseWithRefreshMethod: @"refreshAppointmentsAndDisplay()"];

  return result;
}

- (NSString *) saveUrl
{
  return [NSString stringWithFormat: @"%@/saveAsAppointment",
                   [[self clientObject] baseURL]];
}

- (id) acceptAction
{
  return [self acceptOrDeclineAction:YES];
}

- (id) declineAction
{
  return [self acceptOrDeclineAction:NO];
}

// TODO: add tentatively

- (id) acceptOrDeclineAction: (BOOL) _accept
{
  // TODO: this should live in the SoObjects
  NSException *ex;

  if ((ex = [self validateObjectForStatusChange]) != nil)
    return ex;
  
  ex = [[self clientObject] changeParticipationStatus:
                              _accept ? @"ACCEPTED" : @"DECLINED"
                            inContext:[self context]];
  if (ex != nil) return ex;

  return self;  
//   return [self redirectToLocation: [self completeURIForMethod: @"../view"]];
}

@end /* UIxAppointmentEditor */
