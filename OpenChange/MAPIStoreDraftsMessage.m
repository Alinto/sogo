/* MAPIStoreDraftsMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGMail/NGMailAddress.h>
#import <NGMail/NGMailAddressParser.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>
#import <Mailer/SOGoDraftObject.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreMIME.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreDraftsMessage.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

static Class NGMailAddressK, NSArrayK, SOGoDraftObjectK;

typedef void (*getMessageData_inMemCtx_) (MAPIStoreMessage *, SEL,
                                          struct mapistore_message **,
                                          TALLOC_CTX *);

@implementation SOGoDraftObject (MAPIStoreExtension)

- (Class) mapistoreMessageClass
{
  return [MAPIStoreDraftsMessage class];
}

@end

@implementation MAPIStoreDraftsMessage

+ (void) initialize
{
  NGMailAddressK = [NGMailAddress class];
  NSArrayK = [NSArray class];
  SOGoDraftObjectK = [SOGoDraftObject class];
}

- (uint64_t) objectVersion
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? ULLONG_MAX 
          : [super objectVersion]);
}

- (void) _fetchHeaderData
{
  [sogoObject fetchInfo];
  ASSIGN (headerMimeType, ([sogoObject isHTML] ? @"text/html" : @"text/plain"));
  ASSIGN (headerEncoding, @"8bit");
  ASSIGN (headerCharset, @"utf-8");
  headerSetup = YES;
}

- (void) _fetchBodyData
{
  ASSIGN (bodyContent,
          [[sogoObject text] dataUsingEncoding: NSUTF8StringEncoding]);
  bodySetup = YES;
}

- (void) getMessageData: (struct mapistore_message **) dataPtr
               inMemCtx: (TALLOC_CTX *) memCtx
{
  NSArray *to;
  NSInteger count, max, p;
  NSString *username, *cn, *email;
  NSData *entryId;
  NSDictionary *contactInfos;
  SOGoUserManager *mgr;
  NSDictionary *headers;
  NGMailAddress *currentAddress;
  NGMailAddressParser *parser;
  struct mapistore_message *msgData;
  struct mapistore_message_recipient *recipient;
  getMessageData_inMemCtx_ superMethod;

  if ([sogoObject isKindOfClass: SOGoDraftObjectK])
    {
      /* FIXME: this is a hack designed to work-around a hierarchy issue between
         SOGoMailObject and SOGoDraftObject */
      superMethod = (getMessageData_inMemCtx_)
        [MAPIStoreMessage instanceMethodForSelector: _cmd];
      superMethod (self, _cmd, &msgData, memCtx);

      /* Retrieve recipients from the message */
      if (!headerSetup)
        [self _fetchHeaderData];
      headers = [sogoObject headers];

      to = [headers objectForKey: @"to"];
      max = [to count];

      msgData->columns = set_SPropTagArray (msgData, 9,
                                            PR_OBJECT_TYPE,
                                            PR_DISPLAY_TYPE,
                                            PR_7BIT_DISPLAY_NAME_UNICODE,
                                            PR_SMTP_ADDRESS_UNICODE,
                                            PR_SEND_INTERNET_ENCODING,
                                            PR_RECIPIENT_DISPLAY_NAME_UNICODE,
                                            PR_RECIPIENT_FLAGS,
                                            PR_RECIPIENT_ENTRYID,
                                            PR_RECIPIENT_TRACKSTATUS);

      if (max > 0)
        {
          mgr = [SOGoUserManager sharedUserManager];
          msgData->recipients_count = max;
          msgData->recipients = talloc_array (msgData, struct mapistore_message_recipient *, max);
          for (count = 0; count < max; count++)
            {
              msgData->recipients[count]
                = talloc_zero (msgData, struct mapistore_message_recipient);
              recipient = msgData->recipients[count];
              recipient->data = talloc_array (msgData, void *, msgData->columns->cValues);
              memset (recipient->data, 0, msgData->columns->cValues * sizeof (void *));

              email = nil;
              cn = nil;

              parser = [NGMailAddressParser
                         mailAddressParserWithString: [to objectAtIndex: count]];
              currentAddress = [parser parse];
              if ([currentAddress isKindOfClass: NGMailAddressK])
                {
                  email = [currentAddress address];
                  cn = [currentAddress displayName];
                  contactInfos = [mgr contactInfosForUserWithUIDorEmail: email];

                  // PR_ACCOUNT_UNICODE
                  if (contactInfos)
                    {
                      username = [contactInfos objectForKey: @"c_uid"];
                      recipient->username = [username asUnicodeInMemCtx: msgData];
                      entryId = MAPIStoreInternalEntryId (username);
                    }
                  else
                    entryId = MAPIStoreExternalEntryId (cn, email);
                }
              else
                {
                  entryId = nil;
                  [self warnWithFormat: @"address could not be parsed"
                        @" properly (ignored)"];
                }
              recipient->type = MAPI_TO;

              /* properties */
              p = 0;
              recipient->data = talloc_array (msgData, void *, msgData->columns->cValues);
              memset (recipient->data, 0, msgData->columns->cValues * sizeof (void *));
              
              // PR_OBJECT_TYPE = MAPI_MAILUSER (see MAPI_OBJTYPE)
              recipient->data[p] = MAPILongValue (msgData, MAPI_MAILUSER);
              p++;
              
              // PR_DISPLAY_TYPE = DT_MAILUSER (see MS-NSPI)
              recipient->data[p] = MAPILongValue (msgData, 0);
              p++;

              // PR_7BIT_DISPLAY_NAME_UNICODE
              recipient->data[p] = [cn asUnicodeInMemCtx: msgData];
              p++;
              
              // PR_SMTP_ADDRESS_UNICODE
              recipient->data[p] = [email asUnicodeInMemCtx: msgData];
              p++;
              
              // PR_SEND_INTERNET_ENCODING = 0x00060000 (plain text, see OXCMAIL)
              recipient->data[p] = MAPILongValue (msgData, 0x00060000);
              p++;

              // PR_RECIPIENT_DISPLAY_NAME_UNICODE
              recipient->data[p] = [cn asUnicodeInMemCtx: msgData];
              p++;

              // PR_RECIPIENT_FLAGS
              recipient->data[p] = NULL;
              p++;

              // PR_RECIPIENT_ENTRYID
              recipient->data[p] = [entryId asShortBinaryInMemCtx: msgData];
              p++;
            }
        }
      *dataPtr = msgData;
    }
  else
    [super getMessageData: dataPtr inMemCtx: memCtx];
}

