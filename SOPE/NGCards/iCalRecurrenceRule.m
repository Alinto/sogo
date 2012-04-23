/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2006-2010 Inverse inc.

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

/*
  See http://tools.ietf.org/html/rfc2445#section-4.3.10

4.3.10 Recurrence Rule

   Value Name: RECUR

   Purpose: This value type is used to identify properties that contain
   a recurrence rule specification.

   Formal Definition: The value type is defined by the following
   notation:

     recur      = "FREQ"=freq *(

                ; either UNTIL or COUNT may appear in a 'recur',
                ; but UNTIL and COUNT MUST NOT occur in the same 'recur'

                ( ";" "UNTIL" "=" enddate ) /
                ( ";" "COUNT" "=" 1*DIGIT ) /

                ; the rest of these keywords are optional,
                ; but MUST NOT occur more than once

                ( ";" "INTERVAL" "=" 1*DIGIT )          /
                ( ";" "BYSECOND" "=" byseclist )        /
                ( ";" "BYMINUTE" "=" byminlist )        /
                ( ";" "BYHOUR" "=" byhrlist )           /
                ( ";" "BYDAY" "=" bywdaylist )          /
                ( ";" "BYMONTHDAY" "=" bymodaylist )    /
                ( ";" "BYYEARDAY" "=" byyrdaylist )     /
                ( ";" "BYWEEKNO" "=" bywknolist )       /
                ( ";" "BYMONTH" "=" bymolist )          /
                ( ";" "BYSETPOS" "=" bysplist )         /
                ( ";" "WKST" "=" weekday )              /
                ( ";" x-name "=" text )
                )

     freq       = "SECONDLY" / "MINUTELY" / "HOURLY" / "DAILY"
                / "WEEKLY" / "MONTHLY" / "YEARLY"

     enddate    = date
     enddate    =/ date-time            ;An UTC value

     byseclist  = seconds / ( seconds *("," seconds) )

     seconds    = 1DIGIT / 2DIGIT       ;0 to 59

     byminlist  = minutes / ( minutes *("," minutes) )

     minutes    = 1DIGIT / 2DIGIT       ;0 to 59

     byhrlist   = hour / ( hour *("," hour) )

     hour       = 1DIGIT / 2DIGIT       ;0 to 23

     bywdaylist = weekdaynum / ( weekdaynum *("," weekdaynum) )

     weekdaynum = [([plus] ordwk / minus ordwk)] weekday

     plus       = "+"

     minus      = "-"

     ordwk      = 1DIGIT / 2DIGIT       ;1 to 53

     weekday    = "SU" / "MO" / "TU" / "WE" / "TH" / "FR" / "SA"
     ;Corresponding to SUNDAY, MONDAY, TUESDAY, WEDNESDAY, THURSDAY,
     ;FRIDAY, SATURDAY and SUNDAY days of the week.

     bymodaylist = monthdaynum / ( monthdaynum *("," monthdaynum) )

     monthdaynum = ([plus] ordmoday) / (minus ordmoday)

     ordmoday   = 1DIGIT / 2DIGIT       ;1 to 31

     byyrdaylist = yeardaynum / ( yeardaynum *("," yeardaynum) )

     yeardaynum = ([plus] ordyrday) / (minus ordyrday)

     ordyrday   = 1DIGIT / 2DIGIT / 3DIGIT      ;1 to 366

     bywknolist = weeknum / ( weeknum *("," weeknum) )

     weeknum    = ([plus] ordwk) / (minus ordwk)

     bymolist   = monthnum / ( monthnum *("," monthnum) )

     monthnum   = 1DIGIT / 2DIGIT       ;1 to 12

     bysplist   = setposday / ( setposday *("," setposday) )

     setposday  = yeardaynum
*/

