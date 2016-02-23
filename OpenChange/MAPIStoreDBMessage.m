/* MAPIStoreDBMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <SOGo/SOGoFolder.h>
#import <SOGo/SOGoUser.h>

#import "MAPIStoreContext.h"
#import "MAPIStorePropertySelectors.h"
#import "SOGoMAPIDBMessage.h"

#import "MAPIStoreDBFolder.h"
#import "MAPIStoreDBMessage.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreDBMessage

+ (enum mapistore_error) getAvailableProperties: (struct SPropTagArray **) propertiesP
                                       inMemCtx: (TALLOC_CTX *) memCtx
{
  struct SPropTagArray *properties;
  NSUInteger count;

  enum MAPITAGS faiProperties[] = {
    0x68330048, /* PR_VIEW_CLSID */
    0x68350102, /* PR_VIEW_STATE */
    0x683c0102,
    0x683d0040,
    0x683e0102,
    0x683f0102, /* PR_VIEW_VIEWTYPE_KEY */
    0x68410003,
    0x68420102,
    0x68450102,
    0x68460003,
    0x7006001F, /* PR_VD_NAME_W */
    0x70030003, /* PR_VD_FLAGS */
    0x70070003  /* PR_VD_VERSION */
  };

  size_t faiSize = sizeof(faiProperties) / sizeof(enum MAPITAGS);

  properties = talloc_zero (memCtx, struct SPropTagArray);
  properties->cValues = MAPIStoreSupportedPropertiesCount + faiSize;
  properties->aulPropTag = talloc_array (properties, enum MAPITAGS,
                                         MAPIStoreSupportedPropertiesCount + faiSize);

  for (count = 0; count < MAPIStoreSupportedPropertiesCount; count++)
    properties->aulPropTag[count] = MAPIStoreSupportedProperties[count];

  /* FIXME (hack): append a few undocumented properties that can be added to
     FAI messages */
  for (count = 0; count < faiSize; count++)
    properties->aulPropTag[MAPIStoreSupportedPropertiesCount+count]
      = faiProperties[count];

  *propertiesP = properties;

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getAvailableProperties: (struct SPropTagArray **) propertiesP
                                       inMemCtx: (TALLOC_CTX *) memCtx
{
  return [[self class] getAvailableProperties: propertiesP
                                     inMemCtx: memCtx];
}

- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newContainer
{
  if ((self = [super initWithSOGoObject: newSOGoObject
                            inContainer: newContainer]))
    {
      [properties release];
      properties = [newSOGoObject properties];
      [properties retain];
    }

  return self;
}

- (NSString *) description
{
  id key, value;
  NSEnumerator *propEnumerator;
  NSMutableString *description;

  description = [NSMutableString stringWithFormat: @"%@ %@. Properties: {", NSStringFromClass ([self class]),
                                 [self url]];

  propEnumerator = [properties keyEnumerator];
  while ((key = [propEnumerator nextObject]))
    {
      uint32_t proptag = 0;
      if ([key isKindOfClass: [NSString class]] && [(NSString *)key intValue] > 0)
        proptag = [(NSString *)key intValue];
      else if ([key isKindOfClass: [NSNumber class]])
        proptag = [key unsignedLongValue];

      if (proptag > 0)
        {
          const char *propTagName = get_proptag_name ([key unsignedLongValue]);
          NSString *propName;

          if (propTagName)
            propName = [NSString stringWithCString: propTagName
                                          encoding: NSUTF8StringEncoding];
          else
            propName = [NSString stringWithFormat: @"0x%.4x", [key unsignedLongValue]];

          [description appendFormat: @"'%@': ", propName];
        }
      else
        [description appendFormat: @"'%@': ", key];

      value = [properties objectForKey: key];
      [description appendFormat: @"%@ (%@), ", value, NSStringFromClass ([value class])];
    }

  [description appendString: @"}\n"];

  return description;
}

- (uint64_t) objectVersion
{
  /* Return the global counter from CN structure.
     See [MS-OXCFXICS] Section 2.2.2.1 */
  NSNumber *versionNbr, *cn;
  uint64_t objectVersion;

  [(SOGoMAPIDBMessage *) sogoObject reloadIfNeeded];
  versionNbr = [properties objectForKey: @"version_number"];
  if (versionNbr)
    objectVersion = exchange_globcnt ([versionNbr unsignedLongLongValue]);
  else
    {
      /* Old version which stored the CN structure not useful for searching */
      cn = [properties objectForKey: @"version"];
      if (cn)
        objectVersion = (([cn unsignedLongLongValue] >> 16)
                          & 0x0000ffffffffffffLL);
      else
        objectVersion = ULLONG_MAX;
    }

  return objectVersion;
}

