/* UIxListEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2015 Inverse inc.
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


#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOResponse.h>

#import <NGCards/NGVCardReference.h>
#import <NGCards/NGVList.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>

#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactGCSFolder.h>

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
                      [newContact saveComponent: newCard];

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

- (void) setReferences: (NSArray *) references
{
  NSDictionary *values;
  NSArray *initialReferences, *emails;
  NSDictionary *currentReference;
  NSString *uid, *workMail, *fn, *newUID;
  int i, count;
  NGVCardReference *cardReference;
  SOGoContactGCSFolder *folder;

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

  // TODO: update existing cards?

  // Add new cards
  count = [references count];

  for (i = 0; i < count; i++)
    {
      if ([[references objectAtIndex: i] isKindOfClass: [NSDictionary class]])
        {
          currentReference = [references objectAtIndex: i];
          uid = [currentReference objectForKey: @"id"];
          if (![self cardReferences: [list cardReferences]
                            contain: uid])
            {
              // Search contact by vCard UID
	      values = [folder lookupContactWithName: uid];
	      if (values)
		{
                  emails = [[values objectForKey: @"c_mail"] componentsSeparatedByString: @","];
		  cardReference = [NGVCardReference elementWithTag: @"card"];
		  [cardReference setFn: [values objectForKey: @"c_cn"]];
                  if ([emails count])
                    [cardReference setEmail: [emails objectAtIndex: 0]];
		  [cardReference setReference: uid];

		  [list addCardReference: cardReference];
		}
              else
                {
                  // Invalid UID or no UID
                  NGVCard *newCard;
                  CardElement *newWorkMail;
                  SOGoContactGCSEntry *newContact;

                  workMail = [currentReference objectForKey: @"email"];
                  fn = [currentReference objectForKey: @"c_cn"];

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
                  [newContact saveComponent: newCard];

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

- (BOOL) cardReferences: (NSArray *) references
                contain: (NSString *) reference
{
  int i, count;
  BOOL rc = NO;

  if (reference)
    {
      count = [references count];
      for (i = 0; i < count; i++)
        {
          if ([reference isEqualToString: [[references objectAtIndex: i] reference]])
            {
              rc = YES;
              break;
            }
        }
    }

  return rc;
}

/**
 *
 */
- (void) setAttributes: (NSDictionary *) attributes
{
  [list setNickname: [attributes objectForKey: @"nickname"]];
  [list setFn: [attributes objectForKey: @"c_cn"]];
  [list setDescription: [attributes objectForKey: @"description"]];
}

- (BOOL) canCreateOrModify
{
  return ([co isKindOfClass: [SOGoContentObject class]]
          && [super canCreateOrModify]);
}

- (id <WOActionResults>) saveAction
{
  WORequest *request;
  WOResponse *response;
  NSDictionary *params, *data;
  id o;

  co = [self clientObject];
  list = [co vList];
  [list retain];

  request = [context request];
  params = [[request contentAsString] objectFromJSONString];

  o = [params objectForKey: @"refs"];
  if (![o isKindOfClass: [NSArray class]])
    o = nil;
  [self setReferences: (NSArray *) o];
  [self setAttributes: params];
  [co save];

  // Return list UID and addressbook ID in a JSON payload
  data = [NSDictionary dictionaryWithObjectsAndKeys:
                         [[co container] nameInContainer], @"pid",
                         [co nameInContainer], @"id",
                         nil];
  response = [self responseWithStatus: 200
                            andString: [data jsonRepresentation]];

  return response;
}

@end
