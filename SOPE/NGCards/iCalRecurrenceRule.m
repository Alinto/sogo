/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#import <Foundation/NSException.h>
#import <NGExtensions/NSString+Ext.h>
#import <NGExtensions/NSObject+Logs.h>

#import <ctype.h>

#import "NSCalendarDate+NGCards.h"
#import "NSString+NGCards.h"

#import "NSCalendarDate+ICal.h"

#import "iCalRecurrenceRule.h"

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
- (NSString *) iCalRepresentationForWeekDay: (iCalWeekDay) _waeekDay;
- (NSString *) freq;
- (NSString *) wkst;
- (NSString *) byDayList;

// - (void)_parseRuleString:(NSString *)_rrule;

/* currently used by parser, should be removed (replace with an -init..) */
- (void)setByday:(NSString *)_byDayList;

@end

@implementation iCalRecurrenceRule

+ (id) recurrenceRuleWithICalRepresentation: (NSString *) _iCalRep
{
  return [self simpleElementWithTag: @"rrule" value: _iCalRep];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      [self setTag: @"rrule"];
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

- (void) setRrule: (NSString *) _rrule
{
  NSEnumerator *newValues;
  NSString *newValue;

  newValues = [[_rrule componentsSeparatedByString: @";"] objectEnumerator];
  newValue = [newValues nextObject];
  while (newValue)
    {
      [self addValue: newValue];
      newValue = [newValues nextObject];
    }
}

- (iCalRecurrenceFrequency) valueForFrequency: (NSString *) value
{
  NSString *frequency;
  iCalRecurrenceFrequency freq;

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
  [self setNamedValue: @"freq" to: [self frequencyForValue: _frequency]];
}

- (iCalRecurrenceFrequency) frequency
{
  return [self valueForFrequency: [self namedValue: @"freq"]];
}

- (void) setRepeatCount: (int) _repeatCount
{
  [self setNamedValue: @"count"
        to: [NSString stringWithFormat: @"%d", _repeatCount]];
}

- (int) repeatCount
{
  return [[self namedValue: @"count"] intValue];
}

- (void) setUntilDate: (NSCalendarDate *) _untilDate
{
  [self setNamedValue: @"until"
        to: [_untilDate iCalFormattedDateTimeString]];
}

- (NSCalendarDate *) untilDate
{
#warning handling of default timezone needs to be implemented
  return [[self namedValue: @"until"] asCalendarDate];
}

- (void) setInterval: (NSString *) _interval
{
  [self setNamedValue: @"interval" to: _interval];
}

- (void) setCount: (NSString *) _count
{
  [self setNamedValue: @"count" to: _count];
}

- (void) setUntil: (NSString *) _until
{
  [self setNamedValue: @"until" to: _until];
}

- (void) setRepeatInterval: (int) _repeatInterval
{
  [self setNamedValue: @"interval"
        to: [NSString stringWithFormat: @"%d", _repeatInterval]];
}

- (int) repeatInterval
{
  return [[self namedValue: @"interval"] intValue];
}

- (void) setWkst: (NSString *) _weekStart
{
  [self setNamedValue: @"wkst" to: _weekStart];
}

- (NSString *) wkst
{
  return [self namedValue: @"wkst"];
}

- (void) setWeekStart: (iCalWeekDay) _weekStart
{
  [self setWkst: [self iCalRepresentationForWeekDay: _weekStart]];
}

- (iCalWeekDay) weekStart
{
  return [self weekDayFromICalRepresentation: [self wkst]];
}

- (void) setByDayMask: (unsigned) _mask
{
  NSMutableArray *days;
  unsigned int count;
  unsigned char maskDays[] = { iCalWeekDayMonday, iCalWeekDayTuesday,
                               iCalWeekDayWednesday, iCalWeekDayThursday,
                               iCalWeekDayFriday, iCalWeekDaySaturday,
                               iCalWeekDaySunday };
  days = [NSMutableArray arrayWithCapacity: 7];
  if (_mask)
    {
      for (count = 0; count < 7; count++)
        if (_mask & maskDays[count])
          [days addObject:
                  [self iCalRepresentationForWeekDay: maskDays[count]]];
    }

  [self setNamedValue: @"byday" to: [days componentsJoinedByString: @","]];
}

- (unsigned int) byDayMask
{
  NSArray *days;
  unsigned int mask, count, max;
  NSString *day;

  mask = 0;

  days = [[self namedValue: @"byday"] componentsSeparatedByString: @","];
  max = [days count];
  for (count = 0; count < max; count++)
    {
      day = [days objectAtIndex: count];
      day = [day substringFromIndex: [day length] - 2];
      mask |= [self weekDayFromICalRepresentation: day];
    }

  return mask;
}

#warning this is fucked up
- (int) byDayOccurence1
{
  return 0;
//   return byDayOccurence1;
}

- (NSArray *) byMonthDay
{
  return [[self namedValue: @"bymonthday"] componentsSeparatedByString: @","];
}

- (BOOL) isInfinite
{
  return !([self repeatCount] || [self untilDate]);
}

/* private */

- (iCalWeekDay) weekDayFromICalRepresentation: (NSString *) _day
{
  if ([_day length] > 1) {
    /* be tolerant */
    unichar c0, c1;
    
    c0 = [_day characterAtIndex:0];
    if (c0 == 'm' || c0 == 'M') return iCalWeekDayMonday;
    if (c0 == 'w' || c0 == 'W') return iCalWeekDayWednesday;
    if (c0 == 'f' || c0 == 'F') return iCalWeekDayFriday;

    c1 = [_day characterAtIndex:1];
    if (c0 == 't' || c0 == 'T') {
      if (c1 == 'u' || c1 == 'U') return iCalWeekDayTuesday;
      if (c1 == 'h' || c1 == 'H') return iCalWeekDayThursday;
    }
    if (c0 == 's' || c0 == 'S') {
      if (c1 == 'a' || c1 == 'A') return iCalWeekDaySaturday;
      if (c1 == 'u' || c1 == 'U') return iCalWeekDaySunday;
    }
  }
  
  // TODO: do not raise but rather return an error value?
  [NSException raise:NSGenericException
	       format:@"Incorrect weekDay '%@' specified!", _day];
  return iCalWeekDayMonday; /* keep compiler happy */
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

/* key/value coding */

- (void) handleTakeValue: (id) _value
           forUnboundKey: (NSString *)_key
{
  [self warnWithFormat:@"Cannot handle unbound key: '%@'", _key];
}

@end /* iCalRecurrenceRule */
