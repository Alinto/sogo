/* SOGoUserDefaults.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2022 Inverse inc.
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

#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGImap4/NSString+Imap4.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WEClientCapabilities.h>

#import "NSString+Utilities.h"
#import "SOGoSystemDefaults.h"
#import "SOGoUserProfile.h"



NSString *SOGoWeekStartJanuary1 = @"January1";
NSString *SOGoWeekStartFirst4DayWeek = @"First4DayWeek";
NSString *SOGoWeekStartFirstFullWeek = @"FirstFullWeek";

NSString *SOGoPasswordRecoveryDisabled = @"Disabled";
NSString *SOGoPasswordRecoveryQuestion = @"SecretQuestion";
NSString *SOGoPasswordRecoveryQuestion1 = @"SecretQuestion1";
NSString *SOGoPasswordRecoveryQuestion2 = @"SecretQuestion2";
NSString *SOGoPasswordRecoveryQuestion3 = @"SecretQuestion3";
NSString *SOGoPasswordRecoverySecondaryEmail = @"SecondaryEmail";


@implementation SOGoUserDefaults

+ (NSString *) userProfileClassName
{
  return @"SOGoSQLUserProfile";
}

+ (SOGoUserDefaults *) defaultsForUser: (NSString *) userId
                              inDomain: (NSString *) domainId
{
  SOGoUserProfile *up;
  SOGoUserDefaults *ud;
  SOGoDefaultsSource *parent;
  WOContext *context;
  WEClientCapabilities *cc;
  static Class SOGoUserProfileKlass = Nil;

  if (!SOGoUserProfileKlass)
    SOGoUserProfileKlass = NSClassFromString ([self userProfileClassName]);

  up = [SOGoUserProfileKlass userProfileWithType: SOGoUserProfileTypeDefaults
                                          forUID: userId];
  [up fetchProfile];

  parent = [SOGoDomainDefaults defaultsForDomain: domainId];
  if (!parent)
    parent = [SOGoSystemDefaults sharedSystemDefaults];

  ud = [self defaultsSourceWithSource: up andParentSource: parent];

  // CKEditor (the HTML editor) is no longer compatible with IE7;
  // force the user to use the plain text editor with IE7
  context = [[WOApplication application] context];
  cc = [[context request] clientCapabilities];
  if ([cc isInternetExplorer] && [cc majorVersion] < 8)
    {
      [ud setObject: @"text" forKey: @"SOGoMailComposeMessageType"];
    }

  return ud;
}

- (id) init
{
  if ((self = [super init]))
    {
      userLanguage = nil;
    }

  return self;
}

- (void) dealloc
{
  [userLanguage release];
  [super dealloc];
}

- (BOOL) _migrateLastModule
{
  BOOL rc;
  NSString *loginModule;

  loginModule = [source objectForKey: @"SOGoUIxLastModule"];
  if ([loginModule length])
    {
      rc = YES;
      /* we need to use the old key, otherwise the migration will be blocked */
      [self setObject: loginModule forKey: @"SOGoUIxDefaultModule"];
      [self setRememberLastModule: YES];
      [self removeObjectForKey: @"SOGoUIxLastModule"];
    }
  else
    rc = NO;

  return rc;
}