/*
  Examples :

   Every other week on Monday, Wednesday and Friday until December 24,
   1997, but starting on Tuesday, September 2, 1997:

     DTSTART;TZID=US-Eastern:19970902T090000
     RRULE:FREQ=WEEKLY;INTERVAL=2;UNTIL=19971224T000000Z;WKST=SU;
      BYDAY=MO,WE,FR
     ==> (1997 9:00 AM EDT)September 2,3,5,15,17,19,29;October
     1,3,13,15,17
         (1997 9:00 AM EST)October 27,29,31;November 10,12,14,24,26,28;
                           December 8,10,12,22

   Monthly on the 1st Friday for ten occurrences:

     DTSTART;TZID=US-Eastern:19970905T090000
     RRULE:FREQ=MONTHLY;COUNT=10;BYDAY=1FR

     ==> (1997 9:00 AM EDT)September 5;October 3
         (1997 9:00 AM EST)November 7;Dec 5
         (1998 9:00 AM EST)January 2;February 6;March 6;April 3
         (1998 9:00 AM EDT)May 1;June 5

   Every other month on the 1st and last Sunday of the month for 10
   occurrences:

     DTSTART;TZID=US-Eastern:19970907T090000
     RRULE:FREQ=MONTHLY;INTERVAL=2;COUNT=10;BYDAY=1SU,-1SU

     ==> (1997 9:00 AM EDT)September 7,28
         (1997 9:00 AM EST)November 2,30

   Monthly on the third to the last day of the month, forever:

     DTSTART;TZID=US-Eastern:19970928T090000
     RRULE:FREQ=MONTHLY;BYMONTHDAY=-3

     ==> (1997 9:00 AM EDT)September 28
         (1997 9:00 AM EST)October 29;November 28;December 29
         (1998 9:00 AM EST)January 29;February 26
     ...

   Every other year on January, February, and March for 10 occurrences:

     DTSTART;TZID=US-Eastern:19970310T090000
     RRULE:FREQ=YEARLY;INTERVAL=2;COUNT=10;BYMONTH=1,2,3

     ==> (1997 9:00 AM EST)March 10
         (1999 9:00 AM EST)January 10;February 10;March 10
         (2001 9:00 AM EST)January 10;February 10;March 10
         (2003 9:00 AM EST)January 10;February 10;March 10

   Everyday in January, for 3 years:

     DTSTART;TZID=US-Eastern:19980101T090000
     RRULE:FREQ=YEARLY;UNTIL=20000131T090000Z;
      BYMONTH=1;BYDAY=SU,MO,TU,WE,TH,FR,SA
     or
     RRULE:FREQ=DAILY;UNTIL=20000131T090000Z;BYMONTH=1

     ==> (1998 9:00 AM EDT)January 1-31
         (1999 9:00 AM EDT)January 1-31
         (2000 9:00 AM EDT)January 1-31

*/

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <NGExtensions/NSString+Ext.h>
#import <NGExtensions/NSObject+Logs.h>

#import <ctype.h>

#import "NSCalendarDate+ICal.h"
#import "NSCalendarDate+NGCards.h"
#import "NSString+NGCards.h"

#import "CardGroup.h"
#import "iCalByDayMask.h"
#import "iCalRecurrenceRule.h"

NSString *iCalWeekDayString[] = { @"SU", @"MO", @"TU", @"WE", @"TH", @"FR",
				  @"SA" };

/*
  freq       = rrFreq;
  until      = rrUntil;
  count      = rrCount;
  interval   = rrInterval;
  bysecond   = rrBySecondList;
  byminute   = rrByMinuteList;
  byhour     = rrByHourList;
  byday      = rrByDayList;
  bymonthday = rrByMonthDayList;
  byyearday  = rrByYearDayList;
  byweekno   = rrByWeekNumberList;
  bymonth    = rrByMonthList;
  bysetpos   = rrBySetPosList;
  wkst       = rrWeekStart;
*/

// TODO: private API in the header file?!
@interface iCalRecurrenceRule (PrivateAPI)

- (iCalWeekDay) weekDayFromICalRepresentation: (NSString *) _day;
- (NSString *) freq;
- (NSString *) wkst;
- (NSString *) byDayList;

@end

@implementation iCalRecurrenceRule

+ (id) recurrenceRuleWithICalRepresentation: (NSString *) _iCalRep
{
  iCalRecurrenceRule *rule;

  rule = [self elementWithTag: @"rrule"];
  [rule setRrule: _iCalRep];

  return rule;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      [self setTag: @"rrule"];
      dayMask = nil;
    }

  return self;
}

