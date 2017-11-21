/*
  Copyright (C) 2006-2016 Inverse inc.

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
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __Contacts_SOGoContactGCSFolder_H__
#define __Contacts_SOGoContactGCSFolder_H__

#import <EOControl/EOQualifier.h>

#import <SOGo/SOGoGCSFolder.h>

#import "SOGoFolder+CardDAV.h"

@class NSArray;
@class NSString;

@interface SOGoContactGCSFolder : SOGoGCSFolder <SOGoContactFolder>
{
  NSString *baseCardDAVURL, *basePublicCardDAVURL;
}
- (void) fixupContactRecord: (NSMutableDictionary *) contactRecord;
- (EOQualifier *) qualifierForFilter: (NSString *) filter
                          onCriteria: (NSArray *) criteria;
- (NSDictionary *) lookupContactWithName: (NSString *) aName;
- (NSArray *) lookupContactsWithQualifier: (EOQualifier *) qualifier;
- (NSArray *) lookupContactsFields: (NSArray *) fields
                     withQualifier: (EOQualifier *) qualifier
                      andOrderings: (NSArray *) orderings;
- (NSString *) cardDavURL;
- (NSString *) publicCardDavURL;

@end

#endif /* __Contacts_SOGoContactGCSFolder_H__ */
