/* UIxCalMainView.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2009 Inverse inc.
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

#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/SoUser.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGCards/NGCards.h>

#import <SoObjects/Appointments/SOGoAppointmentFolder.h>
#import <SoObjects/Appointments/SOGoAppointmentObject.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoObject.h>

#import <SOGoUI/SOGoAptFormatter.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <GDLContentStore/GCSFolder.h>

#import "UIxCalView.h"

@interface UIxCalView (PrivateAPI)
- (NSString *) _userFolderURI;
@end

@implementation UIxCalView

static BOOL shouldDisplayWeekend = NO;

+ (void) initialize
{
  static BOOL didInit = NO;
  NSUserDefaults *ud;

  if (didInit) return;

  ud = [NSUserDefaults standardUserDefaults];
  shouldDisplayWeekend = [ud boolForKey: @"SOGoShouldDisplayWeekend"];
  didInit = YES;
}

- (id) init
{
  self = [super init];
  if (self)
    {
      timeZone = [[context activeUser] timeZone];
      [timeZone retain];
      aptFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: timeZone];
      aptTooltipFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: timeZone];
      privateAptFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: timeZone];
      privateAptTooltipFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: timeZone];
      [self configureFormatters];
      componentsData = [NSMutableDictionary new];
    }

  return self;
}

- (void) dealloc
{
  [componentsData release];
  [appointments release];
  [allDayApts release];
  [appointment release];
  [currentDay release];
  [aptFormatter release];
  [aptTooltipFormatter release];
  [privateAptFormatter release];
  [privateAptTooltipFormatter release];
  [timeZone release];
  [super dealloc];
}

/* subclasses should override this */
- (void) configureFormatters
{
  NSString *title;

  [aptFormatter setFullDetails];
  [aptTooltipFormatter setTooltip];
  [privateAptFormatter setPrivateDetails];
  [privateAptTooltipFormatter setPrivateTooltip];

  title = [self labelForKey: @"empty title"];
  [aptFormatter setTitlePlaceholder: title];
  [aptTooltipFormatter setTitlePlaceholder: title];

  title = [self labelForKey: @"private appointment"];
  [privateAptFormatter setPrivateTitle: title];
  [privateAptTooltipFormatter setPrivateTitle: title];
}

- (NSArray *) filterAppointments:(NSArray *) _apts
{
  NSMutableArray *filtered;
  unsigned i, count, p, pCount;
  NSString *email, *partmailsString, *state, *pEmail;
  NSDictionary *info, *primaryIdentity;
  NSArray *partmails, *partstates;
  BOOL shouldAdd;

  if ([self shouldDisplayRejectedAppointments])
    return _apts;
  {
    count = [_apts count];
    filtered = [[[NSMutableArray alloc] initWithCapacity: count] autorelease];

    primaryIdentity = [[context activeUser] primaryIdentity];
    email = [primaryIdentity objectForKey: @"email"];

    for (i = 0; i < count; i++)
      {
        shouldAdd = YES;
        info = [_apts objectAtIndex: i];
        partmailsString = [info objectForKey: @"partmails"];
        if ([partmailsString isNotNull])
          {
            partmails = [partmailsString componentsSeparatedByString: @"\n"];
            pCount = [partmails count];
            for (p = 0; p < pCount; p++)
              {
                pEmail = [partmails objectAtIndex: p];
                if ([pEmail isEqualToString: email])
                  {
                    partstates = [[info objectForKey: @"partstates"]
                                   componentsSeparatedByString: @"\n"];
                    state = [partstates objectAtIndex: p];
                    if ([state intValue] == iCalPersonPartStatDeclined)
                      shouldAdd = NO;
                    break;
                  }
              }
          }
        if (shouldAdd)
          [filtered addObject: info];
      }
  }

  return filtered;
}

/* accessors */

- (void) setAppointments:(NSArray *) _apts
{
  _apts = [self filterAppointments: _apts];
  ASSIGN(appointments, _apts);
}

- (NSArray *) appointments
{
  return appointments;
}

- (void) setAppointment:(id) _apt
{
  ASSIGN (appointment, _apt);
}

// - (void) setAppointment:(id) _apt
// {
//   NSString *mailtoChunk;
//   NSString *myEmail;
//   NSString *partmails;

//   ASSIGN(appointment, _apt);

//   /* cache some info about apt for faster access */
  
//   mailtoChunk = [_apt valueForKey: @"orgmail"];
//   myEmail = [self emailForUser];
//   if ([mailtoChunk rangeOfString: myEmail].length > 0)
//     {
//       aptFlags.isMyApt = YES;
//       aptFlags.canAccessApt = YES;
//     }
//   else
//     {
//       aptFlags.isMyApt = NO;

