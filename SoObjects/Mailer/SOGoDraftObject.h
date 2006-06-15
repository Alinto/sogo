/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __Mailer_SOGoDraftObject_H__
#define __Mailer_SOGoDraftObject_H__

#include <Mailer/SOGoMailBaseObject.h>

/*
  SOGoDraftsFolder
    Parent object: SOGoDraftsFolder
    Child objects: draft attachments?
  
  The SOGoDraftObject is used for composing new messages. It is necessary
  because we can't cache objects in a session. So the contents of the drafts
  folder are some kind of "mail creation transaction".

  TODO: store-info should be an own object, not NSDictionary.
*/

@class NSString, NSArray, NSDictionary, NSData, NSException;
@class NGMimeMessage, NGImap4Envelope;

@interface SOGoDraftObject : SOGoMailBaseObject
{
  NSString        *path;
  NSDictionary    *info; /* stores the envelope information */
  NGImap4Envelope *envelope;
}

/* contents */

- (NSDictionary *)fetchInfo;
- (NSException *)storeInfo:(NSDictionary *)_info;

/* attachments */

- (NSArray *)fetchAttachmentNames;
- (BOOL)isValidAttachmentName:(NSString *)_name;
- (NSException *)saveAttachment:(NSData *)_attach withName:(NSString *)_name;
- (NSException *)deleteAttachmentWithName:(NSString *)_name;

/* NGMime representations */

- (NGMimeMessage *)mimeMessage;

- (NSString *)saveMimeMessageToTemporaryFile;
- (NSString *)saveMimeMessageToTemporaryFileWithHeaders:(NSDictionary *)_addh;
- (NSException *)sendMimeMessageAtPath:(NSString *)_path;

- (NSException *)sendMail;

/* operations */

- (NSException *)delete;

/* fake being a SOGoMailObject */

- (id)fetchParts:(NSArray *)_parts;

@end

#endif /* __Mailer_SOGoDraftObject_H__ */
