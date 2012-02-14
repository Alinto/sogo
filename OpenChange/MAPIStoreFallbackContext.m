/* MAPIStoreFallbackContext.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc.
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
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import "MAPIStoreUserContext.h"
#import "NSString+MAPIStore.h"
#import "SOGoMAPIFSFolder.h"

#import "MAPIStoreFallbackContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>

@implementation MAPIStoreFallbackContext

+ (NSString *) MAPIModuleName
{
  return @"fallback";
}

+ (enum mapistore_context_role) MAPIContextRole
{
  return MAPISTORE_MAIL_ROLE;
}

+ (struct mapistore_contexts_list *) listContextsForUser: (NSString *)  userName
                                         withTDBIndexing: (struct tdb_wrap *) indexingTdb
                                                inMemCtx: (TALLOC_CTX *) memCtx
{
  struct mapistore_contexts_list *firstContext = NULL, *context;
  SOGoMAPIFSFolder *root;
  NSArray *names;
  NSUInteger count, max;
  NSString *baseURL, *url, *name;

  baseURL = [NSString stringWithFormat: @"sogo://%@@fallback/", userName];

  context = talloc_zero (memCtx, struct mapistore_contexts_list);
  context->url = [baseURL asUnicodeInMemCtx: context];
  context->name = "Fallback";
  context->main_folder = true;
  context->role = MAPISTORE_FALLBACK_ROLE;
  context->tag = "tag";

  DLIST_ADD_END (firstContext, context, void);


  /* Maybe emsmdbp_provisioning should be fixed in order to only take the uri
     returned above to avoid deleting its entries... */
  root = [SOGoMAPIFSFolder folderWithURL: [NSURL URLWithString: baseURL]
                            andTableType: MAPISTORE_MESSAGE_TABLE];
  names = [root toManyRelationshipKeys];
  max = [names count];
  for (count = 0; count < max; count++)
    {
      name = [names objectAtIndex: count];
      url = [NSString stringWithFormat: @"%@%@/", baseURL, name];
      context = talloc_zero (memCtx, struct mapistore_contexts_list);
      context->url = [url asUnicodeInMemCtx: context];
      context->name = [name asUnicodeInMemCtx: context];
      context->main_folder = false;
      context->role = MAPISTORE_FALLBACK_ROLE;
      context->tag = "tag";
      DLIST_ADD_END (firstContext, context, void);
    }

  return firstContext;
}

+ (NSString *)
 createRootSecondaryFolderWithFID: (uint64_t) fid
                          andName: (NSString *) folderName
                          forUser: (NSString *) userName
{
  return [NSString stringWithFormat: @"sogo://%@@fallback/0x%.16"PRIx64"/",
                   userName, (unsigned long long) fid];
}

@end
