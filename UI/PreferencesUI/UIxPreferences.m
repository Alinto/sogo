/* UIxPreferences.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2010 Inverse inc.
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSScanner.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSUserDefaults.h> /* for locale strings */
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>

#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+BSJSONAdditions.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSScanner+BSJSONAdditions.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUserFolder.h>
#import <Mailer/SOGoMailAccount.h>
#import "../../Main/SOGo.h"

#import "UIxPreferences.h"

#warning this class is not finished
/* remaining:
   default event length
   default snooze length
   refresh calendar every X minutes
   workweek = from -> to
   identities */

@implementation UIxPreferences

- (id) init
{
  //NSDictionary *locale;
  SOGoDomainDefaults *dd;
  NSString *language;
  
  if ((self = [super init]))
    {
      item = nil;
      ASSIGN (user, [context activeUser]);
      ASSIGN (userDefaults, [user userDefaults]);
      ASSIGN (today, [NSCalendarDate date]);
      //locale = [context valueForKey: @"locale"];
      language = [userDefaults language];

      calendarCategories = nil;
      calendarCategoriesColors = nil;
      defaultCategoryColor = nil;
      category = nil;

      ASSIGN (locale,
              [[WOApplication application] localeForLanguageNamed: language]);
      ASSIGN (daysOfWeek, [locale objectForKey: NSWeekDayNameArray]);

      dd = [user domainDefaults];
      if ([dd sieveScriptsEnabled])
	{
	  sieveFilters = [[userDefaults sieveFilters] copy];
	  if (!sieveFilters)
            sieveFilters = [NSArray new];
	}

      if ([dd vacationEnabled])
	{
	  vacationOptions = [[userDefaults vacationOptions] mutableCopy];
	  if (!vacationOptions)
            vacationOptions = [NSMutableDictionary new];
	}

      if ([dd forwardEnabled])
	{
	  forwardOptions = [[userDefaults forwardOptions] mutableCopy];
	  if (!forwardOptions)
            forwardOptions = [NSMutableDictionary new];
	}

      hasChanged = NO;
    }

  return self;
}

- (void) dealloc
{
  [today release];
  [item release];
  [user release];
  [userDefaults release];
  [sieveFilters release];
  [vacationOptions release];
  [calendarCategories release];
  [calendarCategoriesColors release];
  [defaultCategoryColor release];
  [category release];
  [forwardOptions release];
  [daysOfWeek release];
  [locale release];
  [super dealloc];
}

- (void) setHasChanged: (BOOL) newHasChanged
{
  hasChanged = newHasChanged;
}

- (BOOL) hasChanged
{
  return hasChanged;
}

- (void) setItem: (NSString *) newItem
{
  ASSIGN (item, newItem);
}

- (NSString *) item
{
  return item;
}

- (NSArray *) timeZonesList
{
  return [[NSTimeZone knownTimeZoneNames]
           sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)];
}

- (NSString *) userTimeZone
{
  return [userDefaults timeZoneName];
}

- (void) setUserTimeZone: (NSString *) newUserTimeZone
{
  [userDefaults setTimeZoneName: newUserTimeZone];
}

- (NSArray *) shortDateFormatsList
{
  NSMutableArray *shortDateFormatsList = nil;
  NSString *key, *currentFormat;
  unsigned int nbr;
  BOOL done;

  shortDateFormatsList = [NSMutableArray arrayWithObject: @"default"];

  nbr = 0;
  done = NO;
  while (!done)
    {
      key = [NSString stringWithFormat: @"shortDateFmt_%d", nbr];
      currentFormat = [self labelForKey: key];
      if ([currentFormat length] > 0)
        {
          [shortDateFormatsList addObject: currentFormat];
          nbr++;
        }
      else
        done = YES;
    }

  return shortDateFormatsList;
}

