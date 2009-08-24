/* UIxListEditor.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOResponse.h>
#import <Foundation/NSPropertyList.h>

#import <Contacts/SOGoContactGCSFolder.h>
#import <NGCards/NGVCardReference.h>
#import <NGCards/NGVList.h>

#import "UIxListEditor.h"

@implementation UIxListEditor


- (NSString *) name
{
  return [list fn];
}
- (void) setName: (NSString *) newName
{
  [list setFn: newName];
}

- (NSString *) nickname
{
  return [list nickname];
}
- (void) setNickname: (NSString *) newName
{
  [list setNickname: newName];
}

- (NSString *) description
{
  return [list description];
}
- (void) setDescription: (NSString *) newDescription
{
  [list setDescription: newDescription];
}

- (NSArray *) references
{
  NSMutableArray *rc;
  NSMutableDictionary *row;
  id ref;
  int i, count;

  rc = [NSMutableArray array];
  count = [[list cardReferences] count];

  for (i = 0; i < count; i++)
    {
      ref = [[list cardReferences] objectAtIndex: i];
      row = [NSMutableDictionary dictionary];
      [row setObject: [NSString stringWithFormat: @"%@ <%@>", [ref fn], [ref email]]
              forKey: @"name"];
      [row setObject: [ref reference] forKey: @"id"];
      [rc addObject: row];
    }

  return rc;
}

- (void) setReferencesValue: (NSString *) value
{
  NSData *data;
  NSDictionary *references;
  NSArray *values, *initialReferences;
  NSString *error, *currentReference;
  NSPropertyListFormat format;
  int i, count;
  NGVCardReference *cardReference;

  data = [value dataUsingEncoding: NSUTF8StringEncoding];
  references = [NSPropertyListSerialization propertyListFromData: data
                                                mutabilityOption: NSPropertyListImmutable
                                                          format: &format
                                                errorDescription: &error];
  if(!references)
    {
      NSLog(error);
      [error release];
    }
  else
    {
      // Remove from list
      initialReferences = [list cardReferences];
      count = [initialReferences count];

      for (i = 0; i < count; i++)
        {
          cardReference = [initialReferences objectAtIndex: i];
          if (![[references allKeys] containsObject: [cardReference reference]])
            [list deleteCardReference: cardReference];
        }

      // Add new objects
      initialReferences = [list cardReferences];
      count = [[references allKeys] count];

      for (i = 0; i < count; i++)
        {
          currentReference = [[references allKeys] objectAtIndex: i];
          if (![self cardReferences: initialReferences 
                            contain: currentReference])
            {
              NSLog (@"Adding a new cardRef");
              values = [references objectForKey: currentReference];
              cardReference = [NGVCardReference elementWithTag: @"card"];
              [cardReference setFn: [values objectAtIndex: 0]];
              [cardReference setEmail: [values objectAtIndex: 1]];
              [cardReference setReference: currentReference];
              [list addCardReference: cardReference];
            }
        }
    }
}
- (BOOL) cardReferences: (NSArray *) references
                contain: (NSString *) ref
{
  int i, count;
  BOOL rc = NO;

  count = [references count];
  for (i = 0; i < count; i++)
    {
      if ([ref isEqualToString: [[references objectAtIndex: i] reference]])
        {
          rc = YES;
          break;
        }
    }

  return rc;
}

- (NSString *) saveURL
{
  return [NSString stringWithFormat: @"%@/saveAsList",
                   [[self clientObject] baseURL]];
}

- (BOOL) canCreateOrModify
{
  return ([co isKindOfClass: [SOGoContentObject class]]
          && [super canCreateOrModify]);
}

- (id <WOActionResults>) defaultAction
{
  co = [self clientObject];
  list = [co vList];
  if (list)
    NSLog (@"Found list");
  else
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
                        reason: @"could not open list"];

  return self;
}

- (void) takeValuesFromRequest: (WORequest *) _rq
                     inContext: (WOContext *) _ctx
{
  co = [self clientObject];
  list = [co vList];

  [super takeValuesFromRequest: _rq inContext: _ctx];
}

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
                           inContext: (WOContext*) context
{
  NSString *actionName;

  actionName = [[request requestHandlerPath] lastPathComponent];

  return ([[self clientObject] isKindOfClass: [SOGoContactGCSList class]]
	  && [actionName hasPrefix: @"save"]);
}



#warning Could this be part of a common parent with UIxAppointment/UIxTaskEditor/UIxListEditor ?
- (id) newAction
{
  NSString *objectId, *method, *uri;
  id <WOActionResults> result;

  co = [self clientObject];
  objectId = [co globallyUniqueObjectId];
  if ([objectId length] > 0)
    {
      method = [NSString stringWithFormat:@"%@/%@.vlf/editAsList",
                         [co soURL], objectId];
      uri = [self completeHrefForMethod: method];
      result = [self redirectToLocation: uri];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 500 /* Internal Error */
                          reason: @"could not create a unique ID"];

  return result;
}

- (id <WOActionResults>) saveAction
{
  id result;
  NSString *jsRefreshMethod;

  if (co)
    {
      [co save];
      if ([[[[self context] request] formValueForKey: @"nojs"] intValue])
                   result = [self redirectToLocation: [self applicationPath]];
      else
        {
          jsRefreshMethod
            = [NSString stringWithFormat: @"refreshContacts(\"%@\")",
            [co nameInContainer]];
          result = [self jsCloseWithRefreshMethod: jsRefreshMethod];
        }
    }
  else
    result = [NSException exceptionWithHTTPStatus: 400 /* Bad Request */
                                           reason: @"method cannot be invoked on "
                                           @"the specified object"];
  return result;
}

@end
