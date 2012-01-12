/*
  Copyright (C) 2012 Inverse inc.

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef	__Appointments_MSExchangeFreeBusySOAPRequest_H_
#define	__Appointments_MSExchangeFreeBusySOAPRequest_H_

#include <NGObjWeb/SoComponent.h>

@class NSCalendarDate;
@class NSMutableDictionary;
@class NSString;
@class NSTimeZone;
@class iCalEvent;

/*
 * NOTE: We inherit from SoComponent in order to get the correct
 *       resourceManager required for this product
 */
@interface MSExchangeFreeBusySOAPRequest : SoComponent
{
  NSString *address;
  NSTimeZone *timeZone;
  NSCalendarDate *startDate;
  NSCalendarDate *endDate;
  int interval;
}

- (void) setAddress: (NSString *) _address
               from: (NSCalendarDate *) _startDate
                 to: (NSCalendarDate *) _endDate;

@end

#endif	/* __Appointments_MSExchangeFreeBusySOAPRequest_H_ */