- (NSString *) itemShortDateFormatText
{
  NSString *todayText, *shortDateFormatText;

  if ([item isEqualToString: @"default"])
    {
      todayText = [today descriptionWithCalendarFormat: [locale objectForKey: NSShortDateFormatString]
                                                locale: locale];
      shortDateFormatText = [NSString stringWithFormat: @"%@ (%@)",
                                     [self labelForKey: item],
                                      todayText];
    }
  else
    shortDateFormatText = [today descriptionWithCalendarFormat: item
                                                        locale: locale];

  return shortDateFormatText;
}

- (NSString *) userShortDateFormat
{
  return [userDefaults shortDateFormat];
}

- (void) setUserShortDateFormat: (NSString *) newFormat
{
  if ([newFormat isEqualToString: @"default"])
    [userDefaults unsetShortDateFormat];
  else
    [userDefaults setShortDateFormat: newFormat];
}

- (NSArray *) longDateFormatsList
{
  NSMutableArray *longDateFormatsList = nil;
  NSString *key, *currentFormat;
  unsigned int nbr;
  BOOL done;

  longDateFormatsList = [NSMutableArray arrayWithObject: @"default"];

  nbr = 0;
  done = NO;
  while (!done)
    {
      key = [NSString stringWithFormat: @"longDateFmt_%d", nbr];
      currentFormat = [self labelForKey: key];
      if ([currentFormat length] > 0)
        {
          [longDateFormatsList addObject: currentFormat];
          nbr++;
        }
      else
        done = YES;
    }

  if (![longDateFormatsList containsObject: [self userLongDateFormat]])
    [longDateFormatsList addObject: [self userLongDateFormat]];
  
  return longDateFormatsList;
}

- (NSString *) itemLongDateFormatText
{
  NSString *todayText, *longDateFormatText;

  if ([item isEqualToString: @"default"])
    {
      todayText = [today descriptionWithCalendarFormat: [locale objectForKey: NSDateFormatString]
                                                locale: locale];
      longDateFormatText = [NSString stringWithFormat: @"%@ (%@)",
                                    [self labelForKey: item],
                                     todayText];
    }
  else
    longDateFormatText = [today descriptionWithCalendarFormat: item
                                                       locale: locale];

  return longDateFormatText;
}

- (NSString *) userLongDateFormat
{
  NSString *longDateFormat;
 
  longDateFormat = [userDefaults longDateFormat];
  if (!longDateFormat)
    longDateFormat = @"default";

  return longDateFormat;
}

- (void) setUserLongDateFormat: (NSString *) newFormat
{
  if ([newFormat isEqualToString: @"default"])
    [userDefaults unsetLongDateFormat];
  else
    [userDefaults setLongDateFormat: newFormat];
}

- (NSArray *) timeFormatsList
{
  NSMutableArray *timeFormatsList = nil;
  NSString *key, *currentFormat;
  unsigned int nbr;
  BOOL done;

  timeFormatsList = [NSMutableArray arrayWithObject: @"default"];

  nbr = 0;
  done = NO;
  while (!done)
    {
      key = [NSString stringWithFormat: @"timeFmt_%d", nbr];
      currentFormat = [self labelForKey: key];
      if ([currentFormat length] > 0)
        {
          [timeFormatsList addObject: currentFormat];
          nbr++;
        }
      else
        done = YES;
    }

  return timeFormatsList;
}

- (NSString *) itemTimeFormatText
{
  NSString *todayText, *timeFormatText;
  SOGoDomainDefaults *dd;

  if ([item isEqualToString: @"default"])
    {
      dd = [user domainDefaults];
      todayText = [today descriptionWithCalendarFormat: [dd timeFormat]
                                                locale: locale];
      timeFormatText = [NSString stringWithFormat: @"%@ (%@)",
                                [self labelForKey: item],
                                 todayText];
    }
  else
    timeFormatText = [today descriptionWithCalendarFormat: item
                                                   locale: locale];

  return timeFormatText;
}

