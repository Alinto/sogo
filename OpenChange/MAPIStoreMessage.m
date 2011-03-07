/* MAPIStoreMessage.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/SOGoObject.h>

#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>

@interface SOGoObject (MAPIStoreProtocol)

- (NSString *) davEntityTag;
- (NSString *) davContentLength;

@end

@implementation MAPIStoreMessage

- (id) init
{
  if ((self = [super init]))
    {
      mapiRetainCount = 0;
      attachmentKeys = nil;
      attachmentParts = nil;
      activeTables = [NSMutableArray new];
    }

  return self;
}

- (void) dealloc
{
  [attachmentKeys release];
  [attachmentParts release];
  [activeTables release];
  [super dealloc];
}

- (void) setMAPIRetainCount: (uint32_t) newCount
{
  mapiRetainCount = newCount;
}

- (uint32_t) mapiRetainCount
{
  return mapiRetainCount;
}

- (void) openMessage: (struct mapistore_message *) msg
{
  static enum MAPITAGS tags[] = { PR_SUBJECT_PREFIX_UNICODE,
                                  PR_NORMALIZED_SUBJECT_UNICODE };
  struct SRowSet *recipients;
  struct SRow *properties;
  NSInteger count, max;
  const char *propName;
  void *propValue;

  // [self logWithFormat: @"INCOMPLETE METHOD '%s' (%d): no recipient handling",
  //       __FUNCTION__, __LINE__];

  recipients = talloc_zero (memCtx, struct SRowSet);
  recipients->cRows = 0;
  recipients->aRow = NULL;
  msg->recipients = recipients;

  max = 2;
  properties = talloc_zero (memCtx, struct SRow);
  properties->cValues = 0;
  properties->ulAdrEntryPad = 0;
  properties->lpProps = talloc_array (properties, struct SPropValue, max);
  for (count = 0; count < max; count++)
    {
      if ([self getProperty: &propValue withTag: tags[count]]
          == MAPI_E_SUCCESS)
	{
	  if (propValue == NULL)
	    {
	      propName = get_proptag_name (tags[count]);
	      if (!propName)
		propName = "<unknown>";
	      [self errorWithFormat: @"both 'success' and NULL data"
		    @" returned for proptag %s(0x%.8x)",
		    propName, tags[count]];
	    }
	  else
	    {
	      set_SPropValue_proptag (properties->lpProps + properties->cValues,
				      tags[count],
				      propValue);
	      properties->cValues++;
	    }
	}
    }
  msg->properties = properties;
}

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag
{
  int rc;
  NSString *stringValue;
  NSUInteger length;

  rc = MAPI_E_SUCCESS;
  switch (propTag)
    {
    case PR_INST_ID: // TODO: DOUBT
      /* we return a unique id based on the key */
      *data = MAPILongLongValue (memCtx, [[sogoObject nameInContainer] hash]);
      break;
    case PR_INSTANCE_NUM: // TODO: DOUBT
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_ROW_TYPE: // TODO: DOUBT
      *data = MAPILongValue (memCtx, TBL_LEAF_ROW);
      break;
    case PR_DEPTH: // TODO: DOUBT
      *data = MAPILongLongValue (memCtx, 0);
      break;
    case PR_ACCESS: // TODO
      *data = MAPILongValue (memCtx, 0x03);
      break;
    case PR_ACCESS_LEVEL: // TODO
      *data = MAPILongValue (memCtx, 0x01);
      break;
    case PR_VIEW_STYLE:
    case PR_VIEW_MAJORVERSION:
      *data = MAPILongValue (memCtx, 0);
      break;
    case PidLidSideEffects: // TODO
      *data = MAPILongValue (memCtx, 0x00000000);
      break;
    case PidLidCurrentVersion:
      *data = MAPILongValue (memCtx, 115608); // Outlook 11.5608
      break;
    case PidLidCurrentVersionName:
      *data = [@"11.0" asUnicodeInMemCtx: memCtx];
      break;
    case PidLidAutoProcessState:
      *data = MAPILongValue (memCtx, 0x00000000);
      break;
    case PidNameContentClass:
      *data = [@"Sharing" asUnicodeInMemCtx: memCtx];
      break;
    case PR_FID:
      *data = MAPILongLongValue (memCtx, [container objectId]);
      break;
    case PR_MID:
      *data = MAPILongLongValue (memCtx, [self objectId]);
      break;
    case PR_MESSAGE_LOCALE_ID:
      *data = MAPILongValue (memCtx, 0x0409);
      break;
    case PR_MESSAGE_FLAGS: // TODO
      *data = MAPILongValue (memCtx, MSGFLAG_FROMME | MSGFLAG_READ | MSGFLAG_UNMODIFIED);
      break;
    case PR_MESSAGE_SIZE: // TODO
      /* TODO: choose another name in SOGo for that method */
      *data = MAPILongValue (memCtx, [[sogoObject davContentLength] intValue]);
      break;
    case PR_MSG_STATUS: // TODO
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_IMPORTANCE: // TODO -> subclass?
      *data = MAPILongValue (memCtx, 1);
      break;
    case PR_PRIORITY: // TODO -> subclass?
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_SENSITIVITY: // TODO -> subclass in calendar
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_CHANGE_KEY:
      stringValue = [sogoObject davEntityTag];
      if (stringValue)
        {
          stringValue = @"-1";
          length = [stringValue length];
          if (length < 6) /* guid = 16 bytes */
            {
              length += 6;
              stringValue = [NSString stringWithFormat: @"000000%@",
                                      stringValue];
            }
          if (length > 6)
            stringValue = [stringValue substringFromIndex: length - 6];
          stringValue = [NSString stringWithFormat: @"SOGo%@%@%@",
                                  stringValue, stringValue, stringValue];
          *data = [[stringValue dataUsingEncoding: NSASCIIStringEncoding]
                    asShortBinaryInMemCtx: memCtx];
        }
      else
        rc = MAPISTORE_ERR_NOT_FOUND;
      break;

    case PR_ORIGINAL_SUBJECT_UNICODE:
    case PR_CONVERSATION_TOPIC_UNICODE:
      rc = [self getProperty: data withTag: PR_NORMALIZED_SUBJECT_UNICODE];
      break;

    case PR_SUBJECT_PREFIX_UNICODE:
      *data = [@"" asUnicodeInMemCtx: memCtx];
      break;
    case PR_NORMALIZED_SUBJECT_UNICODE:
      rc = [self getProperty: data withTag: PR_SUBJECT_UNICODE];
      break;

    case PR_DISPLAY_TO_UNICODE:
    case PR_DISPLAY_CC_UNICODE:
    case PR_DISPLAY_BCC_UNICODE:
    case PR_ORIGINAL_DISPLAY_TO_UNICODE:
    case PR_ORIGINAL_DISPLAY_CC_UNICODE:
    case PR_ORIGINAL_DISPLAY_BCC_UNICODE:
      *data = [@"" asUnicodeInMemCtx: memCtx];
      break;
    case PR_LAST_MODIFIER_NAME_UNICODE:
      *data = [@"openchange" asUnicodeInMemCtx: memCtx];
      break;

    case PR_ORIG_MESSAGE_CLASS_UNICODE:
      rc = [self getProperty: data withTag: PR_MESSAGE_CLASS_UNICODE];
      break;

    default:
      rc = [super getProperty: data withTag: propTag];
    }

  return rc;
}

- (void) save
{
  [self subclassResponsibility: _cmd];
}

- (void) submit
{
  [self subclassResponsibility: _cmd];
}

- (MAPIStoreAttachment *) createAttachment
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (MAPIStoreAttachmentTable *) attachmentTable
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (void) addActiveTable: (MAPIStoreTable *) activeTable
{
  [activeTables addObject: activeTable];
}

- (void) removeActiveTable: (MAPIStoreTable *) activeTable
{
  [activeTables removeObject: activeTable];
}

@end
