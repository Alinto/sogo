/* iCalXMLRenderer.m - this file is part of SOPE
 *
 * Copyright (C) 2006 Inverse inc.
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

/* This class implements most of the XML iCalendar spec as defined here:
   http://tools.ietf.org/html/rfc6321 */

#import <Foundation/NSArray.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>

#import "CardElement.h"
#import "CardGroup.h"
#import "iCalCalendar.h"
#import "iCalDateTime.h"
#import "iCalPerson.h"
#import "iCalRecurrenceRule.h"
#import "iCalUTCOffset.h"

#import "iCalXMLRenderer.h"

@interface CardElement (iCalXMLExtension)

- (NSString *) xmlRender;

@end

@interface iCalXMLRenderer (PrivateAPI)

- (NSString *) renderElement: (CardElement *) anElement;
- (NSString *) renderGroup: (CardGroup *) aGroup;

@end

@implementation iCalXMLRenderer

+ (iCalXMLRenderer *) sharedXMLRenderer
{
  static iCalXMLRenderer *sharedXMLRenderer = nil;

  if (!sharedXMLRenderer)
    sharedXMLRenderer = [self new];

  return sharedXMLRenderer;
}

- (NSString *) render: (iCalCalendar *) calendar
{
  return [NSString stringWithFormat:
                     @"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
                   @"<icalendar xmlns=\"urn:ietf:params:xml:ns:icalendar-2.0\">"
                   @"%@"
                   @"</icalendar>",
                   [calendar xmlRender]];
}

@end

@implementation CardElement (iCalXMLExtension)

- (NSString *) xmlValueTag
{
  return @"text";
}

- (NSString *) xmlParameterTag: (NSString *) paramName
{
  return nil;
}

- (void) _appendPaddingValues: (int) max
                      withTag: (NSString *) valueTag
                   intoString: (NSMutableString *) rendering    
{
  int count;

  for (count = 0; count < max; count++)
    [rendering appendFormat: @"<%@/>", valueTag];
}

- (NSString *) _xmlRenderParameter: (NSString *) paramName
{
  NSMutableString *rendering;
  NSArray *paramValues;
  NSString *lowerName, *paramTypeTag, *escapedValue;
  int count, max;

  paramValues = [attributes objectForKey: paramName];
  max = [paramValues count];
  if (max > 0)
    {
      lowerName = [paramName lowercaseString];
      rendering = [NSMutableString stringWithCapacity: 32];
      paramTypeTag = [self xmlParameterTag: [paramName lowercaseString]];
      for (count = 0; count < max; count++)
        {
          [rendering appendFormat: @"<%@>", lowerName];
          if (paramTypeTag)
            [rendering appendFormat: @"<%@>", paramTypeTag];
          escapedValue = [[paramValues objectAtIndex: count]
                           stringByEscapingXMLString];
          [rendering appendFormat: @"%@", escapedValue];
          if (paramTypeTag)
            [rendering appendFormat: @"</%@>", paramTypeTag];
          [rendering appendFormat: @"</%@>", lowerName];
        }
    }
  else
    rendering = nil;

  return rendering;
}

- (NSString *) _xmlRenderParameters
{
  NSArray *keys;
  NSMutableString *rendering;
  NSString *currentValue;
  int count, max;

  keys = [attributes allKeys];
  max = [keys count];
  if (max > 0)
    {
      rendering = [NSMutableString stringWithCapacity: 64];
      for (count = 0; count < max; count++)
        {
          currentValue
            = [self _xmlRenderParameter: [keys objectAtIndex: count]];
          if ([currentValue length] > 0)
            [rendering appendString: currentValue];
        }
    }
  else
    rendering = nil;

  return rendering;
}

