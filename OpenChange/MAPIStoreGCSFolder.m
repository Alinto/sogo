/* MAPIStoreGCSFolder.m - this file is part of SOGo
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
#import <EOControl/EOQualifier.h>
#import <EOControl/EOFetchSpecification.h>
#import <GDLContentStore/GCSFolder.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoGCSFolder.h>

#import "MAPIStoreGCSFolder.h"

@implementation MAPIStoreGCSFolder

- (NSArray *) childKeysMatchingQualifier: (EOQualifier *) qualifier
                        andSortOrderings: (NSArray *) sortOrderings
{
  static NSArray *fields = nil;
  NSArray *records;
  EOQualifier *componentQualifier, *fetchQualifier;
  GCSFolder *ocsFolder;
  EOFetchSpecification *fs;
  NSArray *keys;

  if (!fields)
    fields = [[NSArray alloc]
	       initWithObjects: @"c_name", @"c_version", nil];

  componentQualifier = [self componentQualifier];
  if (qualifier)
    {
      fetchQualifier = [[EOAndQualifier alloc]
                         initWithQualifiers:
                           componentQualifier,
                         qualifier,
                         nil];
      [fetchQualifier autorelease];
    }
  else
    fetchQualifier = componentQualifier;
    
  ocsFolder = [sogoObject ocsFolder];
  fs = [EOFetchSpecification
         fetchSpecificationWithEntityName: [ocsFolder folderName]
                                qualifier: fetchQualifier
                            sortOrderings: sortOrderings];
  records = [ocsFolder fetchFields: fields fetchSpecification: fs];
  keys = [records objectsForKey: @"c_name"
                 notFoundMarker: nil];

  return keys;
}

/* subclasses */

- (EOQualifier *) componentQualifier
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end
