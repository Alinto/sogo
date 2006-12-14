/*
  Copyright (C) 2004 SKYRIX Software AG

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
// $Id: UIxAppointmentEditor.m 181 2004-08-11 15:13:25Z helge $

#include <SOGoUI/UIxComponent.h>

@interface UIxAppointmentProposal : UIxComponent
{
  id item;
  id currentDay;

  /* individual values */
  id startDateHour;
  id startDateMinute;
  id endDateHour;
  id endDateMinute;

  id startDateDay;
  id startDateMonth;
  id startDateYear;
  id endDateDay;
  id endDateMonth;
  id endDateYear;
  
  NSArray        *participants; /* array of iCalPerson's */
  NSArray        *resources;    /* array of iCalPerson's */
  id             duration;
  
  NSArray *blockedRanges;
  NSMutableDictionary *currentQueryParameters;
}

- (NSMutableDictionary *)currentQueryParameters;
- (NSDictionary *)currentHourQueryParametersForFirstHalf:(BOOL)_first;

- (void)setICalPersons:(NSArray *)_ps asQueryParameter:(NSString *)_qp;
@end

#include <SoObjects/Appointments/SOGoAppointmentFolder.h>
#include <SoObjects/Appointments/SOGoFreeBusyObject.h>
#include <NGExtensions/NGCalendarDateRange.h>
#include <NGCards/NGCards.h>
#include "common.h"

@implementation UIxAppointmentProposal

- (void)dealloc {
  [self->blockedRanges   release];

  [self->startDateHour   release];
  [self->startDateMinute release];
  [self->startDateDay    release];
  [self->startDateMonth  release];
  [self->startDateYear   release];

  [self->endDateHour     release];
  [self->endDateMinute   release];
  [self->endDateDay      release];
  [self->endDateMonth    release];
  [self->endDateYear     release];
  [self->duration        release];
    
  [self->participants    release];
  [self->resources       release];
  
  [self->currentQueryParameters release];
  [super dealloc];
}

/* notifications */

- (void)sleep {
  [self->currentDay release]; self->currentDay = nil;
  [self->item       release]; self->item       = nil;
  [super sleep];
}

/* accessors */

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (void)setStartDateHour:(id)_startDateHour {
  ASSIGN(self->startDateHour, _startDateHour);
}
- (id)startDateHour {
  return self->startDateHour;
}
- (void)setStartDateMinute:(id)_startDateMinute {
  ASSIGN(self->startDateMinute, _startDateMinute);
}
- (id)startDateMinute {
  return self->startDateMinute;
}
- (void)setStartDateDay:(id)_startDateDay {
  ASSIGN(self->startDateDay, _startDateDay);
}
- (id)startDateDay {
  return self->startDateDay;
}
- (void)setStartDateMonth:(id)_startDateMonth {
  ASSIGN(self->startDateMonth, _startDateMonth);
}
- (id)startDateMonth {
  return self->startDateMonth;
}
- (void)setStartDateYear:(id)_startDateYear {
  ASSIGN(self->startDateYear, _startDateYear);
}
- (id)startDateYear {
  return self->startDateYear;
}
- (void)setEndDateHour:(id)_endDateHour {
  ASSIGN(self->endDateHour, _endDateHour);
}
- (id)endDateHour {
  return self->endDateHour;
}
- (void)setEndDateMinute:(id)_endDateMinute {
  ASSIGN(self->endDateMinute, _endDateMinute);
}
- (id)endDateMinute {
  return self->endDateMinute;
}
- (void)setEndDateDay:(id)_endDateDay {
  ASSIGN(self->endDateDay, _endDateDay);
}
- (id)endDateDay {
  return self->endDateDay;
}
- (void)setEndDateMonth:(id)_endDateMonth {
  ASSIGN(self->endDateMonth, _endDateMonth);
}
- (id)endDateMonth {
  return self->endDateMonth;
}
- (void)setEndDateYear:(id)_endDateYear {
  ASSIGN(self->endDateYear, _endDateYear);
}
- (id)endDateYear {
  return self->endDateYear;
}

