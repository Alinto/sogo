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

+ (id) qualifierFromMailDAVMailFilters: (id <DOMElement>) mailFilters
{
  EOQualifier *qualifier;
  NSMutableArray *args, *formats;
  NSArray *flags, *strings, *dates;
  NSString *valueA, *valueB, *tagName, *format, *negate;
  id <DOMNodeList> list;
  id <DOMElement> current;
  NSCalendarDate *startDate, *endDate;
  int count, max;
  BOOL datesAreEqual;

  flags = [NSArray arrayWithObjects: @"answered", @"draft", @"flagged", 
           @"recent", @"seen", @"deleted", nil];
  strings = [NSArray arrayWithObjects: @"from", @"to", @"cc", 
             @"keywords", @"body", nil];
  dates = [NSArray arrayWithObjects: @"date", @"receive-date", nil];

  formats = nil;
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
                negate = [NSMutableString stringWithString: @"NOT "];
              else
                negate = [NSMutableString string];

              tagName = [current tagName];

              // Dates
              if ([dates containsObject: tagName])
                {
                  startDate = [[current attribute: @"from"] asCalendarDate];
                  endDate = [[current attribute: @"to"] asCalendarDate];
                  datesAreEqual = NO;
                  if (startDate)
                    {
                      if (endDate && [startDate isEqual: endDate])
                        {
                          [formats addObject: [NSString stringWithFormat: 
                                               @"%@%@ = %%@", negate, tagName]];
                          datesAreEqual = YES;
                        }
                      else
                        {
                          [formats addObject: [NSString stringWithFormat: 
                                               @"%@%@ > %%@", negate, tagName]];
                        }
                      [args addObject: startDate];
                    }
                  if (endDate && !datesAreEqual)
                    {
                      [formats addObject: [NSString stringWithFormat: 
                                           @"%@%@ < %%@", negate, tagName]];
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

                  [formats addObject: [NSString stringWithFormat: 
                                       @"%@uid = %%@", negate]];
                  [args addObject: [NSString stringWithFormat: @"%@:%@",
                                    valueA, valueB]];
                }
              // Size
              else if ([tagName isEqualToString: @"size"])
                {
                  valueA = [current attribute: @"min"];
                  if (valueA)
                    {
                      [formats addObject: [NSString stringWithFormat: 
                                           @"%@size > %%@", negate]];
                      [args addObject: valueA];
                    }
                  valueA = [current attribute: @"max"];
                  if (valueA)
                    {
                      [formats addObject: [NSString stringWithFormat: 
                                           @"%@size < %%@", negate]];
                      [args addObject: valueA];
                    }
                }
              // All flags
              else if ([flags containsObject: tagName])
                {
                  [formats addObject: [NSString stringWithFormat: 
                                       @"%@flags doesContain: %%@", negate]];
                  [args addObject: tagName];
                }
              // All strings
              else if ([strings containsObject: tagName])
                {
                  valueA = [current attribute: @"match"];
                  if (valueA)
                    {
                      format = [NSString stringWithFormat: 
                                @"%@%@ doesContain: %%@", negate, tagName];
                      [formats addObject: format];
                      [args addObject: valueA];
                    }
                }
             }
        }
    }

  if (formats)
    {
      format = [formats componentsJoinedByString: @" AND "];
      qualifier = [EOQualifier qualifierWithQualifierFormat: format
                                                  arguments: args];
    }
  else
    qualifier = nil;

  return qualifier;
}

@end
