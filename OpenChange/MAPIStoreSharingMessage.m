/* MAPIStoreSharingMessage.m - this file is part of SOGo-OpenChange
 *
 * Copyright (C) 2015-2016 Enrique J. Hernández
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

#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>

#import <Mailer/SOGoMailObject.h>
#import <NGExtensions/NGBase64Coding.h>

#import "NSData+MAPIStore.h"
#import "NSDate+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "NSValue+MAPIStore.h"

#import "MAPIStoreMailFolder.h"
#import "MAPIStoreSharingMessage.h"
#import "MAPIStoreTypes.h"

#include <gen_ndr/property.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>

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
               fromMessage: (MAPIStoreMailMessage *) msg
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

      /* Set request properties from container folder */
      NSDictionary *requestProps = [(MAPIStoreMailFolder *)[msg container]
                                       extraPropertiesForMessage: [msg nameInContainer]];
      if (requestProps)
        [properties addEntriesFromDictionary: requestProps];
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

- (enum mapistore_error) getPidLidSharingCapabilities: (void **) data
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

- (enum mapistore_error) getPidNameXSharingCapabilities: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx
{

  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  id value;

  value = [properties objectForKey: @"x-ms-sharing-capabilities"];
  if (value)
    {
      *data = [[NSString stringWithFormat:@"%X", [value intValue]]
                 asUnicodeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }

  return rc;
}

- (enum mapistore_error) getPidLidSharingConfigurationUrl: (void **) data
                                                 inMemCtx: (TALLOC_CTX *) memCtx
{

  *data = [@"" asUnicodeInMemCtx: memCtx];
  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidNameXSharingConfigUrl: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingConfigurationUrl: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidSharingFlavor: (void **) data
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
          if ([value intValue] == SHARING_SPECIAL_FOLDER)
            {
              value = [properties objectForKey: @"x-ms-sharing-responsetime"];
              auxValue = [properties objectForKey: @"x-ms-sharing-remoteuid"];
              if (value)  /* A sharing request */
                {
                  if (auxValue)
                    *data = MAPILongValue (memCtx, SHARING_INVITATION_REQUEST_FOLDER);
                  else
                    *data = MAPILongValue (memCtx, SHARING_REQUEST_SPECIAL_FOLDER);
                }
              else
                {
                  if (auxValue)  /* It SHOULD be an invitation or response */
                    *data = MAPILongValue (memCtx, SHARING_INVITATION_SPECIAL_FOLDER);
                  else  /* No remote info, then denial */
                    *data = MAPILongValue (memCtx, SHARING_DENY_REQUEST);
                }
            }
          else
            {
              *data = MAPILongValue (memCtx, SHARING_INVITATION_FOLDER);
            }
          rc = MAPISTORE_SUCCESS;
        }
    }

  return rc;
}

- (enum mapistore_error) getPidNameXSharingFlavor: (void **) data
                                         inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  id value;

  value = [properties objectForKey: @"x-ms-sharing-flavor"];
  if (value)
    {
      *data = [[NSString stringWithFormat:@"%X", [value intValue]]
                asUnicodeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }

  return rc;
}

- (enum mapistore_error) getPidLidSharingInitiatorEntryId: (void **) data
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

- (enum mapistore_error) getPidLidSharingInitiatorName: (void **) data
                                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-initiatorname"
                           inData: data
                         inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidSharingInitiatorSmtp: (void **) data
                                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-initiatorsmtp"
                           inData: data
                         inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidSharingLocalType: (void **) data
                                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-localtype"
                           inData: data
                         inMemCtx: memCtx];
}

- (enum mapistore_error) getPidNameXSharingLocalType: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingLocalType: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidSharingProviderGuid: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx
{
  const unsigned char providerGuidBytes[] = {0xAE, 0xF0, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00,
                                             0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46};
  NSData *providerGuid = [NSData dataWithBytes: providerGuidBytes length: 16];
  *data = [providerGuid asBinaryInMemCtx: memCtx];
  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidNameXSharingProviderGuid: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"AEF0060000000000C000000000000046" asUnicodeInMemCtx: memCtx];
  return MAPISTORE_SUCCESS;
}