- (void)setStartDate:(NSCalendarDate *)_date {
  [self setStartDateHour:[NSNumber numberWithInt:[_date hourOfDay]]];
  [self setStartDateMinute:[NSNumber numberWithInt:[_date minuteOfHour]]];
  [self setStartDateDay:[NSNumber numberWithInt:[_date dayOfMonth]]];
  [self setStartDateMonth:[NSNumber numberWithInt:[_date monthOfYear]]];
  [self setStartDateYear:[NSNumber numberWithInt:[_date yearOfCommonEra]]];
}
- (NSCalendarDate *)startDate {
  return [NSCalendarDate dateWithYear:[[self startDateYear] intValue]
			 month:[[self startDateMonth] intValue]
			 day:[[self startDateDay] intValue]
			 hour:[[self startDateHour] intValue]
			 minute:[[self startDateMinute] intValue]
			 second:0
			 timeZone:[[self clientObject] userTimeZone]];
}
- (void)setEndDate:(NSCalendarDate *)_date {
  [self setEndDateHour:[NSNumber numberWithInt:[_date hourOfDay]]];
  [self setEndDateMinute:[NSNumber numberWithInt:[_date minuteOfHour]]];
  [self setEndDateDay:[NSNumber numberWithInt:[_date dayOfMonth]]];
  [self setEndDateMonth:[NSNumber numberWithInt:[_date monthOfYear]]];
  [self setEndDateYear:[NSNumber numberWithInt:[_date yearOfCommonEra]]];
}
- (NSCalendarDate *)endDate {
  return [NSCalendarDate dateWithYear:[[self endDateYear] intValue]
			 month:[[self endDateMonth] intValue]
			 day:[[self endDateDay] intValue]
			 hour:[[self endDateHour] intValue]
			 minute:[[self endDateMinute] intValue]
			 second:59
			 timeZone:[[self clientObject] userTimeZone]];
}

- (void)setDuration:(id)_duration {
  ASSIGN(self->duration, _duration);
}
- (id)duration {
  return self->duration;
}
- (int)durationInMinutes {
  return [[self duration] intValue];
}
- (NSTimeInterval)durationAsTimeInterval {
  return [self durationInMinutes] * 60;
}

- (NSString *)itemDurationText {
  // TODO: use a formatter
  // TODO: localize
  switch ([[self item] intValue]) {
  case  30: return @"30 minutes";
  case  60: return @"1 hour";
  case 120: return @"2 hours";
  case 240: return @"4 hours";
  case 480: return @"8 hours";
  default:
    return [NSString stringWithFormat:@"%@ minutes", [self item]];
  }
}

- (void)setParticipants:(NSArray *)_parts {
  ASSIGN(self->participants, _parts);
}
- (NSArray *)participants {
  return self->participants;
}
- (void)setResources:(NSArray *)_res {
  ASSIGN(self->resources, _res);
}
- (NSArray *)resources {
  return self->resources;
}

- (NSArray *)attendees {
  NSArray *a, *b;
  
  a = [self participants];
  b = [self resources];
  if ([b count] == 0) return a;
  if ([a count] == 0) return b;
  return [a arrayByAddingObjectsFromArray:b];
}

- (void)setCurrentDay:(id)_day {
  ASSIGN(self->currentDay, _day);
}
- (id)currentDay {
  return self->currentDay;
}

- (NSArray *)hours {
  // TODO: from 'earliest start' to 'latest endtime'
  unsigned lStartHour = 9, lEndHour = 17, i;
  NSMutableArray *ma;
  
  lStartHour = [[self startDateHour] intValue];
  lEndHour   = [[self endDateHour]   intValue];
  if (lStartHour < 1) lStartHour = 1;
  if (lEndHour < lStartHour) lEndHour = lStartHour + 1;
  
  ma = [NSMutableArray arrayWithCapacity:lEndHour - lStartHour + 2];
  for (i = lStartHour; i <= lEndHour; i++)
    [ma addObject:[NSNumber numberWithInt:i]];
  return ma;
}