- (NSString *) userTimeFormat
{
  return [userDefaults timeFormat];
}

- (void) setUserTimeFormat: (NSString *) newFormat
{
  if ([newFormat isEqualToString: @"default"])
    [userDefaults unsetTimeFormat];
  else
    [userDefaults setTimeFormat: newFormat];
}

- (NSArray *) daysList
{
  NSMutableArray *daysList;
  unsigned int currentDay;

  daysList = [NSMutableArray array];
  for (currentDay = 0; currentDay < 7; currentDay++)
    [daysList addObject: [NSString stringWithFormat: @"%d", currentDay]];

  return daysList;
}

- (NSString *) itemWeekStartDay
{
  return [daysOfWeek objectAtIndex: [item intValue]];
}

- (NSString *) userWeekStartDay
{
  return [NSString stringWithFormat: @"%d", [userDefaults firstDayOfWeek]];
}

- (void) setUserWeekStartDay: (NSString *) newDay
{
  [userDefaults setFirstDayOfWeek: [newDay intValue]];
}

- (NSArray *) hoursList
{
  static NSMutableArray *hours = nil;
  unsigned int currentHour;

  if (!hours)
    {
      hours = [[NSMutableArray alloc] initWithCapacity: 24];
      for (currentHour = 0; currentHour < 24; currentHour++)
        [hours addObject: [NSString stringWithFormat: @"%.2d:00",
                                    currentHour]];
    }

  return hours;
}

- (NSString *) userDayStartTime
{
  return [NSString stringWithFormat: @"%02d:00",
                   [userDefaults dayStartHour]];
}

- (void) setUserDayStartTime: (NSString *) newTime
{
  [userDefaults setDayStartTime: newTime];
}

- (NSString *) userDayEndTime
{
  return [NSString stringWithFormat: @"%02d:00",
                   [userDefaults dayEndHour]];
}

- (void) setUserDayEndTime: (NSString *) newTime
{
  [userDefaults setDayEndTime: newTime];
}

- (NSArray *) firstWeekList
{
  return [NSArray arrayWithObjects:
                    SOGoWeekStartJanuary1,
                  SOGoWeekStartFirst4DayWeek,
                  SOGoWeekStartFirstFullWeek,
                  nil];
}

- (NSString *) itemFirstWeekText
{
  return [self labelForKey: [NSString stringWithFormat: @"firstWeekOfYear_%@",
                                      item]];
}

- (NSString *) userFirstWeek
{
  return [userDefaults firstWeekOfYear];
}

- (void) setUserFirstWeek: (NSString *) newFirstWeek
{
  [userDefaults setFirstWeekOfYear: newFirstWeek];
}

- (BOOL) reminderEnabled
{
  return [userDefaults reminderEnabled];
}

- (void) setReminderEnabled: (BOOL) newValue
{
  [userDefaults setReminderEnabled: newValue];
}

- (BOOL) remindWithASound
{
  return [userDefaults remindWithASound];
}

- (void) setRemindWithASound: (BOOL) newValue
{
  [userDefaults setRemindWithASound: newValue];
}

- (NSArray *) reminderTimesList
{
  static NSArray *reminderTimesList = nil;

  if (!reminderTimesList)
    {
      reminderTimesList = [NSArray arrayWithObjects: @"0000", @"0005",
                                   @"0010", @"0015", @"0030", @"0100",
                                   @"0200", @"0400", @"0800", @"1200",
                                   @"2400", @"4800", nil];
      [reminderTimesList retain];
    }

  return reminderTimesList;
}

- (NSString *) itemReminderTimeText
{
  return [self labelForKey:
                 [NSString stringWithFormat: @"reminderTime_%@", item]];
}

- (NSString *) userReminderTime
{
  return [userDefaults reminderTime];
}

- (void) setReminderTime: (NSString *) newTime
{
  [userDefaults setReminderTime: newTime];
}

