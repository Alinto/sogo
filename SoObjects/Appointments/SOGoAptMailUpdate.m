/*
  Copyright (C) 2010-2012 Inverse

  This file is part of SOGo

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSCalendarDate.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalEventChanges.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>

#import "SOGoAptMailNotification.h"

@interface SOGoAptMailUpdate : SOGoAptMailNotification
@end

@implementation SOGoAptMailUpdate

- (NSString *) valueForProperty: (NSString *) property
              withDateFormatter: (SOGoDateFormatter *) dateFormatter
{
  static NSDictionary *valueTypes = nil;
  NSString *valueType;
  id value;

  if (!valueTypes)
    {
      valueTypes = [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"date", @"startDate",
                                 @"date", @"endDate",
                                 @"date", @"due",
                                 @"text", @"location",
                                 @"text", @"summary",
                                 @"text", @"comment",
                                 nil];
      [valueTypes retain];
    }

  valueType = [valueTypes objectForKey: property];
  if (valueType)
    {
      value = [(iCalEvent *) apt propertyValue: property];
      if ([valueType isEqualToString: @"date"])
        {
          [value setTimeZone: viewTZ];
          value = [dateFormatter formattedDateAndTime: value];
        }
    }
  else
    value = nil;

  return value;
}

- (void) _setupBodyContentWithFormatter: (SOGoDateFormatter *) dateFormatter
{
  NSArray *updatedProperties;
  NSMutableString *bodyContent;
  NSString *property, *label, *value;
  int count, max;

  updatedProperties = [[iCalEventChanges changesFromEvent: previousApt
                                                  toEvent: apt]
                        updatedProperties];
  bodyContent = [NSMutableString new];
  max = [updatedProperties count];
  for (count = 0; count < max; count++)
    {
      property = [updatedProperties objectAtIndex: count];
      value = [self valueForProperty: property
                   withDateFormatter: dateFormatter];
      /* Unhandled properties will return nil */
      if (value)
        {
          label = [self labelForKey: [NSString stringWithFormat: @"%@_label",
                                               property]
                          inContext: context];
          [bodyContent appendFormat: @"  %@ %@\n", label, value];
        }
    }
  [values setObject: bodyContent forKey: @"_bodyContent"];
  [bodyContent release];
}

- (void) _setupBodyValuesWithFormatter: (SOGoDateFormatter *) dateFormatter
{
  NSString *bodyText;

  bodyText = [self labelForKey: @"The following parameters have changed"
                   @" in the \"%{Summary}\" meeting:"
                     inContext: context];
  [values setObject: [values keysWithFormat: bodyText]
             forKey: @"_bodyStart"];
  [self _setupBodyContentWithFormatter: dateFormatter];
  [values setObject: [self labelForKey: @"Please accept"
                           @" or decline those changes."
                             inContext: context]
             forKey: @"_bodyEnd"];
}

- (void) setupValues
{
  NSCalendarDate *date;
  SOGoDateFormatter *dateFormatter;

  [super setupValues];

  dateFormatter = [[context activeUser] dateFormatterInContext: context];

  date = [self oldStartDate];
  [values setObject: [dateFormatter shortFormattedDate: date]
             forKey: @"OldStartDate"];

  if (![apt isAllDay])
    [values setObject: [dateFormatter formattedTime: date]
               forKey: @"OldStartTime"];

  [self _setupBodyValuesWithFormatter: dateFormatter];
}

- (NSString *) getSubject
{
  NSString *subjectFormat;

  if (!values)
    [self setupValues];

  if ([values objectForKey: @"OldStartTime"])
    subjectFormat = [self labelForKey: (@"The appointment \"%{Summary}\" for the"
                                        @" %{OldStartDate} at"
                                        @" %{OldStartTime} has changed")
                            inContext: context];
  else
    subjectFormat = [self labelForKey: (@"The appointment \"%{Summary}\" for the"
                                        @" %{OldStartDate}"
                                        @" has changed")
                            inContext: context];

  return [values keysWithFormat: subjectFormat];
}

- (NSString *) getBody
{
  if (!values)
    [self setupValues];

  return [values keysWithFormat:
                   @"%{_bodyStart}\n%{_bodyContent}\n%{_bodyEnd}\n"];
}

@end