- (NSArray *)days {
  // TODO: from startdate to enddate
  NSMutableArray *ma;
  NSCalendarDate *base, *stop, *current;
  
  base = [NSCalendarDate dateWithYear:[[self startDateYear] intValue]
			 month:[[self startDateMonth] intValue]
			 day:[[self startDateDay] intValue]
			 hour:12 minute:0 second:0
			 timeZone:[[self clientObject] userTimeZone]];
  stop = [NSCalendarDate dateWithYear:[[self endDateYear] intValue]
			 month:[[self endDateMonth] intValue]
			 day:[[self endDateDay] intValue]
			 hour:12 minute:0 second:0
			 timeZone:[[self clientObject] userTimeZone]];
  
  ma = [NSMutableArray arrayWithCapacity:16];
  
  current = base;
  while ([current compare:stop] != NSOrderedDescending) {
    [current setTimeZone:[[self clientObject] userTimeZone]];
    [ma addObject:current];
    
    /* Note: remember the timezone behaviour of the method below! */
    current = [current dateByAddingYears:0 months:0 days:1];
  }
  return ma;
}

- (NSArray *)durationSteps {
  // TODO: make configurable
  return [NSArray arrayWithObjects:
		    @"30", @"60", @"120", @"240", @"480", nil];
}

/* slots */

- (BOOL)isRangeGreen:(NGCalendarDateRange *)_range {
  unsigned idx;
  
  idx = [self->blockedRanges indexOfFirstIntersectingDateRange:_range];
  if (idx != NSNotFound) {
    [self debugWithFormat:@"blocked range:\n  range: %@\n  block: %@\nintersection:%@", 
	    _range,
	    [self->blockedRanges objectAtIndex:idx],
      [_range intersectionDateRange:[self->blockedRanges objectAtIndex:idx]]];
  }
  
  return idx == NSNotFound ? YES : NO;
}

- (BOOL)isSlotRangeGreen:(NGCalendarDateRange *)_slotRange {
  NGCalendarDateRange *aptRange;
  NSCalendarDate *aptStartDate, *aptEndDate;

  if (_slotRange == nil)
    return NO;
  
  /* calculate the interval requested by the user (can be larger) */

  aptStartDate = [_slotRange startDate];
  // TODO: gives warning on MacOSX
  aptEndDate   = [[NSCalendarDate alloc] initWithTimeIntervalSince1970:
					   [aptStartDate timeIntervalSince1970]
					 + [self durationAsTimeInterval]];
  [aptStartDate setTimeZone:[[self clientObject] userTimeZone]];
  [aptEndDate   setTimeZone:[[self clientObject] userTimeZone]];
  aptRange = [NGCalendarDateRange calendarDateRangeWithStartDate:aptStartDate
				  endDate:aptEndDate];
  [aptEndDate release]; aptEndDate = nil;
  
  return [self isRangeGreen:aptRange];
}

- (BOOL)isFirstHalfGreen {
  /* currentday is the date, self->item the hour */
  NSCalendarDate *from, *to;
  NGCalendarDateRange *range;

  from  = [self->currentDay hour:[[self item] intValue] minute:0];
  to    = [self->currentDay hour:[[self item] intValue] minute:30];
  range = [NGCalendarDateRange calendarDateRangeWithStartDate:from endDate:to];
  return [self isSlotRangeGreen:range];
}
- (BOOL)isSecondHalfGreen {
  /* currentday is the date, self->item the hour */
  NSCalendarDate *from, *to;
  NGCalendarDateRange *range;

  from  = [self->currentDay hour:[[self item] intValue]     minute:30];
  to    = [self->currentDay hour:[[self item] intValue] + 1 minute:0];
  range = [NGCalendarDateRange calendarDateRangeWithStartDate:from endDate:to];
  return [self isSlotRangeGreen:range];
}

- (BOOL)isFirstHalfBlocked {
  return [self isFirstHalfGreen] ? NO : YES;
}
- (BOOL)isSecondHalfBlocked {
  return [self isSecondHalfGreen] ? NO : YES;
}

