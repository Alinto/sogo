/*
  Copyright (C) 2009-2017 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __Mailer_SOGoMailObject_H__
#define __Mailer_SOGoMailObject_H__

#import <Mailer/SOGoMailBaseObject.h>

/*
  SOGoMailObject
    Parent object: the SOGoMailFolder
    Child objects: SOGoMailBodyPart's
  
  Represents a single mail as retrieved using NGImap4. Since IMAP4 can parse
  MIME structures on the server side, which we map into child objects of the
  message.
  The child objects are accessed using integer IDs, eg:
    /INBOX/12345/1/2/3
  would address the MIME part 1.2.3 of the mail 12345 in the folder INBOX.
*/

@class NSArray;
@class NSCalendarDate;
@class NSData;
@class NSDictionary;
@class NSException;
@class NSMutableArray;
@class NSString;

@class NGImap4Envelope;
@class NGImap4EnvelopeAddress;

@class WOResponse;

extern NSArray *SOGoMailCoreInfoKeys;

@interface SOGoMailObject : SOGoMailBaseObject
{
  id coreInfos;
  id headerPart;
  NSDictionary *headers;
}

/* message */

- (id)fetchParts:(NSArray *)_parts; /* Note: 'parts' are fetch keys here */

/* core infos */

- (BOOL) doesMailExist;
- (id) fetchCoreInfos; // TODO: what does it do?
- (void) setCoreInfos: (NSDictionary *) newCoreInfos;

- (NGImap4Envelope *) envelope;
- (NSString *) subject;
- (NSString *) decodedSubject;
- (NSCalendarDate *) date;
- (NSArray *) fromEnvelopeAddresses;
- (NSArray *) replyToEnvelopeAddresses;
- (NSArray *) toEnvelopeAddresses;
- (NSArray *) ccEnvelopeAddresses;
- (NSArray *) bccEnvelopeAddresses;

- (NSDictionary *) mailHeaders;

- (id) bodyStructure;
- (id) lookupInfoForBodyPart:(id)_path;
- (id) lookupImap4BodyPartKey: (NSString *) _key
		    inContext: (id) _ctx;

/* content */

- (NSData *) content;
- (NSString *) contentAsString;
- (NSString *) davContentLength;

- (NSString *) to;
- (NSString *) cc;
- (NSString *) from;
- (NSString *) inReplyTo;
- (NSString *) messageId;
- (NSString *) received;

/* bulk fetching of plain/text content */

- (NSArray *) plainTextContentFetchKeys;
- (NSDictionary *) fetchPlainTextParts:(NSArray *)_fetchKeys;
- (NSDictionary *) fetchPlainTextParts;
- (NSDictionary *) fetchPlainTextStrings:(NSArray *)_fetchKeys;

- (BOOL) hasAttachment;
- (NSDictionary *) fetchFileAttachmentIds;
- (NSArray *) fetchFileAttachmentKeys;
- (NSArray *) fetchFileAttachments;
- (WOResponse *) archiveAllFilesinArchiveNamed: (NSString *) archiveName;

/* flags */

- (NSException *) addFlags:(id)_f;
- (NSException *) removeFlags:(id)_f;

- (BOOL) isNewMail;   /* \Recent */
- (BOOL) flagged;     /* \Flagged */
- (BOOL) read;        /* \Unseen */
- (BOOL) replied;     /* \Answered */
- (BOOL) forwarded;   /* $forwarded */
- (BOOL) deleted;     /* \Deleted */
- (BOOL) isSigned;       /* S/MIME signed message (detached signature) */
- (BOOL) isOpaqueSigned; /* S/MIME signed message (embedded content) */
- (BOOL) isEncrypted; /* S/MIME encrypted message */

/* deletion */

- (BOOL) isDeletionAllowed;

- (void) addRequiredKeysOfStructure: (NSDictionary *) info
                               path: (NSString *) p
                            toArray: (NSMutableArray *) keys
                      acceptedTypes: (NSArray *) types
                           withPeek: (BOOL) withPeek;

@end

#endif /* __Mailer_SOGoMailObject_H__ */
