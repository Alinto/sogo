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
// $Id$

#import <Foundation/Foundation.h>
#import <Foundation/NSURL.h>

#include <NGExtensions/NGExtensions.h>

#if NeXT_RUNTIME || APPLE_RUNTIME
#  define objc_free(__mem__)    free(__mem__)
#  define objc_malloc(__size__) malloc(__size__)
#  define objc_calloc(__cnt__, __size__) calloc(__cnt__, __size__)
#  define objc_realloc(__ptr__, __size__) realloc(__ptr__, __size__)
#  ifndef sel_eq
#    define sel_eq(sela,selb) (sela==selb?YES:NO)
#  endif
#endif
