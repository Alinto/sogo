/*
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

#ifndef __Mailer_UIxMailFormatter_H__
#define __Mailer_UIxMailFormatter_H__

#import <Foundation/NSFormatter.h>

/*
  UIxMailFormatter
  
  Formatters which render various mail related fields.
*/

@class NSData, NSString, NSCalendarDate, NSTimeZone;

@interface UIxMailFormatter : NSFormatter
{
}

/* labels */

- (NSString *)labelForKey:(NSString *)_key;

@end

@interface UIxMailDateFormatter : UIxMailFormatter
{
  NSCalendarDate *now;
  NSTimeZone     *timeZone;
  struct {
    int showOnlyTimeForToday:1;
    int showLabelsForNearDays:1; /* 'yesterday' instead of '2004-09-31' */
    int reserved:30;
  } dfFlags;
}

/* configuration */

- (NSTimeZone *)timeZone;
- (void) setTimeZone: (NSTimeZone *) newTimeZone;

- (BOOL)showOnlyTimeForToday;
- (BOOL)showLabelsForNearDays;

@end

/*
  TODO: the subject formatter should deal with the various 're:' like prefixes
        and translate them into the native languages?
        (or something like Re(5): ?)
*/

@interface UIxSubjectFormatter : UIxMailFormatter
{
  unsigned maxLength;
}

/* configuration */

- (unsigned int)maxLength;

/* labels */

- (NSString *)missingSubjectLabel;

/* specific formatters */

- (NSString *)stringForStringValue:(NSString *)_subject;
- (NSString *)stringForDataValue:(NSData *)_subject;

@end

@interface UIxEnvelopeAddressFormatter : UIxMailFormatter
{
  NSString     *separator;
  unsigned int maxLength;
  struct {
    int fullEMail:1;
    int reserved:31;
  } eafFlags;
}

- (id)initWithMaxLength:(unsigned int)_max generateFullEMail:(BOOL)_genFull;

@end

#endif /* __Mailer_UIxMailFormatter_H__ */
