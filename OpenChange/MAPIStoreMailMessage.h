/* MAPIStoreMailMessage.h - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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

@class NSData;
@class NSString;

@class MAPIStoreAppointmentWrapper;
@class MAPIStoreMailFolder;

@interface MAPIStoreMailMessage : MAPIStoreMessage
{
  BOOL headerSetup;
  BOOL mailIsEvent;
  NSString *mimeKey;
  NSString *headerCharset;
  NSString *headerEncoding;
  NSString *headerMimeType;
  BOOL bodySetup;
  NSData *bodyContent;
  BOOL fetchedAttachments;

  MAPIStoreAppointmentWrapper *appointmentWrapper;
}

- (NSString *) subject;

- (int) getPidTagIconIndex: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagFlagStatus: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx;

- (int) getPidTagMessageFlags: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagFollowupIcon: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagImportance: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagReceivedByEmailAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagSenderEmailAddress: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagDisplayTo: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagDisplayCc: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagDisplayBcc: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx;

@end

#endif /* MAPISTOREMAILMESSAGE_H */
