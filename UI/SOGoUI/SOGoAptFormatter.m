/*
  Copyright (C) 2008-2009 Inverse inc.
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

#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>

#import "SOGoAptFormatter.h"

@interface SOGoAptFormatter(PrivateAPI)
- (NSString *)titleForApt:(id)_apt :(NSCalendarDate *)_refDate;
- (NSString *)shortTitleForApt:(id)_apt :(NSCalendarDate *)_refDate;
- (NSTimeZone *)displayTZ;

- (void)appendTimeInfoForDate:(NSCalendarDate *)_date
  usingReferenceDate:(NSCalendarDate *)_refDate
  toBuffer:(NSMutableString *)_buf;

- (void)appendTimeInfoFromApt:(id)_apt
  usingReferenceDate:(NSCalendarDate *)_refDate
  toBuffer:(NSMutableString *)_buf;
@end

// TODO: Clean this up, put it into NGExtensions!
@interface NSCalendarDate (UIxCalMonthOverviewExtensions_UsedPrivates)
- (BOOL)isDateInSameMonth:(NSCalendarDate *)_other;
@end

@implementation SOGoAptFormatter

- (id)initWithDisplayTimeZone:(NSTimeZone *)_tz {
  if ((self = [super init])) {
    self->tz = [_tz retain];
    [self setFullDetails];
  }
  return self;
}

- (void)dealloc {
  [self->tz               release];
  [self->privateTitle     release];
  [self->titlePlaceholder release];
  [super dealloc];
}

/* accessors */

- (void)setTooltip {
  self->formatAction = @selector(tooltipForApt::);
}

- (void)setSingleLineFullDetails {
  self->formatAction = @selector(singleLineFullDetailsForApt::);
}

- (void)setFullDetails {
  self->formatAction = @selector(fullDetailsForApt::);
}

- (void)setPrivateTooltip {
  self->formatAction = @selector(tooltipForPrivateApt::);
}

- (void)setPrivateDetails {
  self->formatAction = @selector(detailsForPrivateApt::);
}

- (void)setTitleOnly {
  self->formatAction = @selector(titleForApt::);
}

- (void)setShortTitleOnly {
  self->formatAction = @selector(shortTitleForApt::);
}

- (void)setShortMonthTitleOnly {
  self->formatAction = @selector(shortMonthTitleForApt::);
}

- (void)setPrivateSuppressAll {
  self->formatAction = @selector(suppressApt::);
}

- (void)setPrivateTitleOnly {
  self->formatAction = @selector(titleOnlyForPrivateApt::);
}

- (void)setPrivateTitle:(NSString *)_privateTitle {
  ASSIGN(self->privateTitle, _privateTitle);
}
- (NSString *)privateTitle {
  return self->privateTitle;
}

- (void)setTitlePlaceholder:(NSString *)_titlePlaceholder {
  ASSIGN(self->titlePlaceholder, _titlePlaceholder);
}
- (NSString *)titlePlaceholder {
  return self->titlePlaceholder;
}

- (void)setOmitsEndDate {
  self->omitsEndDate = YES;
}

- (NSString *)stringForObjectValue:(id)_obj {
  [self warnWithFormat:@"%s called, please use "
                       @"stringForObjectValue:referenceDate: instead!",
                       __PRETTY_FUNCTION__];
  return [self stringForObjectValue:_obj referenceDate:nil];
}

- (NSString *)stringForObjectValue:(id)_obj
  referenceDate:(NSCalendarDate *)_refDate
{
  return [self performSelector:self->formatAction
               withObject:_obj
               withObject:_refDate];
}

/* Private */

- (NSTimeZone *)displayTZ {
  return self->tz;
}

- (void)appendTimeInfoForDate:(NSCalendarDate *)_date
  usingReferenceDate:(NSCalendarDate *)_refDate
  toBuffer:(NSMutableString *)_buf
{
  /* several cases:
   * 12:00
   * 12:00 - 13:00
   * 12:00 (07-05) - 13:00 (07-07)
   * 12:00 (12-30-2004) - 13:00 (01-01-2005)
   */

  [_buf appendFormat:@"%02i:%02i",
                     [_date hourOfDay],
                     [_date minuteOfHour]];
  if (_refDate && ![_date isDateOnSameDay:_refDate]) {
    [_buf appendFormat:@" (%02i-%02i",
                       [_date monthOfYear],
                       [_date dayOfMonth]];
    if ([_date yearOfCommonEra] != [_refDate yearOfCommonEra])
      [_buf appendFormat:@"-%04i", [_date yearOfCommonEra]];
    [_buf appendString:@")"];
  }
}

- (void)appendTimeInfoFromApt:(id)_apt
  usingReferenceDate:(NSCalendarDate *)_refDate
  toBuffer:(NSMutableString *)_buf
{
  NSCalendarDate *startDate, *endDate, *date;
  NSTimeZone     *dtz;
  BOOL           spansRange;

  spansRange = NO;
  dtz        = [self displayTZ];
  startDate  = [_apt valueForKey:@"startDate"];
  [startDate setTimeZone:dtz];
  endDate    = [_apt valueForKey:@"endDate"];
  if(endDate != nil) {
    [endDate setTimeZone:dtz];
    spansRange = ![endDate isEqualToDate:startDate];
  }
  if (_refDate)
    [_refDate setTimeZone:dtz];

#if 0
  if (!_refDate || [startDate isDateOnSameDay:_refDate])
    date = startDate;
  else
    date = [startDate hour:0 minute:0];
#else
  date = startDate;
#endif

  [self appendTimeInfoForDate:date
        usingReferenceDate:_refDate
        toBuffer:_buf];

  if (spansRange && !self->omitsEndDate) {
    [_buf appendString:@" - "];
#if 0
    if (!_refDate || [endDate isDateOnSameDay:_refDate])
      date = endDate;
    else
      date = [endDate hour:23 minute:59];
#else
    date = endDate;
#endif
    [self appendTimeInfoForDate:date
          usingReferenceDate:_refDate
          toBuffer:_buf];
  }
}

