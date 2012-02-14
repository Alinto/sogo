/* SOGoParentFolder.h - this file is part of SOGo
 *
 * Copyright (C) 2006-2009 Inverse inc.
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

#ifndef SOGOPARENTFOLDERS_H
#define SOGOPARENTFOLDERS_H

#import "SOGoFolder.h"

@class NSMutableDictionary;
@class NSString;
@class WOResponse;

@interface SOGoParentFolder : SOGoFolder
{
  NSMutableDictionary *subFolders, *subscribedSubFolders;
  NSString *OCSPath;
  Class subFolderClass;
  BOOL hasSubscribedSources;
}

+ (NSString *) gcsFolderType;
+ (Class) subFolderClass;

- (NSString *) defaultFolderName;

- (NSException *) appendPersonalSources;
- (void) removeSubFolder: (NSString *) subfolderName;

- (void) setBaseOCSPath: (NSString *) newOCSPath;

- (NSArray *) toManyRelationshipKeys;
- (NSArray *) subFolders;

- (BOOL) hasLocalSubFolderNamed: (NSString *) name;

- (NSException *) newFolderWithName: (NSString *) name
		 andNameInContainer: (NSString *) newNameInContainer;
- (NSException *) newFolderWithName: (NSString *) name
		    nameInContainer: (NSString **) newNameInContainer;

- (id) lookupPersonalFolder: (NSString *) name
             ignoringRights: (BOOL) ignoreRights;

@end

#endif /* SOGOPARENTFOLDERS_H */