- (id) initWithString: (NSString *) _str
{
  if ((self = [self init]))
    {
      [self setRrule: _str];
    }

  return self;
}

- (void) dealloc
{
  [dayMask release];
  [super dealloc];
}

- (void) setRrule: (NSString *) _rrule
{
  CardGroup *mockParent;
  NSString *wrappedRule;
  CardElement *mockRule;

  if ([_rrule length] > 0)
    {
      wrappedRule = [NSString stringWithFormat:
                                @"BEGIN:MOCK\r\nRRULE:%@\r\nEND:MOCK",
                              _rrule];
      mockParent = [CardGroup parseSingleFromSource: wrappedRule];
      mockRule = [mockParent uniqueChildWithTag: @"rrule"];
      [values release];
      values = [[mockRule values] mutableCopy];
    }
}

- (iCalRecurrenceFrequency) valueForFrequency: (NSString *) value
{
  NSString *frequency;
  iCalRecurrenceFrequency freq;

  if ([value length] > 0)
    {
      frequency = [value uppercaseString];
      if ([frequency isEqualToString:@"WEEKLY"])
	freq = iCalRecurrenceFrequenceWeekly;
      else if ([frequency isEqualToString:@"MONTHLY"])
	freq = iCalRecurrenceFrequenceMonthly;
      else if ([frequency isEqualToString:@"DAILY"])
	freq = iCalRecurrenceFrequenceDaily;
      else if ([frequency isEqualToString:@"YEARLY"])
	freq = iCalRecurrenceFrequenceYearly;
      else if ([frequency isEqualToString:@"HOURLY"])
	freq = iCalRecurrenceFrequenceHourly;
      else if ([frequency isEqualToString:@"MINUTELY"])
	freq = iCalRecurrenceFrequenceMinutely;
      else if ([frequency isEqualToString:@"SECONDLY"])
	freq = iCalRecurrenceFrequenceSecondly;
      else
	freq = NSNotFound;
    }
  else
    freq = NSNotFound;

  return freq;
}

- (NSString *) frequencyForValue: (iCalRecurrenceFrequency) freq
{
  NSString *frequency;

  switch (freq)
    {
    case iCalRecurrenceFrequenceWeekly:
      frequency = @"WEEKLY";
      break;
    case iCalRecurrenceFrequenceMonthly:
      frequency = @"MONTHLY";
      break;
    case iCalRecurrenceFrequenceDaily:
      frequency = @"DAILY";
      break;
    case iCalRecurrenceFrequenceYearly:
      frequency = @"YEARLY";
      break;
    case iCalRecurrenceFrequenceHourly:
      frequency = @"HOURLY";
      break;
    case iCalRecurrenceFrequenceMinutely:
      frequency = @"MINUTELY";
      break;
    case iCalRecurrenceFrequenceSecondly:
      frequency = @"SECONDLY";
      break;
    default:
      frequency = nil;
    }

  return frequency;
}

/* accessors */

- (void) setFrequency: (iCalRecurrenceFrequency) _frequency
{
  [self setSingleValue: [self frequencyForValue: _frequency] forKey: @"freq"];
}

- (iCalRecurrenceFrequency) frequency
{
  return [self valueForFrequency: [self flattenedValuesForKey: @"freq"]];
}

- (void) setUntilDate: (NSCalendarDate *) _untilDate
{
  [self setSingleValue: [_untilDate icalString] forKey: @"until"];
}

- (NSCalendarDate *) untilDate
{
#warning handling of default timezone needs to be implemented
  return [[self flattenedValuesForKey: @"until"] asCalendarDate];
}

- (void) setInterval: (NSString *) _interval
{
  if ([_interval intValue] < 2)
    [self setSingleValue: nil forKey: @"interval"];
  else
    [self setSingleValue: _interval forKey: @"interval"];
}

- (void) setRepeatInterval: (int) _repeatInterval
{
  [self setInterval: [NSString stringWithFormat: @"%d", _repeatInterval]];
}

- (int) repeatInterval
{
  int interval;

  interval = [[self flattenedValuesForKey: @"interval"] intValue];
  if (interval < 1)
    interval = 1;

  return interval;
}

