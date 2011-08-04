/* MAPIStoreDraftsMessage.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGMail/NGMailAddress.h>
#import <NGMail/NGMailAddressParser.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <Mailer/SOGoDraftObject.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreTypes.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreDraftsMessage.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

static Class NGMailAddressK, SOGoDraftObjectK;

typedef void (*getMessageData_inMemCtx_) (MAPIStoreMessage *, SEL,
                                          struct mapistore_message **,
                                          TALLOC_CTX *);

@implementation MAPIStoreDraftsMessage

+ (void) initialize
{
  NGMailAddressK = [NGMailAddress class];
  SOGoDraftObjectK = [SOGoDraftObject class];
}

- (uint64_t) objectVersion
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? 0xffffffffffffffffLL
          : [super objectVersion]);
}

- (void) getMessageData: (struct mapistore_message **) dataPtr
               inMemCtx: (TALLOC_CTX *) memCtx
{
  struct SRowSet *recipients;
  NSArray *to;
  NSInteger count, max;
  NSString *text;
  NSDictionary *headers;
  NGMailAddress *currentAddress;
  NGMailAddressParser *parser;
  struct mapistore_message *msgData;
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
        {
          [sogoObject fetchInfo];
          headerSetup = YES;
        }
      headers = [sogoObject headers];

      to = [headers objectForKey: @"to"];
      max = [to count];
      recipients = talloc_zero (msgData, struct SRowSet);
      recipients->cRows = max;
      recipients->aRow = talloc_array (recipients, struct SRow, max);
      for (count = 0; count < max; count++)
        {
          recipients->aRow[count].ulAdrEntryPad = 0;
          recipients->aRow[count].cValues = 3;
          recipients->aRow[count].lpProps = talloc_array (recipients->aRow,
                                                          struct SPropValue,
                                                          4);

          // TODO (0x01 = primary recipient)
          set_SPropValue_proptag (recipients->aRow[count].lpProps + 0,
                                  PR_RECIPIENT_TYPE,
                                  MAPILongValue (recipients->aRow, 0x01));
     
          set_SPropValue_proptag (recipients->aRow[count].lpProps + 1,
                                  PR_ADDRTYPE_UNICODE,
                                  [@"SMTP" asUnicodeInMemCtx: recipients->aRow]);

          parser = [NGMailAddressParser
                     mailAddressParserWithString: [to objectAtIndex: count]];
          currentAddress = [parser parse];
          if ([currentAddress isKindOfClass: NGMailAddressK])
            {
              // text = [currentAddress personalName];
              // if (![text length])
              text = [currentAddress address];
              if (!text)
                text = @"";
              set_SPropValue_proptag (recipients->aRow[count].lpProps + 2,
                                      PR_EMAIL_ADDRESS_UNICODE,
                                      [text asUnicodeInMemCtx: recipients->aRow]);
              
              text = [currentAddress displayName];
              if ([text length] > 0)
                {
                  recipients->aRow[count].cValues++;
                  set_SPropValue_proptag (recipients->aRow[count].lpProps + 3,
                                          PR_DISPLAY_NAME_UNICODE,
                                          [text asUnicodeInMemCtx: recipients->aRow]);
                }
            }
          else
            [self warnWithFormat: @"address could not be parsed properly (ignored)"];
        }
      msgData->recipients = recipients;
      *dataPtr = msgData;
    }
  else
    [super getMessageData: dataPtr inMemCtx: memCtx];
}

- (int) getPrImportance: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t v;
  NSString *s;

  if ([sogoObject isKindOfClass: SOGoDraftObjectK])
    {
      if (!headerSetup)
        {
          [sogoObject fetchInfo];
          headerSetup = YES;
        }
      s = [[sogoObject headers] objectForKey: @"X-Priority"];
      v = 0x1;
    
      if ([s hasPrefix: @"1"]) v = 0x2;
      else if ([s hasPrefix: @"2"]) v = 0x2;
      else if ([s hasPrefix: @"4"]) v = 0x0;
      else if ([s hasPrefix: @"5"]) v = 0x0;
    
      *data = MAPILongValue (memCtx, v);
    }
  else
    [super getPrImportance: data inMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageFlags: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  unsigned int v = MSGFLAG_FROMME;
  int rc;

  if ([sogoObject isKindOfClass: SOGoDraftObjectK])
    {
      if ([[self attachmentKeys]
        count] > 0)
        v |= MSGFLAG_HASATTACH;
      
      *data = MAPILongValue (memCtx, v);
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = [super getPrMessageFlags: data inMemCtx: memCtx];

  return rc;
}

- (void) _saveAttachment: (NSString *) attachmentKey
{
  NSDictionary *properties, *metadata;
  NSString *filename, *mimeType;
  NSData *content;
  MAPIStoreAttachment *attachment;

  attachment = [attachmentParts objectForKey: attachmentKey];
  properties = [attachment newProperties];
  mimeType = [properties
               objectForKey: MAPIPropertyKey (PR_ATTACH_MIME_TAG_UNICODE)];
  if (!mimeType)
    mimeType = @"application/octet-stream";
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
  NSUInteger count, max;
  WOContext *woContext;
  id value;

  newHeaders = [NSMutableDictionary dictionaryWithCapacity: 6];
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

  value = [newProperties
	    objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
  if (!value)
  value = [newProperties objectForKey: MAPIPropertyKey (PR_SUBJECT_UNICODE)];
  if (value)
    [newHeaders setObject: value forKey: @"subject"];

  woContext = [[self context] woContext];
  identity = [[woContext activeUser] primaryIdentity];
  [newHeaders setObject: [identity keysWithFormat: @"%{fullName} <%{email}>"]
	      forKey: @"from"];
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

  max = [[self attachmentKeys] count];
  for (count = 0; count < max; count++)
    [self _saveAttachment: [attachmentKeys objectAtIndex: count]];
}

- (int) getPrReceivedByEmailAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;
  NGMailAddress *currentAddress;
  NGMailAddressParser *parser;
  NSArray *to;

  if ([sogoObject isKindOfClass: SOGoDraftObjectK])
    {
      stringValue = @"";

      if (!headerSetup)
        {
          [sogoObject fetchInfo];
          headerSetup = YES;
        }

      to = [[sogoObject headers] objectForKey: @"to"];
      if ([to count] > 0)
        {
          parser = [NGMailAddressParser
                     mailAddressParserWithString: [to objectAtIndex: 0]];
          currentAddress = [parser parse];
          if ([currentAddress isKindOfClass: NGMailAddressK])
            {
              stringValue = [currentAddress address];
              if (!stringValue)
                stringValue = @"";
            }
        }
      *data = [stringValue asUnicodeInMemCtx: memCtx];
    }
  else
    [super getPrReceivedByEmailAddress: data inMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
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

  msgClass = [newProperties
                   objectForKey: MAPIPropertyKey (PR_MESSAGE_CLASS_UNICODE)];
  if (![msgClass isEqualToString: @"IPM.Schedule.Meeting.Request"])
    {
      [self logWithFormat: @"sending message"];
      [self _commitProperties];
      [(SOGoDraftObject *) sogoObject sendMail];
    }
  else
    [self logWithFormat: @"ignored scheduling message"];
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
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? [[sogoObject headers] objectForKey: @"subject"]
          : [super subject]);
}

- (NSCalendarDate *) creationTime
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? [newProperties objectForKey: MAPIPropertyKey (PR_CREATION_TIME)]
          : [super creationTime]);
}

- (NSCalendarDate *) lastModificationTime
{
  return ([sogoObject isKindOfClass: SOGoDraftObjectK]
          ? [newProperties
              objectForKey: MAPIPropertyKey (PR_LAST_MODIFICATION_TIME)]
          : [super lastModificationTime]);
}

@end
