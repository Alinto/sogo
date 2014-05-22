/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Inverse inc. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#include "NGDOMElement+ActiveSync.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

static NSArray *asElementArray = nil;

@implementation NGDOMElement (ActiveSync)

- (BOOL) isTextNode
{
  id <DOMNodeList> children;
  id <DOMElement> element;
  int i;

  if ([self nodeType] == DOM_TEXT_NODE)
    return YES;
  
  children = [self childNodes];

  for (i = 0; i < [children length]; i++)
    {
      element = [children objectAtIndex: i];

      if ([element nodeType] != DOM_TEXT_NODE)
        return NO;
    }
  
  return YES;
}

//
// We must handle "inner data" like this:
// 
// <ApplicationData>
//  <Flag xmlns="Email:">
//   <FlagStatus>2</FlagStatus>
//   <FlagType>Flag for follow up</FlagType>
//  </Flag>
// </ApplicationData>
//
// and stuff like that:
//
// <Attendees xmlns="Calendar:">
//  <Attendee>
//   <Attendee_Email>sogo1@example.com</Attendee_Email>
//   <Attendee_Name>John Doe</Attendee_Name>
//   <Attendee_Status>5</Attendee_Status>
//   <Attendee_Type>1</Attendee_Type>
//  </Attendee>
//  <Attendee>
//   <Attendee_Email>sogo2@example.com</Attendee_Email>
//   <Attendee_Name>Balthazar César</Attendee_Name>
//   <Attendee_Status>5</Attendee_Status>
//   <Attendee_Type>1</Attendee_Type>
//  </Attendee>
//  <Attendee>
//   <Attendee_Email>sogo3@example.com</Attendee_Email>
//   <Attendee_Name>Wolfgang Fritz</Attendee_Name>
//   <Attendee_Status>5</Attendee_Status>
//   <Attendee_Type>1</Attendee_Type>
//  </Attendee>
// </Attendees>
//

- (NSDictionary *) applicationData
{
  NSMutableDictionary *data;
  id <DOMNodeList> children;
  id <DOMElement> element;
  int i, count;
  
  if (!asElementArray)
    asElementArray = [[NSArray alloc] initWithObjects: @"Attendee", @"Category", nil];

  data = [NSMutableDictionary dictionary];

  children = [self childNodes];

  for (i = 0; i < [children length]; i++)
    {
      element = [children objectAtIndex: i];

      if ([element nodeType] == DOM_ELEMENT_NODE)
        {
          NSString *tag;
          id value;
          
          tag = [element tagName];
          count = [(NSArray *)[element childNodes] count];
          
          // We check if the node is a text one or if all its
          // children are text nodes. This is important to avoid side-effects
          // in SOPE where "foo & bar" would result into 3 childnodes instead
          // of just one.
          if ([(id)element isTextNode])
            {
              value = [(id)element textValue];
            }
          // Handle inner data - see above for samples
          else
            {
              NSMutableArray *innerElements;
              id <DOMElement> innerElement;
              NSArray *childNodes;
              NSString *innerTag;
              BOOL same;
              int j;
              
              childNodes = (NSArray *)[element childNodes];
              innerElements = [NSMutableArray array];
              innerTag = nil;
              same = YES;

              for (j = 1; j < count; j++)
                {
                  innerElement = [childNodes objectAtIndex: j];

                  if ([innerElement nodeType] == DOM_ELEMENT_NODE)
                    {
                      if (!innerTag)
                        innerTag = [innerElement tagName];

                      if ([innerTag isEqualToString: [innerElement tagName]])
                        {
                          if ([(id)innerElement isTextNode])
                            [innerElements addObject: [(NGDOMElement *)innerElement textValue]];
                          else
                            [innerElements addObject: [(NGDOMElement *)innerElement applicationData]];
                        }
                      else
                        {
                          same = NO;
                          break;
                        }
                    }
                }

              if (same && [asElementArray containsObject: innerTag])
                value = innerElements;
              else
                {
                  value = [(NGDOMElement *)element applicationData];
                  
                  // Don't set empty values like Foo = {}
                  if (![value count])
                    value = nil;
                }
            }
          
          if (value && tag)
            [data setObject: value  forKey: tag];
          
        } // if ([element nodeType] == DOM_ELEMENT_NODE)
    }
  
  return data;
}

@end