- (enum mapistore_error) getPidLidSharingProviderName: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx
{

  return [self _getStringProperty: @"x-ms-sharing-providername"
                           inData: data
                         inMemCtx: memCtx];
}

- (enum mapistore_error) getPidNameXSharingProviderName: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingProviderName: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidSharingProviderUrl: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-providerurl"
                           inData: data
                         inMemCtx: memCtx];
}

- (enum mapistore_error) getPidNameXSharingProviderUrl: (void **) data
                                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingProviderUrl: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidSharingRemoteName: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-remotename"
                           inData: data
                         inMemCtx: memCtx];
}

- (enum mapistore_error) getPidNameXSharingRemoteName: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingRemoteName: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidSharingRemoteStoreUid: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-remotestoreuid"
                           inData: data
                         inMemCtx: memCtx];
}

- (enum mapistore_error) getPidNameXSharingRemoteStoreUid: (void **) data
                                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingRemoteStoreUid: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidSharingRemoteType: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-remotetype"
                           inData: data
                         inMemCtx: memCtx];
}

- (enum mapistore_error) getPidTypeXSharingRemoteType: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingRemoteType: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidSharingRemoteUid: (void **) data
                                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getStringProperty: @"x-ms-sharing-remoteuid"
                           inData: data
                         inMemCtx: memCtx];
}

- (enum mapistore_error) getPidUidXSharingRemoteUid: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidSharingRemoteUid: data inMemCtx: memCtx];
}

- (enum mapistore_error) getPidLidSharingResponseTime: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  id value;

  value = [properties objectForKey: MAPIPropertyKey (PidLidSharingResponseTime)];
  if (!value)
    {
      value = [properties objectForKey: @"x-ms-sharing-responsetime"];
      if (value)
        {
          /* Here the value is a GSCBufferString */
          NSString * responseTime = [NSString stringWithUTF8String: [value UTF8String]];
          value = [NSDate dateWithString: responseTime];
        }
    }

  if (value)
    {
      *data = [value asFileTimeInMemCtx: memCtx];
      rc = MAPISTORE_SUCCESS;
    }

  return rc;
}

- (enum mapistore_error) getPidLidSharingResponseType: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx
{

  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;
  id value;

  value = [properties objectForKey: MAPIPropertyKey (PidLidSharingResponseType)];
  if (!value)
    value = [properties objectForKey: @"x-ms-sharing-responsetype"];

  if (value)
    {
      *data = MAPILongValue (memCtx, [value intValue]);
      rc = MAPISTORE_SUCCESS;
    }

  return rc;
}

- (enum mapistore_error) getPidNameContentClass: (void **) data
                                       inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = talloc_strdup (memCtx, "Sharing");
  return MAPISTORE_SUCCESS;
}

- (void) saveWithMessage: (MAPIStoreMailMessage *) msg
           andSOGoObject: (SOGoMailObject *) sogoObject
{
  /* Store PidLidSharingResponseType and PidLidSharingResponseTime if
     required in versions message from the container as I don't see
     other straightforward place to put that information */
  id response;
  NSDictionary *propsToStore;

  response = [[msg properties] objectForKey: MAPIPropertyKey (PidLidSharingResponseType)];
  if (response)
    {
      /* FIXME: Is there any better way to increase the modseq? */
      [sogoObject addFlags: @"\\Draft"];
      [sogoObject removeFlags: @"\\Draft"];

      /* Store this modification in container folder along the property values */
      propsToStore = [NSDictionary dictionaryWithObjects:
                               [NSArray arrayWithObjects: response,
                                        [[msg properties] objectForKey: MAPIPropertyKey (PidLidSharingResponseTime)],
                                        nil]
                                                 forKeys:
                               [NSArray arrayWithObjects: MAPIPropertyKey (PidLidSharingResponseType),
                                        MAPIPropertyKey (PidLidSharingResponseTime), nil]];

      [(MAPIStoreMailFolder *)[msg container] setExtraProperties: propsToStore
                                                      forMessage: [msg nameInContainer]];
    }
}

@end
