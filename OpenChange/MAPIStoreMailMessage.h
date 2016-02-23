/* MAPIStoreMailMessage.h - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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

#ifndef MAPISTOREMAILMESSAGE_H
#define MAPISTOREMAILMESSAGE_H

#import "MAPIStoreMessage.h"

@class NSString;
@class NSArray;
@class NSMutableArray;
@class NSMutableDictionary;

@class MAPIStoreAppointmentWrapper;
@class MAPIStoreMailFolder;

@interface MAPIStoreMailMessage : MAPIStoreMessage
{
  BOOL headerSetup;
  BOOL mailIsEvent;
  BOOL mailIsMeetingRequest;
  BOOL mailIsSharingObject;

  NSMutableArray *bodyContentKeys;
  NSMutableDictionary *bodyPartsEncodings;
  NSMutableDictionary *bodyPartsCharsets;
  NSMutableDictionary *bodyPartsMimeTypes;
  NSMutableDictionary *bodyPartsMixed;
  
  NSString *headerCharset;
  NSString *headerMimeType;
  BOOL bodySetup;
  NSArray *bodyContent;
  BOOL fetchedAttachments;

  MAPIStoreAppointmentWrapper *appointmentWrapper;
}

- (NSString *) subject;

- (enum mapistore_error) getPidTagIconIndex: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagFlagStatus: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx;

- (enum mapistore_error) getPidTagMessageFlags: (void **) data
                                      inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagFollowupIcon: (void **) data
                                      inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagImportance: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagReceivedByEmailAddress: (void **) data
                                                inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagSenderEmailAddress: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagDisplayTo: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagDisplayCc: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagDisplayBcc: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx;

/* batch-mode helpers */
- (void) setBodyContentFromRawData: (NSArray *) rawContent;
- (NSArray *) getBodyContent;

@end

#endif /* MAPISTOREMAILMESSAGE_H */