/* actions */

- (BOOL)shouldTakeValuesFromRequest:(WORequest *)_rq inContext:(WOContext*)_c{
  return YES;
}

- (id<WOActionResults>)defaultAction {
  NSCalendarDate *now;
  
  now = [NSCalendarDate date];

  [self setDuration:@"120"]; /* 1 hour as default */
  [self setStartDate:[now hour:9 minute:0]];
  [self setEndDate:[now hour:18 minute:0]];
  
  return self;
}

- (id)proposalSearchAction {
  NSArray        *attendees, *uids, *fbos, *ranges;
  unsigned       i, count;
  NSMutableArray *allInfos;

  [self logWithFormat:@"search from %@ to %@", 
	  [self startDate], [self endDate]];
  
  attendees = [self attendees];
  uids      = [[self clientObject] uidsFromICalPersons:attendees];
  if ([uids count] == 0) {
    [self logWithFormat:@"Note: no UIDs selected."];
    return self;
  }

  fbos     = [[self clientObject] lookupFreeBusyObjectsForUIDs:uids
                                  inContext:[self context]];
  count    = [fbos count];
  // wild guess at capacity
  allInfos = [[[NSMutableArray alloc] initWithCapacity:count * 10] autorelease];

  for (i = 0; i < count; i++) {
    SOGoFreeBusyObject *fb;
    NSArray            *infos;
    
    fb    = [fbos objectAtIndex:i];
    if (fb != (SOGoFreeBusyObject *)[NSNull null]) {
      infos = [fb fetchFreeBusyInfosFrom:[self startDate] to:[self endDate]];
      [allInfos addObjectsFromArray:infos];
    }
  }
  [self debugWithFormat:@"  processing: %d infos", [allInfos count]];
  ranges = [allInfos arrayByCreatingDateRangesFromObjectsWithStartDateKey:
                       @"startDate"
                     andEndDateKey:@"endDate"];
  ranges = [ranges arrayByCompactingContainedDateRanges];
  [self debugWithFormat:@"  ranges: %@", ranges];
  
  ASSIGNCOPY(self->blockedRanges, ranges);
  
  return self;
}

/* URLs */

- (NSMutableDictionary *)currentQueryParameters {
  if(!self->currentQueryParameters) {
    self->currentQueryParameters = [[self queryParameters] mutableCopy];
    [self->currentQueryParameters setObject:[self duration] forKey:@"dur"];
    [self setICalPersons:[self resources] asQueryParameter:@"rs"];
    [self setICalPersons:[self participants] asQueryParameter:@"ps"];
  }
  return self->currentQueryParameters;
}

- (void)setICalPersons:(NSArray *)_ps asQueryParameter:(NSString *)_qp {
  NSMutableString *s;
  unsigned i, count;
  
  s = [[NSMutableString alloc] init];
  count = [_ps count];
  for(i = 0; i < count; i++) {
    iCalPerson *p = [_ps objectAtIndex:i];
    [s appendString:[p rfc822Email]];
    if(i != (count - 1))
      [s appendString:@","];
  }
  [[self currentQueryParameters] setObject:s forKey:_qp];
  [s release];
}

- (NSDictionary *)currentHourQueryParametersForFirstHalf:(BOOL)_first {
  NSMutableDictionary *qp;
  NSString *hmString;
  NSCalendarDate *date;
  unsigned minute;

  minute = _first ? 0 : 30;
  qp = [self currentQueryParameters];

  date = [self currentDay];
  hmString = [NSString stringWithFormat:@"%02d%02d",
    [item intValue], minute];
  [self setSelectedDateQueryParameter:date inDictionary:qp];
  [qp setObject:hmString forKey:@"hm"];
  return qp;
}

- (NSDictionary *)currentFirstHalfQueryParameters {
  return [self currentHourQueryParametersForFirstHalf:YES];
}

- (NSDictionary *)currentSecondHalfQueryParameters {
  return [self currentHourQueryParametersForFirstHalf:NO];
}

@end /* UIxAppointmentProposal */
