/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __ICal_common_H__
#define __ICal_common_H__

#import <Foundation/Foundation.h>
#import <EOControl/EOControl.h>
#include <NGExtensions/NGExtensions.h>

#define IS_EQUAL(a, b, sel) \
  _iCalSafeCompareObjects(a, b, @selector(sel))

static __inline__ BOOL _iCalSafeCompareObjects(id a, id b, SEL comparator) {
  id va = a;
  id vb = b;
  BOOL (*compm)(id, SEL, id);

  if((va == nil && vb != nil) || (va != nil && vb == nil))
    return NO;
  else if(va == vb)
    return YES;
  compm = (BOOL (*)( id, SEL, id))[va methodForSelector:comparator];
  return compm(va, comparator, vb);
}

#endif /* __ICal_common_H__ */
