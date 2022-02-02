/* UIxListView.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2014 Inverse inc.
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

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOResponse.h>
#import <NGCards/NGVList.h>
#import <NGCards/NGVCardReference.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>

#import "UIxListView.h"

@implementation UIxListView

- (void) checkListReferences
{
  NSMutableArray *invalid;
  NGVCardReference *card, *cardCopy;
  int i, count;
  id test;

  invalid = [NSMutableArray array];

  count = [[list cardReferences] count];
  for (i = 0; i < count; i++)
    {
      card = [[list cardReferences] objectAtIndex: i];
      test = [[co container] lookupName: [card reference] 
                              inContext: context
                                acquire: NO];
      if ([test isKindOfClass: [NSException class]])
        {
          //NSLog (@"%@ not found", [card reference]);
          cardCopy = [card copy];
          [invalid addObject: cardCopy];
          [cardCopy release];
        }
    }

  count = [invalid count];
  if (count > 0)
    {
      for (i = 0; i < count; i++)
        [list deleteCardReference: [invalid objectAtIndex: i]];
      [co save];
    }
}

- (id <WOActionResults>) defaultAction
{
  id rc;

  co = [self clientObject];
  list = [co vList];

  if (list)
    {
      [self checkListReferences];
      rc = self;
    }
  else
    rc = [NSException exceptionWithHTTPStatus: 404 /* Not Found */
                                       reason: @"could not locate contact"];

  return rc;
}

- (id <WOActionResults>) dataAction
{
  id <WOActionResults> result;
  NSMutableDictionary *data;
  NSMutableArray *cards;
  NGVCardReference *card;
  int i, count;

  co = [self clientObject];
  list = [co vList];

  if (list)
    {
      [self checkListReferences];
    }
  else
    return [NSException exceptionWithHTTPStatus: 404 /* Not Found */
                                       reason: @"could not locate contact"];

  count = [[list cardReferences] count];
  cards = [NSMutableArray arrayWithCapacity: count];
  for (i = 0; i < count; i++)
    {
      card = [[list cardReferences] objectAtIndex: i];
      [cards addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                        [card reference], @"reference",
                                        [card fn], @"c_cn",
                                      [card email], @"email",
                                      nil]];
    }

  data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                [[co container] nameInContainer], @"pid",
                              [co nameInContainer], @"id",
                              [[list tag] lowercaseString], @"c_component",
                              [list fn], @"c_cn",
                              [list nickname], @"nickname",
                              [list description], @"description",
                              cards, @"refs",
                              nil];

  result = [self responseWithStatus: 200
                          andString: [data jsonRepresentation]];
  
  return result;  
}

- (WOResponse *) propertiesAction
{
  NSArray *references;
  NSMutableArray *data;
  NGVCardReference *card;
  int count, max;

  list = [[self clientObject] vList];
  references = [list cardReferences];
  max = [references count];
  data = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      card = [references objectAtIndex: count];
      [data addObject: [NSArray arrayWithObjects: [card reference],
                                [card fn], [card email], nil]];
    }

  return [self responseWithStatus: 200 andJSONRepresentation: data];
}

@end
