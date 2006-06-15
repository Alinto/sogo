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
// $Id: SOGoGroupsFolder.h 107 2004-06-30 10:26:46Z helge $

#ifndef __SOGo_SOGoGroupsFolder_H__
#define __SOGo_SOGoGroupsFolder_H__

#include <SOGo/SOGoObject.h>

/*
  SOGoGroupsFolder
    Parent object: the SOGoUserFolder
    Child objects: SOGoGroupFolder objects
      '_custom_*': SOGoCustomGroupFolder
  
  This object represents a collection of groups, its the "Groups" in such a
  path:
    /SOGo/so/znek/Groups/sales
  
  It also acts as a factory for the proper group folders, eg "custom" groups
  (arbitary person collections) or later on cookie based configured groups or
  groups stored in LDAP.
*/

@class NSString;

@interface SOGoGroupsFolder : SOGoObject
{
}

/* accessors */

/* looking up shared objects */

- (SOGoGroupsFolder *)lookupGroupsFolder;

/* pathes */

@end

#endif /* __SOGo_SOGoGroupsFolder_H__ */