- (NSString *)titleForApt:(id)_apt :(NSCalendarDate *)_refDate {
  NSString *title;
  
  title = [_apt valueForKey:@"title"];
  if (![title isNotEmpty])
    title = [self titlePlaceholder];
  return title;
}

- (NSString *)shortTitleForApt:(id)_apt :(NSCalendarDate *)_refDate {
  NSString *title;
  
  title = [self titleForApt:_apt :_refDate];
  if ([title length] > 50)
    title = [[title substringToIndex: 49] stringByAppendingString:@"..."];
  
  return title;
}

- (NSString *)shortMonthTitleForApt:(id)_apt :(NSCalendarDate *)_refDate {
  NSMutableString *title;
  NSCalendarDate *startDate;
  NSTimeZone *dtz;

  title = [NSMutableString new];
  [title autorelease];

  dtz        = [self displayTZ];
  startDate  = [_apt valueForKey: @"startDate"];
  [startDate setTimeZone:dtz];
  [self appendTimeInfoForDate: startDate usingReferenceDate: nil
        toBuffer: title];
  [title appendFormat: @" %@", [self titleForApt:_apt :_refDate]];
  
  return title;
}

- (NSString *)singleLineFullDetailsForApt:(id)_apt :(NSCalendarDate *)_refDate {
  NSMutableString *aptDescr;
  NSString        *s;
  
  aptDescr = [NSMutableString stringWithCapacity:60];
  [self appendTimeInfoFromApt:_apt
        usingReferenceDate:_refDate
        toBuffer:aptDescr];
  if ((s = [_apt valueForKey:@"location"]) != nil) {
    [aptDescr appendFormat:@"; (%@)", s];
  }
  if ((s = [self titleForApt:_apt :_refDate]) != nil)
    [aptDescr appendFormat:@"; %@", s];
  return aptDescr;
}

- (NSString *) fullDetailsForApt: (id)_apt
                                : (NSCalendarDate *)_refDate
{
  NSMutableString *aptDescr;
  NSString *s;

  aptDescr = [NSMutableString stringWithCapacity: 60];
  [self appendTimeInfoFromApt: _apt
        usingReferenceDate: _refDate
        toBuffer: aptDescr];
  s = [_apt valueForKey: @"location"];
  if ([s length] > 0)
    {
      if ([s length] > 50)
        s = [[s substringToIndex: 49] stringByAppendingString: @"..."];
      [aptDescr appendFormat:@" (%@)", s];
    }
  s = [self shortTitleForApt: _apt : _refDate];
  if ([s length] > 0)
    [aptDescr appendFormat:@"<br />%@", s];
  
  return aptDescr;
}

- (NSString *) detailsForPrivateApt: (id) _apt
                                   : (NSCalendarDate *) _refDate
{
  NSMutableString *aptDescr;
  NSString        *s;

  aptDescr = [NSMutableString stringWithCapacity:40];
  [self appendTimeInfoFromApt:_apt
        usingReferenceDate:_refDate
        toBuffer:aptDescr];
  if ((s = [self privateTitle]) != nil)
    [aptDescr appendFormat:@"<br />%@", s];
  return aptDescr;
}

- (NSString *) titleOnlyForPrivateApt: (id)_apt
                                     : (NSCalendarDate *) _refDate
{
  NSString *s;
  
  s = [self privateTitle];
  if (!s)
    s = @"";

  return s;
}

- (NSString *) tooltipForApt: (id)_apt
                            : (NSCalendarDate *) _refDate
{
  NSMutableString *aptDescr;
  NSString *s;

  aptDescr = [NSMutableString stringWithCapacity: 60];
  [aptDescr appendString: @"Date: "];
  [self appendTimeInfoFromApt: _apt
        usingReferenceDate: _refDate
        toBuffer: aptDescr];
  s = [self titleForApt: _apt : _refDate];
  if ([s length] > 0)
    [aptDescr appendFormat: @"\nTitle: %@", s];
  s = [_apt valueForKey: @"location"];
  if ([s length] > 0)
    [aptDescr appendFormat: @"\nLocation: %@", s];
  s = [_apt valueForKey: @"description"];
  if ([s length] > 0)
    [aptDescr appendFormat:@"\n%@", s];

  return aptDescr;
}

- (NSString *) tooltipForPrivateApt: (id) _apt
                                   : (NSCalendarDate *) _refDate
{
  NSMutableString *aptDescr;
  NSString *s;
  
  aptDescr = [NSMutableString stringWithCapacity: 25];
  [self appendTimeInfoFromApt: _apt
        usingReferenceDate: _refDate
        toBuffer: aptDescr];  
  if ((s = [self privateTitle]) != nil)
    [aptDescr appendFormat:@"\n%@", s];

  return aptDescr;
}

- (NSString *) suppressApt: (id) _apt
                          : (NSCalendarDate *) _refDate
{
  return @"";
}

@end /* SOGoAptFormatter */
