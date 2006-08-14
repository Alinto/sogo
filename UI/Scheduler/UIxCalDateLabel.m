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
// $Id: UIxCalDateLabel.m 619 2005-03-02 15:16:32Z znek $

#include <SOGoUI/UIxComponent.h>

@interface UIxCalDateLabel : UIxComponent
{
  NSString       *selection;
  NSCalendarDate *startDate;
  NSCalendarDate *endDate;
}

- (NSString *)dayLabel;
- (NSString *)weekLabel;
- (NSString *)monthLabel;
- (NSString *)yearLabel;

@end

#include "common.h"
#include <NGiCal/NGiCal.h>

@implementation UIxCalDateLabel

- (void)dealloc {
  [self->selection release];
  [self->startDate release];
  [self->endDate   release];
  [super dealloc];
}

/* accessors */

- (void)setSelection:(NSString *)_selection {
  ASSIGNCOPY(self->selection, _selection);
}
- (NSString *)selection {
  return self->selection;
}

- (void)setStartDate:(NSCalendarDate *)_date {
  ASSIGN(self->startDate, _date);
}
- (NSCalendarDate *)startDate {
  return self->startDate;
}

- (void)setEndDate:(NSCalendarDate *)_date {
  ASSIGN(self->endDate, _date);
}
- (NSCalendarDate *)endDate {
  return self->endDate;
}

- (NSString *)label {
  NSString *key = [self selection];
  
  if([key isEqualToString:@"day"])
    return [self dayLabel];
  if ([key isEqualToString:@"week"])
    return [self weekLabel];
  if ([key isEqualToString:@"month"])
    return [self monthLabel];
  return [self yearLabel];
}

- (NSString *)dayLabel {
  NSString *fmt;
  
  fmt = [self labelForKey:@"dayLabelFormat"];
  return [self->startDate descriptionWithCalendarFormat:fmt];
}

- (NSString *)weekLabel {
  NSString *label, *le;
  
  if ([self->startDate monthOfYear] == [self->endDate monthOfYear])
    label = [NSString stringWithFormat:@"%@ %d",
                      [self localizedNameForMonthOfYear: [self->startDate monthOfYear]],
                      [self->startDate yearOfCommonEra]];
  else
    {
      le = [self localizedNameForMonthOfYear:[self->endDate monthOfYear]];
      label = [NSString stringWithFormat:@"<nobr>%@ / %@ %d</nobr>",
                        label, le,
                        [self->endDate yearOfCommonEra]];
    }

  return label;
}

- (NSString *)monthLabel {
  NSString *l;
  unsigned diff;

  diff = [self->startDate monthsBetweenDate:self->endDate];
  if (diff == 0) {
    l = [self localizedNameForMonthOfYear:[self->startDate monthOfYear]];
  }
  else {
    NSCalendarDate *date;

    date = [self->startDate dateByAddingYears:0 months:0 days:15];
    l    = [self localizedNameForMonthOfYear:[date monthOfYear]];
  }
  return [NSString stringWithFormat:@"%@ %d",
		   l, [self->startDate yearOfCommonEra]];
}

- (NSString *)yearLabel {
  return [NSString stringWithFormat:@"%d",
		   [self->startDate yearOfCommonEra]]; 
}

@end /* UIxCalDateLabel */