- (void) _updatePredecessorChangeList
{
  BOOL updated;
  enum mapistore_error rc;
  NSData *currentChangeList, *changeKey;
  NSMutableArray *changeKeys;
  NSMutableData *newChangeList;
  NSUInteger count, len;
  struct SizedXid *changes;
  struct SPropValue property;
  struct SRow aRow;
  struct XID *currentChangeKey;
  TALLOC_CTX *localMemCtx;
  uint32_t nChanges;

  localMemCtx = talloc_new (NULL);
  if (!localMemCtx)
    {
      [self errorWithFormat: @"No more memory"];
      return;
    }

  changeKey = [self getReplicaKeyFromGlobCnt: [self objectVersion]];

  currentChangeList = [properties objectForKey: MAPIPropertyKey (PidTagPredecessorChangeList)];
  if (!currentChangeList)
    {
      /* Create a new PredecessorChangeList */
      len = [changeKey length];
      newChangeList = [NSMutableData dataWithCapacity: len + 1];
      [newChangeList appendUInt8: len];
      [newChangeList appendData: changeKey];
    }
  else
    {
      /* Update current predecessor change list with new change key */
      changes = [currentChangeList asSizedXidArrayInMemCtx: localMemCtx
                                                      with: &nChanges];

      updated = NO;
      currentChangeKey = [changeKey asXIDInMemCtx: localMemCtx];
      for (count = 0; count < nChanges && !updated; count++)
        {
          if (GUID_equal(&changes[count].XID.NameSpaceGuid, &currentChangeKey->NameSpaceGuid))
            {
              NSData *globCnt, *oldGlobCnt;
              oldGlobCnt = [NSData dataWithBytes: changes[count].XID.LocalId.data length: changes[count].XID.LocalId.length];
              globCnt = [NSData dataWithBytes: currentChangeKey->LocalId.data length: currentChangeKey->LocalId.length];
              if ([globCnt compare: oldGlobCnt] == NSOrderedDescending)
                {
                  if ([globCnt length] != [oldGlobCnt length])
                    {
                      [self errorWithFormat: @"Cannot compare globcnt with different length: %@ and %@", globCnt, oldGlobCnt];
                      abort();
                    }
                  memcpy (changes[count].XID.LocalId.data, currentChangeKey->LocalId.data, currentChangeKey->LocalId.length);
                  updated = YES;
                }
            }
        }

      /* Serialise it */
      changeKeys = [NSMutableArray array];

      if (!updated)
        [changeKeys addObject: changeKey];

      for (count = 0; count < nChanges; count++)
        {
          changeKey = [NSData dataWithXID: &changes[count].XID];
          [changeKeys addObject: changeKey];
        }

      [changeKeys sortUsingFunction: MAPIChangeKeyGUIDCompare context: localMemCtx];

      newChangeList = [NSMutableData data];
      len = [changeKeys count];
      for (count = 0; count < len; count++)
        {
          changeKey = [changeKeys objectAtIndex: count];
          [newChangeList appendUInt8: [changeKey length]];
          [newChangeList appendData: changeKey];
        }
    }

  if ([newChangeList length] > 0)
    {
      property.ulPropTag = PidTagPredecessorChangeList;
      property.value.bin = *[newChangeList asBinaryInMemCtx: localMemCtx];
      aRow.cValues = 1;
      aRow.lpProps = &property;
      rc = [self addPropertiesFromRow: &aRow];
      if (rc != MAPISTORE_SUCCESS)
          [self errorWithFormat: @"Impossible to add a new predecessor change list: %d", rc];
    }

  talloc_free (localMemCtx);
}

//
// FIXME: how this can happen?
//
// We might get there if for some reasons, all classes weren't able
// to tell us the message class.
//
- (enum mapistore_error) getPidTagMessageClass: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"IPM.Note" asUnicodeInMemCtx: memCtx];

  [self logWithFormat: @"METHOD '%s' - unable to determine message class. Falling back to IPM.Note", __FUNCTION__];

  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getProperties: (struct mapistore_property_data *) data
                              withTags: (enum MAPITAGS *) tags
                              andCount: (uint16_t) columnCount
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  [sogoObject reloadIfNeeded];

  return [super getProperties: data
                     withTags: tags
                     andCount: columnCount
                     inMemCtx: memCtx];
}

- (enum mapistore_error) getProperty: (void **) data
                             withTag: (enum MAPITAGS) propTag
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  id value;
  enum mapistore_error rc;
 
  value = [properties objectForKey: MAPIPropertyKey (propTag)];
  if (value)
    rc = [value getValue: data forTag: propTag inMemCtx: memCtx];
  else
    rc = [super getProperty: data withTag: propTag inMemCtx: memCtx];

  return rc;
}

- (void) addProperties: (NSDictionary *) newNewProperties
{
  [sogoObject reloadIfNeeded];

  [super addProperties: newNewProperties];
}