- (BOOL) _migrateMailIdentities
{
  BOOL rc;
  NSArray *mailIdentities;
  NSMutableDictionary *identity;
  NSString *fullName, *email, *replyTo, *signature;

  mailIdentities = [self mailIdentities];
  if (mailIdentities)
    {
      rc = NO;
    }
  else
    {
      identity = [NSMutableDictionary dictionaryWithCapacity: 4];
      fullName = [self stringForKey: @"SOGoMailCustomFullName"];
      email = [self stringForKey: @"SOGoMailCustomEmail"];
      replyTo = [self stringForKey: @"SOGoMailReplyTo"];
      signature = [self stringForKey: @"SOGoMailSignature"];
      rc = NO;

      if ([fullName length])
        [identity setObject: fullName forKey: @"fullName"];
      if ([email length])
        [identity setObject: email forKey: @"email"];
      if ([replyTo length])
        [identity setObject: replyTo forKey: @"replyTo"];
      if ([signature length])
        [identity setObject: signature forKey: @"signature"];

      if ([identity count])
        {
          [identity setObject: [NSNumber numberWithBool: YES] forKey: @"isDefault"];
          [self setMailIdentities: [NSArray arrayWithObject: identity]];
          rc = YES;
        }

      /**
       * Keep old attributes for now because v2 doesn't handle identities
       *
      if (fullName)
       [self removeObjectForKey: @"SOGoMailCustomFullName"];
      if (email)
       [self removeObjectForKey: @"SOGoMailCustomEmail"];
      if (replyTo)
       [self removeObjectForKey: @"SOGoMailReplyTo"];
      if (signature)
        [self removeObjectForKey: @"SOGoMailSignature"];
      */
    }

  return rc;
}

- (BOOL) _migrateCalendarCategories
{
  NSArray *categories, *colors;
  NSDictionary *newColors;
  BOOL rc;

  colors = [source objectForKey: @"SOGoCalendarCategoriesColors"];
  if ([colors isKindOfClass: [NSArray class]])
    {
      categories = [source objectForKey: @"SOGoCalendarCategories"];
      if ([categories count] == [colors count])
        {
          newColors = [NSDictionary dictionaryWithObjects: colors
                                                  forKeys: categories];
          [source setObject: newColors
                     forKey: @"SOGoCalendarCategoriesColors"];
        }
      else
        [source removeObjectForKey: @"SOGoCalendarCategoriesColors"];
      rc = YES;
    }
  else
    rc = NO;

  return rc;
}

- (BOOL) migrate
{
  static NSDictionary *migratedKeys = nil;

  if (!migratedKeys)
    {
      migratedKeys
        = [NSDictionary dictionaryWithObjectsAndKeys:
                        @"SOGoLoginModule", @"SOGoUIxDefaultModule",
                        @"SOGoLoginModule", @"SOGoDefaultModule",
                        @"SOGoTimeFormat", @"TimeFormat",
                        @"SOGoShortDateFormat", @"ShortDateFormat",
                        @"SOGoLongDateFormat", @"LongDateFormat",
                        @"SOGoDayStartTime", @"DayStartTime",
                        @"SOGoDayEndTime", @"DayEndTime",
                        @"SOGoFirstDayOfWeek", @"WeekStartDay",
                        @"SOGoFirstWeekOfYear", @"FirstWeek",
                        @"SOGoLanguage", @"SOGoDefaultLanguage",
                        @"SOGoLanguage", @"Language",
                        @"SOGoMailComposeMessageType", @"ComposeMessagesType",
                        @"SOGoSelectedAddressBook", @"SelectedAddressBook",
                        @"SOGoRefreshViewCheck", @"RefreshViewCheck",
                        @"SOGoMailMessageForwarding", @"MessageForwarding",
                        @"SOGoMailSignature", @"MailSignature",
                        @"SOGoMailSignaturePlacement", @"SignaturePlacement",
                        @"SOGoMailReplyPlacement", @"ReplyPlacement",
                        @"SOGoTimeZone", @"TimeZone",
                        @"SOGoCalendarShouldDisplayWeekend", @"SOGoShouldDisplayWeekend",
                        @"SOGoMailShowSubscribedFoldersOnly", @"showSubscribedFoldersOnly",
                        @"SOGoReminderEnabled", @"ReminderEnabled",
                        @"SOGoReminderTime", @"ReminderTime",
                        @"SOGoRemindWithASound", @"RemindWithASound",
                        @"SOGoTOTPEnabled", @"SOGoGoogleAuthenticatorEnabled",
                        nil];
      [migratedKeys retain];
    }

  /* we must not use a boolean operation, otherwise subsequent migrations will
     not be invoked in the case where rc = YES. */
  return ([self _migrateLastModule]
          // | [self _migrateSignature]
          | [self _migrateMailIdentities]
          | [self _migrateCalendarCategories]
          | [self migrateOldDefaultsWithDictionary: migratedKeys]
          | [super migrate]);
}

