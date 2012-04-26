/* UIxPreferences.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
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
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSUserDefaults.h> /* for locale strings */
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>

#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalTimeZonePeriod.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/WOResourceManager+SOGo.h>
#import <Mailer/SOGoMailAccount.h>

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
#warning user should be the owner rather than the activeUser
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
	      [[self resourceManager] localeForLanguageNamed: language]);
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

      mailCustomFromEnabled = [dd mailCustomFromEnabled];

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
  [contactsCategories release];
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
  return [[iCalTimeZone knownTimeZoneNames] sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)];
}

- (NSString *) userTimeZone
{
  NSString *name;
  iCalTimeZone *tz;

  name = [userDefaults timeZoneName];
  tz = [iCalTimeZone timeZoneForName: name];

  if (!tz)
    {
      // The specified timezone is not in our Olson database.
      // Look for a known timezone with the same GMT offset.
      NSString *current;
      NSCalendarDate *now;
      NSEnumerator *zones;
      BOOL found;
      unsigned int offset;
      
      found = NO;
      now = [NSCalendarDate calendarDate];
      offset = [[userDefaults timeZone] secondsFromGMTForDate: now];
      zones = [[iCalTimeZone knownTimeZoneNames] objectEnumerator];

      while ((current = [zones nextObject]))
	{
	  tz = [iCalTimeZone timeZoneForName: current];
	  if ([[tz periodForDate: now] secondsOffsetFromGMT] == offset)
	    {
	      found = YES;
	      break;
	    }
	}

      if (found)
	{
	  [self warnWithFormat: @"User %@ has an unknown timezone (%@) -- replaced by %@", [user login], name, current];
	  name = current;
	}
      else
	[self errorWithFormat: @"User %@ has an unknown timezone (%@)", [user login], name];
    }

  return name;
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

- (NSArray *) defaultCalendarList
{
  NSMutableArray *options;

  options = [NSArray arrayWithObjects: @"selected", @"personal", @"first", nil];

  return options;
}

- (NSString *) itemCalendarText
{
  return [self labelForKey: [NSString stringWithFormat: @"%@Calendar", item]];
}

- (NSString *) userDefaultCalendar
{
  return [userDefaults defaultCalendar];
}

- (void) setUserDefaultCalendar: (NSString *) newValue
{
  [userDefaults setDefaultCalendar: newValue];
}

- (NSArray *) calendarClassificationsList
{
  static NSArray *classifications = nil;

  if (!classifications)
    classifications = [[NSArray alloc] initWithObjects:
                                         @"PUBLIC",
                                       @"CONFIDENTIAL",
                                       @"PRIVATE",
                                       nil];

  return classifications;
}

- (NSString *) itemClassificationText
{
  return [self labelForKey: [NSString stringWithFormat: @"%@_item",
                                      item]];
}

- (void) setEventsDefaultClassification: (NSString *) newValue
{
  [userDefaults setCalendarEventsDefaultClassification: newValue];
}

- (NSString *) eventsDefaultClassification
{
  return [userDefaults calendarEventsDefaultClassification];
}

- (void) setTasksDefaultClassification: (NSString *) newValue
{
  [userDefaults setCalendarTasksDefaultClassification: newValue];
}

- (NSString *) tasksDefaultClassification
{
  return [userDefaults calendarTasksDefaultClassification];
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

- (void) setBusyOffHours: (BOOL) busyOffHours
{
  [userDefaults setBusyOffHours: busyOffHours];
}

- (BOOL) busyOffHours
{
  return [userDefaults busyOffHours];
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

- (void) setSortByThreads: (BOOL) sortByThreads
{
  [userDefaults setMailSortByThreads: sortByThreads];
}

- (BOOL) sortByThreads
{
  return [userDefaults mailSortByThreads];
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
#warning sieve caps should be deduced from the server
  static NSArray *capabilities = nil;

  if (!capabilities)
    {
      capabilities = [NSArray arrayWithObjects: @"fileinto", @"reject",
                              @"envelope", @"vacation", @"imapflags",
                              @"notify", @"subaddress", @"relational",
                              @"comparator-i;ascii-numeric", @"regex", nil];
      [capabilities retain];
    }

  return [capabilities jsonRepresentation];
}

- (BOOL) isVacationEnabled
{
  return [[user domainDefaults] vacationEnabled];
}

- (void) setSieveFiltersValue: (NSString *) newValue
{
  sieveFilters = [newValue objectFromJSONString];
  if (sieveFilters)
    {
      if ([sieveFilters isKindOfClass: [NSArray class]])
        [sieveFilters retain];
      else
        sieveFilters = nil;
    }
}

- (NSString *) sieveFiltersValue
{
  return [sieveFilters jsonRepresentation];
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

- (BOOL) enableVacationEndDate
{
  return [[vacationOptions objectForKey: @"endDateEnabled"] boolValue];
}

- (BOOL) disableVacationEndDate
{
  return ![self enableVacationEndDate];
}

- (void) setEnableVacationEndDate: (BOOL) enableVacationEndDate
{
  [vacationOptions setObject: [NSNumber numberWithBool: enableVacationEndDate]
                      forKey: @"endDateEnabled"];
}

- (void) setVacationEndDate: (NSCalendarDate *) endDate
{
  NSNumber *time;
  
  time = [NSNumber numberWithInt: [endDate timeIntervalSince1970]];

  [vacationOptions setObject: time forKey: @"endDate"];
}

- (NSCalendarDate *) vacationEndDate
{
  int time;

  time = [[vacationOptions objectForKey: @"endDate"] intValue];

  if (time > 0)
    return [NSCalendarDate dateWithTimeIntervalSince1970: time];
  else
    return [NSCalendarDate calendarDate];
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
  NSArray *addresses;

  addresses = [[forwardAddress componentsSeparatedByString: @","]
                trimmedComponents];
  [forwardOptions setObject: addresses
		     forKey: @"forwardAddress"];
}

- (NSString *) forwardAddress
{
  id addresses;

  addresses = [forwardOptions objectForKey: @"forwardAddress"];

  return ([addresses respondsToSelector: @selector(componentsJoinedByString:)]
          ? [(NSArray *)addresses componentsJoinedByString: @", "]
          : (NSString *)addresses);
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
      SOGoMailAccounts *folder;

      dd = [[context activeUser] domainDefaults];
      if ([dd sieveScriptsEnabled])
        [userDefaults setSieveFilters: sieveFilters];
      if ([dd vacationEnabled])
        [userDefaults setVacationOptions: vacationOptions];
      if ([dd forwardEnabled])
        [userDefaults setForwardOptions: forwardOptions];

      [userDefaults synchronize];

      folder = [[self clientObject] mailAccountsFolder: @"Mail"
                                             inContext: context];
      account = [folder lookupName: @"0" inContext: context acquire: NO];
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

- (NSArray *) _languageCalendarCategories
{
  NSArray *categoryLabels;

  categoryLabels = [[self labelForKey: @"calendar_category_labels"]
                       componentsSeparatedByString: @","];

  return [categoryLabels trimmedComponents];
}

- (NSArray *) calendarCategoryList
{
  if (!calendarCategories)
    {
      ASSIGN (calendarCategories, [userDefaults calendarCategories]);
      if (!calendarCategories)
        ASSIGN (calendarCategories, [self _languageCalendarCategories]);
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

- (NSString *) calendarCategoriesValue
{
  return @"";
}

- (void) setCalendarCategoriesValue: (NSString *) value
{
  NSDictionary *newColors;

  newColors = [value objectFromJSONString];
  if (newColors && [newColors isKindOfClass: [NSDictionary class]])
    {
      [userDefaults setCalendarCategories: [newColors allKeys]];
      [userDefaults setCalendarCategoriesColors: newColors];
    }
}

- (NSArray *) _languageContactsCategories
{
  NSArray *categoryLabels;

  categoryLabels = [[self labelForKey: @"contacts_category_labels"]
                       componentsSeparatedByString: @","];
  if (!categoryLabels)
    categoryLabels = [NSArray array];
  
  return [categoryLabels trimmedComponents];
}

- (NSArray *) contactsCategoryList
{
  if (!contactsCategories)
    {
      ASSIGN (contactsCategories, [userDefaults contactsCategories]);
      if (!contactsCategories)
        ASSIGN (contactsCategories, [self _languageContactsCategories]);
    }

  return [contactsCategories
           sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)];
}

- (NSString *) contactsCategoriesValue
{
  return @"";
}

- (void) setContactsCategoriesValue: (NSString *) value
{
  NSArray *newCategories;

  newCategories = [value objectFromJSONString];
  if (newCategories && [newCategories isKindOfClass: [NSArray class]])
    [userDefaults setContactsCategories: newCategories];
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

- (BOOL) mailAuxiliaryUserAccountsEnabled
{
  return [[user domainDefaults] mailAuxiliaryUserAccountsEnabled];
}

- (void) _extractMainIdentity: (NSDictionary *) identity
{
  /* We perform some validation here as we have no guaranty on the input
     validity. */
  NSString *value;

  if ([identity isKindOfClass: [NSDictionary class]])
    {
      value = [identity objectForKey: @"signature"];
      if (!value)
        value = @"";
      [userDefaults setMailSignature: value];

      if (mailCustomFromEnabled)
        {
          value = [[identity objectForKey: @"email"]
                    stringByTrimmingSpaces];

          /* We make sure that the "custom" value is different from the values
             returned by the user directory service. */
          if ([value length] == 0
              || [[user allEmails] containsObject: value])
            value = nil;
          [userDefaults setMailCustomEmail: value];

          value = [[identity objectForKey: @"fullName"]
                    stringByTrimmingSpaces];
          if ([value length] == 0
              || [[user cn] isEqualToString: value])
            value = nil;
          [userDefaults setMailCustomFullName: value];
        }

      value = [[identity objectForKey: @"replyTo"]
                stringByTrimmingSpaces];
      [userDefaults setMailReplyTo: value];
    }
}

- (BOOL) _validateReceiptAction: (NSString *) action
{
  return ([action isKindOfClass: [NSString class]]
          && ([action isEqualToString: @"ignore"]
              || [action isEqualToString: @"send"]
              || [action isEqualToString: @"ask"]));
}

- (void) _extractMainReceiptsPreferences: (NSDictionary *) receipts
{
  /* We perform some validation here as we have no guaranty on the input
     validity. */
  NSString *action;

  if ([receipts isKindOfClass: [NSDictionary class]])
    {
      action = [receipts objectForKey: @"receiptAction"];
      [userDefaults
        setAllowUserReceipt: [action isEqualToString: @"allow"]];
      
      action = [receipts objectForKey: @"receiptNonRecipientAction"];
      if ([self _validateReceiptAction: action])
        [userDefaults setUserReceiptNonRecipientAction: action];

      action = [receipts objectForKey: @"receiptOutsideDomainAction"];
      if ([self _validateReceiptAction: action])
        [userDefaults setUserReceiptOutsideDomainAction: action];
      
      action = [receipts objectForKey: @"receiptAnyAction"];
      if ([self _validateReceiptAction: action])
        [userDefaults setUserReceiptAnyAction: action];
    }
}

- (void) _extractMainCustomFrom: (NSDictionary *) account
{
}

- (void) _extractMainReplyTo: (NSDictionary *) account
{
}

- (BOOL) _validateAccountIdentities: (NSArray *) identities
{
  static NSString *identityKeys[] = { @"fullName", @"email", nil };
  static NSArray *knownKeys = nil;
  NSString **key, *value;
  NSDictionary *identity;
  NSMutableDictionary *clone;
  BOOL valid;
  int count, max;

  if (!knownKeys)
    {
      knownKeys = [NSArray arrayWithObjects: @"fullName", @"email",
                           @"signature", @"replyTo", nil];
      [knownKeys retain];
    }

  valid = [identities isKindOfClass: [NSArray class]];
  if (valid)
    {
      max = [identities count];
      valid = (max > 0);
      for (count = 0; valid && count < max; count++)
        {
          identity = [identities objectAtIndex: count];
          clone = [identity mutableCopy];
          [clone removeObjectsForKeys: knownKeys];
          valid = ([clone count] == 0);
          [clone autorelease];
          if (valid)
            {
              key = identityKeys;
              while (valid && *key)
                {
                  value = [identity objectForKey: *key];
                  if ([value isKindOfClass: [NSString class]]
                      && [value length] > 0)
                    key++;
                  else
                    valid = NO;
                }
              if (valid)
                {
                  value = [identity objectForKey: @"signature"];
                  valid = (!value || [value isKindOfClass: [NSString class]]);
                }
            }
        }
    }

  return valid;
}

- (BOOL) _validateAccount: (NSDictionary *) account
{
  static NSString *accountKeys[] = { @"name", @"serverName", @"userName",
                                     nil };
  static NSArray *knownKeys = nil;
  NSMutableDictionary *clone;
  NSString **key, *value;
  BOOL valid;

  if (!knownKeys)
    {
      knownKeys = [NSArray arrayWithObjects: @"name", @"serverName", @"port",
                           @"userName", @"password", @"encryption", @"replyTo",
                           @"identities", @"mailboxes",
                           @"receipts",
                           nil];
      [knownKeys retain];
    }

  valid = [account isKindOfClass: [NSDictionary class]];
  if (valid)
    {
      clone = [account mutableCopy];
      [clone removeObjectsForKeys: knownKeys];
      valid = ([clone count] == 0);
      [clone autorelease];

      key = accountKeys;
      while (valid && *key)
        {
          value = [account objectForKey: *key];
          if ([value isKindOfClass: [NSString class]]
              && [value length] > 0)
            key++;
          else
            valid = NO;
        }

      if (valid)
        {
          value = [account objectForKey: @"security"];
          if (value)
            valid = ([value isKindOfClass: [NSString class]]
                     && ([value isEqualToString: @"none"]
                         || [value isEqualToString: @"ssl"]
                         || [value isEqualToString: @"tls"]));

          valid &= [self _validateAccountIdentities: [account objectForKey: @"identities"]];
        }
    }

  return valid;
}

- (void) _extractMainAccountSettings: (NSDictionary *) account
{
  NSArray *identities;

  if ([account isKindOfClass: [NSDictionary class]])
    {
      identities = [account objectForKey: @"identities"];
      if ([identities isKindOfClass: [NSArray class]]
          && [identities count] > 0)
        [self _extractMainIdentity: [identities objectAtIndex: 0]];
      [self _extractMainReceiptsPreferences: [account objectForKey: @"receipts"]];
    }
}

- (void) _extractAuxiliaryAccounts: (NSArray *) accounts
{
  int count, max, oldMax;
  NSArray *oldAccounts;
  NSMutableArray *auxAccounts;
  NSDictionary *oldAccount;
  NSMutableDictionary *account;
  NSString *password;

  oldAccounts = [user mailAccounts];
  oldMax = [oldAccounts count];

  max = [accounts count];
  auxAccounts = [NSMutableArray arrayWithCapacity: max];

  for (count = 1; count < max; count++)
    {
      account = [accounts objectAtIndex: count];
      if ([self _validateAccount: account])
        {
          password = [account objectForKey: @"password"];
          if (!password)
            {
              if (count < oldMax)
                {
                  oldAccount = [oldAccounts objectAtIndex: count];
                  password = [oldAccount objectForKey: @"password"];
                }
              if (!password)
                password = @"";
              [account setObject: password forKey: @"password"];
            }
          [auxAccounts addObject: account];
        }
    }

  [userDefaults setAuxiliaryMailAccounts: auxAccounts];
}

- (void) setMailAccounts: (NSString *) newMailAccounts
{
  NSArray *accounts;
  int max;

  accounts = [newMailAccounts objectFromJSONString];
  if (accounts && [accounts isKindOfClass: [NSArray class]])
    {
      max = [accounts count];
      if (max > 0)
        {
          [self _extractMainAccountSettings: [accounts objectAtIndex: 0]];
          if ([self mailAuxiliaryUserAccountsEnabled])
            [self _extractAuxiliaryAccounts: accounts];
        }
    }
}

- (NSString *) mailAccounts
{
  NSArray *accounts;
  NSMutableDictionary *account;
  int count, max;

  accounts = [user mailAccounts];
  max = [accounts count];
  for (count = 0; count < max; count++)
    {
      account = [accounts objectAtIndex: count];
      [account removeObjectForKey: @"password"];
    }

  return [accounts jsonRepresentation];
}

- (NSString *) mailCustomFromEnabled
{
  return (mailCustomFromEnabled ? @"true" : @"false");
}

@end