- (void) setRepeatCount: (int) _repeatCount
{
  [self setSingleValue: [NSString stringWithFormat: @"%d", _repeatCount]
                forKey: @"count"];
}

- (int) repeatCount
{
  return [[self flattenedValuesForKey: @"count"] intValue];
}

- (void) setCount: (NSString *) _count
{
  [self setSingleValue: _count forKey: @"count"];
}

- (void) setUntil: (NSString *) _until
{
  [self setSingleValue: _until forKey: @"until"];
}

- (void) setWkst: (NSString *) _weekStart
{
  [self setSingleValue: _weekStart forKey: @"wkst"];
}

#warning we also should handle the user weekstarts
- (NSString *) wkst
{
  NSString *start;

  start = [self flattenedValuesForKey: @"wkst"];
  if (![start length])
    start = @"MO";

  return start;
}

- (void) setWeekStart: (iCalWeekDay) _weekStart
{
  [self setWkst: [self iCalRepresentationForWeekDay: _weekStart]];
}

- (iCalWeekDay) weekStart
{
  return [self weekDayFromICalRepresentation: [self wkst]];
}

- (void) setByDay: (NSString *) newByDay
{
  NSMutableArray *byDays;

  byDays = [[newByDay componentsSeparatedByString: @","] mutableCopy];
  [self setValues: byDays atIndex: 0 forKey: @"byday"];
  [byDays release];
}

- (NSString *) byDay
{
  return [self flattenedValuesForKey: @"byday"];
}

- (void) setByDayMask: (iCalByDayMask *) newByDayMask
{
  [self setByDay: [newByDayMask asRuleString]];
}

- (iCalByDayMask *) byDayMask
{
  if (dayMask == nil && [[self byDay] length])
    {
      dayMask = [iCalByDayMask byDayMaskWithRuleString: [self byDay]];
      [dayMask retain];
    }
  
  return dayMask;
}

- (NSArray *) byMonthDay
{
  NSArray *byMonthDay;

  byMonthDay = [self valuesAtIndex: 0 forKey: @"bymonthday"];
  if (![byMonthDay count])
    byMonthDay = nil;

  return byMonthDay;
}

- (NSArray *) byMonth
{
  NSArray *byMonth;

  byMonth = [self valuesAtIndex: 0 forKey: @"bymonth"];
  if (![byMonth count])
    byMonth = nil;

  return byMonth;
}

- (BOOL) hasByMask
{
  /* There are more BYxxx rule parts but we don't support them yet :
   * - BYYEARDAY
   * - BYWEEKNO
   * - BYHOUR
   * - BYMINUTE
   * - BYSECOND
   * - BYSETPOS
   */
  return ([[self valuesAtIndex: 0 forKey: @"bymonthday"] count] || 
	  [[self valuesAtIndex: 0 forKey: @"byday"] count] ||
	  [[self valuesAtIndex: 0 forKey: @"bymonth"] count]);
}

- (BOOL) isInfinite
{
  return !(([self repeatCount] && [self repeatCount] > 0) || [self untilDate]);
}

/* private */

- (iCalWeekDay) weekDayFromICalRepresentation: (NSString *) _day
{
  /* be tolerant */
  iCalWeekDay foundDay;
  unichar chars[2];
  unsigned int dayLength;

  foundDay = 0;

  dayLength = [_day length];
  if (dayLength > 1)
    {
      // Ignore any prefix, only consider last two characters
      [[_day uppercaseString] getCharacters: chars
			      range: NSMakeRange (dayLength - 2, 2)];

      switch (chars[0])
	{
	case 'M': foundDay = iCalWeekDayMonday;
	  break;
	case 'W': foundDay = iCalWeekDayWednesday;
	  break;
	case 'F': foundDay = iCalWeekDayFriday;
	  break;
	case 'T':
	  if (chars[1] == 'U')
	    foundDay = iCalWeekDayTuesday;
	  else if (chars[1] == 'H')
	    foundDay = iCalWeekDayThursday;
	  break;
	case 'S':
	  if (chars[1] == 'A')
	    foundDay = iCalWeekDaySaturday;
	  else if (chars[1] == 'U')
	    foundDay = iCalWeekDaySunday;
	  break;
	}
    }

  if (!foundDay)
    [self errorWithFormat: @"wrong weekday representation: '%@'", _day];

  return foundDay;
//   // TODO: do not raise but rather return an error value?
//   [NSException raise:NSGenericException
// 	       format:@"Incorrect weekDay '%@' specified!", _day];
//   return iCalWeekDayMonday; /* keep compiler happy */
}