- (void) setLoginModule: (NSString *) newLoginModule
{
  [self setObject: newLoginModule forKey: @"SOGoLoginModule"];
}

- (NSString *) loginModule
{
  return [self stringForKey: @"SOGoLoginModule"];
}

- (void) setRememberLastModule: (BOOL) rememberLastModule
{
  [self setBool: rememberLastModule forKey: @"SOGoRememberLastModule"];
}

- (BOOL) rememberLastModule
{
  return [self boolForKey: @"SOGoRememberLastModule"];
}

- (void) setDefaultCalendar: (NSString *) newDefaultCalendar
{
  [self setObject: newDefaultCalendar forKey: @"SOGoDefaultCalendar"];
}

- (NSString *) defaultCalendar
{
  return [self stringForKey: @"SOGoDefaultCalendar"];
}

- (void) setDayStartTime: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoDayStartTime"];
}

- (NSString *) dayStartTime
{
  return [self stringForKey: @"SOGoDayStartTime"];
}

- (unsigned int) dayStartHour
{
  return [[self dayStartTime] timeValue];
}

- (void) setDayEndTime: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoDayEndTime"];
}

- (NSString *) dayEndTime
{
  return [self stringForKey: @"SOGoDayEndTime"];
}

- (unsigned int) dayEndHour
{
  return [[self dayEndTime] timeValue];
}

- (void) setBusyOffHours: (BOOL) newValue
{
  [self setBool: newValue forKey: @"SOGoBusyOffHours"];
}

- (BOOL) busyOffHours
{
  return [self boolForKey: @"SOGoBusyOffHours"];
}

- (void) setTimeZoneName: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoTimeZone"];
}

- (NSString *) timeZoneName
{
  return [self stringForKey: @"SOGoTimeZone"];
}

- (void) setTimeZone: (NSTimeZone *) newValue
{
  [self setTimeZoneName: [newValue name]];
}

- (NSTimeZone *) timeZone
{
  return [NSTimeZone timeZoneWithName: [self timeZoneName]];
}

- (void) setLongDateFormat: (NSString *) newFormat
{
  [self setObject: newFormat forKey: @"SOGoLongDateFormat"];
}

- (void) unsetLongDateFormat
{
  [self removeObjectForKey: @"SOGoLongDateFormat"];
}

- (NSString *) longDateFormat
{
  return [self stringForKey: @"SOGoLongDateFormat"];
}

- (void) setShortDateFormat: (NSString *) newFormat;
{
  [self setObject: newFormat forKey: @"SOGoShortDateFormat"];
}

- (void) unsetShortDateFormat
{
  [self removeObjectForKey: @"SOGoShortDateFormat"];
}

- (NSString *) shortDateFormat;
{
  return [self stringForKey: @"SOGoShortDateFormat"];
}

- (void) setTimeFormat: (NSString *) newFormat
{
  [self setObject: newFormat forKey: @"SOGoTimeFormat"];
}

- (void) unsetTimeFormat
{
  [self removeObjectForKey: @"SOGoTimeFormat"];
}

- (NSString *) timeFormat
{
  return [self stringForKey: @"SOGoTimeFormat"];
}

- (void) setLanguage: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoLanguage"];
}

