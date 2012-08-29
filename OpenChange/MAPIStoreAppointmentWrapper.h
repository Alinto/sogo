/* MAPIStoreAppointmentWrapper.h - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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

#import <NGCards/iCalPerson.h>
#import <Appointments/iCalEntityObject+SOGo.h>

#import "MAPIStoreObjectProxy.h"

@class NSTimeZone;

@class iCalAlarm;
@class iCalCalendar;
@class iCalEvent;

@class SOGoUser;

@interface MAPIStoreAppointmentWrapper : MAPIStoreObjectProxy
{
  struct mapistore_connection_info *connInfo;
  iCalCalendar *calendar;
  iCalEvent *firstEvent;
  iCalEvent *event;
  NSTimeZone *timeZone;
  SOGoUser *user;
  NSString *senderEmail;
  NSData *globalObjectId;
  NSData *cleanGlobalObjectId;
  BOOL alarmSet;
  iCalAlarm *alarm;
  BOOL itipSetup;
  NSString *method;
  iCalPersonPartStat partstat;
}

+ (id) wrapperWithICalEvent: (iCalEvent *) newEvent
                    andUser: (SOGoUser *) newUser
             andSenderEmail: (NSString *) newSenderEmail
                 inTimeZone: (NSTimeZone *) newTimeZone
         withConnectionInfo: (struct mapistore_connection_info *) newConnInfo;
- (id) initWithICalEvent: (iCalEvent *) newEvent
                 andUser: (SOGoUser *) newUser
          andSenderEmail: (NSString *) newSenderEmail
              inTimeZone: (NSTimeZone *) newTimeZone
      withConnectionInfo: (struct mapistore_connection_info *) newConnInfo;

/* getters */
- (void) fillMessageData: (struct mapistore_message *) dataPtr
                inMemCtx: (TALLOC_CTX *) memCtx;

- (int) getPidTagSenderEmailAddress: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagSenderAddressType: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagSenderName: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagSenderEntryId: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx;

- (int) getPidTagReceivedByAddressType: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagReceivedByEmailAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagReceivedByName: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagReceivedByEntryId: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx;

- (int) getPidTagIconIndex: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagOwnerAppointmentId: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidMeetingType: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagMessageClass: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagStartDate: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidAppointmentSequence: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidAppointmentStateFlags: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidResponseStatus: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx;

- (int) getPidLidAppointmentStartWhole: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidCommonStart: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagEndDate: (void **) data
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
- (int) getPidTagNormalizedSubject: (void **) data // SUMMARY
                          inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidLocation: (void **) data // LOCATION
                 inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidPrivate: (void **) data // private (bool), should depend on CLASS and permissions
                inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagSensitivity: (void **) data // not implemented, depends on CLASS
                inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagImportance: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidTagBody: (void **) data
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
- (int) getPidLidServerProcessingActions: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidAppointmentReplyTime: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx;

/* reminders */
- (int) getPidLidReminderSet: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidReminderDelta: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidReminderTime: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidReminderSignalTime: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidReminderOverride: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidReminderType: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidReminderPlaySound: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getPidLidReminderFileParameter: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx;

@end

#endif /* MAPISTORECALENDARWRAPPER_H */