- (void) save: (TALLOC_CTX *) memCtx
{
  uint64_t newVersion;

  if ([attachmentKeys count] > 0)
    [properties setObject: attachmentParts forKey: @"attachments"];

  newVersion = [[self context] getNewChangeNumber];
  newVersion = exchange_globcnt ((newVersion >> 16) & 0x0000ffffffffffffLL);

  [properties setObject: [NSNumber numberWithUnsignedLongLong: newVersion]
                 forKey: @"version_number"];

  /* Remove old version */
  [properties removeObjectForKey: @"version"];

  /* Update PredecessorChangeList accordingly */
  [self _updatePredecessorChangeList];

  if (isNew)
    {
      NSString *lastModifierName;

      lastModifierName = (NSString *)[properties objectForKey: MAPIPropertyKey (PidTagLastModifierName)];
      if ([lastModifierName length] > 0)
        [properties setObject: lastModifierName
                       forKey: MAPIPropertyKey (PidTagCreatorName)];
    }

  // [self logWithFormat: @"Saving %@", [self description]];
  // [self logWithFormat: @"%d props in dict", [properties count]];

  [sogoObject save];
}

- (BOOL) _messageIsFreeBusy
{
  NSString *msgClass;
  
  /* This is a HACK until we figure out how to determine a message position in
     the mailbox hierarchy.... (missing: folderid and role) */
  msgClass = [properties
               objectForKey: MAPIPropertyKey (PR_MESSAGE_CLASS_UNICODE)];

  return [msgClass isEqualToString: @"IPM.Microsoft.ScheduleData.FreeBusy"];
}

//-----------------------------
// Permissions
//-----------------------------

- (BOOL) subscriberCanReadMessage
{
  return [(MAPIStoreFolder *) container subscriberCanReadMessages];
}

- (SOGoUser *) _ownerUser
{
  NSString *ownerName;
  SOGoUser *ownerUser = nil;

  ownerName = [properties objectForKey: MAPIPropertyKey (PidTagCreatorName)];
  if ([ownerName length] > 0)
    ownerUser = [SOGoUser userWithLogin: ownerName];

  return ownerUser;
}

- (NSArray *) activeUserRoles
{
  /* Override because of this exception: NSInvalidArgumentException,
     reason: [SOGoMAPIDBMessage-aclsForUser:] should be overridden by
     subclass */
  if (!activeUserRoles)
    {
      SOGoUser *activeUser;

      activeUser = [[self context] activeUser];
      activeUserRoles = [[container aclFolder] aclsForUser: [activeUser login]];
      [activeUserRoles retain];
    }

  return activeUserRoles;
}

- (BOOL) subscriberCanModifyMessage
{
  BOOL rc;
  NSArray *roles;

  roles = [self activeUserRoles];

  if (isNew)
    rc = [(MAPIStoreFolder *) container subscriberCanCreateMessages];
  else
    rc = [roles containsObject: MAPIStoreRightEditAll];

  /* Check if the message is owned and it has permission to edit it */
  if (!rc && [roles containsObject: MAPIStoreRightEditOwn])
    rc = [[[container context] activeUser] isEqual: [self _ownerUser]];

  return rc;
}

- (BOOL) subscriberCanDeleteMessage
{
  BOOL rc;
  NSArray *roles;

  roles = [self activeUserRoles];

  rc = [roles containsObject: MAPIStoreRightDeleteAll];

  /* Check if the message is owned and it has permission to delete it */
  if (!rc && [roles containsObject: MAPIStoreRightDeleteOwn])
    rc = [[[container context] activeUser] isEqual: [self _ownerUser]];

  return rc;
}

- (NSDate *) creationTime
{
  return [sogoObject creationDate];
}

- (NSDate *) lastModificationTime
{
  return [sogoObject lastModified];
}

- (enum mapistore_error) setReadFlag: (uint8_t) flag
{
  /* Modify PidTagMessageFlags from SetMessageReadFlag and
     SyncImportReadStateChanges ROPs */
  NSNumber *flags;
  uint32_t newFlag;

  flags = [properties objectForKey: MAPIPropertyKey (PR_MESSAGE_FLAGS)];
  if (flags)
    {
      newFlag = [flags unsignedLongValue];
      if (flag & SUPPRESS_RECEIPT)
        newFlag |= MSGFLAG_READ;
      if (flag & CLEAR_RN_PENDING)
        newFlag &= ~MSGFLAG_RN_PENDING;
      if (flag & CLEAR_READ_FLAG)
        newFlag &= ~MSGFLAG_READ;
      if (flag & CLEAR_NRN_PENDING)
        newFlag &= ~MSGFLAG_NRN_PENDING;
    }
  else
    {
      newFlag = MSGFLAG_READ;
      if (flag & CLEAR_READ_FLAG)
        newFlag = 0x0;
    }
  [properties setObject: [NSNumber numberWithUnsignedLong: newFlag]
                 forKey: MAPIPropertyKey (PR_MESSAGE_FLAGS)];

  return MAPISTORE_SUCCESS;
}

@end
