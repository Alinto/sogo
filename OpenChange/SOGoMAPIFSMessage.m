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
    }

  return self;
}

- (void) dealloc
{
  [properties release];
  [super dealloc];
}

- (NSDictionary *) properties
{
  NSString *filePath;

  if (!properties)
    {
      filePath = [[container directory]
		   stringByAppendingPathComponent: nameInContainer];
      properties = [[NSMutableDictionary alloc]
		     initWithContentsOfFile: filePath];
    }

  return properties;
}

- (void) setMAPIProperties: (NSDictionary *) newProperties
{
  NSArray *keys;
  NSString *key;
  int i, count;
  
  // We ensure the current properties are loaded
  [self properties];
  
  // We merge the changes
  keys = [newProperties allKeys];
  count = [keys count];
  for (i = 0; i < count; i++)
    {
      key = [keys objectAtIndex: i];
      [properties setObject: [newProperties objectForKey: key]
                     forKey: key];
    }
}

- (void) MAPISave
{
  NSArray *pathComponents;
  NSString *filePath;

  [self logWithFormat: @"-MAPISave"];

  [container ensureDirectory];

  filePath = [[container directory]
	       stringByAppendingPathComponent: nameInContainer];

  // FIXME
  // We do NOT save the FAI data for the Inbox, as upon the 
  // next Outlook restart, when restoring those saved properties,
  // Outlook will crash. 
  pathComponents = [filePath pathComponents];
  if ([[pathComponents objectAtIndex: [pathComponents count]-2] isEqualToString: @"inbox"])
    {
      [self logWithFormat: @"-MAPISave - skipping FAI at path %@", filePath];
      return;
    }

  if (![properties writeToFile: filePath atomically: YES])
    [NSException raise: @"MAPIStoreIOException"
		 format: @"could not save message"];
}

- (NSString *) davEntityTag
{
  NSDictionary *attributes;
  NSFileManager *fm;
  NSString *filePath;

  fm = [NSFileManager defaultManager];

  filePath = [[container directory]
	       stringByAppendingPathComponent: nameInContainer];
  attributes = [fm fileAttributesAtPath: filePath traverseLink: NO];

  return [NSString stringWithFormat: @"%p", attributes];
}

- (NSException *) delete
{
  NSFileManager *fm;
  NSString *filePath;
  
  fm = [NSFileManager defaultManager];

  filePath = [[container directory]
	       stringByAppendingPathComponent: nameInContainer];

  if (![fm removeFileAtPath: filePath  handler: NULL])
    [NSException raise: @"MAPIStoreIOException"
		 format: @"could not delete message"];

  return nil;
}

@end
