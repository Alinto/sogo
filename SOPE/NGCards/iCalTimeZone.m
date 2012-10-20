/* iCalTimeZone.m - this file is part of SOPE
 *
 * Copyright (C) 2006-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
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
static NSArray *knownTimeZones;


@implementation iCalTimeZone

+ (void) initialize
{
  cache = [[NSMutableDictionary alloc] init];
  knownTimeZones = nil;
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

/**
 * Fetch the names of the available timezones for which we have a
 * vTimeZone definition (.ics).
 * @return an array of timezones names.
 * @see [NSTimeZone knownTimeZoneNames]
 */
+ (NSArray *) knownTimeZoneNames
{
  NSFileManager *fm;
  NSEnumerator *e;
  NSDirectoryEnumerator *zones;
  NSArray *paths;
  NSMutableArray *timeZoneNames;
  NSString *path, *zone, *zonePath;
  NSRange ext;
  BOOL b;

  if (!knownTimeZones)
    {
      timeZoneNames = [NSMutableArray new];

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
	      if ([fm fileExistsAtPath: path isDirectory: &b] && b)
		{
		  zones = [fm enumeratorAtPath: path];
		  while ((zone = [zones nextObject])) {
		    zonePath = [NSString stringWithFormat: @"%@/%@", path, zone];
		    if ([fm fileExistsAtPath: zonePath isDirectory: &b] && !b)
		      {
			ext = [zone rangeOfString: @".ics"];
                        if (ext.location != NSNotFound)
                          {
                            zone = [zone substringToIndex: ext.location];
                            [timeZoneNames addObject: zone];
                          }
		      }
		  }
		}
	    }
	}
      knownTimeZones = [NSArray arrayWithArray: timeZoneNames];
      [knownTimeZones retain];
    }

  return knownTimeZones;
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
  [[self uniqueChildWithTag: @"tzid"] setSingleValue: tzId forKey: @""];
}

- (NSString *) tzId
{
  return [[self uniqueChildWithTag: @"tzid"] flattenedValuesForKey: @""];
}

- (NSCalendarDate *) _occurrenceForPeriodNamed: (NSString *) pName
                                       forDate: (NSCalendarDate *) aDate
{
  NSArray *periods;
  NSEnumerator *periodsList;
  iCalTimeZonePeriod *period;
  NSCalendarDate *occurrence;

  occurrence = nil;

  periods = [[self childrenWithTag: pName]
              sortedArrayUsingSelector: @selector (compare:)];
  periodsList = [periods reverseObjectEnumerator];
  while (!occurrence
         && (period = (iCalTimeZonePeriod *) [periodsList nextObject]))
    occurrence = [period occurrenceForDate: aDate];

  return occurrence;
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

  return period;
}

/**
 * Adjust a date with respect to this vTimeZone.
 * @param theDate the date to adjust to the timezone.
 * @return a new GMT date adjusted with the offset of the timezone.
 */
- (NSCalendarDate *) computedDateForDate: (NSCalendarDate *) theDate
{
  NSCalendarDate *tmpDate;
  NSTimeZone *utc;

  utc = [NSTimeZone timeZoneWithName: @"GMT"];
  tmpDate = [theDate copy];
  [tmpDate autorelease];
  [tmpDate setTimeZone: utc];

  return [tmpDate addYear: 0 month: 0 day: 0
		  hour: 0 minute: 0
		  second: [[self periodForDate: theDate] secondsOffsetFromGMT]];
}

/**
 * Adjust a date with respect to this vTimeZone.
 * Example: Timezone is -0400, the date is 2012-05-23 13:00:00 +0000:
 *                              it returns 2012-05-23 09:00:00 +0000
 * @param theDate the string representing a date.
 * @return a new GMT date adjusted with the offset of this timezone.
 */
- (NSCalendarDate *) computedDateForString: (NSString *) theDate
{
  NSCalendarDate *tmpDate;
  NSTimeZone *utc;

  utc = [NSTimeZone timeZoneWithName: @"GMT"];
  tmpDate = [theDate asCalendarDate];
  [tmpDate setTimeZone: utc];

  return [tmpDate addYear: 0 month: 0 day: 0
		  hour: 0 minute: 0
		  second: [[self periodForDate: tmpDate] secondsOffsetFromGMT]];
}

/**
 * Adjust multiple dates with respect to this vTimeZone.
 * @param theDates an array of strings representing dates.
 * @param an array of NSCalendarDate objects.
 */
- (NSMutableArray *) computedDatesForStrings: (NSArray *) theDates
{
  NSCalendarDate *date;
  NSMutableArray *dates;
  NSEnumerator *dateList;
  NSString *dateString;

  dates = [NSMutableArray array];
  dateList = [theDates objectEnumerator];
  
  while ((dateString = [dateList nextObject]))
    {
      date = [self computedDateForString: dateString];
      [dates addObject: date];
    }

  return dates;
}

- (NSString *) dateTimeStringForDate: (NSCalendarDate *) date
{
  return [[self computedDateForDate: date]
	   iCalFormattedDateTimeString];
}

- (NSString *) dateStringForDate: (NSCalendarDate *) date
{
  return [[self computedDateForDate: date]
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
