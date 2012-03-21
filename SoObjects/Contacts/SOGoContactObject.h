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

#ifndef __Contacts_SOGoContactObject_H__
#define __Contacts_SOGoContactObject_H__

@class NSDictionary;
@class NGVCard;

@protocol SOGoContactObject

- (NGVCard *) vCard;
- (BOOL) hasPhoto;

/* web editing */
- (void) setLDIFRecord: (NSDictionary *) newLDIFRecord;
- (NSDictionary *) ldifRecord;
- (NSDictionary *) simplifiedLDIFRecord;

- (NSException *) save;
- (NSException *) delete;

@end

#endif /* __Contacts_SOGoContactObject_H__ */
