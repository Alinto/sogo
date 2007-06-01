/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __Contacts_SOGoContactFolder_H__
#define __Contacts_SOGoContactFolder_H__

/*
  SOGoContactFolder
    Parent object: the user's SOGoUserFolders
    Child objects: SOGoContactObject

  The SOGoContactFolder maps to an GCS folder of type 'contact', that
  is, a content folder containing vcal?? files (and a proper quicktable).
*/

#import <Foundation/NSObject.h>

@class NSString, NSArray;
@class SOGoContactObject;
@class SOGoObject;

@protocol SOGoContactObject;

#import <SoObjects/SOGo/SOGoFolder.h>

@protocol SOGoContactFolder <NSObject>

+ (id <SOGoContactFolder>) contactFolderWithName: (NSString *) aName
                                  andDisplayName: (NSString *) aDisplayName
                                     inContainer: (SOGoObject *) aContainer;

- (id <SOGoContactFolder>) initWithName: (NSString *) aName
                         andDisplayName: (NSString *) aDisplayName
                            inContainer: (SOGoObject *) aContainer;

- (NSString *) displayName;

- (NSArray *) lookupContactsWithFilter: (NSString *) filter
                                sortBy: (NSString *) sortKey
                              ordering: (NSComparisonResult) sortOrdering;

@end

#endif /* __Contacts_SOGoContactFolder_H__ */
