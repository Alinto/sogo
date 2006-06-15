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
// $Id: SOGoCustomGroupFolder.h 107 2004-06-30 10:26:46Z helge $

#ifndef __SOGo_SOGoCustomGroupFolder_H__
#define __SOGo_SOGoCustomGroupFolder_H__

#include <SOGo/SOGoGroupFolder.h>

/*
  SOGoCustomGroupFolder
    same parent/child like SOGoGroupFolder

  Note: parent folder can be different if instantiated for internal use.
  
  Note: you can use this folder for internal handling of groups! Eg aggregate
        Calendar fetches.
  
  This is a specific group folder for 'custom' groups. Group members are
  currently encoded as the folder name in the URL like
    _custom_znek,helge
*/

@class NSArray;

@interface SOGoCustomGroupFolder : SOGoGroupFolder
{
  NSArray *uids;
}

- (id)initWithUIDs:(NSArray *)_uids inContainer:(id)_container;

/* accessors */

- (NSArray *)uids;

/* pathes */

@end

#endif /* __SOGo_SOGoCustomGroupFolder_H__ */
