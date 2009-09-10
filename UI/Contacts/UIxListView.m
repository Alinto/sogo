/* UIxListView.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse inc.
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

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOResponse.h>
#import <NGCards/NGVList.h>
#import <NGCards/NGVCard.h>
#import <NGCards/NGVCardReference.h>

#import "UIxListView.h"

@implementation UIxListView


- (NSString *) listName
{
  return [list fn];
}

- (BOOL) hasNickname
{
  return [list nickname] != nil;
}
- (NSString *) listNickname
{
  return [list nickname];
}

- (BOOL) hasDescription
{
  return [list description] != nil;
}
- (NSString *) listDescription
{
  return [list description];
}

- (NSArray *) components
{
  return [list cardReferences];
}
- (NSString *) itemText
{
  NSString *rc;

  rc = [NSString stringWithFormat: @"%@ <%@>", 
     [item fn], [item email]];

  return rc;
}

- (void) checkListReferences
{
  NSMutableArray *invalid;
  NGVCardReference *card;
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
          NSLog (@"%@ not found", [card reference]);
          [invalid addObject: [card copy]];
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

- (WOResponse *) propertiesAction
{
  NSMutableArray *data;
  NGVCardReference *card;
  WOResponse *rc;
  int i, count;

  data = [NSMutableArray array];
  co = [self clientObject];
  list = [co vList];

  count = [[list cardReferences] count];
  for (i = 0; i < count; i++)
    {
      card = [[list cardReferences] objectAtIndex: i];
      [data addObject: [NSArray arrayWithObjects: [card reference], [card fn], 
        [card email], nil]];
    }

  rc = [context response];
  [rc setHeader: @"text/plain; charset=utf-8"
         forKey: @"content-type"];
  [rc appendContentString: [data jsonRepresentation]];

  return rc;
}

@end
