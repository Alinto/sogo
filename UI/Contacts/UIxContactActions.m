/* UIxContactActions.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WODirectAction.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGCards/NGVCard.h>

#import <Contacts/SOGoContactGCSEntry.h>

#import <Common/WODirectAction+SOGo.h>

@interface NGVCard (SOGoActionCategory)

- (BOOL) addOrRemove: (BOOL) set
            category: (NSString *) newCategory;

@end

@implementation NGVCard (SOGoActionCategory)

- (BOOL) addOrRemove: (BOOL) set
            category: (NSString *) category
{
  NSMutableArray *categories;
  BOOL modified;
  NSUInteger idx;

  modified = NO;

  categories = [[self categories] mutableCopy];
  [categories autorelease];
  if (!categories)
    categories = [NSMutableArray array];
  if (set)
    {
      if (![categories containsObject: category])
        {
          [categories addObject: category];
          modified = YES;
        }
    }
  else
    {
      idx = [categories indexOfObject: category];
      if (idx != NSNotFound)
        {
          [categories removeObjectAtIndex: idx];
          modified = YES;
        }
    }

  if (modified)
    [self setCategories: categories];

  return modified;
}

@end

@interface UIxContactActions : WODirectAction

- (WOResponse *) setCategoryAction;
- (WOResponse *) unsetCategoryAction;

@end

@implementation UIxContactActions

- (WOResponse *) _setOrUnsetCategoryAction: (BOOL) set
{
  SOGoContactGCSEntry *contact;
  NSString *category;
  WORequest *rq;
  WOResponse *response;
  NGVCard *card;

  rq = [context request];
  category = [rq formValueForKey: @"category"];
  if ([category length] > 0)
    {
      contact = [self clientObject];
      if (![contact isNew])
        {
          card = [contact vCard];
          if ([card addOrRemove: set category: category])
            [contact save];
          response = [self responseWith204];
        }
      else
        response = [self responseWithStatus: 404
                                  andString: @"Contact does not exist"];
    }
  else
    response = [self responseWithStatus: 403
                              andString: @"Missing 'category' parameter"];

  return response;
}

- (WOResponse *) setCategoryAction
{
  return [self _setOrUnsetCategoryAction: YES];
}

- (WOResponse *) unsetCategoryAction
{
  return [self _setOrUnsetCategoryAction: NO];
}

// returns the raw content of the object
- (WOResponse *) rawAction
{
  NSMutableString *content;
  WOResponse *response;

  content = [NSMutableString string];
  response = [context response];

  [content appendFormat: [[self clientObject] contentAsString]];
  [response setHeader: @"text/plain; charset=utf-8" 
            forKey: @"content-type"];
  [response appendContentString: content];

  return response;
}

@end
