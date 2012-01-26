/* MAPIStoreMailContext.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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

#import <Foundation/NSString.h>

#import "MAPIStoreMailFolder.h"
#import "MAPIStoreMapping.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMailContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>

@implementation MAPIStoreMailContext

+ (NSString *) MAPIModuleName
{
  return nil;
}

+ (enum mapistore_context_role) contextRole
{
  return MAPISTORE_MAIL_ROLE;
}

@end

@implementation MAPIStoreInboxContext

+ (NSString *) MAPIModuleName
{
  return @"inbox";
}

+ (struct mapistore_contexts_list *) listContextsForUser: (NSString *) userName
                                                inMemCtx: (TALLOC_CTX *) memCtx
{
  struct mapistore_contexts_list *context;
  NSString *url;

  context = talloc_zero(memCtx, struct mapistore_contexts_list);
  url = [NSString stringWithFormat: @"sogo://%@:%@@%@/", userName, userName, [self MAPIModuleName]];
  context->url = [url asUnicodeInMemCtx: context];
  // context->name = "Inbox";
  context->main_folder = true;
  context->role = [self contextRole];
  context->tag = "tag";
  context->prev = context;

  return context;
}

- (void) setupBaseFolder: (NSURL *) newURL
{
  baseFolder = [MAPIStoreInboxFolder baseFolderWithURL: newURL
                                             inContext: self];
  [baseFolder retain];
}

@end

@implementation MAPIStoreSentItemsContext

+ (NSString *) MAPIModuleName
{
  return @"sent-items";
}

+ (enum mapistore_context_role) contextRole
{
  return MAPISTORE_SENTITEMS_ROLE;
}

- (void) setupBaseFolder: (NSURL *) newURL
{
  baseFolder = [MAPIStoreSentItemsFolder baseFolderWithURL: newURL
                                                 inContext: self];
  [baseFolder retain];
}

@end

@implementation MAPIStoreDraftsContext

+ (NSString *) MAPIModuleName
{
  return @"drafts";
}

+ (enum mapistore_context_role) contextRole
{
  return MAPISTORE_DRAFTS_ROLE;
}

- (void) setupBaseFolder: (NSURL *) newURL
{
  baseFolder = [MAPIStoreDraftsFolder baseFolderWithURL: newURL
                                              inContext: self];
  [baseFolder retain];
}

@end

#import "MAPIStoreFSFolder.h"

@implementation MAPIStoreDeletedItemsContext

+ (NSString *) MAPIModuleName
{
  return @"deleted-items";
}

+ (enum mapistore_context_role) contextRole
{
  return MAPISTORE_DELETEDITEMS_ROLE;
}

- (void) setupBaseFolder: (NSURL *) newURL
{
  baseFolder = [MAPIStoreFSFolder baseFolderWithURL: newURL inContext: self];
  [baseFolder retain];
}

// - (void) setupBaseFolder: (NSURL *) newURL
// {
//   baseFolder = [MAPIStoreDeletedItemsFolder baseFolderWithURL: newURL
//                                                     inContext: self];
//   [baseFolder retain];
// }

@end

@implementation MAPIStoreOutboxContext

+ (NSString *) MAPIModuleName
{
  return @"outbox";
}

+ (enum mapistore_context_role) contextRole
{
  return MAPISTORE_OUTBOX_ROLE;
}

- (void) setupBaseFolder: (NSURL *) newURL
{
  baseFolder = [MAPIStoreOutboxFolder baseFolderWithURL: newURL
                                              inContext: self];
  [baseFolder retain];
}

@end