/* Mailer */
- (void) setShowSubscribedFoldersOnly: (BOOL) showSubscribedFoldersOnly
{
  [userDefaults setMailShowSubscribedFoldersOnly: showSubscribedFoldersOnly];
}

- (BOOL) showSubscribedFoldersOnly
{
  return [userDefaults mailShowSubscribedFoldersOnly];
}

- (NSArray *) messageCheckList
{
  NSArray *intervalsList;
  NSMutableArray *messageCheckList;
  NSString *value;
  int count, max, interval;

  intervalsList = [[user domainDefaults] mailPollingIntervals];
  messageCheckList = [NSMutableArray arrayWithObjects: @"manually", nil];
  max = [intervalsList count];
  for (count = 0; count < max; count++)
    {
      interval = [[intervalsList objectAtIndex: count] intValue];
      value = nil;
      if (interval == 1)
        value = @"every_minute";
      else if (interval == 60)
        value = @"once_per_hour";
      else if (interval == 2 || interval == 5 || interval == 10 
               || interval == 20 || interval == 30)
        value = [NSString stringWithFormat: @"every_%d_minutes", interval];
      else
        {
          [self warnWithFormat: @"interval '%d' not handled", interval];
          value = nil;
        }
      if (value)
        [messageCheckList addObject: value];
    }

  return messageCheckList;
}

- (NSString *) itemMessageCheckText
{
  return [self labelForKey:
                 [NSString stringWithFormat: @"messagecheck_%@", item]];
}

- (NSString *) userMessageCheck
{
  return [userDefaults mailMessageCheck];
}

- (void) setUserMessageCheck: (NSString *) newMessageCheck
{
  [userDefaults setMailMessageCheck: newMessageCheck];
}

- (NSArray *) messageForwardingList
{
  return [NSArray arrayWithObjects: @"inline", @"attached", nil];
}

- (NSString *) itemMessageForwardingText
{
  return [self labelForKey:
                 [NSString stringWithFormat: @"messageforward_%@", item]];
}

- (NSString *) userMessageForwarding
{
  return [userDefaults mailMessageForwarding];
}

- (void) setUserMessageForwarding: (NSString *) newMessageForwarding
{
  [userDefaults setMailMessageForwarding: newMessageForwarding];
}

/*
// <label><var:string label:value="Default identity:"/>
//   <var:popup list="identitiesList" item="item"
//     string="itemIdentityText" selection="defaultIdentity"/></label>
- (NSArray *) identitiesList
{
  NSDictionary *primaryAccount;

#warning we manage only one account per user at this time...
  primaryAccount = [[user mailAccounts] objectAtIndex: 0];

  return [primaryAccount objectForKey: @"identities"];
}

- (NSString *) itemIdentityText
{
  return [(NSDictionary *) item keysWithFormat: @"%{fullName} <%{email}>"];
  } */

- (NSString *) signature
{
  return [userDefaults mailSignature];
}

- (void) setSignature: (NSString *) newSignature
{
  [userDefaults setMailSignature: newSignature];
}

- (NSArray *) replyPlacementList
{
  return [NSArray arrayWithObjects: @"above", @"below", nil];
}

- (NSString *) itemReplyPlacementText
{
  return [self labelForKey:
                 [NSString stringWithFormat: @"replyplacement_%@", item]];
}

- (NSString *) userReplyPlacement
{
  return [userDefaults mailReplyPlacement];
}

- (void) setUserReplyPlacement: (NSString *) newReplyPlacement
{
  [userDefaults setMailReplyPlacement: newReplyPlacement];
}

- (NSString *) itemSignaturePlacementText
{
  return [self labelForKey:
                 [NSString stringWithFormat: @"signatureplacement_%@", item]];
}

- (NSArray *) signaturePlacementList
{
  return [NSArray arrayWithObjects: @"above", @"below", nil];
}

