/* EOQualifier+MailDAV.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#import <Foundation/NSString.h>
#import <Foundation/NSSet.h>

#import <DOM/DOMElement.h>
#import <DOM/DOMProtocols.h>
#import <SaxObjC/XMLNamespaces.h>
#import <SOGo/DOMNode+SOGo.h>

#import <NGCards/NSString+NGCards.h>
#import <SoObjects/SOGo/NSCalendarDate+SOGo.h>

#import "EOQualifier+MailDAV.h"

@implementation EOQualifier (SOGoMailDAVExtension)

+ (EOQualifier *) buildQualifierFromFilters: (DOMElement *) mailFilters
{
  NSMutableArray *args, *formats;
  NSArray *flags, *strings, *dates;
  NSString *valueA, *valueB, *tagName, *format;
  id <DOMNodeList> list;
  DOMElement *current;
  NSCalendarDate *startDate, *endDate;
  int count, max;
  BOOL datesAreEqual;

  flags = [NSArray arrayWithObjects: @"answered", @"draft", @"flagged", 
           @"recent", @"seen", @"deleted", nil];
  strings = [NSArray arrayWithObjects: @"from", @"to", @"cc", 
             @"keywords", @"body", nil];
  dates = [NSArray arrayWithObjects: @"date", @"receive-date", nil];

  list = [mailFilters childNodes];
  if (list)
    {
      formats = [NSMutableArray array];
      args = [NSMutableArray array];
      max = [list length];
      for (count = 0; count < max; count++)
        {
          current = [list objectAtIndex: count];
          if ([current nodeType] == DOM_ELEMENT_NODE)
            {
              // Negate condition
              if ([current attribute: @"not"])
                [formats addObject: @"NOT "];

              tagName = [current tagName];

              // Dates
              if ([dates containsObject: tagName])
                {
                  startDate = [[current attribute: @"from"] asCalendarDate];
                  endDate = [[current attribute: @"to"] asCalendarDate];
                  if (startDate)
                    {
                      if (endDate && [startDate isEqual: endDate])
                        {
                          [formats addObject: [NSString stringWithFormat: 
                                               @"(%@ = %%@", tagName]];
                          datesAreEqual = YES;
                        }
                      else
                        {
                          [formats addObject: [NSString stringWithFormat: 
                                               @"(%@ > %%@", tagName]];
                          datesAreEqual = NO;
                        }
                      [args addObject: startDate];
                    }
                  if (endDate && !datesAreEqual)
                    {
                      [formats addObject: [NSString stringWithFormat: 
                                           @"(%@ < %%@", tagName]];
                      [args addObject: endDate];
                    }
                }
              // Sequence
              else if ([tagName isEqualToString: @"sequence"])
                {
                  //TODO
                }
              // UID
              else if ([tagName isEqualToString: @"uid"])
                {
                  valueA = [current attribute: @"from"];
                  valueB = [current attribute: @"to"];
                  if (!valueA)
                    valueA = @"1";
                  if (!valueB)
                    valueB = @"*";

                  [formats addObject: @"(uid = %@)"];
                  [args addObject: [NSString stringWithFormat: @"%@:%@",
                                    valueA, valueB]];
                }
              // Size
              else if ([tagName isEqualToString: @"size"])
                {
                  valueA = [current attribute: @"min"];
                  if (valueA)
                    {
                      [formats addObject: @"(size > %@)"];
                      [args addObject: valueA];
                    }
                  valueA = [current attribute: @"max"];
                  if (valueA)
                    {
                      [formats addObject: @"(size < %@)"];
                      [args addObject: valueA];
                    }
                }
              // All flags
              else if ([flags containsObject: tagName])
                {
                  [formats addObject: @"(flags doesContain: %@)"];
                  [args addObject: tagName];
                }
              // All strings
              else if ([strings containsObject: tagName])
                {
                  valueA = [current attribute: @"match"];
                  if (valueA)
                    {
                      format = [NSString stringWithFormat: 
                                @"(%@ doesContain: %%@)", tagName];
                      [formats addObject: format];
                      [args addObject: valueA];
                    }
                }
             }
        }
    }

  format = [formats componentsJoinedByString: @" AND "];
  return [EOQualifier qualifierWithQualifierFormat: format
                                         arguments: args];
}


+ (id) qualifierFromMailDAVMailFilters: (DOMElement *) mailFilters
{
  EOQualifier *newQualifier;

  newQualifier = [EOQualifier buildQualifierFromFilters: mailFilters];

  return newQualifier;
}

@end
