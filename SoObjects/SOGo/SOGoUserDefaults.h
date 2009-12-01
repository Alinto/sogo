/* SOGoUserDefaults.h - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
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

#ifndef SOGOUSERDEFAULTS_H
#define SOGOUSERDEFAULTS_H

#import <SOGo/SOGoDefaultsSource.h>

@class NSArray;
@class NSDictionary;
@class NSString;
@class NSTimeZone;

extern NSString *SOGoWeekStartJanuary1;
extern NSString *SOGoWeekStartFirst4DayWeek;
extern NSString *SOGoWeekStartFirstFullWeek;

@interface SOGoUserDefaults : SOGoDefaultsSource

+ (SOGoUserDefaults *) defaultsForUser: (NSString *) userId
                              inDomain: (NSString *) domainId;

- (void) setLoginModule: (NSString *) newLoginModule;
- (NSString *) loginModule;

- (void) setRememberLastModule: (BOOL) rememberLastModule;
- (BOOL) rememberLastModule;

- (void) setAppointmentSendEMailReceipts: (BOOL) newPoil;
- (BOOL) appointmentSendEMailReceipts;

- (void) setLongDateFormat: (NSString *) newFormat;
- (void) unsetLongDateFormat;
- (NSString *) longDateFormat;

- (void) setShortDateFormat: (NSString *) newFormat;
- (void) unsetShortDateFormat;
- (NSString *) shortDateFormat;

- (void) setTimeFormat: (NSString *) newFormat;
- (void) unsetTimeFormat;
- (NSString *) timeFormat;

- (void) setDayStartTime: (NSString *) newValue;
- (NSString *) dayStartTime;
- (unsigned int) dayStartHour;

- (void) setDayEndTime: (NSString *) newValue;
- (NSString *) dayEndTime;
- (unsigned int) dayEndHour;

- (void) setTimeZoneName: (NSString *) newValue;
- (NSString *) timeZoneName;

- (void) setTimeZone: (NSTimeZone *) newValue;
- (NSTimeZone *) timeZone;

- (void) setTimeFormat: (NSString *) newValue;
- (NSString *) timeFormat;

- (void) setLanguage: (NSString *) newValue;
- (NSString *) language;

- (void) setMailShowSubscribedFoldersOnly: (BOOL) newValue;
- (BOOL) mailShowSubscribedFoldersOnly;

- (void) setDraftsFolderName: (NSString *) newValue;
- (NSString *) draftsFolderName;

- (void) setSentFolderName: (NSString *) newValue;
- (NSString *) sentFolderName;

- (void) setTrashFolderName: (NSString *) newValue;
- (NSString *) trashFolderName;

- (void) setFirstDayOfWeek: (int) newValue;
- (int) firstDayOfWeek;

- (void) setFirstWeekOfYear: (NSString *) newValue;
- (NSString *) firstWeekOfYear;

- (void) setMailListViewColumnsOrder: (NSArray *) newValue;
- (NSArray *) mailListViewColumnsOrder;

- (void) setMailMessageCheck: (NSString *) newValue;
- (NSString *) mailMessageCheck;

- (void) setMailComposeMessageType: (NSString *) newValue;
- (NSString *) mailComposeMessageType;

- (void) setMailMessageForwarding: (NSString *) newValue;
- (NSString *) mailMessageForwarding;

- (void) setMailReplyPlacement: (NSString *) newValue;
- (NSString *) mailReplyPlacement;

- (void) setMailSignature: (NSString *) newValue;
- (NSString *) mailSignature;

- (void) setMailSignaturePlacement: (NSString *) newValue;
- (NSString *) mailSignaturePlacement;

- (void) setMailUseOutlookStyleReplies: (BOOL) newValue;
- (BOOL) mailUseOutlookStyleReplies;

- (void) setCalendarCategories: (NSArray *) newValues;
- (NSArray *) calendarCategories;

- (void) setCalendarCategoriesColors: (NSArray *) newValues;
- (NSArray *) calendarCategoriesColors;

- (void) setCalendarShouldDisplayWeekend: (BOOL) newValue;
- (BOOL) calendarShouldDisplayWeekend;

- (void) setReminderEnabled: (BOOL) newValue;
- (BOOL) reminderEnabled;

- (void) setReminderTime: (NSString *) newValue;
- (NSString *) reminderTime;

- (void) setRemindWithASound: (BOOL) newValue;
- (BOOL) remindWithASound;

- (void) setVacationOptions: (NSDictionary *) newValue;
- (NSDictionary *) vacationOptions;

- (void) setForwardOptions: (NSDictionary *) newValue;
- (NSDictionary *) forwardOptions;

@end

#endif /* SOGOUSERDEFAULTS_H */