- (int) getPrIconIndex: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;

  if ([sogoObject isKindOfClass: SOGoDraftObjectK])
    {
      *data = MAPILongValue (memCtx, 0xffffffff);
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = [super getPrIconIndex: data inMemCtx: memCtx];

  return rc;
}

- (int) getPrImportance: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;
  uint32_t v;
  NSString *s;

  if ([sogoObject isKindOfClass: SOGoDraftObjectK])
    {
      if (!headerSetup)
        [self _fetchHeaderData];
      s = [[sogoObject headers] objectForKey: @"X-Priority"];
      v = 0x1;
    
      if ([s hasPrefix: @"1"]) v = 0x2;
      else if ([s hasPrefix: @"2"]) v = 0x2;
      else if ([s hasPrefix: @"4"]) v = 0x0;
      else if ([s hasPrefix: @"5"]) v = 0x0;
    
      *data = MAPILongValue (memCtx, v);

      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = [super getPrImportance: data inMemCtx: memCtx];

  return rc;
}

- (int) getPrMessageFlags: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  unsigned int v = MSGFLAG_FROMME;
  int rc;

  if ([sogoObject isKindOfClass: SOGoDraftObjectK])
    {
      if ([[self attachmentKeys] count] > 0)
        v |= MSGFLAG_HASATTACH;
      
      *data = MAPILongValue (memCtx, v);
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = [super getPrMessageFlags: data inMemCtx: memCtx];

  return rc;
}

