/*
  Copyright (C) 2000-2004 SKYRIX Software AG

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
// $Id: UIxAppointmentFormatter.m 59 2004-06-22 13:40:19Z znek $

#include "UIxAppointmentFormatter.h"
#import <Foundation/Foundation.h>
#import <NGExtensions/NGExtensions.h>
#import <EOControl/EOControl.h>

@implementation UIxAppointmentFormatter

- (id)init {
  if ((self = [super init])) {
    [self setFormat:@"%S - %E, \n%T"];
    [self setDateFormat:@"%H:%M"];
    [self setOtherDayDateFormat:@"%H:%M(%m-%d)"];
    [self setOtherYearDateFormat:@"%H:%M(%Y-%m-%d)"];
    [self setToLongString:@".."];
    [self setMoreParticipantsString:@"..."];
    [self setParticipantsSeparator:@", "];
    [self setRelationDate:nil];
    self->showFullNames = NO;
  }
  return self;
}

- (id)initWithFormat:(NSString *)_format {
  if ((self = [self init])) {
    [self setFormat:_format];
  }
  return self;
}

+ (UIxAppointmentFormatter *)formatterWithFormat:(NSString *)_format {
  return AUTORELEASE([(UIxAppointmentFormatter *)[UIxAppointmentFormatter alloc]
                                                 initWithFormat:_format]);
}

+ (UIxAppointmentFormatter *)formatter {
  return AUTORELEASE([[UIxAppointmentFormatter alloc] init]);
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->formatString);
  RELEASE(self->dateFormat);
  RELEASE(self->otherDayDateFormat);
  RELEASE(self->otherYearDateFormat);
  RELEASE(self->toLongString);
  RELEASE(self->moreParticipantsString);
  RELEASE(self->participantsSeparator);
  RELEASE(self->relationDate);

  [super dealloc];
}
#endif

// accessors

- (void)setFormat:(NSString *)_format {
  ASSIGN(self->formatString,_format);
}
- (NSString *)format {
  return self->formatString;
}

- (void)setDateFormat:(NSString *)_format {
  ASSIGN(self->dateFormat,_format);
}
- (NSString *)dateFormat {
  return self->dateFormat;
}

- (void)setOtherDayDateFormat:(NSString *)_format {
  ASSIGN(self->otherDayDateFormat,_format);
}
- (NSString *)otherDayDateFormat {
  return self->otherDayDateFormat;
}

- (void)setOtherYearDateFormat:(NSString *)_format {
  ASSIGN(self->otherYearDateFormat,_format);
}
- (NSString *)otherYearDateFormat {
  return self->otherYearDateFormat;
}

- (void)setToLongString:(NSString *)_toLong {
  ASSIGN(self->toLongString,_toLong);
}
- (NSString *)toLongString {
  return self->toLongString;
}

- (void)setMoreParticipantsString:(NSString *)_more {
  ASSIGN(self->moreParticipantsString,_more);
}
- (NSString *)moreParticipantsString {
  return self->moreParticipantsString;
}

- (void)setParticipantsSeparator:(NSString *)_sep {
  ASSIGN(self->participantsSeparator,_sep);
}
- (NSString *)participantsSeparator {
  return self->participantsSeparator;
}

- (void)setRelationDate:(NSCalendarDate *)_relation {
  ASSIGN(self->relationDate,_relation);
}
- (NSCalendarDate *)relationDate {
  return self->relationDate;
}

- (void)setShowFullNames:(BOOL)_flag {
  self->showFullNames = _flag;
}
- (BOOL)showFullNames {
  return self->showFullNames;
}

// easy switching
- (void)switchToAMPMTimes:(BOOL)_showAMPM {
  if (_showAMPM) {
    [self setDateFormat:@"%I:%M %p"];
    [self setOtherDayDateFormat:@"%I:%M %p(%m-%d)"];
    [self setOtherYearDateFormat:@"%I:%M %p(%Y-%m-%d)"];
  }
  else {
    [self setDateFormat:@"%H:%M"];
    [self setOtherDayDateFormat:@"%H:%M(%m-%d)"];
    [self setOtherYearDateFormat:@"%H:%M(%Y-%m-%d)"];
  }
}

// formatting helpers

- (NSString *)formatDate:(NSCalendarDate *)_date
              withFormat:(NSString *)_format
{
  NSString *f;
  NSCalendarDate *rel;

  rel = self->relationDate;
  
  if (_format == nil) {
    if (rel == nil) {
      f = self->dateFormat;
    }
    else if ([_date isDateOnSameDay:rel]) {
      f = self->dateFormat;
    }
    else if ([_date yearOfCommonEra] == [rel yearOfCommonEra]) {
      f = self->otherDayDateFormat;
    }
    else {
      f = self->otherYearDateFormat;
    }
  }
  else {
    f = _format;
  }
  return [_date descriptionWithCalendarFormat:f];
}

- (NSString *)formatStartDateFromApt:(id)_apt
                          withFormat:(NSString *)_format
{
  return [self formatDate:[_apt valueForKey:@"startDate"]
               withFormat:_format];
}

- (NSString *)formatEndDateFromApt:(id)_apt
                        withFormat:(NSString *)_format
{
  return [self formatDate:[_apt valueForKey:@"endDate"]
               withFormat:_format];
}

- (NSString *)stringForParticipant:(id)_part {
  id label = nil;
  
  if ([[_part valueForKey:@"isTeam"] boolValue]) {
    if ((label = [_part valueForKey:@"info"]) == nil)
      label = [_part valueForKey:@"description"];
  }
  else if (self->showFullNames) {
    label = [_part valueForKey:@"firstname"];
    label = ([label length])
      ? [label stringByAppendingFormat:@" %@", [_part valueForKey:@"name"]]
      : [_part valueForKey:@"name"];
  }
  else if ([[_part valueForKey:@"isAccount"] boolValue]) {
    label = [_part valueForKey:@"login"];
  }
  else {
    if ((label = [_part valueForKey:@"name"]) == nil) {
      if ((label = [_part valueForKey:@"info"]) == nil)
        label = [_part valueForKey:@"description"];
    }
  }

  if (![label isNotNull])
    label = @"*";

  return label;
}

- (NSString *)participantsForApt:(id)_apt
                    withMaxCount:(NSString *)_cnt {
  NSArray         *p;
  int             max;
  int             cnt;
  NSMutableString *pString;

  pString = [NSMutableString stringWithCapacity:255];

  if (_cnt == nil) {
    max = -1; // no limit
  }
  else {
    max = [_cnt intValue];
  }

  p = [_apt valueForKey:@"participants"];

  p = [p sortedArrayUsingKeyOrderArray:
         [NSArray arrayWithObjects:
                  [EOSortOrdering sortOrderingWithKey:@"isAccount"
                                  selector:EOCompareAscending],
                  [EOSortOrdering sortOrderingWithKey:@"login"
                                  selector:EOCompareAscending],
                  nil]];

  max = ((max > [p count]) || (max == -1))
    ? [p count]
    : max;

  for (cnt = 0; cnt < max; cnt++) {

    if (cnt != 0)
      [pString appendString:self->participantsSeparator];
      
    [pString appendString:
             [self stringForParticipant:[p objectAtIndex:cnt]]];
  }

  if (max < [p count]) {
    [pString appendString:self->moreParticipantsString];
  }

  return pString;
}

- (NSString *)titleForApt:(id)_apt withMaxLength:(NSString *)_length {
  NSString    *t = nil;
  int l;

  l = (_length == nil)
    ? -1
    : [_length intValue];

  t = [_apt valueForKey:@"title"];
  if (!t) return @"*";

  if (l > 1) {
    if ([t length] > l) {
      t = [t substringToIndex:(l - 2)];
      t = [t stringByAppendingString:self->toLongString];
    }
  }
  
  if (l == 0)
    t = @"*";
  
  return t;
}

- (NSString *)locationForApt:(id)_apt withMaxLength:(NSString *)_length {
  NSString    *t = nil;
  int l;

  l = (_length == nil)
    ? -1
    : [_length intValue];

  t = [_apt valueForKey:@"location"];
  if (![t isNotNull] ||
      [t length] == 0 ||
      [t isEqualToString:@" "])
    return @"";
  
  if (l > 1) {
    if ([t length] > l) {
      t = [t substringToIndex:(l - 2)];
      t = [t stringByAppendingString:self->toLongString];
    }
  }
  
  if (l == 0)
    t = @"";
  
  return t;
}

- (NSString *)resourcesForApt:(id)_apt withMaxLength:(NSString *)_length {
  NSString    *t = nil;
  int l;

  l = (_length == nil)
    ? -1
    : [_length intValue];

  t = [_apt valueForKey:@"resourceNames"];
  if (![t isNotNull]  ||
      [t length] == 0 ||
      [t isEqualToString:@" "])
    return @"";

  if (l > 1) {
    if ([t length] > l) {
      t = [t substringToIndex:(l - 2)];
      t = [t stringByAppendingString:self->toLongString];
    }
  }
  
  if (l == 0)
    t = @"";
  
  return t;
}

// NSFormatter stuff

- (NSString *)stringForObjectValue:(id)_obj {
  NSMutableString *newString;
  int             cnt;
  int             length;
  BOOL            replaceMode = NO;
  NSString        *helper = nil;
  NSCharacterSet  *digits;

  newString = [NSMutableString stringWithCapacity:255];
  length    = [self->formatString length];
  digits    = [NSCharacterSet decimalDigitCharacterSet];

  //  NSLog(@"Formatting with format: %@", self->formatString);

  for (cnt = 0; cnt < length; cnt++) {
    unichar c;
    c = [self->formatString characterAtIndex:cnt];
    //    NSLog(@"Character is: %c mode is: %@", c,
    //          [NSNumber numberWithBool:replaceMode]);
    if (replaceMode) {
      if (c == 'S') {
        [newString appendString:
                   [self formatStartDateFromApt:_obj withFormat:helper]];
        helper = nil;
        replaceMode = NO;
      }
      else if (c == 'E') {
        [newString appendString:
                   [self formatEndDateFromApt:_obj withFormat:helper]];
        helper = nil;
        replaceMode = NO;
      }
      else if (c == 'P') {
        [newString appendString:
                   [self participantsForApt:_obj withMaxCount:helper]];
        helper = nil;
        replaceMode = NO;
      }
      else if (c == 'T') {
        [newString appendString:
                   [self titleForApt:_obj withMaxLength:helper]];
        helper = nil;
        replaceMode = NO;
      }
      else if (c == 'L') {
        NSString *l;

        l = [self locationForApt:_obj withMaxLength:helper];

        if ([l length] > 0)
          [newString appendString:l];
        helper = nil;
        replaceMode = NO;
      }
      else if (c == 'R') {
        NSString *r;

        r = [self resourcesForApt:_obj withMaxLength:helper];

        if ([r length] > 0)
          [newString appendString:r];
        helper = nil;
        replaceMode = NO;
      }
      else if (c == '(') {
        int     end;
        NSRange r = NSMakeRange(cnt,length-cnt);
        
        r = [self->formatString rangeOfString:@")"
                 options:0 range:r];
        
        end = r.location - 1;
        r = NSMakeRange(cnt+1, end-cnt-1);
        
        helper = [self->formatString substringWithRange:r];
        cnt = end + 1;
      }
      else if ([digits characterIsMember:c]) {
        helper = (helper == nil)
          ? [NSString stringWithFormat:@"%c",c]
          : [NSString stringWithFormat:@"%@%c", helper, c];
      }
      else {
        NSLog(@"UNKNOWN FORMAT CHARACTER '%c'!!",c);
        replaceMode = NO;
        helper = nil;
      }
    } else {
      if (c == '%') {
        replaceMode = YES;
      }
      else {
        [newString appendFormat:@"%c", c];
      }
    }
  }
  
  return newString;
}

@end
