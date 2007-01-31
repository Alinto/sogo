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

/* WAS: class being obsoleted !! */

#ifndef __NGiCal_iCalObject_H__
#define __NGiCal_iCalObject_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>

/*
  iCalObject

  A common base class for all iCal objects. Does some patches on key-value
  coding.
*/

@class NSTimeZone;

@interface iCalObject : NSObject <NSCopying>
{
}

// what shall we take, if no timeZone is specified in dateValues
+ (void)setICalDefaultTimeZone:(NSTimeZone *)_timeZone;
+ (NSTimeZone *)iCalDefaultTimeZone;

@end



#endif /* __NGiCal_iCalObject_H__ */