- (int) getPrFlagStatus: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? [self getLongZero: data inMemCtx: memCtx]
          : [super getPrFlagStatus: data inMemCtx: memCtx]);
}

- (int) getPrFollowupIcon: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? [self getLongZero: data inMemCtx: memCtx]
          : [super getPrFollowupIcon: data inMemCtx: memCtx]);
}

- (int) getPrChangeKey: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPrPredecessorChangeList: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidLidImapDeleted: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPrInternetMessageId: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (void) _saveAttachment: (NSString *) attachmentKey
{
  NSDictionary *properties, *metadata;
  NSString *filename, *mimeType;
  NSData *content;
  MAPIStoreAttachment *attachment;

  attachment = [attachmentParts objectForKey: attachmentKey];
  properties = [attachment newProperties];
  filename
    = [properties
        objectForKey: MAPIPropertyKey (PR_ATTACH_LONG_FILENAME_UNICODE)];
  if (![filename length])
    {
      filename
        = [properties
            objectForKey: MAPIPropertyKey (PR_ATTACH_FILENAME_UNICODE)];
      if (![filename length])
        filename = @"untitled.bin";
    }

  mimeType = [properties
               objectForKey: MAPIPropertyKey (PR_ATTACH_MIME_TAG_UNICODE)];
  if (!mimeType)
    mimeType = [[MAPIStoreMIME sharedMAPIStoreMIME]
                 mimeTypeForExtension: [filename pathExtension]];
  if (!mimeType)
    mimeType = @"application/octet-stream";

  content = [properties objectForKey: MAPIPropertyKey (PR_ATTACH_DATA_BIN)];
  if (content)
    {
      metadata = [NSDictionary dictionaryWithObjectsAndKeys:
                                 filename, @"filename",
                               mimeType, @"mimetype", nil];
      [sogoObject saveAttachment: content withMetadata: metadata];
    }
  else
    [self errorWithFormat: @"no content for attachment"];
}

