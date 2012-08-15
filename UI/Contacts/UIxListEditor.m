/* UIxListEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2012 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOResponse.h>

#import <NGCards/NGVCardReference.h>
#import <NGCards/NGVList.h>

#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactGCSFolder.h>
#import <Contacts/SOGoContactGCSList.h>

#import "UIxListEditor.h"

@implementation UIxListEditor

- (void) dealloc
{
  [list release];
  [super dealloc];
}

- (id <WOActionResults>) defaultAction
{
  co = [self clientObject];
  list = [co vList];
  [list retain];

  return self;
}

- (NSString *) listName
{
  return [list fn];
}

- (void) setListName: (NSString *) newName
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
  NSArray *references;
  NSMutableArray *referenceDicts;
  NSMutableDictionary *row;
  NGVCardReference *ref;
  NSString *name, *email;
  int count, max;

  references = [list cardReferences];
  max = [references count];
  referenceDicts = [NSMutableArray arrayWithCapacity: max];

  for (count = 0; count < max; count++)
    {
      ref = [references objectAtIndex: count];
      row = [NSMutableDictionary new];
      email = [ref email];
      if ([email length] > 0)
        name = [NSString stringWithFormat: @"%@ <%@>", [ref fn], email];
      else
        name = [ref fn];
      [row setObject: name forKey: @"name"];
      [row setObject: [ref reference] forKey: @"id"];
      [referenceDicts addObject: row];
      [row release];
    }

  return referenceDicts;
}

- (void) setReferencesValue: (NSString *) value
{
  NSDictionary *values;
  NSArray *references, *initialReferences;
  NSString *currentReference;
  int i, count;
  NGVCardReference *cardReference;
  SOGoContactGCSFolder *folder;
  
  references = [value componentsSeparatedByString: @","];
  if ([references count])
    {
      folder = [co container];

      // Remove from the list the cards that were deleted
      initialReferences = [list cardReferences];
      count = [initialReferences count];

      for (i = 0; i < count; i++)
        {
          cardReference = [initialReferences objectAtIndex: i];
          if (![references containsObject: [cardReference reference]])
            [list deleteCardReference: cardReference];
        }

      // Add new cards
      count = [references count];
      
      for (i = 0; i < count; i++)
        {
          currentReference = [references objectAtIndex: i];
          if (![self cardReferences: [list cardReferences] 
                            contain: currentReference])
            {
              // Search contact by vCard UID
	      values = [folder lookupContactWithName: currentReference];
	      if (values)
		{
		  cardReference = [NGVCardReference elementWithTag: @"card"];
		  [cardReference setFn: [values objectForKey: @"c_cn"]];
		  [cardReference setEmail: [values objectForKey: @"c_mail"]];
		  [cardReference setReference: currentReference];
		  
		  [list addCardReference: cardReference];
		}
              else
                {
                  // Not a valid UID; expect a string formatted as :  "email|fullname"
                  NSString *workMail, *fn, *newUID;
                  NSArray *contactInfo;
                  NGVCard *newCard;
                  CardElement *newWorkMail;
                  SOGoContactGCSEntry *newContact;
                  
                  contactInfo = [currentReference componentsSeparatedByString: @"|"];
                  if ([contactInfo count] > 1)
                    {
                      workMail = [contactInfo objectAtIndex: 0];
                      fn = [contactInfo objectAtIndex: 1];

                      // Create a new vCard
                      newUID = [NSString stringWithFormat: @"%@.vcf", [co globallyUniqueObjectId]];
                      newCard = [NGVCard cardWithUid: newUID];
                      newWorkMail = [CardElement new];
                      [newWorkMail autorelease];
                      [newWorkMail setTag: @"email"];
                      [newWorkMail addType: @"work"];
                      [newCard addChild: newWorkMail];
                      [newWorkMail setSingleValue: workMail forKey: @""];
                      [newCard setFn: fn];

                      // Add vCard to current folder
                      newContact = [SOGoContactGCSEntry objectWithName: newUID
                                                           inContainer: folder];
                      [newContact saveContentString: [newCard versitString]];

                      // Create card reference for the list
                      cardReference = [NGVCardReference elementWithTag: @"card"];
                      [cardReference setFn: fn];
                      [cardReference setEmail: workMail];
                      [cardReference setReference: newUID];
                      
                      [list addCardReference: cardReference];
                    }
                }
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
               [co baseURLInContext: context]];
}

- (BOOL) canCreateOrModify
{
  return ([co isKindOfClass: [SOGoContentObject class]]
          && [super canCreateOrModify]);
}

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
                           inContext: (WOContext*) context
{
  NSString *actionName;
  BOOL rc;

  co = [self clientObject];
  actionName = [[request requestHandlerPath] lastPathComponent];
  if ([co isKindOfClass: [SOGoContactGCSList class]]
      && [actionName hasPrefix: @"save"])
    {
      list = [co vList];
      [list retain];
      rc = YES;
    }
  else
    rc = NO;

  return rc;
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
        result = [self redirectToLocation: [self modulePath]];
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
