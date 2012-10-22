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
#import <Foundation/NSCharacterSet.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>

#import <NGCards/iCalEvent.h>
#import <NGCards/iCalEventChanges.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>

#import "SOGoAptMailNotification.h"

@interface SOGoAptMailUpdate : SOGoAptMailNotification
{
  NSMutableDictionary *changes;
  NSString *currentItem;
}

@end

@implementation SOGoAptMailUpdate

- (id) init
{
  self = [super init];

  changes = [[NSMutableDictionary alloc] init];

  return self;
}

- (void) dealloc
{
  RELEASE(currentItem);
  RELEASE(changes);
  [super dealloc];
}

- (NSString *) valueForProperty: (NSString *) property
              withDateFormatter: (SOGoDateFormatter *) _dateFormatter
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
          if ([apt isAllDay])
            value = [_dateFormatter formattedDate: value];
          else
            value = [_dateFormatter formattedDateAndTime: value];
        }
    }
  else
    value = nil;

  return value;
}

- (void) _setupBodyContentWithFormatter: (SOGoDateFormatter *) _dateFormatter
{
  NSString *property, *label, *value;
  NSArray *updatedProperties;
  int count, max;

  updatedProperties = [[iCalEventChanges changesFromEvent: previousApt
                                                  toEvent: apt]
                        updatedProperties];
  max = [updatedProperties count];
  for (count = 0; count < max; count++)
    {
      property = [updatedProperties objectAtIndex: count];
      value = [self valueForProperty: property
                   withDateFormatter: _dateFormatter];
      /* Unhandled properties will return nil */
      if (value)
        {
          label = [self labelForKey: [NSString stringWithFormat: @"%@_label",
                                               property]
                          inContext: context];
	  [changes setObject: value  forKey: label];
        }
    }
}

- (NSArray *) allChangesList
{
  return [changes allKeys];
}

- (void) setCurrentItem: (NSString *) theItem
{
  ASSIGN(currentItem, theItem);
}

- (NSString *) currentItem
{
  return currentItem;
}

- (NSString *) valueForCurrentItem
{
  return [changes objectForKey: currentItem];
}

- (NSString *) bodyStartText
{
  NSString *bodyText;

  bodyText = [self labelForKey: @"The following parameters have changed"
                   @" in the \"%{Summary}\" meeting:"
                     inContext: context];

  return [values keysWithFormat: bodyText];
}

- (void) setupValues
{
  NSCalendarDate *date;
  SOGoDateFormatter *localDateFormatter;

  [super setupValues];

  localDateFormatter = [[context activeUser] dateFormatterInContext: context];

  date = [self oldStartDate];
  [values setObject: [localDateFormatter shortFormattedDate: date]
             forKey: @"OldStartDate"];

  if (![apt isAllDay])
    [values setObject: [localDateFormatter formattedTime: date]
               forKey: @"OldStartTime"];

  [self _setupBodyContentWithFormatter: localDateFormatter];
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
  NSString *body;

  if (!values)
    [self setupValues];

  body = [[self generateResponse] contentAsString];
  
  return [body stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