- (NSString *) _xmlRenderValue
{
  NSMutableString *rendering;
  NSArray *keys, *orderedValues, *subValues;
  NSString *key, *valueTag;
  NSUInteger count, max, oCount, oMax, sCount, sMax;

#warning this code should be fix to comply better with the RFC
  rendering = [NSMutableString stringWithCapacity: 64];

  valueTag = [self xmlValueTag];

  keys = [values allKeys];
  max = [keys count];
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      orderedValues = [values objectForKey: key];
      oMax = [orderedValues count];
      for (oCount = 0; oCount < oMax; oCount++)
        {
          if ([key length] > 0)
            [rendering appendFormat: @"<%@>", [key lowercaseString]];
          else
            [rendering appendFormat: @"<%@>", valueTag];

          subValues = [orderedValues objectAtIndex: oCount];
          sMax = [subValues count];
          for (sCount = 0; sCount < sMax; sCount++)
            [rendering appendString: [[subValues objectAtIndex: sCount] stringByEscapingXMLString]];

          if ([key length] > 0)
            [rendering appendFormat: @"</%@>", [key lowercaseString]];
          else
            [rendering appendFormat: @"</%@>", valueTag];
        }
    }

  return rendering;
}

- (NSString *) xmlRender
{
  NSMutableString *rendering;
  NSString *lowerTag, *rParameters, *value;

  rParameters = [self _xmlRenderParameters];
  value = [self _xmlRenderValue];
  if ([value length])
    {
      rendering = [NSMutableString stringWithCapacity: 128];
      lowerTag = [tag lowercaseString];
      [rendering appendFormat: @"<%@>", lowerTag];
      if ([rParameters length] > 0)
        [rendering appendFormat: @"<parameters>%@</parameters>",
                   rParameters];
      [rendering appendString: value];
      [rendering appendFormat: @"</%@>", lowerTag];
    }
  else
    rendering = nil;

  return rendering;
}

@end

@implementation iCalDateTime (iCalXMLExtension)

- (NSString *) xmlValueTag
{
  return ([self isAllDay] ? @"date" : @"date-time");
}

@end

@implementation iCalPerson (iCalXMLExtension)

- (NSString *) xmlParameterTag: (NSString *) paramName
{
  NSString *paramTag;

  if ([paramName isEqualToString: @"delegated-from"]
      || [paramName isEqualToString: @"delegated-to"]
      || [paramName isEqualToString: @"sent-by"])
    paramTag = @"cal-address";
  else
    paramTag = [super xmlParameterTag: paramName];

  return paramTag;
}

- (NSString *) xmlValueTag
{
  return @"cal-address";
}

@end

// @implementation iCalRecurrenceRule (iCalXMLExtension)

// - (NSString *) _xmlRenderValue
// {
//   NSMutableString *rendering;
//   NSArray *valueParts;
//   NSString *valueTag, *currentValue;
//   int count, max;

//   max = [values count];
//   rendering = [NSMutableString stringWithCapacity: 64];
//   for (count = 0; count < max; count++)
//     {
//       currentValue = [[values objectAtIndex: count]
//                        stringByEscapingXMLString];
//       if ([currentValue length] > 0)
//         {
//           valueParts = [currentValue componentsSeparatedByString: @"="];
//           if ([valueParts count] == 2)
//             {
//               valueTag = [[valueParts objectAtIndex: 0] lowercaseString];
//               [rendering appendFormat: @"<%@>%@</%@>",
//                          valueTag,
//                          [valueParts objectAtIndex: 1],
//                          valueTag];
//             }
//         }
//     }

//   return rendering;
// }

// @end

@implementation iCalUTCOffset (iCalXMLExtension)

- (NSString *) xmlValueTag
{
  return @"utc-offset";
}

@end

@implementation CardGroup (iCalXMLExtension)

