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
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <Mailer/SOGoDraftObject.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreDraftsAttachment.h"
#import "MAPIStoreTypes.h"

#import "MAPIStoreDraftsMessage.h"

#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreDraftsMessage

- (id) init
{
  if ((self = [super init]))
    {
      attachmentKeys = [NSMutableArray new];
      attachmentParts = [NSMutableDictionary new];
    }

  return self;
}

- (int) getPrMessageFlags: (void **) data
{
  unsigned int v = MSGFLAG_FROMME;

  if ([[self childKeysMatchingQualifier: nil
                       andSortOrderings: nil] count] > 0)
    v |= MSGFLAG_HASATTACH;
    
  *data = MAPILongValue (memCtx, v);

  return MAPISTORE_SUCCESS;
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

  max = [attachmentKeys count];
  for (count = 0; count < max; count++)
    [self _saveAttachment: [attachmentKeys objectAtIndex: count]];
}

- (MAPIStoreAttachment *) createAttachment
{
  MAPIStoreDraftsAttachment *newAttachment;
  uint32_t newAid;
  NSString *newKey;

  newAid = [attachmentKeys count];

  newAttachment = [MAPIStoreDraftsAttachment
                    mapiStoreObjectWithSOGoObject: nil
                                      inContainer: self];
  [newAttachment setIsNew: YES];
  [newAttachment setAID: newAid];
  newKey = [NSString stringWithFormat: @"%ul", newAid];
  [attachmentParts setObject: newAttachment
                      forKey: newKey];
  [attachmentKeys addObject: newKey];

  return newAttachment;
}

- (NSArray *) childKeysMatchingQualifier: (EOQualifier *) qualifier
                        andSortOrderings: (NSArray *) sortOrderings
{
  if (qualifier)
    [self errorWithFormat: @"qualifier is not used for attachments"];
  if (sortOrderings)
    [self errorWithFormat: @"sort orderings are not used for attachments"];
  
  return attachmentKeys;
}

- (id) lookupChild: (NSString *) childKey
{
  return [attachmentParts objectForKey: childKey];
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

- (void) save
{
  NSString *msgClass;

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

- (NSCalendarDate *) creationTime
{
  return [newProperties objectForKey: MAPIPropertyKey (PR_CREATION_TIME)];
}

- (NSCalendarDate *) lastModificationTime
{
  return [newProperties objectForKey: MAPIPropertyKey (PR_LAST_MODIFICATION_TIME)];
}

@end
