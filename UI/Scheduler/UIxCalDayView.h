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
// $Id: UIxCalDayView.h 181 2004-08-11 15:13:25Z helge $


#ifndef	__UIxCalDayView_H_
#define	__UIxCalDayView_H_


#import "UIxCalView.h"

@interface UIxCalDayView : UIxCalView

- (NSDictionary *) dayBeforePrevDayQueryParameters;
- (NSDictionary *) prevDayQueryParameters;
- (NSDictionary *) nextDayQueryParameters;
- (NSDictionary *) dayAfterNextDayQueryParameters;
- (NSDictionary *) currentDateQueryParameters;

- (NSCalendarDate *) startDate;

- (NSString *) dayBeforeYesterdayName;
- (NSString *) yesterdayName;
- (NSString *) currentDayName;
- (NSString *) tomorrowName;
- (NSString *) dayAfterTomorrowName;

@end

#endif	/* __UIxCalDayView_H_ */
