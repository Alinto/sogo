/* MAPIStoreCalendarContext.m - this file is part of SOGo
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

#import "MAPIStoreMapping.h"
#import "MAPIStoreCalendarFolder.h"

#import "MAPIStoreCalendarContext.h"

@implementation MAPIStoreCalendarContext

+ (NSString *) MAPIModuleName
{
  return @"calendar";
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@calendar/"
                withID: 0x190001];
}

- (void) setupBaseFolder: (NSURL *) newURL
{
  baseFolder = [MAPIStoreCalendarFolder baseFolderWithURL: newURL
                                                inContext: self];
  [baseFolder retain];
}


- (int) readCount: (uint32_t *) rowCount
      ofTableType: (uint8_t) tableType
            inFID: (uint64_t) fid
{
  return [super readCount: rowCount ofTableType: tableType inFID: fid];
}

@end
