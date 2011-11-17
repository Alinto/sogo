/* MAPIStoreSamDBUtils.m - this file is part of SOGo
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

#import <Foundation/NSString.h>
#include <talloc.h>
#include <ldb.h>

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
