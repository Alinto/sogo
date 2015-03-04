/* MAPIStoreSharingMessage.m - this file is part of SOGo-OpenChange
 *
 * Copyright (C) 2015 Enrique J. Hernández
 *
 * Author: Enrique J. Hernández <ejhernandez@zentyal.com>
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

#include <talloc.h>

#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>

#import <NGExtensions/NGBase64Coding.h>

#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSDate+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "NSValue+MAPIStore.h"

#import "MAPIStoreSharingMessage.h"

#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreSharingMessage

- (id) init
{
  if ((self = [super init]))
    {
      connInfo = NULL;
      properties = nil;
    }

  return self;
}

- (id) initWithMailHeaders: (NSDictionary *) mailHeaders
         andConnectionInfo: (struct mapistore_connection_info *) newConnInfo
{
  NSEnumerator *enumerator;
  NSString *key;

  if ((self = [self init]))
    {
      connInfo = newConnInfo;
      enumerator = [mailHeaders keyEnumerator];
      properties = [NSMutableDictionary new];
      while ((key = [enumerator nextObject]))
        {
          if ([key hasPrefix: @"x-ms-sharing-"])
            [properties setObject: [mailHeaders objectForKey: key]
                           forKey: key];
        }
    }

  return self;
}

- (void) dealloc
{
  [properties release];
  [super dealloc];
}

- (enum mapistore_error) _getStringProperty: (NSString *) propertyName
                                     inData: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  id value;

  value = [properties objectForKey: propertyName];
  if (value)
    {
      *data = [value asUnicodeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }

  return rc;

}

- (int) getPidLidSharingCapabilities: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{

  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  id value;

  value = [properties objectForKey: @"x-ms-sharing-capabilities"];
  if (value)
    {
      *data = MAPILongValue (memCtx, [value intValue]);
      rc = MAPISTORE_SUCCESS;
    }

  return rc;
}

- (int) getPidNameXSharingCapabilities: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{

  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  id value;

  value = [properties objectForKey: @"x-ms-sharing-capabilities"];
  if (value)
    {
      *data = [[value stringValue] asUnicodeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }

  return rc;
}

- (int) getPidLidSharingConfigurationUrl: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{

  *data = [@"" asUnicodeInMemCtx: memCtx];
  return MAPISTORE_SUCCESS;
}

- (int) getPidNameXSharingConfigUrl: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingConfigurationUrl: data inMemCtx: memCtx];
}

- (int) getPidLidSharingFlavor: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  /* See [MS-OXSHARE] Section 2.2.2.5 for details */
  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  id value, auxValue;

  value = [properties objectForKey: @"x-ms-sharing-flavor"];
  if (value)
    {
      *data = MAPILongValue (memCtx, [value intValue]);
      rc = MAPISTORE_SUCCESS;
    }
  else
    {
      /* Guess its value required by old clients based on other properties */
      value = [properties objectForKey: @"x-ms-sharing-capabilities"];
      if (value)
        {
          if ([value intValue] == 0x40290)  /* Special folder */
            {
              value = [properties objectForKey: @"x-ms-sharing-responsetime"];
              auxValue = [properties objectForKey: @"x-ms-sharing-remotename"];
              if (value)  /* A sharing request */
                {
                  if (auxValue)
                    *data = MAPILongValue (memCtx, 0x20710);
                  else
                    *data = MAPILongValue (memCtx, 0x20500);
                }
              else
                {
                  if (auxValue)  /* It SHOULD be an invitation or response acceptance */
                    *data = MAPILongValue (memCtx, 0x20310);
                  else
                    *data = MAPILongValue (memCtx, 0x23310);
                }
            }
          else
            {
              *data = MAPILongValue (memCtx, 0x310);
            }
          rc = MAPISTORE_SUCCESS;
        }
    }

  return rc;
}

- (int) getPidNameXSharingFlavor: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  id value;

  value = [properties objectForKey: @"x-ms-sharing-flavor"];
  if (value)
    {
      *data = [[value stringValue] asUnicodeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }

  return rc;
}

- (int) getPidLidSharingInitiatorEntryId: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  id value;
  NSData *entryId;

  value = [properties objectForKey: @"x-ms-sharing-initiatorentryid"];
  if (value)
    {
      entryId = [value dataByDecodingBase64];
      if (entryId)
        {
          *data = [entryId asBinaryInMemCtx: memCtx];
          rc = MAPISTORE_SUCCESS;
        }
    }

  return rc;
}

- (int) getPidLidSharingInitiatorName: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-initiatorname"
                           inData: data
                         inMemCtx: memCtx];
}

- (int) getPidLidSharingInitiatorSmtp: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-initiatorsmtp"
                           inData: data
                         inMemCtx: memCtx];
}

- (int) getPidLidSharingLocalType: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-localtype"
                           inData: data
                         inMemCtx: memCtx];
}

- (int) getPidNameXSharingLocalType: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingLocalType: data inMemCtx: memCtx];
}

- (int) getPidLidSharingProviderGuid: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  const unsigned char providerGuidBytes[] = {0xAE, 0xF0, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00,
                                             0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46};
  NSData *providerGuid = [NSData dataWithBytes: providerGuidBytes length: 16];
  *data = [providerGuid asBinaryInMemCtx: memCtx];
  return MAPISTORE_SUCCESS;
}

- (int) getPidNameXSharingProviderGuid: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"AEF0060000000000C000000000000046" asUnicodeInMemCtx: memCtx];
  return MAPISTORE_SUCCESS;
}

- (int) getPidLidSharingProviderName: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{

  return [self _getStringProperty: @"x-ms-sharing-providername"
                           inData: data
                         inMemCtx: memCtx];
}

- (int) getPidNameXSharingProviderName: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingProviderName: data inMemCtx: memCtx];
}

- (int) getPidLidSharingProviderUrl: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-providerurl"
                           inData: data
                         inMemCtx: memCtx];
}

- (int) getPidNameXSharingProviderUrl: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingProviderUrl: data inMemCtx: memCtx];
}

- (int) getPidLidSharingRemoteName: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-remotename"
                           inData: data
                         inMemCtx: memCtx];
}

- (int) getPidNameXSharingRemoteName: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingRemoteName: data inMemCtx: memCtx];
}

- (int) getPidLidSharingRemoteStoreUid: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-remotestoreuid"
                           inData: data
                         inMemCtx: memCtx];
}

- (int) getPidNameXSharingRemoteStoreUid: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingRemoteStoreUid: data inMemCtx: memCtx];
}

- (int) getPidLidSharingRemoteType: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-remotetype"
                           inData: data
                         inMemCtx: memCtx];
}

- (int) getPidTypeXSharingRemoteType: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingRemoteType: data inMemCtx: memCtx];
}

- (int) getPidLidSharingRemoteUid: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-remoteuid"
                           inData: data
                         inMemCtx: memCtx];
}

- (int) getPidUidXSharingRemoteUid: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingRemoteUid: data inMemCtx: memCtx];
}

- (int) getPidLidSharingResponseTime: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  id value;

  value = [properties objectForKey: @"x-ms-sharing-responsetime"];
  if (value)
    {
      *data = [value asFileTimeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }

  return rc;
}

- (int) getPidLidSharingResponseType: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{

  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  id value;

  value = [properties objectForKey: @"x-ms-sharing-responsetype"];
  if (value)
    {
      *data = MAPILongValue (memCtx, [value intValue]);
      rc = MAPISTORE_SUCCESS;
    }

  return rc;
}

- (int) getPidNameContentClass: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
    *data = talloc_strdup (memCtx, "Sharing");
    return MAPISTORE_SUCCESS;
}

@end