- (NSString *) xmlRender
{
  NSString *lowerTag, *childRendering;
  int count, max;
  NSMutableString *rendering;
  NSMutableArray *properties, *components;
  CardElement *currentChild;

  rendering = [NSMutableString stringWithCapacity: 4096];
  max = [children count];
  if (max > 0)
    {
      properties = [[NSMutableArray alloc] initWithCapacity: max];
      components = [[NSMutableArray alloc] initWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          currentChild = [children objectAtIndex: count];
          childRendering = [currentChild xmlRender];
          if (childRendering)
            {
              if ([currentChild isKindOfClass: [CardGroup class]])
                [components addObject: childRendering];
              else
                [properties addObject: childRendering];
            }
        }

      lowerTag = [tag lowercaseString];
      [rendering appendFormat: @"<%@>", lowerTag];
      if ([properties count] > 0)
        [rendering appendFormat: @"<properties>%@</properties>",
                   [properties componentsJoinedByString: @""]];
      if ([components count] > 0)
        [rendering appendFormat: @"<properties>%@</properties>",
                   [components componentsJoinedByString: @""]];
      [rendering appendFormat: @"</%@>", lowerTag];
    }

  return rendering;
}

@end

// - (NSString *) renderElement: (CardElement *) anElement
// {
//   NSMutableString *rendering;
//   NSDictionary *attributes;
//   NSEnumerator *keys;
//   NSArray *values, *renderedAttrs;
//   NSString *key, *finalRendering, *tag;

//   if (![anElement isVoid])
//     {
//       rendering = [NSMutableString string];
//       if ([anElement group])
//         [rendering appendFormat: @"%@.", [anElement group]];
//       tag = [anElement tag];
//       if (!(tag && [tag length]))
//         {
//           tag = @"<no-tag>";
//           [self warnWithFormat: @"card element of class '%@' has an empty tag",
//                 NSStringFromClass([anElement class])];
//         }

//       [rendering appendString: [tag uppercaseString]];
//       attributes = [anElement attributes];
//       keys = [[attributes allKeys] objectEnumerator];
//       while ((key = [keys nextObject]))
//         {
// 	  NSString *s;
// 	  int i, c;

//           renderedAttrs = [[attributes objectForKey: key] renderedForCards];
// 	  c = [renderedAttrs count];
//           if (c > 0)
//             {
//               [rendering appendFormat: @";%@=", [key uppercaseString]];

//               for (i = 0; i < c; i++)
//                 {
//                   s = [renderedAttrs objectAtIndex: i];
	      
//                   /* We MUST quote attribute values that have a ":" in them
//                      and that not already quoted */
//                   if ([s length] > 2 && [s rangeOfString: @":"].length &&
//                       [s characterAtIndex: 0] != '"' && ![s hasSuffix: @"\""])
//                     s = [NSString stringWithFormat: @"\"%@\"", s];
	      
//                   [rendering appendFormat: @"%@", s];

//                   if (i+1 < c)
//                     [rendering appendString: @","];
//                 }
//             }
//         }

//       values = [anElement values];
//       if ([values count] > 0)
//         [rendering appendFormat: @":%@",
//                    [[values renderedForCards] componentsJoinedByString: @";"]];

//       if ([rendering length] > 0)
//         [rendering appendString: @"\r\n"];

//       finalRendering = [rendering foldedForVersitCards];
//     }
//   else
//     finalRendering = @"";

//   return finalRendering;
// }

// - (NSString *) renderGroup: (CardGroup *) aGroup
// {
//   NSEnumerator *children;
//   CardElement *currentChild;
//   NSMutableString *rendering;
//   NSString *groupTag;

//   rendering = [NSMutableString string];

//   groupTag = [aGroup tag];
//   if (!(groupTag && [groupTag length]))
//     {
//       groupTag = @"<no-tag>";
//       [self warnWithFormat: @"card group of class '%@' has an empty tag",
//             NSStringFromClass([aGroup class])];
//     }

//   groupTag = [groupTag uppercaseString];
//   [rendering appendFormat: @"BEGIN:%@\r\n", groupTag];
//   children = [[aGroup children] objectEnumerator];
//   currentChild = [children nextObject];
//   while (currentChild)
//     {
//       [rendering appendString: [self render: currentChild]];
//       currentChild = [children nextObject];
//     }
//   [rendering appendFormat: @"END:%@\r\n", groupTag];

//   return rendering;
// }

// @end
