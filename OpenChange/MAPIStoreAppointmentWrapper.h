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
#import <NGCards/iCalTimeZone.h>
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
  iCalTimeZone *timeZone;
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
         withConnectionInfo: (struct mapistore_connection_info *) newConnInfo;
- (id) initWithICalEvent: (iCalEvent *) newEvent
                 andUser: (SOGoUser *) newUser
          andSenderEmail: (NSString *) newSenderEmail
      withConnectionInfo: (struct mapistore_connection_info *) newConnInfo;

/* getters */
- (void) fillMessageData: (struct mapistore_message *) dataPtr
                inMemCtx: (TALLOC_CTX *) memCtx;

- (NSString *) creator;
- (NSString *) owner;
- (NSUInteger) sensitivity;

- (enum mapistore_error) getPidTagSenderEmailAddress: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagSenderAddressType: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagSenderName: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagSenderEntryId: (void **) data
                                       inMemCtx: (TALLOC_CTX *) memCtx;

- (enum mapistore_error) getPidTagReceivedByAddressType: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagReceivedByEmailAddress: (void **) data
                                                inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagReceivedByName: (void **) data
                                        inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagReceivedByEntryId: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx;

- (enum mapistore_error) getPidTagIconIndex: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagOwnerAppointmentId: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidMeetingType: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagMessageClass: (void **) data
                                      inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagStartDate: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidAppointmentSequence: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidAppointmentStateFlags: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidResponseStatus: (void **) data
                                        inMemCtx: (TALLOC_CTX *) memCtx;

- (enum mapistore_error) getPidLidAppointmentStartWhole: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidCommonStart: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagEndDate: (void **) data
                                 inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidAppointmentEndWhole: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidCommonEnd: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidAppointmentDuration: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidAppointmentSubType: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidBusyStatus: (void **) data // TODO
                                    inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidIndentedBusyStatus: (void **) data // TODO
                                            inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagNormalizedSubject: (void **) data // SUMMARY
                                           inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidLocation: (void **) data // LOCATION
                                  inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidPrivate: (void **) data // private (bool), should depend on CLASS and permissions
                                 inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagSensitivity: (void **) data // not implemented, depends on CLASS
                                     inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagImportance: (void **) data
                                    inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidTagBody: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidIsRecurring: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidRecurring: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidAppointmentRecur: (void **) data
                                          inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidGlobalObjectId: (void **) data
                                        inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidCleanGlobalObjectId: (void **) data
                                             inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidServerProcessed: (void **) data
                                         inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidServerProcessingActions: (void **) data
                                                 inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidAppointmentReplyTime: (void **) data
                                              inMemCtx: (TALLOC_CTX *) memCtx;

/* reminders */
- (enum mapistore_error) getPidLidReminderSet: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidReminderDelta: (void **) data
                                       inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidReminderTime: (void **) data
                                      inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidReminderSignalTime: (void **) data
                                            inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidReminderOverride: (void **) data
                                          inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidReminderType: (void **) data
                                      inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidReminderPlaySound: (void **) data
                                           inMemCtx: (TALLOC_CTX *) memCtx;
- (enum mapistore_error) getPidLidReminderFileParameter: (void **) data
                                               inMemCtx: (TALLOC_CTX *) memCtx;

@end

#endif /* MAPISTORECALENDARWRAPPER_H */
