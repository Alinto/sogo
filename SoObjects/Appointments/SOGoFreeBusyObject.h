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


#ifndef	__Appointments_SOGoFreeBusyObject_H_
#define	__Appointments_SOGoFreeBusyObject_H_

#include <SOGo/SOGoObject.h>

/*
 SOGoFreeBusyObject
 
 Represents Free/Busy information for a single user as specified in RFC2445.
*/

@class NSArray, NSCalendarDate;

@interface SOGoFreeBusyObject : SOGoObject
{
}

/* accessors */

- (NSString *) iCalString;

- (NSString *) contentAsStringFrom: (NSCalendarDate *) _startDate
				to: (NSCalendarDate *) _endDate;

- (NSArray *) fetchFreeBusyInfosFrom: (NSCalendarDate *) _startDate
				  to: (NSCalendarDate *) _endDate;

@end

#endif	/* __Appointments_SOGoFreeBusyObject_H_ */