- (void) _commitProperties
{
  static NSString *recIds[] = { @"to", @"cc", @"bcc" };
  NSArray *list;
  NSDictionary *recipients, *identity;
  NSMutableDictionary *newHeaders;
  NSString *recId, *body;
  NSMutableString *subject;
  NSUInteger count, max;
  WOContext *woContext;
  id value;

  newHeaders = [NSMutableDictionary dictionaryWithCapacity: 7];

  /* save the recipients */
  recipients = [newProperties objectForKey: @"recipients"];
  if (recipients)
    {
      for (count = 0; count < 3; count++)
	{
	  recId = recIds[count];
	  list = [recipients objectForKey: recId];
	  if ([list count] > 0)
	    [newHeaders setObject: [list objectsForKey: @"email"
					 notFoundMarker: nil]
			forKey: recId];
	}
    }
  else
    [self errorWithFormat: @"message without recipients"];

  /*
    message properties (20):
    recipients: {to = ({email = "wsourdeau@inverse.ca"; fullName = "wsourdeau@inverse.ca"; }); }
    0x1000001f (PR_BODY_UNICODE): text body (GSCBufferString)
    0x0037001f (PR_SUBJECT_UNICODE): Test without (GSCBufferString)
    0x30070040 (PR_CREATION_TIME): 2010-11-24 13:45:38 -0500 (NSCalendarDate)
e)
    2010-11-24 13:45:38.715 samba[25685]   0x0e62000b (PR_URL_COMP_NAME_SET):
    0 (NSIntNumber) */

  /* save the subject */
  subject = [NSMutableString stringWithCapacity: 128];
  value = [newProperties objectForKey: MAPIPropertyKey (PR_SUBJECT_UNICODE)];
  if (value)
    [subject appendString: value];
  else
    {
      value = [newProperties
                objectForKey: MAPIPropertyKey (PR_SUBJECT_PREFIX_UNICODE)];
      if (value)
        [subject appendString: value];
      value = [newProperties
                objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
      if (value)
        [subject appendString: value];
    }
  if (subject)
    [newHeaders setObject: subject forKey: @"subject"];

  /* generate a valid from */
  woContext = [[self context] woContext];
  identity = [[woContext activeUser] primaryIdentity];
  [newHeaders setObject: [identity keysWithFormat: @"%{fullName} <%{email}>"]
	      forKey: @"from"];

  /* set the proper priority:
     0x00000000 == Low importance
     0x00000001 == Normal importance
     0x00000002 == High importance */
  value = [newProperties objectForKey: MAPIPropertyKey (PR_IMPORTANCE)];
  if (value && [value intValue] == 0x0)
    {
      [newHeaders setObject: @"LOW"  forKey: @"priority"];
    }
  else if (value && [value intValue] == 0x2)
    {
      [newHeaders setObject: @"HIGH"  forKey: @"priority"];
    }   
  
  /* save the newly generated headers */
  [sogoObject setHeaders: newHeaders];

  value = [newProperties objectForKey: MAPIPropertyKey (PR_HTML)];
  if (value)
    {
      [sogoObject setIsHTML: YES];
      // TODO: encoding
      body = [[NSString alloc] initWithData: value
			       encoding: NSUTF8StringEncoding];
      [sogoObject setText: body];
      [body release];
    }
  else
    {
      value = [newProperties objectForKey: MAPIPropertyKey (PR_BODY_UNICODE)];
      if (value)
	{
	  [sogoObject setIsHTML: NO];
	  [sogoObject setText: value];
	}
    }

  /* save attachments */
  max = [[self attachmentKeys] count];
  for (count = 0; count < max; count++)
    [self _saveAttachment: [attachmentKeys objectAtIndex: count]];
}

- (int) _getAddressHeader: (void **) data
               addressKey: (NSString *) key
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue, *address;
  NGMailAddress *currentAddress;
  NGMailAddressParser *parser;
  id to;

  if (!headerSetup)
    [self _fetchHeaderData];

  stringValue = @"";

  to = [[sogoObject headers] objectForKey: key];
  if ([to isKindOfClass: NSArrayK])
    {
      if ([to count] > 0)
        address = [to objectAtIndex: 0];
      else
        address = @"";
    }
  else
    address = to;

  parser = [NGMailAddressParser mailAddressParserWithString: address];
  currentAddress = [parser parse];
  if ([currentAddress isKindOfClass: NGMailAddressK])
    {
      stringValue = [currentAddress address];
      if (!stringValue)
        stringValue = @"";
    }
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrSenderEmailAddress: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? [self _getAddressHeader: data
                         addressKey: @"from"
                           inMemCtx: memCtx]
          : [super getPrSenderEmailAddress: data inMemCtx: memCtx]);
}

- (int) getPrSenderName: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPrSenderEntryid: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPrReceivedByEmailAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? [self _getAddressHeader: data
                         addressKey: @"to"
                           inMemCtx: memCtx]
          : [super getPrReceivedByEmailAddress: data inMemCtx: memCtx]);
}

- (int) getPrDisplayTo: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? [self _getAddressHeader: data
                         addressKey: @"to"
                           inMemCtx: memCtx]
          : [super getPrDisplayTo: data inMemCtx: memCtx]);
}

- (int) getPrDisplayCc: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? [self _getAddressHeader: data
                         addressKey: @"cc"
                           inMemCtx: memCtx]
          : [super getPrDisplayCc: data inMemCtx: memCtx]);
}