//       partmails = [_apt valueForKey: @"partmails"];
//       if ([partmails rangeOfString: myEmail].length)
//         aptFlags.canAccessApt = YES;
//       else
//         aptFlags.canAccessApt
//           = ([[_apt valueForKey: @"classification"] intValue]
//              == iCalAccessPublic);
//     }
// }

- (id) appointment
{
  return appointment;
}

- (BOOL) isMyApt
{
  return aptFlags.isMyApt ? YES : NO;
}

- (BOOL) canAccessApt
{
  return aptFlags.canAccessApt ? YES : NO;
}

- (BOOL) canNotAccessApt
{
  return aptFlags.canAccessApt ? NO : YES;
}

- (NSDictionary *) aptTypeDict
{
  return nil;
}
- (NSString *) aptTypeLabel
{
  return @"aptLabel";
}
- (NSString *) aptTypeIcon
{
  return @"";
}

- (SOGoAptFormatter *) aptFormatter
{
  if (aptFlags.canAccessApt)
    return aptFormatter;
  return privateAptFormatter;
}

- (SOGoAptFormatter *) aptTooltipFormatter
{
  if (aptFlags.canAccessApt)
    return aptTooltipFormatter;
  return privateAptTooltipFormatter;
}

- (void) setTasks: (NSArray *) _tasks
{
  ASSIGN(tasks, _tasks);
}

- (NSArray *) tasks
{
  return tasks;
}

/* TODO: remove this */
- (NSString *) shortTextForApt
{
  [self warnWithFormat: @"%s IS DEPRECATED!", __PRETTY_FUNCTION__];
  if (![self canAccessApt])
    return @"";
  return [[self aptFormatter] stringForObjectValue: appointment];
}

- (NSString *) shortTitleForApt
{
  NSString *title;

  [self warnWithFormat: @"%s IS DEPRECATED!", __PRETTY_FUNCTION__];

  if (![self canAccessApt])
    return @"";
  title = [appointment valueForKey: @"title"];
  if ([title length] > 12)
    title = [[title substringToIndex: 11] stringByAppendingString: @"..."];
  
  return title;
}

- (NSString *) tooltipForApt
{
  [self warnWithFormat: @"%s IS DEPRECATED!", __PRETTY_FUNCTION__];
  return [[self aptTooltipFormatter] stringForObjectValue: appointment
                                     referenceDate: [self currentDay]];
}

- (NSString *) aptStyle
{
  return nil;
}

- (NSCalendarDate *) referenceDateForFormatter
{
  return [self selectedDate];
}

- (NSCalendarDate *) thisMonth
{
  return [self selectedDate];
}

- (NSCalendarDate *) nextMonth
{
  NSCalendarDate *date = [self thisMonth];
  return [date dateByAddingYears: 0 months: 1 days: 0
               hours: 0 minutes: 0 seconds: 0];
}

- (NSCalendarDate *) prevMonth
{
  NSCalendarDate *date = [self thisMonth];
  return [date dateByAddingYears: 0 months:-1 days: 0
               hours: 0 minutes: 0 seconds: 0];
}

- (NSString *) prevMonthAsString
{
  return [self dateStringForDate: [self prevMonth]];
}

- (NSString *) nextMonthAsString
{
  return [self dateStringForDate: [self nextMonth]];
}

- (void) setCurrentView: (NSString *) theView
{
  SOGoUser *activeUser;
  NSString *module;
  NSUserDefaults *ud;
  NSMutableDictionary *moduleSettings;
  SOGoAppointmentFolders *clientObject;

  activeUser = [context activeUser];
  clientObject = [self clientObject];

  module = [clientObject nameInContainer];

  ud = [activeUser userSettings];
  moduleSettings = [ud objectForKey: module];
  if (!moduleSettings)
    {
      moduleSettings = [NSMutableDictionary dictionary];
      [ud setObject: moduleSettings forKey: module];
    }
  if (![theView isEqualToString: (NSString*)[moduleSettings objectForKey: @"View"]])
    {
      [moduleSettings setObject: theView
			 forKey: @"View"];
      [ud synchronize];
    }
}

/* current day related */

- (void) setCurrentDay:(NSCalendarDate *) _day
{
  [_day setTimeZone: timeZone];
  ASSIGN (currentDay, _day);
}

- (NSCalendarDate *) currentDay
{
  return currentDay;
}

- (NSString *) currentDayName
{
  return [self localizedNameForDayOfWeek: [currentDay dayOfWeek]];
}

- (id) holidayInfo
{
  return nil;
}

