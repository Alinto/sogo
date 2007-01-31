/*
  Copyright (C) 2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include <NGCards/iCalRecurrenceRule.h>
#include <NGCards/iCalRecurrenceCalculator.h>
#include <NGExtensions/NGCalendarDateRange.h>
#include "common.h"

static NSCalendarDate *dateForString(NSString *_s) {
  // copied from ogo-chkaptconflicts, maybe move to NGExtensions?
  static NSCalendarDate *now = nil;
  static NSCalendarDate *mon = nil;
  
  if (now == nil) now = [[NSCalendarDate date] retain];
  if (mon == nil) mon = [[now mondayOfWeek] retain];
  _s = [_s lowercaseString];
  
  if ([_s isEqualToString:@"now"])       return now;
  if ([_s isEqualToString:@"tomorrow"])  return [now tomorrow];
  if ([_s isEqualToString:@"yesterday"]) return [now yesterday];
  
  if ([_s hasPrefix:@"mon"]) return mon;
  if ([_s hasPrefix:@"tue"]) return [mon dateByAddingYears:0 months:0 days:1];
  if ([_s hasPrefix:@"wed"]) return [mon dateByAddingYears:0 months:0 days:2];
  if ([_s hasPrefix:@"thu"]) return [mon dateByAddingYears:0 months:0 days:3];
  if ([_s hasPrefix:@"fri"]) return [mon dateByAddingYears:0 months:0 days:4];
  if ([_s hasPrefix:@"sat"]) return [mon dateByAddingYears:0 months:0 days:5];
  if ([_s hasPrefix:@"sun"]) return [mon dateByAddingYears:0 months:0 days:6];
  
  switch ([_s length]) {
  case 6:
    return [NSCalendarDate dateWithString:_s calendarFormat:@"%Y%m"];
  case 8:
    return [NSCalendarDate dateWithString:_s calendarFormat:@"%Y%m%d"];
  case 10:
    return [NSCalendarDate dateWithString:_s calendarFormat:@"%Y%-m-%d"];
  case 13:
    return [NSCalendarDate dateWithString:_s calendarFormat:@"%Y%m%d %H%M"];
  case 14:
    return [NSCalendarDate dateWithString:_s calendarFormat:@"%Y%m%d %H:%M"];
  case 16:
    return [NSCalendarDate dateWithString:_s calendarFormat:@"%Y-%m-%d %H:%M"];
  default:
    return nil;
  }
}

static int usage(NSArray *args) {
  fprintf(stderr,
	  "usage: %s <rrule> <startdate> <enddate> <cycleend>\n"
	  "\n"
	  "sample:\n"
	  "  %s 'FREQ=MONTHLY;BYDAY=2TU' '20050901 14:00' '20050901 15:00' "
	  "20060921\n",
	  [[args objectAtIndex:0] cString],
	  [[args objectAtIndex:0] cString]);
  return 1;
}

static void printInstances(NSArray *instances) {
  unsigned i, count;
  
  if ((count = [instances count]) == 0) {
    printf("no reccurrences in given range\n");
    return;
  }
  
  for (i = 0; i < count; i++) {
    NGCalendarDateRange *instance;
    NSString *s;
    
    instance = [instances objectAtIndex:i];

    s = [[instance startDate] descriptionWithCalendarFormat:
				@"%a, %Y-%m-%d at %H:%M"];
    printf("%s - ", [s cString]);

    s = [[instance endDate] descriptionWithCalendarFormat:
			      [[instance startDate] isDateOnSameDay:
						      [instance endDate]]
			    ? @"%H:%M"
			    : @"%a, %Y-%m-%d at %H:%M"];
    printf("%s\n", [s cString]);
  }
}

static int runIt(NSArray *args) {
  iCalRecurrenceCalculator *cpu;
  iCalRecurrenceRule  *rrule;
  NGCalendarDateRange *startRange, *calcRange;
  NSCalendarDate      *from, *to, *cycleTo;
  NSString            *pattern;
  NSArray             *instances;
  
  if ([args count] < 5)
    return usage(args);
  
  pattern = [args objectAtIndex:1];
  from    = dateForString([args objectAtIndex:2]);
  to      = dateForString([args objectAtIndex:3]);
  cycleTo = dateForString([args objectAtIndex:4]);
  
  if (from == nil || to == nil || cycleTo == nil || ![pattern isNotEmpty])
    return usage(args);
  
  startRange =
    [NGCalendarDateRange calendarDateRangeWithStartDate:from endDate:to];
  
  calcRange =
    [NGCalendarDateRange calendarDateRangeWithStartDate:from endDate:cycleTo];
  
  /* parse rrule */

  if ((rrule = [[iCalRecurrenceRule alloc] initWithString:pattern]) == nil) {
    usage(args);
    fprintf(stderr, "error: could not parse reccurence rule: '%s'\n",
	    [pattern cString]);
    return 2;
  }
  
  NSLog(@"from: %@ to: %@, cycle %@", from, to, cycleTo);
  NSLog(@"rrule: %@", rrule);
  
  /* calculate */
  
  cpu = [iCalRecurrenceCalculator 
	  recurrenceCalculatorForRecurrenceRule:rrule
	  withFirstInstanceCalendarDateRange:startRange];
  
  instances = [cpu recurrenceRangesWithinCalendarDateRange:calcRange];
  printInstances(instances);
  
  return 0;
}

int main(int argc, char **argv, char **env)  {
  NSAutoreleasePool *pool;
  int rc;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  rc = runIt([[NSProcessInfo processInfo] argumentsWithoutDefaults]);
  [pool release];
  return rc;
}
