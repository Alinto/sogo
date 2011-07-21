/* MAPIStoreAppointmentWrapper.h - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#ifndef MAPISTORECALENDARWRAPPER_H
#define MAPISTORECALENDARWRAPPER_H

#import <Foundation/NSObject.h>

@class NSTimeZone;

@class iCalCalendar;
@class iCalEvent;

extern NSTimeZone *utcTZ;

@interface MAPIStoreAppointmentWrapper : NSObject
{
  iCalCalendar *calendar;
  iCalEvent *event;
  NSTimeZone *timeZone;
}

+ (id) wrapperWithICalEvent: (iCalEvent *) newEvent
                 inTimeZone: (NSTimeZone *) newTimeZone;
- (id) initWithICalEvent: (iCalEvent *) newEvent
              inTimeZone: (NSTimeZone *) newTimeZone;

/* getters */
- (int) getPrIconIndex: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPrMessageClass: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPrBody: (void **) data
         inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPrStartDate: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidAppointmentStartWhole: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidCommonStart: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPrEndDate: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidAppointmentEndWhole: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidCommonEnd: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidAppointmentDuration: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidAppointmentSubType: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidBusyStatus: (void **) data // TODO
                   inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidIndentedBusyStatus: (void **) data // TODO
                           inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPrSubject: (void **) data // SUMMARY
            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidLocation: (void **) data // LOCATION
                 inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidPrivate: (void **) data // private (bool), should depend on CLASS and permissions
                inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPrSensitivity: (void **) data // not implemented, depends on CLASS
                inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPrImportance: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidIsRecurring: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidRecurring: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidAppointmentRecur: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidGlobalObjectId: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidCleanGlobalObjectId: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidServerProcessed: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx;

@end

#endif /* MAPISTORECALENDARWRAPPER_H */
