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

#import "MAPIStoreMailContext.h"

@implementation MAPIStoreMailContext

+ (NSString *) MAPIModuleName
{
  return nil;
}

@end

@implementation MAPIStoreInboxContext

+ (NSString *) MAPIModuleName
{
  return @"inbox";
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

- (void) setupBaseFolder: (NSURL *) newURL
{
  baseFolder = [MAPIStoreOutboxFolder baseFolderWithURL: newURL
                                              inContext: self];
  [baseFolder retain];
}

@end
