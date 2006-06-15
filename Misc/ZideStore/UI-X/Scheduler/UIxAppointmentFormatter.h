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
// $Id: UIxAppointmentFormatter.h 59 2004-06-22 13:40:19Z znek $

#ifndef __UIxAppointmentFormatter_H__
#define __UIxAppointmentFormatter_H__

#import <Foundation/NSFormatter.h>

/*
  Formatter to format appointment-dicts to readable strings:

  %[(dateFormat)]S
             - startDate formatted with the dateFormat string
             - if no dateFormat is defined, the default formats are used
             - !!! dont forget the ()brakes !!!
  %[(dateFormat)]E
             - endDate formatted with the dateFormat string
             - if no dateFormat is defined, the default formats are used
             - !!! dont forget the ()brakes !!!

  %[length]T - title with the specified length
             - if title has more chars than length overLengthString is appended
             - if no length is defined, no limit is set

  %[max]P    - participants
             - if more than max participants at appointment
               moreParticipantsString is appended
             - if no max defined no limit is set

  %[length]L - location
             - if location has more chars than length overLengthString is
               appended
             - if no length is defined, no limit is set

  Example:
  format: @"%S - %E, \n%T";

 */

@class NSCalendarDate;

@interface UIxAppointmentFormatter : NSFormatter
{
@protected
  NSString        *formatString;           // default: @"%S - %E, \n%T"
  
  NSString        *dateFormat;             // default: @"%H:%M"
  NSString        *otherDayDateFormat;     // default: @"%H:%M(%m-%d)"
  NSString        *otherYearDateFormat;    // default: @"%H:%M(%Y-%m-%d)"

  NSString        *toLongString;           // default: @".."
  NSString        *moreParticipantsString; // default: @"..."
  NSString        *participantsSeparator;  // default: @", "

  NSCalendarDate  *relationDate;           // if nil, dateFormat used as format
  // to know whether its the same day, the same year or another year

  BOOL            showFullNames; // try to show full names of participants
}

//init
- (id)initWithFormat:(NSString *)_format;
+ (UIxAppointmentFormatter *)formatterWithFormat:(NSString *)_format;
+ (UIxAppointmentFormatter *)formatter;

//accessors
- (void)setFormat:(NSString *)_format;
- (NSString *)format;

- (void)setDateFormat:(NSString *)_format;
- (NSString *)dateFormat;

- (void)setOtherDayDateFormat:(NSString *)_format;
- (NSString *)otherDayDateFormat;

- (void)setOtherYearDateFormat:(NSString *)_format;
- (NSString *)otherYearDateFormat;

- (void)setToLongString:(NSString *)_toLong;
- (NSString *)toLongString;

- (void)setMoreParticipantsString:(NSString *)_more;
- (NSString *)moreParticipantsString;

- (void)setParticipantsSeparator:(NSString *)_sep;
- (NSString *)participantsSeparator;

- (void)setRelationDate:(NSCalendarDate *)_relation;
- (NSCalendarDate *)relationDate;

- (void)setShowFullNames:(BOOL)_flag;
- (BOOL)showFullNames;

// easy switches

// this resets the date format
- (void)switchToAMPMTimes:(BOOL)_showAMPM;

@end

#endif
