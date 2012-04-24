/* SOGoContactGCSEntry.h - this file is part of SOGo
 *
 * Copyright (C) 2006-2012 Inverse inc.
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGCards/NGVCard.h>
#import <NGCards/NGVCardPhoto.h>

#import "NGVCard+SOGo.h"
#import "SOGoContactEntryPhoto.h"

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

  return [newContact saveContentString: [newCard versitString]];
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
    result = [self saveContentString: [card versitString]];
  else
    result = nil; /* TODO: we should probably return an exception instead */

  return result;
}

- (NSException *) saveContentString: (NSString *) newContent
                        baseVersion: (unsigned int) newVersion
{
  NSException *ex;

  ex = [super saveContentString: newContent baseVersion: newVersion];
  [card release];
  card = nil;

  return ex;
}

@end /* SOGoContactGCSEntry */
