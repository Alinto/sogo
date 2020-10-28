/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2006-2014 Inverse inc.

  This file is part of SOGo

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

#ifndef __UIxContactEditor_H__
#define __UIxContactEditor_H__

#include <SOGoUI/SOGoDirectAction.h>

@class NSString;
@class NSMutableDictionary;

@protocol SOGoContactFolder;

@interface UIxContactEditor : SOGoDirectAction
{
  id addressBookItem;
  NGVCard *card;
  NSString *item;
  NSMutableDictionary *ldifRecord; /* contains the values for editing */
  id <SOGoContactFolder> componentAddressBook;
}

- (NSMutableDictionary *) ldifRecord;

- (void) setAddressBookItem: (id) _item;
- (id) addressBookItem;

- (BOOL) isNew;
- (NSArray *) addressBooksList;
- (id <SOGoContactFolder>) componentAddressBook;
- (NSString *) addressBookDisplayName;

@end

#endif /* __UIxContactEditor_H__ */
