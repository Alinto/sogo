/* MAPIStoreSharingMessage.h - this file is part of SOGo-OpenChange
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

#ifndef MAPISTORESHARINGMESSAGE_H
#define MAPISTORESHARINGMESSAGE_H

#import "MAPIStoreMailMessage.h"
#import "MAPIStoreObjectProxy.h"

#define SHARING_SPECIAL_FOLDER 0x40290

@interface MAPIStoreSharingMessage : MAPIStoreObjectProxy
{
  struct mapistore_connection_info *connInfo;
  NSMutableDictionary *properties;
}

- (id) initWithMailHeaders: (NSDictionary *) mailHeaders
         andConnectionInfo: (struct mapistore_connection_info *) newConnInfo
               fromMessage: (MAPIStoreMailMessage *) msg;

/* getters */
- (enum mapistore_error) getPidLidSharingCapabilities: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidNameXSharingCapabilities: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingConfigurationUrl: (void **) data
                                                 inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidNameXSharingConfigUrl: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingFlavor: (void **) data
                                       inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidNameXSharingFlavor: (void **) data
                                         inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingInitiatorEntryId: (void **) data
                                                 inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingInitiatorName: (void **) data
                                              inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingInitiatorSmtp: (void **) data
                                              inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingLocalType: (void **) data
                                          inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidNameXSharingLocalType: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingProviderGuid: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidNameXSharingProviderGuid: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingProviderName: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidNameXSharingProviderName: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingProviderUrl: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidNameXSharingProviderUrl: (void **) data
                                              inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingRemoteName: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidNameXSharingRemoteName: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingRemoteStoreUid: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidNameXSharingRemoteStoreUid: (void **) data
                                                 inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingRemoteType: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTypeXSharingRemoteType: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingResponseTime: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidSharingResponseType: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidNameContentClass: (void **) data
                                       inMemCtx: (TALLOC_CTX *) memCtx;

/* Save */
- (void) saveWithMessage: (MAPIStoreMailMessage *) msg
           andSOGoObject: (SOGoMailObject *) sogoObject;

@end

#endif /* MAPISTORECALENDARWRAPPER_H */
