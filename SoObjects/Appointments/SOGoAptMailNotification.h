/*
  Copyright (C) 2006-2019 Inverse inc.

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

#ifndef	__Appointments_SOGoAptMailNotification_H_
#define	__Appointments_SOGoAptMailNotification_H_

#include <NGObjWeb/SoComponent.h>

@class NSCalendarDate;
@class NSMutableDictionary;
@class NSString;
@class NSTimeZone;
@class iCalPerson;
@class iCalRepeatableEntityObject;
@class SOGoDateFormatter;

/*
 * NOTE: We inherit from SoComponent in order to get the correct
 *       resourceManager required for this product
 */
@interface SOGoAptMailNotification : SoComponent
{
  iCalRepeatableEntityObject *apt;
  iCalRepeatableEntityObject *previousApt;
  NSString *homePageURL;
  NSTimeZone *viewTZ;
  NSCalendarDate *oldStartDate;
  NSCalendarDate *newStartDate;
  NSCalendarDate *oldEndDate;
  NSCalendarDate *newEndDate;
  NSString *organizerName;
  iCalPerson *currentAttendee;
  NSMutableDictionary *values;
  SOGoDateFormatter *dateFormatter;
}

- (void) setupValues;

- (iCalRepeatableEntityObject *) apt;
- (void) setApt: (iCalRepeatableEntityObject *) theApt;

- (iCalRepeatableEntityObject *) previousApt;
- (void) setPreviousApt: (iCalRepeatableEntityObject *) theApt;

- (void) setOrganizerName: (NSString *) theString;
- (NSString *) organizerName;

- (void) setCurrentAttendee: (iCalPerson *) theAttendee;
- (iCalPerson *) currentAttendee;

- (NSCalendarDate *) oldStartDate;
- (NSCalendarDate *) newStartDate;

- (NSCalendarDate *) oldEndDate;
- (NSCalendarDate *) newEndDate;

- (NSString *) sentByText;
- (NSString *) formattedAptStartDate;
- (NSString *) formattedAptStartTime;
- (NSString *) formattedAptEndDate;
- (NSString *) formattedAptEndTime;

- (NSString *) getSubject;
- (NSString *) getBody;
  
@end

#endif	/* __Appointments_SOGoAptMailNotification_H_ */
