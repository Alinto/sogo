/* MAPIStoreGCSBaseContext.m - this file is part of SOGo
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
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <EOControl/EOQualifier.h>

#import <GDLContentStore/GCSFolder.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoGCSFolder.h>

#import "MAPIStoreGCSBaseContext.h"

@implementation MAPIStoreGCSBaseContext

+ (NSString *) MAPIModuleName
{
  return nil;
}

- (NSArray *) getFolderMessageKeys: (SOGoFolder *) folder
		 matchingQualifier: (EOQualifier *) qualifier
{
  NSArray *records;
  static NSArray *fields = nil;

  if (!fields)
    fields = [[NSArray alloc]
	       initWithObjects: @"c_name", @"c_version", nil];

  records = [[(SOGoGCSFolder *) folder ocsFolder]
	      fetchFields: fields matchingQualifier: qualifier];

  return [records objectsForKey: @"c_name"
		 notFoundMarker: nil];
}

@end