- (NSString *) iCalRepresentationForWeekDay: (iCalWeekDay) _weekDay
{
  switch (_weekDay)
    {
    case iCalWeekDayMonday: return @"MO";
    case iCalWeekDayTuesday: return @"TU";
    case iCalWeekDayWednesday: return @"WE";
    case iCalWeekDayThursday: return @"TH";
    case iCalWeekDayFriday: return @"FR";
    case iCalWeekDaySaturday: return @"SA";
    case iCalWeekDaySunday: return @"SU";
    default:  return @"MO"; // TODO: return error?
    }
}

- (NSArray *) bySetPos
{
  NSArray *lists, *bySetPos;

  lists = [self valuesForKey: @"bysetpos"];
  if ([lists count] > 0)
    bySetPos = [lists objectAtIndex: 0];
  else
    bySetPos = nil;

  return bySetPos;
}

// - (iCalWeekDay) weekDayForiCalRepre: (NSString *) _weekDay
// {
//   iCalWeekDay day;
//   NSString *weekDay;

//   weekDay = [_weekDay uppercaseString];
//   if ([weekDay isEqualToString: @"TU"])
//     day = iCalWeekDayTuesday;
//   else if ([weekDay isEqualToString: @"WE"])
//     day = iCalWeekDayWednesday;
//   else if ([weekDay isEqualToString: @"TH"])
//     day = iCalWeekDayThursday;
//   else if ([weekDay isEqualToString: @"FR"])
//     day = iCalWeekDayFriday;
//   else if ([weekDay isEqualToString: @"SA"])
//     day = iCalWeekDaySaturday;
//   else if ([weekDay isEqualToString: @"SU"])
//     day = iCalWeekDaySunday;
//   else
//     day = iCalWeekDayMonday;

//   return day;
// }

// - (NSString *) wkst
// {
//   return [self iCalRepresentationForWeekDay:byDay.weekStart];
// }

/*
  TODO:
  Each BYDAY value can also be preceded by a positive (+n) or negative
  (-n) integer. If present, this indicates the nth occurrence of the
  specific day within the MONTHLY or YEARLY RRULE. For example, within
  a MONTHLY rule, +1MO (or simply 1MO) represents the first Monday
  within the month, whereas -1MO represents the last Monday of the
  month. If an integer modifier is not present, it means all days of
  this type within the specified frequency. For example, within a
  MONTHLY rule, MO represents all Mondays within the month.
*/
// - (NSString *) byDayList
// {
//   NSMutableString *s;
//   unsigned        dow, mask, day;
//   BOOL            needsComma;
  
//   s          = [NSMutableString stringWithCapacity:20];
//   needsComma = NO;
//   mask       = byDay.mask;
//   day        = iCalWeekDayMonday;
  
//   for (dow = 0 /* Sun */; dow < 7; dow++) {
//     if (mask & day) {
//       if (needsComma)
//         [s appendString:@","];
      
//       if (byDay.useOccurence)
// 	// Note: we only support one occurrence for all currently
// 	[s appendFormat:@"%i", byDayOccurence1];
      
//       [s appendString:[self iCalRepresentationForWeekDay:day]];
//       needsComma = YES;
//     }
//     day = (day << 1);
//   }

//   return s;
// }

/* parsing rrule */

// - (void) _parseRuleString: (NSString *) _rrule
// {
//   // TODO: to be exact we would need a timezone to properly process the 'until'
//   //       date
//   unsigned i, count;
//   NSString *pFrequency = nil;
//   NSString *pUntil     = nil;
//   NSString *pCount     = nil;
//   NSString *pByday     = nil;
//   NSString *pBymday    = nil;
//   NSString *pBysetpos  = nil;
//   NSString *pInterval  = nil;
  
