/* iCalTimeZone.m - this file is part of SOPE
 *
 * Copyright (C) 2006-2009 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
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
#import <Foundation/NSBundle.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import "NSCalendarDate+NGCards.h"
#import "NSString+NGCards.h"

#import "iCalCalendar.h"
#import "iCalTimeZonePeriod.h"

#import "iCalTimeZone.h"

static NSMutableDictionary *cache;


@implementation iCalTimeZone

+ (void) initialize
{
  cache = [[NSMutableDictionary alloc] init];
}

+ (iCalTimeZone *) timeZoneForName: (NSString *) theName
{
  iCalTimeZone *o;
  
  o = [cache objectForKey: theName];

  if (!o)
    {
      NSFileManager *fm;
      NSEnumerator *e;
      NSArray *paths;
      NSString *path;
      BOOL b;

      paths = NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory,
						  NSAllDomainsMask,
						  YES);
      fm = [NSFileManager defaultManager];

      if ([paths count] > 0)
	{   
	  e = [paths objectEnumerator];
	  while ((path = [e nextObject]))
	    {
	      path = [NSString stringWithFormat: @"%@/Libraries/Resources/NGCards/TimeZones", path];
	      
	      if ([fm fileExistsAtPath: path  isDirectory: &b] && b)
		{
		  iCalCalendar *calendar;
		  NSString *s;
		  NSData *d;
		  
		  s = [NSString stringWithFormat: @"%@/%@.ics", path, theName];
		  
		  d = [NSData dataWithContentsOfFile: s];
		  s = [[NSString alloc] initWithData: d
					encoding: NSUTF8StringEncoding];
		  AUTORELEASE(s);

  
		  calendar = [iCalCalendar parseSingleFromSource: s];
		  o = [[calendar timezones] lastObject];

		  if (o)
		    [cache setObject: o  forKey: theName];

		  return o;
		}

	    }
	}
    }

  return o;
}

- (Class) classForTag: (NSString *) classTag
{
  Class tagClass;

  if ([classTag isEqualToString: @"STANDARD"]
      || [classTag isEqualToString: @"DAYLIGHT"])
    tagClass = [iCalTimeZonePeriod class];
  else if ([classTag isEqualToString: @"TZID"])
    tagClass = [CardElement class];
  else
    tagClass = [super classForTag: classTag];

  return tagClass;
}

- (void) setTzId: (NSString *) tzId
{
  [[self uniqueChildWithTag: @"tzid"] setValue: 0 to: tzId];
}

- (NSString *) tzId
{
  return [[self uniqueChildWithTag: @"tzid"] value: 0];
}

- (NSCalendarDate *) _occurrenceForPeriodNamed: (NSString *) pName
                                       forDate: (NSCalendarDate *) aDate
{
  NSArray *periods;
  iCalTimeZonePeriod *period;
  NSCalendarDate *occurence;

  periods = [self childrenWithTag: pName];
  if ([periods count])
    {
      period = (iCalTimeZonePeriod *) [periods objectAtIndex: 0];
      occurence = [period occurenceForDate: aDate];
    }
  else
    occurence = nil;

  return occurence;
}

- (iCalTimeZonePeriod *) periodForDate: (NSCalendarDate *) date
{
  NSCalendarDate *daylightOccurence, *standardOccurence;
  iCalTimeZonePeriod *period;

  /* FIXME, this could cause crashes when timezones are not properly
     specified, but let's say it won't happen often... */

  daylightOccurence = [self _occurrenceForPeriodNamed: @"daylight"
                                              forDate: date];
  standardOccurence = [self _occurrenceForPeriodNamed: @"standard"
                                              forDate: date];

  if (!standardOccurence)
    period = (iCalTimeZonePeriod *) [self uniqueChildWithTag: @"daylight"];
  else if (!daylightOccurence)
    period = (iCalTimeZonePeriod *) [self uniqueChildWithTag: @"standard"];
  else if ([date earlierDate: daylightOccurence] == date)
    {
      if ([date earlierDate: standardOccurence] == date
          && ([standardOccurence earlierDate: daylightOccurence]
              == standardOccurence))
        period = (iCalTimeZonePeriod *) [self uniqueChildWithTag: @"daylight"];
      else
        period = (iCalTimeZonePeriod *) [self uniqueChildWithTag: @"standard"];
    }
  else
    {
      if ([standardOccurence earlierDate: date] == standardOccurence
          && ([daylightOccurence earlierDate: standardOccurence]
              == daylightOccurence))
        period = (iCalTimeZonePeriod *) [self uniqueChildWithTag: @"standard"];
      else
        period = (iCalTimeZonePeriod *) [self uniqueChildWithTag: @"daylight"];
    }

  // NSLog (@"chosen period: '%@'", [period tag]);

  return period;
}

- (NSCalendarDate *) _computedDateTimeForDate: (NSCalendarDate *) date
{
  NSCalendarDate *tmpDate;
  NSTimeZone *utc;

  utc = [NSTimeZone timeZoneWithName: @"GMT"];
  tmpDate = [date copy];
  [tmpDate autorelease];
  [tmpDate setTimeZone: utc];

  return [tmpDate addYear: 0 month: 0 day: 0
		  hour: 0 minute: 0
		  second: [[self periodForDate: date] secondsOffsetFromGMT]];
}

- (NSString *) dateTimeStringForDate: (NSCalendarDate *) date
{
  return [[self _computedDateTimeForDate: date]
	   iCalFormattedDateTimeString];
}

- (NSString *) dateStringForDate: (NSCalendarDate *) date
{
  return [[self _computedDateTimeForDate: date]
	   iCalFormattedDateString];
}

- (NSCalendarDate *) dateForDateTimeString: (NSString *) string
{
  NSCalendarDate *tmpDate;
  iCalTimeZonePeriod *period, *realPeriod;

  tmpDate = [string asCalendarDate];
  period = [self periodForDate: tmpDate];
  tmpDate = [tmpDate addYear: 0 month: 0 day: 0
                        hour: 0 minute: 0
                      second: -[period secondsOffsetFromGMT]];

#warning this is a dirty hack due to the fact that the date is first passed as UTC
  realPeriod = [self periodForDate: tmpDate];
  if (realPeriod != period)
    tmpDate = [tmpDate addYear: 0 month: 0 day: 0
                          hour: 0 minute: 0
                        second: ([period secondsOffsetFromGMT]
                                 - [realPeriod secondsOffsetFromGMT])];

  return tmpDate;
}

@end
