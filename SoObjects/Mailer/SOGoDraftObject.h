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

#import "SOGoMailBaseObject.h"

/*
  SOGoDraftsFolder
    Parent object: SOGoDraftsFolder
    Child objects: draft attachments?
  
  The SOGoDraftObject is used for composing new messages. It is necessary
  because we can't cache objects in a session. So the contents of the drafts
  folder are some kind of "mail creation transaction".

  TODO: store-info should be an own object, not NSDictionary.
*/

@class NSArray;
@class NSData;
@class NSDictionary;
@class NSException;
@class NGImap4Envelope;
@class NGMimeMessage;
@class NSMutableDictionary;
@class NSString;

@class SOGoMailObject;

@interface SOGoDraftObject : SOGoMailBaseObject
{
  NSString *path;
  NGImap4Envelope *envelope;
  int IMAP4ID;
  NSMutableDictionary *headers;
  NSString *text;
  NSString *sourceURL;
  NSString *sourceFlag;
}

/* contents */
- (void) fetchInfo;
- (NSException *) storeInfo;

- (void) fetchMailForEditing: (SOGoMailObject *) sourceMail;
- (void) fetchMailForReplying: (SOGoMailObject *) sourceMail
			toAll: (BOOL) toAll;
- (void) fetchMailForForwarding: (SOGoMailObject *) sourceMail;

- (void) setHeaders: (NSDictionary *) newHeaders;
- (NSDictionary *) headers;
- (void) setText: (NSString *) newText;
- (NSString *) text;

/* for replies and forwards */
- (void) setSourceURL: (NSString *) newSurceURL;
- (void) setSourceFlag: (NSString *) newSourceFlag;

- (void) setIMAP4ID: (int) newIMAPID;
- (int) IMAP4ID;

/* attachments */

- (NSArray *) fetchAttachmentNames;
- (BOOL) isValidAttachmentName: (NSString *) _name;
- (NSException *) saveAttachment: (NSData *) _attach
		    withMetadata: (NSDictionary *) metadata;
- (NSException *) deleteAttachmentWithName: (NSString *) _name;

/* NGMime representations */

- (NGMimeMessage *) mimeMessage;
- (NSData *) mimeMessageAsData;

/* operations */

- (NSException *) sendMail;
- (NSException *) save;

// /* fake being a SOGoMailObject */

// - (id) fetchParts: (NSArray *) _parts;

@end

#endif /* __Mailer_SOGoDraftObject_H__ */