- (void) setUserSignaturePlacement: (NSString *) newSignaturePlacement
{
  [userDefaults setMailSignaturePlacement: newSignaturePlacement];
}

- (NSString *) userSignaturePlacement
{
  return [userDefaults mailSignaturePlacement];
}

- (NSArray *) composeMessagesType
{
  return [NSArray arrayWithObjects: @"text", @"html", nil];
}

- (NSString *) itemComposeMessagesText
{
  return [self labelForKey: [NSString stringWithFormat:
                                        @"composemessagestype_%@", item]];
}

- (NSString *) userComposeMessagesType
{
  return [userDefaults mailComposeMessageType];
}

- (void) setUserComposeMessagesType: (NSString *) newType
{
  [userDefaults setMailComposeMessageType: newType];
}

/* mail autoreply (vacation) */

- (BOOL) isSieveScriptsEnabled
{
  return [[user domainDefaults] sieveScriptsEnabled];
}

- (NSString *) sieveCapabilities
{
#warning this should be deduced from the server
  static NSArray *capabilities = nil;

  if (!capabilities)
    {
      capabilities = [NSArray arrayWithObjects: @"fileinto", @"reject",
                              @"envelope", @"vacation", @"imapflags",
                              @"notify", @"subaddress", @"relational",
                              @"comparator-i;ascii-numeric", @"regex", nil];
      [capabilities retain];
    }

  return [[NSDictionary dictionary]
           jsonStringForArray: capabilities
              withIndentLevel: 0];
}

- (BOOL) isVacationEnabled
{
  return [[user domainDefaults] vacationEnabled];
}

- (void) setSieveFiltersValue: (NSString *) newValue
{
  NSScanner *jsonScanner;

  if ([newValue hasPrefix: @"["])
    {
      jsonScanner = [NSScanner scannerWithString: newValue];
      [jsonScanner scanJSONArray: &sieveFilters];
      [sieveFilters retain];
    }
}

- (NSString *) sieveFiltersValue
{
  return [[NSDictionary dictionary]
           jsonStringForArray: sieveFilters
              withIndentLevel: 0];
}

- (void) setEnableVacation: (BOOL) enableVacation
{
  [vacationOptions setObject: [NSNumber numberWithBool: enableVacation]
                      forKey: @"enabled"];
}

- (BOOL) enableVacation
{
  return [[vacationOptions objectForKey: @"enabled"] boolValue];
}

- (void) setAutoReplyText: (NSString *) theText
{
  [vacationOptions setObject: theText forKey: @"autoReplyText"];
}

- (NSString *) autoReplyText
{
  return [vacationOptions objectForKey: @"autoReplyText"];
}

- (void) setAutoReplyEmailAddresses: (NSString *) theAddresses
{
  NSArray *addresses;

  addresses = [[theAddresses componentsSeparatedByString: @","]
                trimmedComponents];
  [vacationOptions setObject: addresses
		      forKey: @"autoReplyEmailAddresses"];
}

- (NSString *) defaultEmailAddresses
{
  NSArray *addressesList;
  NSMutableArray *uniqueAddressesList;
  NSString *address;
  unsigned int i;

  uniqueAddressesList = [NSMutableArray array];
  addressesList = [NSMutableArray arrayWithArray: [user allEmails]];
  for (i = 0; i < [addressesList count]; i++)
    {
      address = [addressesList objectAtIndex: i];
      if (![uniqueAddressesList containsObject: address])
	[uniqueAddressesList addObject: address];
    }

  return [uniqueAddressesList componentsJoinedByString: @", "];
}

- (NSString *) autoReplyEmailAddresses
{
  NSArray *addressesList;
 
  addressesList = [vacationOptions objectForKey: @"autoReplyEmailAddresses"];

  return (addressesList
          ? [addressesList componentsJoinedByString: @", "]
          : [self defaultEmailAddresses]);
}