- (int) getPrDisplayBcc: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? [self _getAddressHeader: data
                         addressKey: @"cc"
                           inMemCtx: memCtx]
          : [super getPrDisplayBcc: data inMemCtx: memCtx]);
}

- (NSArray *) attachmentKeysMatchingQualifier: (EOQualifier *) qualifier
                             andSortOrderings: (NSArray *) sortOrderings
{
  NSArray *keys;

  if ([sogoObject isKindOfClass: SOGoDraftObjectK])
    {
      if (qualifier)
        [self errorWithFormat: @"qualifier is not used for attachments"];
      if (sortOrderings)
        [self errorWithFormat: @"sort orderings are not used for attachments"];
  
      keys = [attachmentParts allKeys];
    }
  else
    keys = [super attachmentKeysMatchingQualifier: qualifier
                                 andSortOrderings: sortOrderings];

  return keys;
}

- (id) lookupAttachment: (NSString *) childKey
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? [attachmentParts objectForKey: childKey]
          : [super lookupAttachment: childKey]);
}

- (void) submit
{
  NSString *msgClass;
  NSException *error;
  MAPIStoreMapping *mapping;

  msgClass = [newProperties
                   objectForKey: MAPIPropertyKey (PR_MESSAGE_CLASS_UNICODE)];
  if (![msgClass isEqualToString: @"IPM.Schedule.Meeting.Request"])
    {
      [self logWithFormat: @"sending message"];
      [self _commitProperties];
      error = [(SOGoDraftObject *) sogoObject sendMailAndCopyToSent: NO];
      if (error)
        [self errorWithFormat: @"an exception occurred: %@", error];
    }
  else
    [self logWithFormat: @"ignored scheduling message"];

  mapping = [[self context] mapping];
  [mapping unregisterURLWithID: [self objectId]];
}

- (int) submitWithFlags: (enum SubmitFlags) flags
{
  int rc;

  if ([sogoObject isKindOfClass: SOGoDraftObjectK])
    {
      [self submit];
      [self setIsNew: NO];
      [self resetNewProperties];
      [[self container] cleanupCaches];
      rc = MAPISTORE_SUCCESS;
    }
  else
    {
      [self errorWithFormat: @"'submit' cannot be invoked on instances of '%@'",
            NSStringFromClass ([sogoObject class])];
      rc = MAPISTORE_ERROR;
    }

  return rc;
}

- (void) save
{
  NSString *msgClass;

  if ([sogoObject isKindOfClass: SOGoDraftObjectK])
    {
      msgClass = [newProperties
                   objectForKey: MAPIPropertyKey (PR_MESSAGE_CLASS_UNICODE)];
      if (![msgClass isEqualToString: @"IPM.Schedule.Meeting.Request"])
        {
          [self logWithFormat: @"saving message"];
          [self _commitProperties];
          [(SOGoDraftObject *) sogoObject save];
        }
      else
        [self logWithFormat: @"ignored scheduling message"];
    }
  else
    [self errorWithFormat: @"'save' cannot be invoked on instances of '%@'",
          NSStringFromClass ([sogoObject class])];
}

- (NSString *) subject
{
  NSString *subject;

  if ([sogoObject isKindOfClass: SOGoDraftObjectK])
    {
      subject = [newProperties objectForKey: MAPIPropertyKey (PR_SUBJECT_UNICODE)];
      if (!subject)
        {
          if (!headerSetup)
            [self _fetchHeaderData];
          subject = [[sogoObject headers] objectForKey: @"subject"];
        }
    }
  else
    subject = [super subject];

  return subject;
}

- (NSDate *) creationTime
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? (NSDate *) [newProperties objectForKey: MAPIPropertyKey (PR_CREATION_TIME)]
          : [super creationTime]);
}

- (NSDate *) lastModificationTime
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? (NSDate *) [newProperties
              objectForKey: MAPIPropertyKey (PR_LAST_MODIFICATION_TIME)]
          : [super lastModificationTime]);
}

@end