- (NSString *) language
{
  NSArray *supportedLanguages;

  if (!userLanguage)
    {
      /* see SOGoDomainDefaults for the meaning of this */
      userLanguage = [source objectForKey: @"SOGoLanguage"];
      if (!(userLanguage && [userLanguage isKindOfClass: [NSString class]]))
        userLanguage = [(SOGoDomainDefaults *) parentSource language];
  
      supportedLanguages = [[SOGoSystemDefaults sharedSystemDefaults]
                             supportedLanguages];

      /* make sure the language is part of the supported languages */
      if (![supportedLanguages containsObject: userLanguage])
        userLanguage = [parentSource stringForKey: @"SOGoLanguage"];
      [userLanguage retain];
    }

  return userLanguage;
}

- (void) setMailAddOutgoingAddresses: (BOOL) newValue
{
  [self setBool: newValue forKey: @"SOGoMailAddOutgoingAddresses"];
}

- (BOOL) mailAddOutgoingAddresses
{
  return [self boolForKey: @"SOGoMailAddOutgoingAddresses"];
}

- (void) setMailShowSubscribedFoldersOnly: (BOOL) newValue
{
  [self setBool: newValue forKey: @"SOGoMailShowSubscribedFoldersOnly"];
}

- (BOOL) mailShowSubscribedFoldersOnly
{
  return [self boolForKey: @"SOGoMailShowSubscribedFoldersOnly"];
}

- (void) setSynchronizeOnlyDefaultMailFolders: (BOOL) newValue
{
  [self setBool: newValue forKey: @"SOGoMailSynchronizeOnlyDefaultFolders"];
}

- (BOOL) synchronizeOnlyDefaultMailFolders
{
  return [self boolForKey: @"SOGoMailSynchronizeOnlyDefaultFolders"];
}

- (void) setMailSortByThreads: (BOOL) newValue
{
  [self setBool: newValue forKey: @"SOGoMailSortByThreads"];
}

- (BOOL) mailSortByThreads
{
  return [self boolForKey: @"SOGoMailSortByThreads"];
}

- (void) setDraftsFolderName: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoDraftsFolderName"];
}

- (NSString *) draftsFolderName
{
  return [[self stringForKey: @"SOGoDraftsFolderName"]
             stringByEncodingImap4FolderName];
}

- (void) setSentFolderName: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoSentFolderName"];
}

- (NSString *) sentFolderName
{
  return [[self stringForKey: @"SOGoSentFolderName"]
             stringByEncodingImap4FolderName];
}

- (void) setTrashFolderName: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoTrashFolderName"];
}

- (NSString *) trashFolderName
{
  return [[self stringForKey: @"SOGoTrashFolderName"]
             stringByEncodingImap4FolderName];
}

- (void) setJunkFolderName: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoJunkFolderName"];
}

- (NSString *) junkFolderName
{
  return [[self stringForKey: @"SOGoJunkFolderName"]
             stringByEncodingImap4FolderName];
}

- (void) setTemplatesFolderName: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoTemplatesFolderName"];
}

- (NSString *) templatesFolderName
{
  return [[self stringForKey: @"SOGoTemplatesFolderName"]
           stringByEncodingImap4FolderName];
}

- (void) setFirstDayOfWeek: (int) newValue
{
  [self setInteger: newValue forKey: @"SOGoFirstDayOfWeek"];
}

- (int) firstDayOfWeek
{
  return [self integerForKey: @"SOGoFirstDayOfWeek"];
}

- (void) setFirstWeekOfYear: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoFirstWeekOfYear"];
}

- (NSString *) firstWeekOfYear
{
  return [self stringForKey: @"SOGoFirstWeekOfYear"];
}

- (void) setMailListViewColumnsOrder: (NSArray *) newValue
{
  [self setObject: newValue forKey: @"SOGoMailListViewColumnsOrder"];
}

- (NSArray *) mailListViewColumnsOrder
{
  return [self stringArrayForKey: @"SOGoMailListViewColumnsOrder"];
}

- (void) setSelectedAddressBook: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoSelectedAddressBook"];
}