- (NSArray *) daysBetweenResponsesList
{
  static NSArray *daysBetweenResponses = nil;

  if (!daysBetweenResponses)
    {
      daysBetweenResponses = [NSArray arrayWithObjects: @"1", @"2", @"3",
                                      @"5", @"7", @"14", @"21", @"30", nil];
      [daysBetweenResponses retain];
    }

  return daysBetweenResponses;
}

- (void) setDaysBetweenResponses: (NSNumber *) theDays
{
  [vacationOptions setObject: theDays
		      forKey: @"daysBetweenResponse"];
}

- (NSString *) daysBetweenResponses
{
  NSString *days;

  days = [vacationOptions objectForKey: @"daysBetweenResponse"];
  if (!days)
    days = @"7"; // defaults to 7 days

  return days;
}

- (void) setIgnoreLists: (BOOL) ignoreLists
{
  [vacationOptions setObject: [NSNumber numberWithBool: ignoreLists]
		      forKey: @"ignoreLists"];
}

- (BOOL) ignoreLists
{
  NSNumber *obj;
  BOOL ignore;

  obj = [vacationOptions objectForKey: @"ignoreLists"];

  if (obj == nil)
    ignore = YES; // defaults to true
  else
    ignore = [obj boolValue];

  return ignore;
}

/* mail forward */

- (BOOL) isForwardEnabled
{
  return [[user domainDefaults] forwardEnabled];
}

- (void) setEnableForward: (BOOL) enableForward
{
  [forwardOptions setObject: [NSNumber numberWithBool: enableForward]
		     forKey: @"enabled"];
}

- (BOOL) enableForward
{
  return [[forwardOptions objectForKey: @"enabled"] boolValue];
}

- (void) setForwardAddress: (NSString *) forwardAddress
{
  [forwardOptions setObject: forwardAddress
		     forKey: @"forwardAddress"];
}

- (NSString *) forwardAddress
{
  return [forwardOptions objectForKey: @"forwardAddress"];
}

- (void) setForwardKeepCopy: (BOOL) keepCopy
{
  [forwardOptions setObject: [NSNumber numberWithBool: keepCopy]
		     forKey: @"keepCopy"];
}

- (BOOL) forwardKeepCopy
{
  return [[forwardOptions objectForKey: @"keepCopy"] boolValue];
}

/* main */

- (NSArray *) availableModules
{
  NSMutableArray *availableModules, *modules;
  NSString *module;
  int count, max;

  modules = [NSMutableArray arrayWithObjects: @"Calendar", @"Mail", nil];
  availableModules = [NSMutableArray arrayWithObjects: @"Last", @"Contacts",
                                     nil];
  max = [modules count];
  for (count = 0; count < max; count++)
    {
      module = [modules objectAtIndex: count];
      if ([user canAccessModule: module])
        [availableModules addObject: module];
    }

  return availableModules;
}

- (NSString *) itemModuleText
{
  return [self labelForKey: item];
}

- (NSString *) userDefaultModule
{
  NSString *userDefaultModule;

  if ([userDefaults rememberLastModule])
    userDefaultModule = @"Last";
  else
    userDefaultModule = [userDefaults loginModule];

  return userDefaultModule;
}

- (void) setUserDefaultModule: (NSString *) newValue
{
  if ([newValue isEqualToString: @"Last"])
    [userDefaults setRememberLastModule: YES];
  else
    {
      [userDefaults setRememberLastModule: NO];
      [userDefaults setLoginModule: newValue];
    }
}

