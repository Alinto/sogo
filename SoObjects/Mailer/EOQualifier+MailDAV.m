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

#import "EOQualifier+MailDAV.h"

@implementation EOQualifier (SOGoMailDAVExtension)

+ (NSString *) buildQualifierFromFilters: (DOMElement *) mailFilters
{
  NSMutableArray *qualifiers;
  NSString *qual, *buffer;
  id <DOMNodeList> list;
  DOMElement *current;
  NSCalendarDate *startDate, *endDate;
  int count, max;

  qualifiers = [NSMutableArray array];
  qual = nil;

  list = [mailFilters childNodes];
  if (list)
    {
      max = [list length];
      for (count = 0; count < max; count++)
        {
          current = [list objectAtIndex: count];
          if ([current nodeType] == DOM_ELEMENT_NODE)
            {
              // Received date
              if ([[current tagName] isEqualToString: @"receive-date"])
                {
                  startDate = [[current attribute: @"from"] asCalendarDate];
                  endDate = [[current attribute: @"to"] asCalendarDate];
                  if (startDate && [startDate isEqual: endDate])
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"(on = '%@')", startDate]];
                  else if (startDate)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"(since > '%@')", startDate]];
                  if (endDate)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"(before < '%@')", endDate]];
                }
              // Sent date
              else if ([[current tagName] isEqualToString: @"date"])
                {
                  startDate = [[current attribute: @"from"] asCalendarDate];
                  endDate = [[current attribute: @"to"] asCalendarDate];
                  if (startDate && [startDate isEqual: endDate])
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"(senton = '%@')", startDate]];
                  else if (startDate)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"(sentsince > '%@')", startDate]];
                  if (endDate)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"(sentbefore < '%@')", endDate]];
                }
              // Sequence
              else if ([[current tagName] isEqualToString: @"sequence"])
                {
                  //TODO
                }
              // UID
              else if ([[current tagName] isEqualToString: @"uid"])
                {
                  buffer = [current attribute: @"uid"];
                  if (buffer)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"(uid = '%@')", buffer]];
                }
              // From
              else if ([[current tagName] isEqualToString: @"from"])
                {
                  buffer = [current attribute: @"from"];
                  if (buffer)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"(from = '%@')", buffer]];
                }
              // To
              else if ([[current tagName] isEqualToString: @"to"])
                {
                  buffer = [current attribute: @"to"];
                  if (buffer)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"(to = '%@')", buffer]];
                }

            }
        }
    }

  if ([qualifiers count])
    qual = [qualifiers componentsJoinedByString: @" AND "];

  return qual;
}


+ (id) qualifierFromMailDAVMailFilters: (DOMElement *) mailFilters
{
  EOQualifier *newQualifier;
  NSString *qual;

  qual = [EOQualifier buildQualifierFromFilters: mailFilters];

  newQualifier = [EOQualifier qualifierWithQualifierFormat: qual];

  return newQualifier;
}

@end
