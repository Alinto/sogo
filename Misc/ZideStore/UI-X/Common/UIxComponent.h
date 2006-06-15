/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OGo

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
// $Id: UIxComponent.h 84 2004-06-29 22:34:55Z znek $


#ifndef	__UIxComponent_H_
#define	__UIxComponent_H_

#include <NGObjWeb/SoComponent.h>

@class NSCalendarDate;


@interface UIxComponent : SoComponent
{
    NSMutableDictionary *queryParameters;
}

- (NSString *)queryParameterForKey:(NSString *)_key;
- (NSDictionary *)queryParameters;

/* use this to set 'sticky' query parameters */
- (void)setQueryParameter:(NSString *)_param forKey:(NSString *)_key;

/* appends queryParameters to _method if any are set */
- (NSString *)completeHrefForMethod:(NSString *)_method;

- (NSString *)ownMethodName;

/* date selection */
- (NSCalendarDate *)selectedDate;
- (NSString *)dateStringForDate:(NSCalendarDate *)_date;
- (NSCalendarDate *)dateForDateString:(NSString *)_dateString;

@end

#endif	/* __UIxComponent_H_ */