- (NSString *) selectedAddressBook
{
  return [self stringForKey: @"SOGoSelectedAddressBook"];
}

- (void) setRefreshViewCheck: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoRefreshViewCheck"];
}

- (NSString *) refreshViewCheck
{
  return [self stringForKey: @"SOGoRefreshViewCheck"];
}

- (BOOL) gravatarEnabled
{
  return [self boolForKey: @"SOGoGravatarEnabled"];
}

- (void) setAlternateAvatar: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoAlternateAvatar"];
}

- (NSString *) alternateAvatar
{
  return [self stringForKey: @"SOGoAlternateAvatar"];
}

- (void) setAnimationMode: (NSString *) newValue
{
  if ([newValue isEqualToString: @"normal"] ||
      [newValue isEqualToString: @"limited"] ||
      [newValue isEqualToString: @"none"])
    [self setObject: newValue forKey: @"SOGoAnimationMode"];
}

- (NSString *) animationMode
{
  return [self stringForKey: @"SOGoAnimationMode"];
}

- (BOOL) totpEnabled
{
  return [self boolForKey: @"SOGoTOTPEnabled"];
}

- (void) setTotpEnabled: (BOOL) newValue
{
  [self setBool: newValue  forKey: @"SOGoTOTPEnabled"];
}

- (void) setMailComposeWindow: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoMailComposeWindow"];
}

- (NSString *) mailComposeWindow
{
  return [self stringForKey: @"SOGoMailComposeWindow"];
}

- (void) setMailComposeMessageType: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoMailComposeMessageType"];
}

- (NSString *) mailComposeMessageType
{
  return [self stringForKey: @"SOGoMailComposeMessageType"];
}

- (void) setMailComposeFontSize: (int) newValue
{
  [self setInteger: newValue forKey: @"SOGoMailComposeFontSize"];
}

- (int) mailComposeFontSize
{
  return [self integerForKey: @"SOGoMailComposeFontSize"];
}

- (void) setMailDisplayRemoteInlineImages: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoMailDisplayRemoteInlineImages"];
}

- (NSString *) mailDisplayRemoteInlineImages;
{
  return [self stringForKey: @"SOGoMailDisplayRemoteInlineImages"];
}

- (void) setMailAutoMarkAsReadDelay: (int) newValue
{
  [self setInteger: newValue forKey: @"SOGoMailAutoMarkAsReadDelay"];
}

- (int) mailAutoMarkAsReadDelay
{
  return [self integerForKey: @"SOGoMailAutoMarkAsReadDelay"];
}

- (void) setMailAutoSave: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoMailAutoSave"];
}

- (NSString *) mailAutoSave
{
  NSString *s;

  s = [self stringForKey: @"SOGoMailAutoSave"];

  if ([s intValue] == 0)
    s = @"5";
  
  return s;
}

- (void) setMailMessageForwarding: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoMailMessageForwarding"];
}

- (NSString *) mailMessageForwarding
{
  return [self stringForKey: @"SOGoMailMessageForwarding"];
}

- (void) setMailReplyPlacement: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoMailReplyPlacement"];
}

- (NSString *) mailReplyPlacement
{
  return [self stringForKey: @"SOGoMailReplyPlacement"];
}

- (void) setMailSignaturePlacement: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoMailSignaturePlacement"];
}

- (NSString *) mailSignaturePlacement
{
  NSString *signaturePlacement;

  if ([[self mailReplyPlacement] isEqualToString: @"below"])
    // When replying to an email, if the reply is below the quoted text,
    // the signature must also be below the quoted text.
    signaturePlacement = @"below";
  else
    signaturePlacement = [self stringForKey: @"SOGoMailSignaturePlacement"];

  return signaturePlacement;
}

- (void) setAllowUserReceipt: (BOOL) allow
{
  [self setBool: allow forKey: @"SOGoMailReceiptAllow"];
}

- (BOOL) allowUserReceipt
{
  return [self boolForKey: @"SOGoMailReceiptAllow"];
}

