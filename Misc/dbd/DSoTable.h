/*
  Copyright (C) 2004 SKYRIX Software AG

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
// $Id: DSoTable.h 54 2004-06-21 12:40:06Z helge $

#ifndef __dbd_DSoTable_H__
#define __dbd_DSoTable_H__

#include "DSoObject.h"

@class NSString;
@class DSoDatabase;

@interface DSoTable : DSoObject
{
  DSoDatabase *database;
  NSString    *tableName;
}

- (id)initWithName:(NSString *)_name inContainer:(id)_container;

/* accessors */

- (DSoDatabase *)database;
- (NSString *)tableName;

- (NSString *)hostName;
- (int)port;
- (NSString *)databaseName;

/* support */

- (EOAdaptor *)adaptorInContext:(WOContext *)_ctx;

@end

#endif /* __dbd_DSoTable_H__ */
