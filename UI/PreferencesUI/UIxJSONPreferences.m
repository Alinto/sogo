/* UIxJSONPreferences.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2017 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/SoObjects.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGExtensions/NSObject+Logs.h>

#import <SOPE/NGCards/iCalRecurrenceRule.h>

#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoUserProfile.h>
#import <SOGo/WOResourceManager+SOGo.h>
#import <SOGoUI/UIxComponent.h>
#import <Mailer/SOGoMailLabel.h>

#import "UIxJSONPreferences.h"

static SoProduct *preferencesProduct = nil;

@implementation UIxJSONPreferences

- (NSDictionary *) _localizedCategoryLabels
{
  NSArray *categoryLabels, *localizedCategoryLabels;
  NSDictionary *labelsDictionary;

  labelsDictionary = nil;
  localizedCategoryLabels = [[self labelForKey: @"calendar_category_labels"
                                   withResourceManager: [preferencesProduct resourceManager]]
                              componentsSeparatedByString: @","];
  categoryLabels = [[[preferencesProduct resourceManager]
                                      stringForKey: @"calendar_category_labels"
                                      inTableNamed: nil
                                  withDefaultValue: @""
                                         languages: [NSArray arrayWithObject: @"English"]]
                                      componentsSeparatedByString: @","];

  if ([localizedCategoryLabels count] == [categoryLabels count])
    labelsDictionary = [NSDictionary dictionaryWithObjects: localizedCategoryLabels
                                                   forKeys: categoryLabels];
  else
    [self logWithFormat: @"ERROR: localizable strings calendar_category_labels is incorrect for language %@",
          [[[context activeUser] userDefaults] language]];

  return labelsDictionary;
}

- (WOResponse *) jsonDefaultsAction
{
  return [self responseWithStatus: 200
                        andString: [self jsonDefaults]];
}

- (NSString *) jsonDefaults
{
  NSMutableDictionary *values, *account, *vacation;
  SOGoUserDefaults *defaults;
  SOGoDomainDefaults *domainDefaults;
  NSMutableArray *accounts;
  NSDictionary *categoryLabels, *vacationOptions;

  if (!preferencesProduct)
    {
      preferencesProduct = [[SoProduct alloc] initWithBundle:
                                    [NSBundle bundleForClass: NSClassFromString(@"PreferencesUIProduct")]];
    }

  defaults = [[context activeUser] userDefaults];
  domainDefaults = [[context activeUser] domainDefaults];
  categoryLabels = nil;

  //
  // Default General preferences
  //
  if (![[defaults source] objectForKey: @"SOGoLanguage"])
    [[defaults source] setObject: [defaults language]  forKey: @"SOGoLanguage"];

  if (![[defaults source] objectForKey: @"SOGoTimeZone"])
    [[defaults source] setObject: [defaults timeZoneName]  forKey: @"SOGoTimeZone"];

  if (![[defaults source] objectForKey: @"SOGoShortDateFormat"])
    [[defaults source] setObject: [defaults shortDateFormat]  forKey: @"SOGoShortDateFormat"];

  if (![[defaults source] objectForKey: @"SOGoLongDateFormat"])
    [[defaults source] setObject: [defaults longDateFormat]  forKey: @"SOGoLongDateFormat"];

  if (![[defaults source] objectForKey: @"SOGoTimeFormat"])
    [[defaults source] setObject: [defaults timeFormat]  forKey: @"SOGoTimeFormat"];

  if (![[defaults source] objectForKey: @"SOGoLoginModule"])
    [[defaults source] setObject: [defaults loginModule]  forKey: @"SOGoLoginModule"];

  if (![[defaults source] objectForKey: @"SOGoRefreshViewCheck"])
    [[defaults source] setObject: [defaults refreshViewCheck]  forKey: @"SOGoRefreshViewCheck"];

  if ([domainDefaults externalAvatarsEnabled])
    {
      if (![[defaults source] objectForKey: @"SOGoGravatarEnabled"])
        [[defaults source] setObject: [NSNumber numberWithBool: [defaults gravatarEnabled]]  forKey: @"SOGoGravatarEnabled"];
      if (![[defaults source] objectForKey: @"SOGoAlternateAvatar"])
        [[defaults source] setObject: [defaults alternateAvatar]  forKey: @"SOGoAlternateAvatar"];
    }
  else
    {
      [[defaults source] setObject: [NSNumber numberWithInt: 0]  forKey: @"SOGoGravatarEnabled"];
      [[defaults source] removeObjectForKey: @"SOGoAlternateAvatar"];
    }

  if (![[defaults source] objectForKey: @"SOGoAnimationMode"])
    [[defaults source] setObject: [defaults animationMode]  forKey: @"SOGoAnimationMode"];

  //
  // Default Calendar preferences
  //
  if (![[defaults source] objectForKey: @"SOGoFirstDayOfWeek"])
    [[defaults source] setObject: [NSNumber numberWithInt: [defaults firstDayOfWeek]] forKey: @"SOGoFirstDayOfWeek"];

  if (![[defaults source] objectForKey: @"SOGoDayStartTime"])
    [[defaults source] setObject: [NSString stringWithFormat: @"%02d:00", [defaults dayStartHour]] forKey: @"SOGoDayStartTime"];

  if (![[defaults source] objectForKey: @"SOGoDayEndTime"])
    [[defaults source] setObject: [NSString stringWithFormat: @"%02d:00", [defaults dayEndHour]] forKey: @"SOGoDayEndTime"];

  if (![[defaults source] objectForKey: @"SOGoCalendarWeekdays"])
    [[defaults source] setObject: [NSArray arrayWithObjects: iCalWeekDayString count: 7] forKey: @"SOGoCalendarWeekdays"];

  if (![[defaults source] objectForKey: @"SOGoFirstWeekOfYear"])
    [[defaults source] setObject: [defaults firstWeekOfYear] forKey: @"SOGoFirstWeekOfYear"];

  if (![[defaults source] objectForKey: @"SOGoDefaultCalendar"])
    [[defaults source] setObject: [defaults defaultCalendar] forKey: @"SOGoDefaultCalendar"];

  if (![[defaults source] objectForKey: @"SOGoCalendarEventsDefaultClassification"])
    [[defaults source] setObject: [defaults calendarEventsDefaultClassification] forKey: @"SOGoCalendarEventsDefaultClassification"];

  if (![[defaults source] objectForKey: @"SOGoCalendarTasksDefaultClassification"])
    [[defaults source] setObject: [defaults calendarTasksDefaultClassification] forKey: @"SOGoCalendarTasksDefaultClassification"];

  if (![[defaults source] objectForKey: @"SOGoCalendarDefaultReminder"])
    [[defaults source] setObject: [defaults calendarDefaultReminder] forKey: @"SOGoCalendarDefaultReminder"];

  // Populate default calendar categories, based on the user's preferred language
  if (![[defaults source] objectForKey: @"SOGoCalendarCategories"])
    {
      NSArray *defaultCalendarCategories;

      categoryLabels = [self _localizedCategoryLabels];

      if ((defaultCalendarCategories = [defaults calendarCategories]))
        {
          // Calendar categories are taken from SOGo's configuration or SOGoDefaults.plist

          NSMutableArray *filteredCalendarCategories;
          NSString *label, *localizedLabel;
          int count, max;

          max = [defaultCalendarCategories count];
          filteredCalendarCategories = [NSMutableArray arrayWithCapacity: max];

          for (count = 0; count < max; count++)
            {
              label = [defaultCalendarCategories objectAtIndex: count];
              if (!(localizedLabel = [categoryLabels objectForKey: label]))
                {
                  localizedLabel = label;
                }
              [filteredCalendarCategories addObject: localizedLabel];
            }

          [defaults setCalendarCategories: filteredCalendarCategories];
        }
      else
        {
          // Calendar categories are taken from localizable strings

          [defaults setCalendarCategories: [categoryLabels allValues]];
        }
    }
  if (![[defaults source] objectForKey: @"SOGoCalendarCategoriesColors"])
    {
      NSDictionary *defaultCalendarCategoriesColors;

      if (!categoryLabels)
        categoryLabels = [self _localizedCategoryLabels];

      if ((defaultCalendarCategoriesColors = [defaults calendarCategoriesColors]))
        {
          // Calendar categories colors are taken from SOGo's configuration or SOGoDefaults.plist

          NSArray *defaultCalendarCategories;
          NSMutableDictionary *filteredCalendarCategoriesColors;
          NSString *label, *localizedLabel;
          int count, max;

          defaultCalendarCategories = [defaultCalendarCategoriesColors allKeys];
          max = [defaultCalendarCategories count];
          filteredCalendarCategoriesColors = [NSMutableDictionary dictionaryWithCapacity: max];

          for (count = 0; count < max; count++)
            {
              label = [defaultCalendarCategories objectAtIndex: count];
              if (!(localizedLabel = [categoryLabels objectForKey: label]))
                {
                  localizedLabel = label;
                }
              [filteredCalendarCategoriesColors setObject: [defaultCalendarCategoriesColors objectForKey: label]
                                                   forKey: localizedLabel];
            }

          [defaults setCalendarCategoriesColors: filteredCalendarCategoriesColors];
        }
      else
        {
          // Calendar categories colors are set to #CCC

          NSArray *calendarCategories;
          NSMutableDictionary *colors;
          int i;

          calendarCategories = [categoryLabels allValues];
          colors = [NSMutableDictionary dictionaryWithCapacity: [calendarCategories count]];

          for (i = 0; i < [calendarCategories count]; i++)
            [colors setObject: @"#CCCCCCC"  forKey: [calendarCategories objectAtIndex: i]];

          [defaults setCalendarCategoriesColors: colors];
        }
    }

  //
  // Default Contacts preferences
  //
  // Populate default contact categories, based on the user's preferred language
  //
  if (![defaults contactsCategories])
    {
      categoryLabels = [[[self labelForKey: @"contacts_category_labels"  withResourceManager: [preferencesProduct resourceManager]]
                          componentsSeparatedByString: @","]
                          sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)];

      if (!categoryLabels)
        categoryLabels = [NSArray array];

      [defaults setContactsCategories: categoryLabels];
    }

  if (![[defaults source] objectForKey: @"SOGoMailAddOutgoingAddresses"])
    [[defaults source] setObject: [NSNumber numberWithBool: [defaults mailAddOutgoingAddresses]] forKey: @"SOGoMailAddOutgoingAddresses"];

  //
  // Default Mail preferences
  //
  if (![[defaults source] objectForKey: @"SOGoMailComposeWindow"])
    [[defaults source] setObject: [defaults mailComposeWindow] forKey: @"SOGoMailComposeWindow"];

  if (![[defaults source] objectForKey: @"SOGoSelectedAddressBook"])
    [[defaults source] setObject: [defaults selectedAddressBook] forKey: @"SOGoSelectedAddressBook"];

  if (![[defaults source] objectForKey: @"SOGoMailMessageForwarding"])
    [[defaults source] setObject: [defaults mailMessageForwarding] forKey: @"SOGoMailMessageForwarding"];

  if (![[defaults source] objectForKey: @"SOGoMailReplyPlacement"])
    [[defaults source] setObject: [defaults mailReplyPlacement] forKey: @"SOGoMailReplyPlacement"];

  if (![[defaults source] objectForKey: @"SOGoMailSignaturePlacement"])
    [[defaults source] setObject: [defaults mailSignaturePlacement] forKey: @"SOGoMailSignaturePlacement"];

  if (![[defaults source] objectForKey: @"SOGoMailComposeMessageType"])
    [[defaults source] setObject: [defaults mailComposeMessageType] forKey: @"SOGoMailComposeMessageType"];

  if (![[defaults source] objectForKey: @"SOGoMailComposeFontSize"])
    [[defaults source] setObject: [defaults mailComposeFontSize] forKey: @"SOGoMailComposeFontSize"];

  if (![[defaults source] objectForKey: @"SOGoMailDisplayRemoteInlineImages"])
    [[defaults source] setObject: [defaults mailDisplayRemoteInlineImages] forKey: @"SOGoMailDisplayRemoteInlineImages"];

  if (![[defaults source] objectForKey: @"SOGoMailAutoSave"])
    [[defaults source] setObject: [defaults mailAutoSave] forKey: @"SOGoMailAutoSave"];

  // Populate default mail labels, based on the user's preferred language
  if (![[defaults source] objectForKey: @"SOGoMailLabelsColors"])
    {
      SOGoMailLabel *label;
      NSArray *labels;
      id v;

      int i;

      v = [defaults mailLabelsColors];

      labels = [SOGoMailLabel labelsFromDefaults: v  component: self];
      v = [NSMutableDictionary dictionary];
      for (i = 0; i < [labels count]; i++)
        {
          label = [labels objectAtIndex: i];
          [v setObject: [NSArray arrayWithObjects: [label label], [label color], nil]
                forKey: [label name]];
        }

      [defaults setMailLabelsColors: v];
    }

  if ([[defaults source] dirty])
    [defaults synchronize];

  values = [[[[defaults source] values] mutableCopy] autorelease];

  //
  // Expose additional information that must *not* be synchronized in the defaults
  //

  // Expose the SOGoAppointmentSendEMailNotifications configuration parameter from the domain defaults
  [values setObject: [NSNumber numberWithBool: [domainDefaults appointmentSendEMailNotifications]]
             forKey: @"SOGoAppointmentSendEMailNotifications"];

  // Add locale code (used by CK Editor)
  [values setObject: [locale objectForKey: @"NSLocaleCode"] forKey: @"LocaleCode"];
  [values setObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                           [locale objectForKey: @"NSMonthNameArray"], @"months",
                                           [locale objectForKey: @"NSShortMonthNameArray"], @"shortMonths",
                                           [locale objectForKey: @"NSWeekDayNameArray"], @"days",
                                           [locale objectForKey: @"NSShortWeekDayNameArray"], @"shortDays",
                                                    nil] forKey: @"locale"];

  accounts = [NSMutableArray arrayWithArray: [values objectForKey: @"AuxiliaryMailAccounts"]];
  if ([accounts count])
    {
      int i;
      NSDictionary *security;
      NSMutableDictionary *auxAccount, *limitedSecurity;

      for (i = 0; i < [accounts count]; i++)
        {
          auxAccount = [accounts objectAtIndex: i];
          security = [auxAccount objectForKey: @"security"];
          if (security)
            {
              limitedSecurity = [NSMutableDictionary dictionaryWithDictionary: security];
              if ([limitedSecurity objectForKey: @"certificate"])
                {
                  [limitedSecurity setObject: [NSNumber numberWithBool: YES] forKey: @"hasCertificate"];
                  [limitedSecurity removeObjectForKey: @"certificate"];
                }
              [auxAccount setObject: limitedSecurity forKey: @"security"];
            }
        }
    }
  // We inject our default mail account
  account = [[[context activeUser] mailAccounts] objectAtIndex: 0];
  if (![account objectForKey: @"receipts"])
    {
      [account setObject: [NSDictionary dictionaryWithObjectsAndKeys: @"ignore", @"receiptAction",
                                        @"ignore", @"receiptNonRecipientAction",
                                        @"ignore", @"receiptOutsideDomainAction",
                                        @"ignore", @"receiptAnyAction", nil]
                  forKey:  @"receipts"];
    }
  if (account)
    [accounts insertObject: account  atIndex: 0];
  [values removeObjectForKey: @"SOGoMailCertificate"];
  [values removeObjectForKey: @"SOGoMailCertificateAlwaysSign"];
  [values removeObjectForKey: @"SOGoMailCertificateAlwaysEncrypt"];
  [values setObject: accounts  forKey: @"AuxiliaryMailAccounts"];

  // Add the domain's default vacation subject if user has not specified a custom subject
  vacationOptions = [defaults vacationOptions];
  if (![[vacationOptions objectForKey: @"customSubject"] length] && [domainDefaults vacationDefaultSubject])
    {
      if (vacationOptions)
        vacation = [NSMutableDictionary dictionaryWithDictionary: vacationOptions];
      else
        vacation = [NSMutableDictionary dictionary];

      [vacation setObject: [domainDefaults vacationDefaultSubject] forKey: @"customSubject"];
      [values setObject: vacation forKey: @"Vacation"];
    }

  return [values jsonRepresentation];
}

- (WOResponse *) jsonSettingsAction
{
  return [self responseWithStatus: 200
                        andString: [self jsonSettings]];
}

- (NSString *) jsonSettings
{
  SOGoUserSettings *settings;
  id v;

  settings = [[context activeUser] userSettings];

  // We sanitize PreventInvitationsWhitelist if we need to, this is due to the fact
  // that SOGo <= 2.2.17 used to store it as a JSON *string* within the JSON-blob -
  // sorry about this engineering brain fart!
  v = [[settings objectForKey: @"Calendar"] objectForKey: @"PreventInvitationsWhitelist"];

  if (v && [v isKindOfClass: [NSString class]])
    {
      [[settings objectForKey: @"Calendar"] setObject: [v objectFromJSONString]
                                               forKey: @"PreventInvitationsWhitelist"];
    }

  // Initialize some default values
  if (![settings objectForKey: @"Calendar"])
    [settings setObject: [NSMutableDictionary dictionary]  forKey: @"Calendar"];

  if (![settings objectForKey: @"Contact"])
    [settings setObject: [NSMutableDictionary dictionary]  forKey: @"Contact"];

  if (![settings objectForKey: @"Mail"])
    [settings setObject: [NSMutableDictionary dictionary]  forKey: @"Mail"];

  return [[[settings source] values] jsonRepresentation];
}

@end
