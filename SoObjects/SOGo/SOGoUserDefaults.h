/* SOGoUserDefaults.h - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc.
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

/* general */
- (void) setLoginModule: (NSString *) newLoginModule;
- (NSString *) loginModule;

- (void) setRememberLastModule: (BOOL) rememberLastModule;
- (BOOL) rememberLastModule;

- (void) setDefaultCalendar: (NSString *) newDefaultCalendar;
- (NSString *) defaultCalendar;

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

- (void) setBusyOffHours: (BOOL) busyOffHours;
- (BOOL) busyOffHours;

- (void) setTimeZoneName: (NSString *) newValue;
- (NSString *) timeZoneName;

- (void) setTimeZone: (NSTimeZone *) newValue;
- (NSTimeZone *) timeZone;

- (void) setTimeFormat: (NSString *) newValue;
- (NSString *) timeFormat;

- (void) setLanguage: (NSString *) newValue;
- (NSString *) language;

/* mail */
- (void) setMailShowSubscribedFoldersOnly: (BOOL) newValue;
- (BOOL) mailShowSubscribedFoldersOnly;

- (void) setMailSortByThreads: (BOOL) newValue;
- (BOOL) mailSortByThreads;

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

- (void) setMailCustomFullName: (NSString *) newValue;
- (NSString *) mailCustomFullName;

- (void) setMailCustomEmail: (NSString *) newValue;
- (NSString *) mailCustomEmail;

- (void) setMailReplyTo: (NSString *) newValue;
- (NSString *) mailReplyTo;

- (void) setAllowUserReceipt: (BOOL) allow;
- (BOOL) allowUserReceipt;
- (void) setUserReceiptNonRecipientAction: (NSString *) action;
- (NSString *) userReceiptNonRecipientAction;
- (void) setUserReceiptOutsideDomainAction: (NSString *) action;
- (NSString *) userReceiptOutsideDomainAction;
- (void) setUserReceiptAnyAction: (NSString *) action;
- (NSString *) userReceiptAnyAction;

- (void) setMailUseOutlookStyleReplies: (BOOL) newValue;
- (BOOL) mailUseOutlookStyleReplies;

- (void) setAuxiliaryMailAccounts: (NSArray *) newAccounts;
- (NSArray *) auxiliaryMailAccounts;

- (void) setSieveFilters: (NSArray *) newValue;
- (NSArray *) sieveFilters;

- (void) setVacationOptions: (NSDictionary *) newValue;
- (NSDictionary *) vacationOptions;

- (void) setForwardOptions: (NSDictionary *) newValue;
- (NSDictionary *) forwardOptions;

/* calendar */
- (void) setCalendarCategories: (NSArray *) newValues;
- (NSArray *) calendarCategories;

- (void) setCalendarCategoriesColors: (NSDictionary *) newValues;
- (NSDictionary *) calendarCategoriesColors;

- (void) setCalendarShouldDisplayWeekend: (BOOL) newValue;
- (BOOL) calendarShouldDisplayWeekend;

- (void) setCalendarEventsDefaultClassification: (NSString *) newValue;
- (NSString *) calendarEventsDefaultClassification;

- (void) setCalendarTasksDefaultClassification: (NSString *) newValue;
- (NSString *) calendarTasksDefaultClassification;

- (void) setReminderEnabled: (BOOL) newValue;
- (BOOL) reminderEnabled;

- (void) setReminderTime: (NSString *) newValue;
- (NSString *) reminderTime;

- (void) setRemindWithASound: (BOOL) newValue;
- (BOOL) remindWithASound;

/* contacts */
- (void) setContactsCategories: (NSArray *) newValues;
- (NSArray *) contactsCategories;

@end

#endif /* SOGOUSERDEFAULTS_H */
