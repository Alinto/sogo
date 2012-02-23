/*
  Copyright (C) 2006-2011 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
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

#import <SOGo/SOGoFolder.h>

@class NSArray;
@class NSDictionary;
@class NSString;
@class WOResponse;

@protocol SOGoContactFolder <NSObject>

- (NSArray *) lookupContactsWithFilter: (NSString *) filter
                            onCriteria: (NSString *) criteria
                                sortBy: (NSString *) sortKey
                              ordering: (NSComparisonResult) sortOrdering
                              inDomain: (NSString *) domain;
- (NSDictionary *) lookupContactWithName: (NSString *) aName;

@end

#endif /* __Contacts_SOGoContactFolder_H__ */
