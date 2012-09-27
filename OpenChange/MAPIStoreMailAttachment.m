/* MAPIStoreMailAttachment.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
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
      bodyPart = nil;
    }

  return self;
}

- (void) dealloc
{
  [bodyInfo release];
  [bodyPart release];
  [super dealloc];
}

- (void) setBodyInfo: (NSDictionary *) newBodyInfo
{
  ASSIGN (bodyInfo, newBodyInfo);
}

- (void) setBodyPart: (SOGoMailBodyPart *) newBodyPart
{
  ASSIGN (bodyPart, newBodyPart);
}

- (int) getPidTagAttachMethod: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x00000001); // afByValue

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAttachTag: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[self mimeAttachTag] asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAttachSize: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  uint32_t longValue;

  longValue = [[bodyInfo objectForKey: @"size"] longValue];
  *data = MAPILongValue (memCtx, longValue);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagRecordKey: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  static char recordBytes[] = {0xd9, 0xd8, 0x11, 0xa3, 0xe2, 0x90, 0x18, 0x41,
                               0x9e, 0x04, 0x58, 0x46, 0x9d, 0x6d, 0x1b,
                               0x68};
  
  *data = [[NSData dataWithBytes: recordBytes length: 16]
            asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (NSString *) _fileName
{
  NSString *fileName;
  NSDictionary *parameters;

  fileName = [[bodyInfo objectForKey: @"parameterList"]
               objectForKey: @"name"];
  if (!fileName)
    {
      parameters = [[bodyInfo objectForKey: @"disposition"]
                     objectForKey: @"parameterList"];
      fileName = [parameters objectForKey: @"filename"];
    }

  return fileName;
}

- (int) getPidTagAttachLongFilename: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[self _fileName] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAttachFilename: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *fileName, *baseName, *ext;

  fileName = [self _fileName];
  baseName = [fileName stringByDeletingPathExtension];
  if ([baseName length] > 8)
    baseName = [baseName substringToIndex: 8];

  ext = [fileName pathExtension];
  if ([ext length] > 3)
    ext = [ext substringToIndex: 3];
  fileName = [NSString stringWithFormat: @"%@.%@", baseName, ext];

  *data = [fileName asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagDisplayName: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[bodyInfo objectForKey: @"description"]
            asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAttachContentId: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{ 
  *data = [[bodyInfo objectForKey: @"bodyId"]
            asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAttachMimeTag: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *mimeTag;

  mimeTag = [NSString stringWithFormat: @"%@/%@",
                [bodyInfo objectForKey: @"type"],
                [bodyInfo objectForKey: @"subtype"]];
  *data = [[mimeTag lowercaseString] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAttachDataBinary: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[bodyPart fetchBLOBWithPeek: YES] asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

@end
