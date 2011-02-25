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

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@inbox/"
		withID: 0x160001];
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

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@sent-items/"
                withID: 0x140001];
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

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@inbox/"
		withID: 0x1e0001];
}

- (void) setupBaseFolder: (NSURL *) newURL
{
  baseFolder = [MAPIStoreDraftsFolder baseFolderWithURL: newURL
                                              inContext: self];
  [baseFolder retain];
}

@end

@implementation MAPIStoreDeletedItemsContext

+ (NSString *) MAPIModuleName
{
  return @"deleted-items";
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@deleted-items/"
                withID: 0x170001];
}

- (void) setupBaseFolder: (NSURL *) newURL
{
  baseFolder = [MAPIStoreDeletedItemsFolder baseFolderWithURL: newURL
                                                    inContext: self];
  [baseFolder retain];
}

@end

@implementation MAPIStoreOutboxContext

+ (NSString *) MAPIModuleName
{
  return @"outbox";
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@outbox/"
                withID: 0x150001];
}

- (void) setupBaseFolder: (NSURL *) newURL
{
  baseFolder = [MAPIStoreOutboxFolder baseFolderWithURL: newURL
                                              inContext: self];
  [baseFolder retain];
}

@end

@implementation MAPIStoreSpoolerContext

+ (NSString *) MAPIModuleName
{
  return @"spooler";
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@spooler/"
                withID: 0x120001];
}

@end
