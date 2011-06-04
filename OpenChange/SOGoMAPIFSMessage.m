/* SOGoMAPIFSMessage.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>

#import "SOGoMAPIFSFolder.h"

#import "SOGoMAPIFSMessage.h"

@implementation SOGoMAPIFSMessage

- (id) init
{
  if ((self = [super init]))
    {
      properties = nil;
      completeFilename = nil;
    }

  return self;
}

- (void) dealloc
{
  [properties release];
  [completeFilename release];
  [super dealloc];
}

- (NSString *) completeFilename
{
  if (!completeFilename)
    {
      completeFilename = [[container directory]
                           stringByAppendingPathComponent: nameInContainer];
      [completeFilename retain];
    }

  return completeFilename;
}

- (NSDictionary *) properties
{
  if (!properties)
    {
      properties = [[NSMutableDictionary alloc]
		     initWithContentsOfFile: [self completeFilename]];
      if (!properties)
        properties = [NSMutableDictionary new];
    }

  return properties;
}

- (void) appendProperties: (NSDictionary *) newProperties
{
  // We ensure the current properties are loaded
  [self properties];
  
  // We merge the changes
  [properties addEntriesFromDictionary: newProperties];
}

- (void) save
{
  [container ensureDirectory];

  if (![properties writeToFile: [self completeFilename] atomically: YES])
    [NSException raise: @"MAPIStoreIOException"
		 format: @"could not save message"];
}

- (NSString *) davEntityTag
{
  NSCalendarDate *lm;

  lm = [self lastModificationTime];

  return [NSString stringWithFormat: @"%d", (int) [lm timeIntervalSince1970]];
}

- (NSException *) delete
{
  NSFileManager *fm;
  
  fm = [NSFileManager defaultManager];

  if (![fm removeFileAtPath: [self completeFilename] handler: NULL])
    [NSException raise: @"MAPIStoreIOException"
		 format: @"could not delete message"];

  return nil;
}

- (id) _fileAttributeForKey: (NSString *) key
{
  NSDictionary *attributes;

  attributes = [[NSFileManager defaultManager]
               fileAttributesAtPath: [self completeFilename]
                       traverseLink: NO];

  return [attributes objectForKey: key];
}

- (NSCalendarDate *) creationTime
{
  return [self _fileAttributeForKey: NSFileCreationDate];
}

- (NSCalendarDate *) lastModificationTime
{
  return [self _fileAttributeForKey: NSFileModificationDate];
}

@end