//   for (i = 0, count = [values count]; i < count; i++) {
//     NSString *prop, *key, *value;
//     NSRange  r;
//     NSString **vHolder = NULL;
    
//     prop = [values objectAtIndex:i];
//     r    = [prop rangeOfString:@"="];
//     if (r.length > 0) {
//       key   = [prop substringToIndex:r.location];
//       value = [prop substringFromIndex:NSMaxRange(r)];
//     }
//     else {
//       key   = prop;
//       value = nil;
//     }
    
//     key = [[key stringByTrimmingSpaces] lowercaseString];
//     if (![key isNotEmpty]) {
//       [self errorWithFormat:@"empty component in rrule: %@", _rrule];
//       continue;
//     }
    
//     vHolder = NULL;
//     switch ([key characterAtIndex:0]) {
//     case 'b':
//       if ([key isEqualToString:@"byday"])      { vHolder = &pByday;    break; }
//       if ([key isEqualToString:@"bymonthday"]) { vHolder = &pBymday;   break; }
//       if ([key isEqualToString:@"bysetpos"])   { vHolder = &pBysetpos; break; }
//       break;
//     case 'c':
//       if ([key isEqualToString:@"count"]) { vHolder = &pCount; break; }
//       break;
//     case 'f':
//       if ([key isEqualToString:@"freq"]) { vHolder = &pFrequency; break; }
//       break;
//     case 'i':
//       if ([key isEqualToString:@"interval"]) { vHolder = &pInterval; break; }
//       break;
//     case 'u':
//       if ([key isEqualToString:@"until"]) { vHolder = &pUntil; break; }
//       break;
//     default:
//       break;
//     }
    
//     if (vHolder != NULL) {
//       if ([*vHolder isNotEmpty])
//         [self errorWithFormat:@"more than one '%@' in: %@", key, _rrule];
//       else
//         *vHolder = [value copy];
//     }
//     else {
//       // TODO: we should just parse known keys and put remainders into a
//       //       separate dictionary
//       [self logWithFormat:@"TODO: add explicit support for key: %@", key];
//       [self takeValue:value forKey:key];
//     }
//   }
  
//   /* parse and fill individual values */
//   // TODO: this method should be a class method and create a new rrule object
  
//   if ([pFrequency isNotEmpty])
//     [self setNamedValue: @"FREQ" to: pFrequency];
//   else
//     [self errorWithFormat:@"rrule contains no frequency: '%@'", _rrule];
//   [pFrequency release]; pFrequency = nil;

//   if (pInterval != nil)
//     interval = [pInterval intValue];
//   [pInterval release]; pInterval = nil;
  
//   // TODO: we should parse byday in here
//   if (pByday != nil) [self setByday:pByday];
//   [pByday release]; pByday = nil;

//   if (pBymday != nil) {
//     NSArray *t;
    
//     t = [pBymday componentsSeparatedByString:@","];
//     ASSIGNCOPY(byMonthDay, t);
//   }
//   [pBymday release]; pBymday = nil;
  
//   if (pBysetpos != nil)
//     // TODO: implement
//     [self errorWithFormat:@"rrule contains bysetpos, unsupported: %@", _rrule];
//   [pBysetpos release]; pBysetpos = nil;
  
//   if (pUntil != nil) {
//     NSCalendarDate *pUntilDate;
    
//     if (pCount != nil) {
//       [self errorWithFormat:@"rrule contains 'count' AND 'until': %@", _rrule];
//       [pCount release];
//       pCount = nil;
//     }
    
//     /*
//       The spec says:
//         "If specified as a date-time value, then it MUST be specified in an
//          UTC time format."
//       TODO: we still need some object representing a 'timeless' date.
//     */
//     if (![pUntil hasSuffix:@"Z"] && [pUntil length] > 8) {
//       [self warnWithFormat:@"'until' date has no explicit UTC marker: '%@'",
//               _rrule];
//     }
    