- (id <WOActionResults>) defaultAction
{
  id <WOActionResults> results;
  WORequest *request;
  SOGoDomainDefaults *dd;
  NSString *method;

  request = [context request];
  if ([[request method] isEqualToString: @"POST"])
    {
      SOGoMailAccount *account;
      id mailAccounts;
      id folder;

      dd = [[context activeUser] domainDefaults];
      if ([dd sieveScriptsEnabled])
        [userDefaults setSieveFilters: sieveFilters];
      if ([dd vacationEnabled])
        [userDefaults setVacationOptions: vacationOptions];
      if ([dd forwardEnabled])
        [userDefaults setForwardOptions: forwardOptions];

      [userDefaults synchronize];
      
      mailAccounts = [[[context activeUser] mailAccounts] objectAtIndex: 0];
      folder = [[self clientObject] mailAccountsFolder: @"Mail"
                                             inContext: context];
      account = [folder lookupName: [[mailAccounts objectForKey: @"name"] asCSSIdentifier]
                         inContext: context
                           acquire: NO];
      [account updateFilters];

      if (hasChanged)
        method = @"window.location.reload()";
      else
        method = nil;

      results = [self jsCloseWithRefreshMethod: method];
    }
  else
    results = self;

  return results;
}

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
                           inContext: (WOContext*) context
{
  return [[request method] isEqualToString: @"POST"];
}

- (BOOL) userHasCalendarAccess
{
  return [user canAccessModule: @"Calendar"];
}

- (BOOL) userHasMailAccess
{
  return [user canAccessModule: @"Mail"];
}

- (BOOL) shouldDisplayAdditionalPreferences
{
  return [[SOGoSystemDefaults sharedSystemDefaults]
           uixAdditionalPreferences];
}

- (BOOL) shouldDisplayPasswordChange
{
  return [[SOGoSystemDefaults sharedSystemDefaults]
           userCanChangePassword];
}

- (NSString *) localeCode
{
  // WARNING : NSLocaleCode is not defined in <Foundation/NSUserDefaults.h>
  return [locale objectForKey: @"NSLocaleCode"];
}

- (NSArray *) languageCategories
{
  NSArray *categoryLabels;

  categoryLabels = [[self labelForKey: @"category_labels"]
                       componentsSeparatedByString: @","];

  return [categoryLabels trimmedComponents];
}

- (NSArray *) categoryList
{
  if (!calendarCategories)
    {
      ASSIGN (calendarCategories, [userDefaults calendarCategories]);
      if (!calendarCategories)
        ASSIGN (calendarCategories, [self languageCategories]);
    }

  return [calendarCategories
           sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)];
}

- (void) setCategory: (NSString *) newCategory
{
  ASSIGN (category, newCategory);
}

- (NSString *) category
{
  return category;
}

- (NSString *) categoryColor
{
  SOGoDomainDefaults *dd;
  NSString *categoryColor;

  if (!calendarCategoriesColors)
    ASSIGN (calendarCategoriesColors, [userDefaults calendarCategoriesColors]);

  categoryColor = [calendarCategoriesColors objectForKey: category];
  if (!categoryColor)
    {
      if (!defaultCategoryColor)
        {
          dd = [[context activeUser] domainDefaults];
          ASSIGN (defaultCategoryColor, [dd calendarDefaultCategoryColor]);
        }
      categoryColor = defaultCategoryColor;
    }

  return categoryColor;
}

- (NSString *) categoriesValue
{
  return @"";
}

- (void) setCategoriesValue: (NSString *) value
{
  NSDictionary *newColors;

  newColors = [NSMutableDictionary dictionaryWithJSONString: value];
  if (newColors)
    {
      [userDefaults setCalendarCategories: [newColors allKeys]];
      [userDefaults setCalendarCategoriesColors: newColors];
    }
}

- (NSArray *) languages
{
  return [[SOGoSystemDefaults sharedSystemDefaults]
           supportedLanguages];
}

- (NSString *) language
{
  return [userDefaults language];
}

- (void) setLanguage: (NSString *) newLanguage
{
  if ([[self languages] containsObject: newLanguage])
    [userDefaults setLanguage: newLanguage];
}

- (NSString *) languageText
{
  return [self labelForKey: item];
}

@end
