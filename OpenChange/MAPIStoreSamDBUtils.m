/* MAPIStoreSamDBUtils.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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

#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#include <talloc.h>
#include <ldb.h>

#import "NSData+MAPIStore.h"

#import "MAPIStoreSamDBUtils.h"

NSString *
MAPIStoreSamDBUserAttribute (struct ldb_context *samCtx,
                             NSString *userKey,
                             NSString *value,
                             NSString *attributeName)
{
  NSString *resultValue = nil;
  const char *attrs[] = { "", NULL };
  NSString *searchFormat;
  const char *result;
  struct ldb_result *res = NULL;
  TALLOC_CTX *memCtx;
  int ret;

  memCtx = talloc_zero(NULL, TALLOC_CTX);

  attrs[0] = [attributeName UTF8String];
  searchFormat
    = [NSString stringWithFormat: @"(&(objectClass=user)(%@=%%s))", userKey];
  ret = ldb_search (samCtx, memCtx, &res, ldb_get_default_basedn(samCtx),
                    LDB_SCOPE_SUBTREE, attrs,
                    [searchFormat UTF8String],
                    [value UTF8String]);
  if (ret == LDB_SUCCESS && res->count == 1)
    {
      result = ldb_msg_find_attr_as_string (res->msgs[0], attrs[0], NULL);
      if (result)
        resultValue = [NSString stringWithUTF8String: result];
    }

  talloc_free (memCtx);

  return resultValue;
}

NSData *
MAPIStoreInternalEntryId (struct ldb_context *samCtx, NSString *username)
{
  static const uint8_t const providerUid[] = { 0xdc, 0xa7, 0x40, 0xc8,
                                               0xc0, 0x42, 0x10, 0x1a,
                                               0xb4, 0xb9, 0x08, 0x00,
                                               0x2b, 0x2f, 0xe1, 0x82 };
  NSMutableData *entryId;
  NSData *legacyDNData;
  NSString *legacyDN;

  /* structure:
     flags: 32
     provideruid: 32 * 4
     version: 32
     type: 32
     X500DN: variable */

  legacyDN = MAPIStoreSamDBUserAttribute (samCtx, @"sAMAccountName", username,
                                          @"legacyExchangeDN");
  if (legacyDN)
    {
      entryId = [NSMutableData dataWithCapacity: 256];
      [entryId appendUInt32: 0]; // flags
      [entryId appendBytes: providerUid length: 16]; // provideruid
      [entryId appendUInt32: 1]; // version
      [entryId appendUInt32: 0]; // type (local mail user)
      legacyDNData = [legacyDN dataUsingEncoding: NSASCIIStringEncoding];
      [entryId appendData: legacyDNData]; // x500dn
      [entryId appendUInt8: 0]; // end of string
    }
  else
    entryId = nil;
 
  return entryId;
}

NSData *
MAPIStoreExternalEntryId (NSString *cn, NSString *email)
{
  NSMutableData *entryId;
  static uint8_t providerUid[] = { 0x81, 0x2b, 0x1f, 0xa4,
                                   0xbe, 0xa3, 0x10, 0x19,
                                   0x9d, 0x6e, 0x00, 0xdd,
                                   0x01, 0x0f, 0x54, 0x02 };
  uint8_t flags21, flags22;

  /* structure:
     flags: 32
     provideruid: 32 * 4
     version: 16
     {
       PaD: 1
       MAE: 2
       Format: 4
       M: 1
       U: 1
       R: 2
       L: 1
       Pad: 4
     }
     DisplayName: variable
     AddressType: variable
     EmailAddress: variable */

  entryId = [NSMutableData dataWithCapacity: 256];
  [entryId appendUInt32: 0]; // flags
  [entryId appendBytes: providerUid length: 16]; // provideruid
  [entryId appendUInt16: 0]; // version

  flags21 = 0;          /* PaD, MAE, R, Pad = 0 */
  flags21 |= 0x16;      /* Format: text and HTML */
  flags21 |= 0x01;     /* M: mime format */

  flags22 = 0x90;      /* U: unicode, L: no lookup */
  [entryId appendUInt8: flags21];
  [entryId appendUInt8: flags22];

  /* DisplayName */
  if (!cn)
    cn = @"";
  [entryId
    appendData: [cn dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  [entryId appendUInt16: 0];

  /* AddressType */
  [entryId
    appendData: [@"SMTP" dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  [entryId appendUInt16: 0];

  /* EMailAddress */
  if (!email)
    email = @"";
  [entryId
    appendData: [email dataUsingEncoding: NSUTF16LittleEndianStringEncoding]];
  [entryId appendUInt16: 0];

  return entryId;
}