- (void) setUserReceiptNonRecipientAction: (NSString *) action
{
  [self setObject: action forKey: @"SOGoMailReceiptNonRecipientAction"];
}

- (NSString *) userReceiptNonRecipientAction
{
  return [self stringForKey: @"SOGoMailReceiptNonRecipientAction"];
}

- (void) setUserReceiptOutsideDomainAction: (NSString *) action
{
  [self setObject: action forKey: @"SOGoMailReceiptOutsideDomainAction"];
}

- (NSString *) userReceiptOutsideDomainAction
{
  return [self stringForKey: @"SOGoMailReceiptOutsideDomainAction"];
}

- (void) setUserReceiptAnyAction: (NSString *) action
{
  [self setObject: action forKey: @"SOGoMailReceiptAnyAction"];
}

- (NSString *) userReceiptAnyAction
{
  return [self stringForKey: @"SOGoMailReceiptAnyAction"];
}

- (void) setMailUseOutlookStyleReplies: (BOOL) newValue
{
  [self setBool: newValue forKey: @"SOGoMailUseOutlookStyleReplies"];
}

- (BOOL) mailUseOutlookStyleReplies
{
  return [self boolForKey: @"SOGoMailUseOutlookStyleReplies"];
}

- (void) setMailCertificate: (NSData *) newValue
{
  [self setObject: [newValue stringByEncodingBase64] forKey: @"SOGoMailCertificate"];
}

- (void) unsetMailCertificate
{
  [self removeObjectForKey: @"SOGoMailCertificate"];
}

- (NSString *) mailCertificate
{
  return [self stringForKey: @"SOGoMailCertificate"];
}

- (void) setMailCertificateAlwaysSign: (BOOL) newValue
{
  [self setBool: newValue forKey: @"SOGoMailCertificateAlwaysSign"];
}

- (BOOL) mailCertificateAlwaysSign
{
  return [self boolForKey: @"SOGoMailCertificateAlwaysSign"];
}

- (void) setMailCertificateAlwaysEncrypt: (BOOL) newValue
{
  [self setBool: newValue forKey: @"SOGoMailCertificateAlwaysEncrypt"];
}

- (BOOL) mailCertificateAlwaysEncrypt
{
  return [self boolForKey: @"SOGoMailCertificateAlwaysEncrypt"];
}

- (void) setMailIdentities: (NSArray *) newIdentites
{
  [self setObject: newIdentites forKey: @"SOGoMailIdentities"];
}

- (NSArray *) mailIdentities
{
  return [self arrayForKey: @"SOGoMailIdentities"];
}

- (void) setMailForceDefaultIdentity: (BOOL) newValue
{
  [self setBool: newValue forKey: @"SOGoMailForceDefaultIdentity"];
}

- (BOOL) mailForceDefaultIdentity
{
  return [self boolForKey: @"SOGoMailForceDefaultIdentity"];
}

- (void) setAuxiliaryMailAccounts: (NSArray *) newAccounts
{
  [self setObject: newAccounts forKey: @"AuxiliaryMailAccounts"];
}

- (NSArray *) auxiliaryMailAccounts
{
  return [self arrayForKey: @"AuxiliaryMailAccounts"];
}

- (void) setCalendarCategories: (NSArray *) newValues
{
  [self setObject: newValues forKey: @"SOGoCalendarCategories"];
}

- (NSArray *) calendarCategories
{
  return [self stringArrayForKey: @"SOGoCalendarCategories"];
}

- (void) setCalendarCategoriesColors: (NSDictionary *) newValues
{
  [self setObject: newValues forKey: @"SOGoCalendarCategoriesColors"];
}

- (NSDictionary *) calendarCategoriesColors
{
  return [self objectForKey: @"SOGoCalendarCategoriesColors"];
}

