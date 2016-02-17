/* MAPIStoreSharingMessage.h - this file is part of SOGo-OpenChange
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
- (int) getPidLidSharingCapabilities: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidNameXSharingCapabilities: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingConfigurationUrl: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidNameXSharingConfigUrl: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingFlavor: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidNameXSharingFlavor: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingInitiatorEntryId: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingInitiatorName: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingInitiatorSmtp: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingLocalType: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidNameXSharingLocalType: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingProviderGuid: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidNameXSharingProviderGuid: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingProviderName: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidNameXSharingProviderName: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingProviderUrl: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidNameXSharingProviderUrl: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingRemoteName: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidNameXSharingRemoteName: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingRemoteStoreUid: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidNameXSharingRemoteStoreUid: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingRemoteType: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTypeXSharingRemoteType: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingResponseTime: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidSharingResponseType: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidNameContentClass: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx;

/* Save */
- (void) saveWithMessage: (MAPIStoreMailMessage *) msg
           andSOGoObject: (SOGoMailObject *) sogoObject;

@end

#endif /* MAPISTORECALENDARWRAPPER_H */
