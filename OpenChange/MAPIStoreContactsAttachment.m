/* MAPIStoreContactsAttachment.m - this file is part of SOGo
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
#import <Foundation/NSString.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGCards/NGVCardPhoto.h>

#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSDate+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreContactsAttachment.h"

#include <mapistore/mapistore_errors.h>

extern NSTimeZone *utcTZ;

/* TODO: handle URL pictures via PidTagAttachMethod = ref ? */

@implementation MAPIStoreContactsAttachment

- (id) init
{
  if ((self = [super init]))
    {
      photo = nil;
      photoData = nil;
    }

  return self;
}

- (void) dealloc
{
  [photo release];
  [photoData release];
  [super dealloc];
}

- (void) setPhoto: (NGVCardPhoto *) newPhoto
{
  ASSIGN (photo, newPhoto);
}

- (NSString *) fileExtension
{
  NSString *type, *extension;

  type = [photo type];
  if ([type isEqualToString: @"JPEG"]
      || [type isEqualToString: @"JPG"])
    extension = @".jpg";
  else if ([type isEqualToString: @"PNG"])
    extension = @".png";
  else if ([type isEqualToString: @"BMP"])
    extension = @".bmp";
  else if ([type isEqualToString: @"GIF"])
    extension = @".gif";
  else
    extension = nil;

  return extension;
}

- (NSDate *) creationTime
{
  return [container creationTime];
}

- (NSDate *) lastModificationTime
{
  return [container lastModificationTime];
}

- (int) getPrAttachMethod: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x00000001);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAttachmentContactphoto: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPrAttachDataBin: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!photoData)
    ASSIGN (photoData, [[photo value: 0] dataByDecodingBase64]);

  *data = [photoData asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrAttachExtension: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[self fileExtension] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrAttachLongFilename: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *filename;

  filename = [NSString stringWithFormat: @"ContactPhoto%@",
                       [self fileExtension]];

  *data = [filename asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrAttachFilename: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrAttachLongFilename: data
                              inMemCtx: memCtx];
}

- (int) getPrDisplayName: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrAttachLongFilename: data inMemCtx: memCtx];
}

@end
