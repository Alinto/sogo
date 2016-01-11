/* UIxJSONPreferences.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2015 Inverse inc.
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
#import <NGObjWeb/WODirectAction.h>
#import <NGObjWeb/WOResponse.h>

#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoUserProfile.h>
#import <SOGo/WOResourceManager+SOGo.h>
#import <Mailer/SOGoMailLabel.h>

#import <SOGoUI/UIxComponent.h>
#import <UI/Common/WODirectAction+SOGo.h>

#import "UIxJSONPreferences.h"

static SoProduct *preferencesProduct = nil;

@implementation UIxJSONPreferences

- (WOResponse *) jsonDefaultsAction
{
  NSMutableDictionary *values, *account;
  SOGoUserDefaults *defaults;
  NSMutableArray *accounts;
  NSArray *categoryLabels;
  NSDictionary *locale;

  if (!preferencesProduct)
    {
      preferencesProduct = [[SoProduct alloc] initWithBundle:
                                    [NSBundle bundleForClass: NSClassFromString(@"PreferencesUIProduct")]];
    }

  defaults = [[context activeUser] userDefaults];

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

  if (![[defaults source] objectForKey: @"SOGoAlternateAvatar"])
      [[defaults source] setObject: [defaults alternateAvatar]  forKey: @"SOGoAlternateAvatar"];

  //
  // Default Calendar preferences
  //
  if (![[defaults source] objectForKey: @"SOGoFirstDayOfWeek"])
    [[defaults source] setObject: [NSNumber numberWithInt: [defaults firstDayOfWeek]] forKey: @"SOGoFirstDayOfWeek"];

  if (![[defaults source] objectForKey: @"SOGoDayStartTime"])
    [[defaults source] setObject: [NSString stringWithFormat: @"%02d:00", [defaults dayStartHour]] forKey: @"SOGoDayStartTime"];

  if (![[defaults source] objectForKey: @"SOGoDayEndTime"])
    [[defaults source] setObject: [NSString stringWithFormat: @"%02d:00", [defaults dayEndHour]] forKey: @"SOGoDayEndTime"];

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
  if (![defaults calendarCategories])
    {
      categoryLabels = [[[self labelForKey: @"calendar_category_labels"  withResourceManager: [preferencesProduct resourceManager]]
                         componentsSeparatedByString: @","]
                         sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)];

      [defaults setCalendarCategories: categoryLabels];

      // TODO: build categories colors dictionary with localized keys
    }
  if (![defaults calendarCategoriesColors])
    {
      NSMutableDictionary *colors;
      int i;

      categoryLabels = [defaults calendarCategories];
      colors = [NSMutableDictionary dictionaryWithCapacity: [categoryLabels count]];

      for (i = 0; i < [categoryLabels count]; i++)
        [colors setObject: @"#aaa"  forKey: [categoryLabels objectAtIndex: i]];

      [defaults setCalendarCategoriesColors: colors];
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

  //
  // Default Mail preferences
  //
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

  if (![[defaults source] objectForKey: @"SOGoMailDisplayRemoteInlineImages"])
    [[defaults source] setObject: [defaults mailDisplayRemoteInlineImages] forKey: @"SOGoMailDisplayRemoteInlineImages"];

  // Populate default mail lablels, based on the user's preferred language
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

  //
  // We inject our default mail account, something we don't want to do before we
  // call -synchronize on our defaults.
  //
  values = [[[[defaults source] values] mutableCopy] autorelease];

  // Add locale code (used by CK Editor)
  locale = [[preferencesProduct resourceManager] localeForLanguageNamed: [defaults language]];
  [values setObject: [locale objectForKey: @"NSLocaleCode"] forKey: @"LocaleCode"];
  [values setObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                           [locale objectForKey: @"NSMonthNameArray"], @"months",
                                           [locale objectForKey: @"NSShortMonthNameArray"], @"shortMonths",
                                           [locale objectForKey: @"NSWeekDayNameArray"], @"days",
                                           [locale objectForKey: @"NSShortWeekDayNameArray"], @"shortDays",
                                                    nil] forKey: @"locale"];

  accounts = [NSMutableArray arrayWithArray: [values objectForKey: @"AuxiliaryMailAccounts"]];
  account = [[[context activeUser] mailAccounts] objectAtIndex: 0];
  if (![account objectForKey: @"receipts"])
    {
      [account setObject: [NSDictionary dictionaryWithObjectsAndKeys: @"ignore", @"receiptAction",
                                        @"ignore", @"receiptNonRecipientAction",
                                        @"ignore", @"receiptOutsideDomainAction",
                                        @"ignore", @"receiptAnyAction", nil]
                  forKey:  @"receipts"];
    }

  [accounts insertObject: account  atIndex: 0];
  [values setObject: accounts  forKey: @"AuxiliaryMailAccounts"];


  return [self responseWithStatus: 200 andJSONRepresentation: values];
}

- (WOResponse *) jsonSettingsAction
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

  return [self responseWithStatus: 200 andJSONRepresentation: [[settings source] values]];
}

@end
