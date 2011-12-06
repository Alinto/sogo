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

#ifndef __SOGo_SOGoUserFolder_H__
#define __SOGo_SOGoUserFolder_H__

#import "SOGoFolder.h"

/*
  SOGoUserFolder
    Parent object: the root object (SoApplication object)
    Child objects: 
      'Calendar': SOGoAppointmentFolder
  
  The SOGoUserFolder is the "home directory" of the user where all his 
  processing starts. It is the 'znek' in such a path:
    /SOGo/so/znek/Calendar
*/

@class NSArray;
@class NSDictionary;
@class NSString;
@class WOContext;
@class SOGoContactFolders;

@interface SOGoUserFolder : SOGoFolder

/* ownership */

- (NSArray *) foldersOfType: (NSString *) folderType
		     forUID: (NSString *) uid;
- (NSDictionary *) foldersOfType: (NSString *) type
		     matchingUID: (NSString *) uid;

- (id) freeBusyObject: (NSString *) _key
            inContext: (WOContext *) _ctx;

- (id) mailAccountsFolder: (NSString *) _key
                inContext: (WOContext *) _ctx;

- (BOOL) collectionDavKey: (NSString *) key
		  matches: (NSString *) value;

- (SOGoContactFolders *) privateContacts: (NSString *) _key
                               inContext: (WOContext *) _ctx;

@end

#endif /* __SOGo_SOGoUserFolder_H__ */