- (void) setCalendarWeekdays: (NSArray *) newValues
{
  [self setObject: newValues forKey: @"SOGoCalendarWeekdays"];
}

- (NSArray *) calendarWeekdays
{
  return [self stringArrayForKey: @"SOGoCalendarWeekdays"];
}

- (void) setCalendarShouldDisplayWeekend: (BOOL) newValue
{
  [self setBool: newValue forKey: @"SOGoCalendarShouldDisplayWeekend"];
}

- (BOOL) calendarShouldDisplayWeekend
{
  return [self boolForKey: @"SOGoCalendarShouldDisplayWeekend"];
}

- (void) setCalendarEventsDefaultClassification: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoCalendarEventsDefaultClassification"];
}

- (NSString *) calendarEventsDefaultClassification
{
  return [self stringForKey: @"SOGoCalendarEventsDefaultClassification"];
}

- (void) setCalendarTasksDefaultClassification: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoCalendarTasksDefaultClassification"];
}

- (NSString *) calendarTasksDefaultClassification
{
  return [self stringForKey: @"SOGoCalendarTasksDefaultClassification"];
}

- (void) setCalendarDefaultReminder: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoCalendarDefaultReminder"];
}

- (NSString *) calendarDefaultReminder
{
  return [self stringForKey: @"SOGoCalendarDefaultReminder"];
}

//
// Dictionary of arrays. Example:
//
// {
//   label1 => ("Important", "#FF0000");
//   label2 => ("Work" "#00FF00");
//   foo_bar => ("Foo Bar", "#0000FF");
// }
//
- (void) setMailLabelsColors: (NSDictionary *) newValues
{
  [self setObject: newValues forKey: @"SOGoMailLabelsColors"];
}

- (NSDictionary *) mailLabelsColors
{
  return [self objectForKey: @"SOGoMailLabelsColors"];
}

- (void) setSieveFilters: (NSArray *) newValue
{
  [self setObject: newValue forKey: @"SOGoSieveFilters"];
}

- (NSArray *) sieveFilters
{
  return [self arrayForKey: @"SOGoSieveFilters"];
}

- (void) setVacationOptions: (NSDictionary *) newValue
{
  [self setObject: newValue forKey: @"Vacation"];
}

- (NSDictionary *) vacationOptions
{
  return [self dictionaryForKey: @"Vacation"];
}

- (void) setForwardOptions: (NSDictionary *) newValue
{
  [self setObject: newValue forKey: @"Forward"];
}

- (NSDictionary *) forwardOptions
{
  return [self dictionaryForKey: @"Forward"];
}

- (void) setContactsCategories: (NSArray *) newValues
{
  [self setObject: newValues forKey: @"SOGoContactsCategories"];
}

- (NSArray *) contactsCategories
{
  return [self stringArrayForKey: @"SOGoContactsCategories"];
}

- (void) setPasswordRecoveryMode: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoPasswordRecoveryMode"];
}

- (NSString *) passwordRecoveryMode
{
  return [self stringForKey: @"SOGoPasswordRecoveryMode"];
}

- (void) setPasswordRecoveryQuestion: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoPasswordRecoveryQuestion"];
}

- (NSString *) passwordRecoveryQuestion
{
  return [self stringForKey: @"SOGoPasswordRecoveryQuestion"];
}

- (void) setPasswordRecoveryQuestionAnswer: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoPasswordRecoveryQuestionAnswer"];
}

- (NSString *) passwordRecoveryQuestionAnswer
{
  return [self stringForKey: @"SOGoPasswordRecoveryQuestionAnswer"];
}

- (void) setPasswordRecoverySecondaryEmail: (NSString *) newValue
{
  [self setObject: newValue forKey: @"SOGoPasswordRecoverySecondaryEmail"];
}

- (NSString *) passwordRecoverySecondaryEmail
{
  return [self stringForKey: @"SOGoPasswordRecoverySecondaryEmail"];
}

@end