- (NSArray *) allDayApts
{
  NSArray        *apts;
  NSMutableArray *filtered;
  unsigned       i, count;

  if (allDayApts)
    return allDayApts;

  apts = [self appointments];
  count = [apts count];
  filtered = [[NSMutableArray alloc] initWithCapacity: 3];
  for (i = 0; i < count; i++)
    {
      id       apt;
      NSNumber *bv;

      apt = [apts objectAtIndex: i];
      bv = [apt valueForKey: @"isallday"];
      if ([bv boolValue])
        [filtered addObject: apt];
    }
    
  ASSIGN(allDayApts, filtered);
  [filtered release];
  return allDayApts;
}


/* special appointments */

- (BOOL) hasDayInfo
{
  return [self hasHoldidayInfo] || [self hasAllDayApts];
}

- (BOOL) hasHoldidayInfo
{
  return [self holidayInfo] != nil;
}

- (BOOL) hasAllDayApts
{
  return [[self allDayApts] count] != 0;
}


/* defaults */

- (BOOL) showFullNames
{
  return YES;
}

- (BOOL) showAMPMDates
{
  return NO;
}

- (unsigned) dayStartHour
{
  return 0;
}

- (unsigned) dayEndHour
{
  return 23;
}

- (BOOL) shouldDisplayWeekend
{
  return shouldDisplayWeekend;
}

- (BOOL) shouldHideWeekend
{
  return ![self shouldDisplayWeekend];
}


/* URLs */

- (NSString *) appointmentViewURL
{
  id pkey;
  
  if (![(pkey = [[self appointment] valueForKey: @"uid"]) isNotNull])
    return nil;
  
  return [[[self clientObject] baseURLForAptWithUID: [pkey stringValue]
                               inContext: [self context]]
           stringByAppendingString: @"/view"];
}

/* fetching */

- (NSCalendarDate *) startDate
{
  return [self selectedDate];
}

- (NSCalendarDate *) endDate
{
  return [[self startDate] tomorrow];
}

/* query parameters */

- (BOOL) shouldDisplayRejectedAppointments
{
  NSString *bv;
  
  bv = [self queryParameterForKey: @"dr"];
  if (!bv) return NO;
  return [bv boolValue];
}

- (NSDictionary *) toggleShowRejectedAptsQueryParameters
{
  NSMutableDictionary *qp;
  BOOL                shouldDisplay;
  
  shouldDisplay = ![self shouldDisplayRejectedAppointments];
  qp = [[[self queryParameters] mutableCopy] autorelease];
  [qp setObject: shouldDisplay ? @"1" : @"0" forKey: @"dr"];
  return qp;
}

- (NSString *) toggleShowRejectedAptsLabel
{
  if (![self shouldDisplayRejectedAppointments])
    return @"show_rejected_apts";
  return @"hide_rejected_apts";
}

/* date selection & conversion */

- (NSDictionary *) _dateQueryParametersWithOffset: (int) daysOffset
{
  NSCalendarDate *date;
  
  date = [[self startDate] dateByAddingYears: 0 months: 0
                           days: daysOffset
                           hours: 0 minutes: 0 seconds: 0];
  return [self queryParametersBySettingSelectedDate: date];
}

- (NSDictionary *) todayQueryParameters
{
  return [self queryParametersBySettingSelectedDate: [NSCalendarDate date]];
}

- (NSDictionary *) currentDayQueryParameters
{
  return [self queryParametersBySettingSelectedDate: currentDay];
}

/* Actions */

- (NSString *) _userFolderURI
{
  WOContext *ctx;
  id        obj;
  NSURL     *url;

  ctx = [self context];
  obj = [[ctx objectTraversalStack] objectAtIndex: 1];
  url = [NSURL URLWithString: [obj baseURLInContext: ctx]];
  return [[url path] stringByUnescapingURL];
}

