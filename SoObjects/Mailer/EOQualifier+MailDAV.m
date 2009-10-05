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

+ (NSString *) buildQualifierFromFilters: (DOMElement *) mailFilters
{
  NSMutableArray *qualifiers;
  NSString *qual, *buffer;
  id <DOMNodeList> list;
  DOMElement *current;
  NSCalendarDate *startDate, *endDate;
  int count, max, intValue;
  NSString *negate;

  qualifiers = [NSMutableArray array];
  qual = nil;

#warning Qualifiers may be invalid, need to be tested

  list = [mailFilters childNodes];
  if (list)
    {
      max = [list length];
      for (count = 0; count < max; count++)
        {
          current = [list objectAtIndex: count];
          if ([current nodeType] == DOM_ELEMENT_NODE)
            {
              // Negate condition
              if ([current attribute: @"not"])
                negate = @"NOT ";
              else
                negate = @"";

              // Received date
              if ([[current tagName] isEqualToString: @"receive-date"])
                {
                  startDate = [[current attribute: @"from"] asCalendarDate];
                  endDate = [[current attribute: @"to"] asCalendarDate];
                  if (startDate && [startDate isEqual: endDate])
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"%@(on = '%@')", 
                      negate, [startDate rfc822DateString]]];
                  else if (startDate)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"%@(since > '%@')", 
                      negate, [startDate rfc822DateString]]];
                  if (endDate)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"%@(before < '%@')", 
                      negate, [endDate rfc822DateString]]];
                }
              // Sent date
              else if ([[current tagName] isEqualToString: @"date"])
                {
                  startDate = [[current attribute: @"from"] asCalendarDate];
                  endDate = [[current attribute: @"to"] asCalendarDate];
                  if (startDate && [startDate isEqual: endDate])
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"%@(senton = '%@')", 
                      negate, [startDate rfc822DateString]]];
                  else if (startDate)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"%@(sentsince > '%@')", 
                      negate, [startDate rfc822DateString]]];
                  if (endDate)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"%@(sentbefore < '%@')", 
                      negate, [endDate rfc822DateString]]];
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
                     [NSString stringWithFormat: @"%@(uid = '%@')", 
                      negate, buffer]];
                }
              // From
              else if ([[current tagName] isEqualToString: @"from"])
                {
                  buffer = [current attribute: @"from"];
                  if (buffer)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"%@(from doesContain: '%@')",
                      negate, buffer]];
                }
              // To
              else if ([[current tagName] isEqualToString: @"to"])
                {
                  buffer = [current attribute: @"to"];
                  if (buffer)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"%@(to doesContain: '%@')", 
                      negate, buffer]];
                }
              // Size
              else if ([[current tagName] isEqualToString: @"size"])
                {
                  intValue = [[current attribute: @"min"] intValue];
                  [qualifiers addObject: 
                   [NSString stringWithFormat: @"%@(larger > '%d')", 
                    negate, intValue]];
                  intValue = [[current attribute: @"max"] intValue];
                  if (intValue)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"%@(smaller < '%d')", 
                      negate, intValue]];
                }
              // Answered
              else if ([[current tagName] isEqualToString: @"answered"])
                {
                  intValue = [[current attribute: @"answered"] intValue];
                  if (intValue)
                    [qualifiers addObject: [NSString stringWithFormat: 
                      @"%@(answered)", negate]];
                  intValue = [[current attribute: @"unanswered"] intValue];
                  if (intValue)
                    [qualifiers addObject: [NSString stringWithFormat: 
                      @"%@(unanswered)", negate]];
                }
              // Draft
              else if ([[current tagName] isEqualToString: @"draft"])
                {
                  intValue = [[current attribute: @"draft"] intValue];
                  if (intValue)
                    [qualifiers addObject: [NSString stringWithFormat: 
                      @"%@(draft)", negate]];
                }
              // Flagged
              else if ([[current tagName] isEqualToString: @"flagged"])
                {
                  intValue = [[current attribute: @"flagged"] intValue];
                  if (intValue)
                    [qualifiers addObject: [NSString stringWithFormat: 
                      @"%@(flagged)", negate]];
                }
              // Recent
              else if ([[current tagName] isEqualToString: @"recent"])
                {
                  intValue = [[current attribute: @"recent"] intValue];
                  if (intValue)
                    [qualifiers addObject: [NSString stringWithFormat: 
                      @"%@(recent)", negate]];
                }
              // Seen
              else if ([[current tagName] isEqualToString: @"seen"])
                {
                  intValue = [[current attribute: @"seen"] intValue];
                  if (intValue)
                    [qualifiers addObject: [NSString stringWithFormat: 
                      @"%@(seen)", negate]];
                }
              // Deleted
              else if ([[current tagName] isEqualToString: @"deleted"])
                {
                  intValue = [[current attribute: @"deleted"] intValue];
                  if (intValue)
                    [qualifiers addObject: [NSString stringWithFormat: 
                      @"%@(deleted)", negate]];
                }
              // Keywords
              else if ([[current tagName] isEqualToString: @"keywords"])
                {
                  buffer = [current attribute: @"keywords"];
                  if (buffer)
                    [qualifiers addObject: 
                     [NSString stringWithFormat: @"%@(keywords doesContain: '%@')", 
                      negate, buffer]];
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