//     pUntilDate = [NSCalendarDate calendarDateWithICalRepresentation:pUntil];
//     if (pUntilDate != nil)
//       [self setUntilDate:pUntilDate];
//     else {
//       [self errorWithFormat:@"could not parse 'until' in rrule: %@", 
//               _rrule];
//     }
//   }
//   [pUntil release]; pUntil = nil;
  
//   if (pCount != nil) 
//     [self setRepeatCount:[pCount intValue]];
//   [pCount release]; pCount = nil;
// }

/* properties */

// - (void) setByday: (NSString *) _byDayList
// {
//   // TODO: each day can have an associated occurence, eg:
//   //        +1MO,+2TU,-9WE
//   // TODO: this should be moved to the parser
//   NSArray  *days;
//   unsigned i, count;
//   NSString    *iCalDay;
//   iCalWeekDay day;
//   unsigned    len;
//   unichar     c0;
//   int         occurence;
//   int offset;

//   /* reset mask */
//   byDay.mask = 0;
//   byDay.useOccurence = 0;
//   byDayOccurence1 = 0;
  
//   days  = [_byDayList componentsSeparatedByString:@","];
//   for (i = 0, count = [days count]; i < count; i++)
//     {
//       iCalDay = [days objectAtIndex:i]; // eg: MO or TU
//       if ((len = [iCalDay length]) == 0)
//         {
//           [self errorWithFormat:@"found an empty day in byday list: '%@'", 
//                 _byDayList];
//           continue;
//         }
    
//       c0 = [iCalDay characterAtIndex:0];
//       if (((c0 == '+' || c0 == '-') && len > 2) || (isdigit(c0) && len > 1)) {
//         occurence = [iCalDay intValue];
      
//         offset = 1; /* skip occurence */
//         while (offset < len && isdigit([iCalDay characterAtIndex:offset]))
//           offset++;
        
//         iCalDay = [iCalDay substringFromIndex:offset];
        
//         if (byDay.useOccurence && (occurence != byDayOccurence1))
//           {
//             [self errorWithFormat:
//                     @"we only supported one occurence (occ=%i,day=%@): '%@'", 
//                   occurence, iCalDay, _byDayList];
//             continue;
//           }
        
//         byDay.useOccurence = 1;
//         byDayOccurence1 = occurence;
//       }
//     else if (byDay.useOccurence)
//       [self errorWithFormat:
// 	      @"a byday occurence was specified on one day, but not on others"
//             @" (unsupported): '%@'", _byDayList];
    
//       day = [self weekDayFromICalRepresentation:iCalDay];
//       byDay.mask |= day;
//     }
// }

/* versit key ordering */
- (NSArray *) orderOfValueKeys
{
  return [NSArray arrayWithObjects: @"freq", @"interval", @"count", @"until",
                  @"bymonth", @"byweekno", @"byyearday", @"bymonthday",
                  @"byday", @"byhour", @"byminute", @"bysecond", @"bysetpos",
                  nil];
}

/* key/value coding */

- (void) handleTakeValue: (id) _value
           forUnboundKey: (NSString *)_key
{
  [self warnWithFormat:@"Cannot handle unbound key: '%@'", _key];
}

- (BOOL) isEqual: (id) rrule
{
  BOOL isEqual = YES;

  if ([rrule isKindOfClass: [iCalRecurrenceRule class]])
    {
      /*
      NSLog(@"*** iCalRecurrenceRule comparison ***");      
      NSLog(@"Event 1 : repeat %i, interval %i, frequency %i, until %@",
	    [self repeatCount], [self repeatInterval], [self frequency], [self untilDate]);
      NSLog(@"Event 2 : repeat %i, interval %i, frequency %i, until %@",
	    [rrule repeatCount], [rrule repeatInterval], [rrule frequency], [rrule untilDate]);
      */

      if ([self untilDate] && [rrule untilDate])
	isEqual = [[self untilDate] isEqual: [rrule untilDate]];
      else if ([self untilDate] || [self untilDate])
	isEqual = NO;
      
      isEqual = isEqual &&
	[self repeatCount] == [rrule repeatCount] &&
	[self repeatInterval] == [rrule repeatInterval] &&
	[self frequency] == [rrule frequency];
    }
  else
    isEqual = NO;
  
  return isEqual;
}

@end /* iCalRecurrenceRule */
