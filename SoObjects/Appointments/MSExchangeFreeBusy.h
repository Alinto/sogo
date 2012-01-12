/* MSExchangeFreeBusy.h - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc.
 *
 * Author: Francis Lachapelle <flachapelle@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef MSEXCHANGEFREEBUSY_H
#define MSEXCHANGEFREEBUSY_H

#include <Foundation/Foundation.h>

@class MSExchangeFreeBusyResponse;
@class MSExchangeFreeBusyView;

@interface MSExchangeFreeBusy : NSObject
{
  NSMutableData *curlBody;
  MSExchangeFreeBusyResponse *response;
}

- (size_t) curlWritePtr: (void *) inPtr
                   size: (size_t) inSize
                 number: (size_t) inNumber;
- (NSArray *) fetchFreeBusyInfosFrom: (NSCalendarDate *) startDate
                                  to: (NSCalendarDate *) endDate
                            forEmail: (NSString *) email
                            inSource: (NSObject <SOGoDNSource> *) source
//                          fromServer: (NSString *) hostname
                           inContext: (WOContext *) context;

@end

@interface MSExchangeFreeBusyResponse : NSObject
{
  MSExchangeFreeBusyView *view;
}

- (MSExchangeFreeBusyView *) view;

@end

@interface MSExchangeFreeBusyView : NSObject
{
  NSString *freeBusyViewType;
  NSString *mergedFreeBusy;
}

- (NSArray *) infosFrom: (NSCalendarDate *) startDate
                     to: (NSCalendarDate *) endDate;

@end

#endif /* MSEXCHANGEFREEBUSY_H */
