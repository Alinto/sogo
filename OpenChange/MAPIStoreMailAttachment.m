/* MAPIStoreMailAttachment.m - this file is part of SOGo
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
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/NSArray+Utilities.h>
#import <Mailer/SOGoMailBodyPart.h>
#import <Mailer/SOGoMailObject.h>

#import "MAPIStoreTypes.h"
#import "MAPIStoreMailMessage.h"
#import "NSData+MAPIStore.h"
#import "NSDate+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMailAttachment.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreMailAttachment

- (id) init
{
  if ((self = [super init]))
    {
      bodyInfo = nil;
    }

  return self;
}

- (void) dealloc
{
  [bodyInfo release];
  [super dealloc];
}

- (void) setBodyInfo: (NSDictionary *) newBodyInfo
{
  ASSIGN (bodyInfo, newBodyInfo);
}

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag
           inMemCtx: (TALLOC_CTX *) localMemCtx
{
  static char recordBytes[] = {0xd9, 0xd8, 0x11, 0xa3, 0xe2, 0x90, 0x18, 0x41,
                               0x9e, 0x04, 0x58, 0x46, 0x9d, 0x6d, 0x1b, 0x68};
  uint32_t longValue;
  NSString *stringValue;
  NSCalendarDate *date;
  NSDictionary *parameters;
  int rc;

  rc = MAPISTORE_SUCCESS;
  switch (propTag)
    {
    case PR_ATTACH_METHOD:
      *data = MAPILongValue (localMemCtx, 0x00000001); // afByValue
      break;
    case PR_ATTACH_TAG:
      *data = [[self mimeAttachTag]
		asBinaryInMemCtx: localMemCtx];
      break;
    case PR_ATTACH_SIZE:
      longValue = [[bodyInfo objectForKey: @"size"] longValue];
      *data = MAPILongValue (localMemCtx, longValue);
      break;

    case PR_RECORD_KEY:
      *data = [[NSData dataWithBytes: recordBytes length: 16]
		asBinaryInMemCtx: localMemCtx];
      break;
      
      // PR_RECORD_KEY (0xFF90102)                             D9 D8 11 A3 E2 90 18 41 9E 04 58 46 9D 6D 1B 68

    case PR_ATTACH_LONG_FILENAME_UNICODE:
    case PR_ATTACH_FILENAME_UNICODE:
      stringValue = [[bodyInfo objectForKey: @"parameterList"]
                      objectForKey: @"name"];
      if (!stringValue)
        {
          parameters = [[bodyInfo objectForKey: @"disposition"]
                         objectForKey: @"parameterList"];
          stringValue = [parameters objectForKey: @"filename"];
        }

      if (propTag == PR_ATTACH_FILENAME_UNICODE)
        {
          NSString *baseName, *ext;

          baseName = [stringValue stringByDeletingPathExtension];
          if ([baseName length] > 8)
            baseName = [baseName substringToIndex: 8];

          ext = [stringValue pathExtension];
          if ([ext length] > 3)
            ext = [ext substringToIndex: 3];
          stringValue = [NSString stringWithFormat: @"%@.%@", baseName, ext];
        }

      *data = [stringValue asUnicodeInMemCtx: localMemCtx];
      break;

    case PR_DISPLAY_NAME_UNICODE: /* TODO: check if description ? */
      stringValue = [bodyInfo objectForKey: @"description"];
      *data = [stringValue asUnicodeInMemCtx: localMemCtx];
      break;

    case PR_ATTACH_CONTENT_ID_UNICODE:
      stringValue = [bodyInfo objectForKey: @"bodyId"];
      *data = [stringValue asUnicodeInMemCtx: localMemCtx];
      break;

    case PR_ATTACH_MIME_TAG_UNICODE:
      stringValue = [NSString stringWithFormat: @"%@/%@",
                              [bodyInfo objectForKey: @"type"],
                              [bodyInfo objectForKey: @"subtype"]];
      *data = [[stringValue lowercaseString] asUnicodeInMemCtx: localMemCtx];
      break;

    case PR_CREATION_TIME:
    case PR_LAST_MODIFICATION_TIME:
      date = [[container sogoObject] date];
      *data = [date asFileTimeInMemCtx: localMemCtx];
      break;

    case PR_ATTACH_DATA_BIN:
      *data = [[sogoObject fetchBLOB] asBinaryInMemCtx: localMemCtx];
      break;

    default:
      rc = [super getProperty: data withTag: propTag inMemCtx: localMemCtx];
    }

  return rc;
}

@end
