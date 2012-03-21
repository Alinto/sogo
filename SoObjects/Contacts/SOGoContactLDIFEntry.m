/* SOGoContactLDIFEntry.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
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
#import <NGCards/CardVersitRenderer.h>

#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoSource.h>
#import <SOGo/SOGoPermissions.h>

#import "NGVCard+SOGo.h"
#import "SOGoContactGCSEntry.h"
#import "SOGoContactLDIFEntry.h"
#import "SOGoContactSourceFolder.h"

@implementation SOGoContactLDIFEntry

+ (SOGoContactLDIFEntry *) contactEntryWithName: (NSString *) newName
                                  withLDIFEntry: (NSDictionary *) newEntry
                                    inContainer: (id) newContainer
{
  SOGoContactLDIFEntry *entry;

  entry = [[self alloc] initWithName: newName
                       withLDIFEntry: newEntry
                         inContainer: newContainer];
  [entry autorelease];

  return entry;
}

- (id) initWithName: (NSString *) newName
      withLDIFEntry: (NSDictionary *) newEntry
        inContainer: (id) newContainer
{
  if ((self = [self initWithName: newName inContainer: newContainer]))
    {
      ASSIGN (ldifEntry, newEntry);
      isNew = NO;
    }

  return self;
}

- (void) dealloc
{
  [ldifEntry release];
  [super dealloc];
}

- (BOOL) isNew
{
  return isNew;
}

- (void) setIsNew: (BOOL) newIsNew
{
  isNew = newIsNew;
}

- (NSString *) contentAsString
{
  return [[self vCard] versitString];
}

- (NGVCard *) vCard
{
  NGVCard *vcard;

  vcard = [NGVCard cardWithUid: [self nameInContainer]];
  [vcard setProdID: [NSString
                      stringWithFormat: @"-//Inverse inc./SOGo %@//EN",
                      SOGoVersion]];
  [vcard updateFromLDIFRecord: [self simplifiedLDIFRecord]];

  return vcard;
}

- (BOOL) isFolderish
{
  return NO;
}

- (void) setLDIFRecord: (NSDictionary *) newLDIFRecord
{
  ASSIGN (ldifEntry, newLDIFRecord);
}

- (NSDictionary *) ldifRecord
{
  return ldifEntry;
}

- (NSDictionary *) simplifiedLDIFRecord
{
  NSMutableDictionary *newRecord;
  NSArray *keys;
  NSUInteger count, max;
  NSString *key;
  id value;

  newRecord = [[self ldifRecord] mutableCopy];
  [newRecord autorelease];

  keys = [newRecord allKeys];
  max = [keys count];
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      value = [newRecord objectForKey: key];
      if ([value isKindOfClass: [NSArray class]]
          && ![key isEqualToString: @"objectclass"])
        {
          if ([value count] > 0)
            [newRecord setObject: [value objectAtIndex: 0]
                          forKey: key];
          else
            [newRecord removeObjectForKey: key];
        }
    }

  return newRecord;
}

- (BOOL) hasPhoto
{
  return NO;
}

- (NSString *) davEntityTag
{
  unsigned int hash;
//   return [ldifEntry objectForKey: @"modifyTimeStamp"];

  hash = [[self contentAsString] hash];

  return [NSString stringWithFormat: @"hash%u", hash];
}

- (NSString *) davContentType
{
  return @"text/x-vcard";
}

- (NSException *) save
{
  return [(SOGoContactSourceFolder *) container saveLDIFEntry: self];
}

- (NSException *) delete
{
  return [(SOGoContactSourceFolder *) container deleteLDIFEntry: self];
}

/* acl */

- (NSArray *) aclsForUser: (NSString *) uid
{
  NSMutableArray *acls;
  NSArray *containerAcls;

  acls = [NSMutableArray array];
  /* this is unused... */
//   ownAcls = [container aclsForUser: uid
// 		       forObjectAtPath: [self pathArrayToSOGoObject]];
//   [acls addObjectsFromArray: ownAcls];
  containerAcls = [container aclsForUser: uid];
  if ([containerAcls count] > 0)
    {
      [acls addObjectsFromArray: containerAcls];
      /* The creation of an object is actually a "modification" to an
	 unexisting object. When the object is new, we give the
	 "ObjectCreator" the "ObjectModifier" role temporarily while we
	 disallow the "ObjectModifier" users to modify them, unless they are
	 ObjectCreators too. */
      if (isNew)
	{
	  if ([containerAcls containsObject: SOGoRole_ObjectCreator])
	    [acls addObject: SOGoRole_ObjectEditor];
	  else
	    [acls removeObject: SOGoRole_ObjectEditor];
	}
    }

  return acls;
}

/* DAV */
- (NSException *) copyToFolder: (SOGoGCSFolder *) newFolder
{
  NGVCard *newCard;
  NSString *newUID;
  SOGoContactGCSEntry *newContact;

  // Change the contact UID
  newUID = [self globallyUniqueObjectId];
  newCard = [self vCard];

  [newCard setUid: newUID];

  newContact = [SOGoContactGCSEntry objectWithName:
				      [NSString stringWithFormat: @"%@.vcf", newUID]
				    inContainer: newFolder];

  return [newContact saveContentString: [newCard versitString]];
}

@end
