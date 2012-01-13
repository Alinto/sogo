/*
  Copyright (C) 2007-2012 Inverse inc.
  Copyright (C) 2000-2004 SKYRIX Software AG

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

@class NSArray;
@class NSCalendarDate;

@class iCalPerson;

@interface SOGoFreeBusyObject : SOGoObject

/* accessors */

- (NSString *) iCalString;

- (NSString *) contentAsStringFrom: (NSCalendarDate *) _startDate
				to: (NSCalendarDate *) _endDate;
- (NSString *) contentAsStringWithMethod: (NSString *) method
                                  andUID: (NSString *) uid
                            andOrganizer: (iCalPerson *) organizer
                              andContact: (NSString *) contactID
				    from: (NSCalendarDate *) _startDate
				      to: (NSCalendarDate *) _endDate;

- (NSArray *) fetchFreeBusyInfosFrom: (NSCalendarDate *) _startDate
				  to: (NSCalendarDate *) _endDate;
- (NSArray *) fetchFreeBusyInfosFrom: (NSCalendarDate *) startDate
                                  to: (NSCalendarDate *) endDate
                          forContact: (NSString *) uid;
@end

#endif	/* __Appointments_SOGoFreeBusyObject_H_ */
