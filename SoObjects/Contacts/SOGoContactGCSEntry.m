/* SOGoContactGCSEntry.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2019 Inverse inc.
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
#import <Foundation/NSString.h>

#import <NGCards/NGVCardReference.h>
#import <NGCards/NGVList.h>

#import <EOControl/EOQualifier.h>

#import "NGVCard+SOGo.h"
#import "SOGoContactEntryPhoto.h"
#import "SOGoContactGCSFolder.h"
#import "SOGoContactGCSList.h"

#import "SOGoContactGCSEntry.h"

@implementation SOGoContactGCSEntry

- (id) init
{
  if ((self = [super init]))
    {
      card = nil;
    }

  return self;
}

- (void) dealloc
{
  [card release];
  [super dealloc];
}

- (Class *) parsingClass
{
  return (Class *)[NGVCard class];
}

/* content */

- (NGVCard *) vCard
{
  if (!card)
    {
      if ([[content uppercaseString] hasPrefix: @"BEGIN:VCARD"])
        card = [NGVCard parseSingleFromSource: content];
      else
        card = [NGVCard cardWithUid: [self nameInContainer]];
      [card retain];
    }

  return card;
}

- (void) setLDIFRecord: (NSDictionary *) newLDIFRecord
{
  [[self vCard] updateFromLDIFRecord: newLDIFRecord];
}

- (NSDictionary *) ldifRecord
{
  return [[self vCard] asLDIFRecord];
}

- (NSDictionary *) simplifiedLDIFRecord
{
  return [self ldifRecord];
}

- (BOOL) hasPhoto
{
  return ([[self vCard] firstChildWithTag: @"photo"] != nil);
}

/* actions */

- (id) lookupName: (NSString *) lookupName
        inContext: (id) localContext
          acquire: (BOOL) acquire
{
  id obj;

  if ([lookupName isEqualToString: @"photo"])
    {
      if ([self hasPhoto])
        obj = [SOGoContactEntryPhoto objectWithName: lookupName
                                        inContainer: self];
      else
        obj = nil;
    }
  else
    obj = [super lookupName: lookupName inContext: localContext
                    acquire: acquire];

  return obj;
}

- (NSException *) copyToFolder: (SOGoGCSFolder *) newFolder
{
  NGVCard *newCard;
  NSString *newUID;
  SOGoContactGCSEntry *newContact;

  // Change the contact UID
  newUID = [self globallyUniqueObjectId];
  newCard = [self vCard];

  [newCard setUid: newUID];

  newContact = [[self class] objectWithName:
			       [NSString stringWithFormat: @"%@.vcf", newUID]
                                inContainer: newFolder];

  return [newContact saveComponent: newCard];
}


- (NSException *) moveToFolder: (SOGoGCSFolder *) newFolder
{
  NSException *ex;

  ex = [self copyToFolder: newFolder];

  if (!ex)
    ex = [self delete];

  return ex;
}


- (NSString *) displayName
{
  return [[self vCard] fn];
}

/* DAV */

- (NSString *) davContentType
{
  return @"text/x-vcard";
}

- (NSString *) davAddressData
{
  return [self contentAsString];
}

/* specialized actions */

- (NSException *) save
{
  NSException *result;

  if (card)
    result = [super saveComponent: card];
  else
    result = nil; /* TODO: we should probably return an exception instead */

  return result;
}

- (NSException *) saveComponent: (NGVCard *) newCard
{
  ASSIGN(card, newCard);
  return [super saveComponent: newCard];
}

- (NSException *) saveComponent: (NGVCard *) newCard
                    baseVersion: (unsigned int) newVersion
{
  NSArray *lists, *references;
  NGVCardReference *reference;
  SOGoContactGCSList *list;
  EOQualifier *qualifier;
  NSException *ex;
  NGVList *vlist;

  int i, j;

  // We make sure new cards always have a UID - see #3819
  if (![[newCard uid] length])
    [newCard setUid: [self globallyUniqueObjectId]];

  ex = [super saveComponent: newCard baseVersion: newVersion];
  [card release];
  card = nil;

  // We now check if we must update lisst where this contact is present
  qualifier = [EOQualifier qualifierWithQualifierFormat: @"c_component = 'vlist'"];
  lists = [[self container] lookupContactsWithQualifier: qualifier];

  for (i = 0; i < [lists count]; i++)
    {
      list = [[self container] lookupName: [[lists objectAtIndex: i] objectForKey: @"c_name"]
                                inContext: context
                                  acquire: NO];
      vlist = [list vList];
      references = [vlist cardReferences];

      for (j = 0; j < [references count]; j++)
        {
          reference = [references objectAtIndex: j];
          if ([[self nameInContainer] isEqualToString: [reference reference]])
            {
              [reference setFn: [newCard fn]];
              [reference setEmail: [newCard preferredEMail]];
              [list save];
            }
        }
    }

  return ex;
}

@end /* SOGoContactGCSEntry */