- (id) redirectForUIDsAction
{
  NSMutableString *uri;
  NSString *uidsString, *loc, *prevMethod, *userFolderID;
  id <WOActionResults> r;
  BOOL useGroups;
  unsigned index;

  uidsString = [self queryParameterForKey: @"userUIDString"];
  uidsString = [uidsString stringByTrimmingSpaces];
  [self setQueryParameter: nil forKey: @"userUIDString"];

  prevMethod = [self queryParameterForKey: @"previousMethod"];
  if (prevMethod == nil)
    prevMethod = @"";

  uri = [[NSMutableString alloc] initWithString: [self _userFolderURI]];
  /* if we have more than one entry, use groups - otherwise don't */
  useGroups = [uidsString rangeOfString: @","].length > 0;
  userFolderID = [uri lastPathComponent];
  if (useGroups)
    {
      NSArray *uids;

      uids = [uidsString componentsSeparatedByString: @","];
      /* guarantee that our id is the first */
      if (((index = [uids indexOfObject: userFolderID]) != NSNotFound)
          && (index != 0))
        {
          uids = [[uids mutableCopy] autorelease];
          [(NSMutableArray *) uids removeObjectAtIndex: index];
          [(NSMutableArray *) uids insertObject: userFolderID atIndex: 0];
          uidsString = [uids componentsJoinedByString: @","];
        }
      [uri appendString: @"Groups/_custom_"];
      [uri appendString: uidsString];
      [uri appendString: @"/"];
      NSLog (@"Group URI = '%@'", uri);
    }
  else
    {
      /* check if lastPathComponent is the base that we want to have */
      if ((([uidsString length] != 0)
           && (![userFolderID isEqualToString: uidsString])))
        {
          NSRange r;
          
          /* uri ends with an '/', so we have to adjust the range a little */
          r = NSMakeRange(0, [uri length] - 1);
          r = [uri rangeOfString: @"/"
                   options: NSBackwardsSearch
                   range: r];
          r = NSMakeRange(r.location + 1, [uri length] - r.location - 2);
          [uri replaceCharactersInRange: r withString: uidsString];
        }
    }
  [uri appendString: @"Calendar/"];
  [uri appendString: prevMethod];

#if 0
  NSLog(@"%s redirect uri:%@",
        __PRETTY_FUNCTION__,
        uri);
#endif
  loc = [self completeHrefForMethod: uri]; /* this might return uri! */
  r = [self redirectToLocation: loc];
  [uri release];
  return r;
}


- (WOResponse *) exportAction
{
  WOResponse *response;
  SOGoAppointmentFolder *folder;
  SOGoAppointmentObject *appt;
  NSArray *array, *values, *fields;
  NSMutableString *rc;
  iCalCalendar *calendar, *component;
  int i, count;

  fields = [NSArray arrayWithObjects: @"c_name", @"c_content", nil];
  rc = [NSMutableString string];

  response = [[WOResponse alloc] init];
  [response autorelease];

  folder = [self clientObject];
  calendar = [iCalCalendar groupWithTag: @"vcalendar"];

  array = [[folder ocsFolder] fetchFields: fields matchingQualifier: nil];
  count = [array count];
  for (i = 0; i < count; i++)
    {
      appt = [folder lookupName: [[array objectAtIndex: i] objectForKey: @"c_name"]
                      inContext: [self context]
                        acquire: NO];

      component = [appt calendar: NO secure: NO];
      values = [component events];
      if (values && [values count])
        [calendar addChildren: values];
      values = [component todos];
      if (values && [values count])
        [calendar addChildren: values];
      values = [component journals];
      if (values && [values count])
        [calendar addChildren: values];
      values = [component freeBusys];
      if (values && [values count])
        [calendar addChildren: values];
      values = [component childrenWithTag: @"vtimezone"];
      if (values && [values count])
        [calendar addChildren: values];
    }
  NSLog ([calendar versitString]);
  
  [response setHeader: @"text/calendar" 
               forKey:@"content-type"];
  [response setHeader: @"attachment;filename=Calendar.ics" 
               forKey: @"Content-Disposition"];
  [response setContent: [[calendar versitString] dataUsingEncoding: NSUTF8StringEncoding]];
  
  return response;
}

- (WOResponse *) importAction
{
  SOGoAppointmentFolder *folder;
  NSArray *components;
  WORequest *request;
  NSString *fileContent;
  NSData *data;
  iCalCalendar *additions;
  int i, count;

  request = [context request];
  folder = [self clientObject];
  data = (NSData *)[request formValueForKey: @"calendarFile"];
  fileContent = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  [fileContent autorelease];

  if (fileContent && [fileContent length])
    {
      additions = [iCalCalendar parseSingleFromSource: fileContent];
      if (additions)
        {
          components = [additions events];
          count = [components count];
          for (i = 0; i < count; i++)
            [folder importComponent: [components objectAtIndex: i]];
          components = [additions todos];
          count = [components count];
          for (i = 0; i < count; i++)
            [folder importComponent: [components objectAtIndex: i]];
          components = [additions journals];
          count = [components count];
          for (i = 0; i < count; i++)
            [folder importComponent: [components objectAtIndex: i]];
          components = [additions freeBusys];
          count = [components count];
          for (i = 0; i < count; i++)
            [folder importComponent: [components objectAtIndex: i]];
        }
    }
  return [self redirectToLocation: @"../view"];
}

@end /* UIxCalView */
