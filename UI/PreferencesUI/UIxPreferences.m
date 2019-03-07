/* UIxPreferences.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2018 Inverse inc.
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
#import <Foundation/NSUserDefaults.h> /* for locale strings */
#import <Foundation/NSValue.h>

#import <NGObjWeb/WORequest.h>

#import <NGImap4/NSString+Imap4.h>

#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalTimeZone.h>

#import <SOPE/NGCards/iCalRecurrenceRule.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoSieveManager.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoParentFolder.h>
#import <SOGo/SOGoTextTemplateFile.h>
#import <SOGo/WOResourceManager+SOGo.h>
#import <SOGo/SOGoBuild.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>

#import <Contacts/SOGoContactGCSFolder.h>

#import "UIxPreferences.h"

static NSArray *reminderItems = nil;
static NSArray *reminderValues = nil;

@implementation UIxPreferences

+ (void) initialize
{
  if (!reminderItems && !reminderValues)
    {
      reminderItems = [NSArray arrayWithObjects:
                               @"NONE",
                               @"5_MINUTES_BEFORE",
                               @"10_MINUTES_BEFORE",
                               @"15_MINUTES_BEFORE",
                               @"30_MINUTES_BEFORE",
                               @"45_MINUTES_BEFORE",
                               @"1_HOUR_BEFORE",
                               @"2_HOURS_BEFORE",
                               @"5_HOURS_BEFORE",
                               @"15_HOURS_BEFORE",
                               @"1_DAY_BEFORE",
                               @"2_DAYS_BEFORE",
                               @"1_WEEK_BEFORE",
                               nil];
      reminderValues = [NSArray arrayWithObjects:
                                @"NONE",
                                @"-PT5M",
                                @"-PT10M",
                                @"-PT15M",
                                @"-PT30M",
                                @"-PT45M",
                                @"-PT1H",
                                @"-PT2H",
                                @"-PT5H",
                                @"-PT15H",
                                @"-P1D",
                                @"-P2D",
                                @"-P1W",
                                nil];

      [reminderItems retain];
      [reminderValues retain];
    }
}

- (id) init
{
  NSCalendarDate *referenceDate;
  SOGoDomainDefaults *dd;

  if ((self = [super init]))
    {
      item = nil;
      addressBooksIDWithDisplayName = nil;
      client = nil;
#warning user should be the owner rather than the activeUser
      ASSIGN (user, [context activeUser]);
      referenceDate = [NSCalendarDate date];
      if ([referenceDate dayOfMonth] > 9)
        referenceDate = [referenceDate addYear:0 month:0 day:(-[referenceDate dayOfMonth] + 1) hour:0 minute:0 second:0];
      ASSIGN (today, referenceDate);

      calendarCategories = nil;
      calendarCategoriesColors = nil;
      category = nil;

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
      forwardEnabled = [dd forwardEnabled];

      hasChanged = NO;
    }

  return self;
}

- (void) dealloc
{
  [today release];
  [item release];
  [user release];
  [sieveFilters release];
  [vacationOptions release];
  [calendarCategories release];
  [calendarCategoriesColors release];
  [category release];
  [contactsCategories release];
  [forwardOptions release];
  [daysOfWeek release];
  [addressBooksIDWithDisplayName release];
  [client release];
  [super dealloc];
}

- (NSString *) modulePath
{
  return @"Preferences";
}

// - (void) setHasChanged: (BOOL) newHasChanged
// {
//   hasChanged = newHasChanged;
// }

// - (BOOL) hasChanged
// {
//   return hasChanged;
// }

- (void) setItem: (NSString *) newItem
{
  ASSIGN (item, newItem);
}

- (NSString *) item
{
  return item;
}

//
// Used by wox template, as a var.
//
- (NSString *) timeZonesList
{
  return [[[iCalTimeZone knownTimeZoneNames] sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)] jsonRepresentation];
}

// - (NSString *) userTimeZone
// {
//   NSString *name;
//   iCalTimeZone *tz;

//   name = [userDefaults timeZoneName];
//   tz = [iCalTimeZone timeZoneForName: name];

//   if (!tz)
//     {
//       // The specified timezone is not in our Olson database.
//       // Look for a known timezone with the same GMT offset.
//       NSString *current;
//       NSCalendarDate *now;
//       NSEnumerator *zones;
//       BOOL found;
//       unsigned int offset;

//       found = NO;
//       now = [NSCalendarDate calendarDate];
//       offset = [[userDefaults timeZone] secondsFromGMTForDate: now];
//       zones = [[iCalTimeZone knownTimeZoneNames] objectEnumerator];

//       while ((current = [zones nextObject]))
// 	{
// 	  tz = [iCalTimeZone timeZoneForName: current];
// 	  if ([[tz periodForDate: now] secondsOffsetFromGMT] == offset)
// 	    {
// 	      found = YES;
// 	      break;
// 	    }
// 	}

//       if (found)
// 	{
// 	  [self warnWithFormat: @"User %@ has an unknown timezone (%@) -- replaced by %@", [user login], name, current];
// 	  name = current;
// 	}
//       else
// 	[self errorWithFormat: @"User %@ has an unknown timezone (%@)", [user login], name];
//     }

//   return name;
// }

// - (void) setUserTimeZone: (NSString *) newUserTimeZone
// {
//   [userDefaults setTimeZoneName: newUserTimeZone];
// }

//
// Used by wox template
//
- (NSArray *) shortDateFormatsList
{
  NSMutableArray *shortDateFormatsList = nil;
  NSString *key, *currentFormat;
  unsigned int nbr;
  BOOL done;

  shortDateFormatsList = [NSMutableArray array];

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

//
// Used by wox template
//
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

// - (NSString *) userShortDateFormat
// {
//   return [userDefaults shortDateFormat];
// }

// - (void) setUserShortDateFormat: (NSString *) newFormat
// {
//   if ([newFormat isEqualToString: @"default"])
//     [userDefaults unsetShortDateFormat];
//   else
//     [userDefaults setShortDateFormat: newFormat];
// }

//
// Used internally
//
- (NSString *) _userLongDateFormat
{
  NSString *longDateFormat;

  longDateFormat = [userDefaults longDateFormat];
  if (!longDateFormat)
    longDateFormat = @"default";

  return longDateFormat;
}

//
// Used by wox template
//
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

  if (![longDateFormatsList containsObject: [self _userLongDateFormat]])
    [longDateFormatsList addObject: [self _userLongDateFormat]];

  return longDateFormatsList;
}

//
// Used by wox template
//
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

// - (void) setUserLongDateFormat: (NSString *) newFormat
// {
//   if ([newFormat isEqualToString: @"default"])
//     [userDefaults unsetLongDateFormat];
//   else
//     [userDefaults setLongDateFormat: newFormat];
// }

//
// Used by wox template
//
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

//
// Used by wox template
//
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

// - (NSString *) userTimeFormat
// {
//   return [userDefaults timeFormat];
// }

// - (void) setUserTimeFormat: (NSString *) newFormat
// {
//   if ([newFormat isEqualToString: @"default"])
//     [userDefaults unsetTimeFormat];
//   else
//     [userDefaults setTimeFormat: newFormat];
// }

//
// Used by wox template
//
- (NSArray *) daysList
{
  NSMutableArray *daysList;
  unsigned int currentDay;

  daysList = [NSMutableArray array];
  for (currentDay = 0; currentDay < 7; currentDay++)
    [daysList addObject: [NSString stringWithFormat: @"%d", currentDay]];

  return daysList;
}

//
// Used by wox template
//
- (NSString *) itemWeekStartDay
{
  return [daysOfWeek objectAtIndex: [item intValue]];
}

// - (NSString *) userWeekStartDay
// {
//   return [NSString stringWithFormat: @"%d", [userDefaults firstDayOfWeek]];
// }

// - (void) setUserWeekStartDay: (NSString *) newDay
// {
//   [userDefaults setFirstDayOfWeek: [newDay intValue]];
// }

//
// Used by wox template
//
- (NSArray *) defaultCalendarList
{
  NSMutableArray *options;

  options = [NSArray arrayWithObjects: @"selected", @"personal", @"first", nil];

  return options;
}

//
// Used by wox template
//
- (NSString *) itemCalendarText
{
  return [self labelForKey: [NSString stringWithFormat: @"%@Calendar", item]];
}

// - (NSString *) userDefaultCalendar
// {
//   return [userDefaults defaultCalendar];
// }

// - (void) setUserDefaultCalendar: (NSString *) newValue
// {
//   [userDefaults setDefaultCalendar: newValue];
// }

//
// Used by wox template
//
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

//
// Used by wox template
//
- (NSString *) itemClassificationText
{
  return [self labelForKey: [NSString stringWithFormat: @"%@_item",
                                      item]];
}

// - (void) setEventsDefaultClassification: (NSString *) newValue
// {
//   [userDefaults setCalendarEventsDefaultClassification: newValue];
// }

// - (NSString *) eventsDefaultClassification
// {
//   return [userDefaults calendarEventsDefaultClassification];
// }

// - (void) setTasksDefaultClassification: (NSString *) newValue
// {
//   [userDefaults setCalendarTasksDefaultClassification: newValue];
// }

// - (NSString *) tasksDefaultClassification
// {
//   return [userDefaults calendarTasksDefaultClassification];
// }

//
// Used by wox template
//
- (NSArray *) reminderValues
{
  return reminderValues;
}

//
// Used by wox template
//
- (NSString *) itemReminderText
{
  NSString *text;

  if ([item isEqualToString: @""])
    text = @"-";
  else
    {
      NSUInteger index;

      index = [reminderValues indexOfObject: item];

      if (index != NSNotFound)
        text = [self labelForKey: [NSString stringWithFormat: @"reminder_%@", [reminderItems objectAtIndex: index]]];
      else
        text = @"NONE";
    }

  return text;
}

// - (void) setReminder: (NSString *) theReminder
// {
//   NSString *value;
//   NSUInteger index;

//   index = NSNotFound;
//   value = @"NONE";

//   if (theReminder && [theReminder caseInsensitiveCompare: @"-"] != NSOrderedSame)
//     index = [reminderItems indexOfObject: theReminder];

//   if (index != NSNotFound)
//     value = [reminderValues objectAtIndex: index];

//   [userDefaults setCalendarDefaultReminder: value];
// }

// - (NSString *) reminder
// {
//   NSString *value;
//   NSUInteger index;

//   value = [userDefaults calendarDefaultReminder];
//   if (value != nil)
//     {
//       index = [reminderValues indexOfObject: value];

//       if (index != NSNotFound)
//         return [reminderItems objectAtIndex: index];
//     }

//   return @"NONE";
// }

//
// Used by wox template
//
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

// - (NSString *) userDayStartTime
// {
//   return [NSString stringWithFormat: @"%02d:00",
//                    [userDefaults dayStartHour]];
// }

// - (void) setUserDayStartTime: (NSString *) newTime
// {
//   [userDefaults setDayStartTime: newTime];
// }

// - (NSString *) userDayEndTime
// {
//   return [NSString stringWithFormat: @"%02d:00",
//                    [userDefaults dayEndHour]];
// }

// - (void) setUserDayEndTime: (NSString *) newTime
// {
//   [userDefaults setDayEndTime: newTime];
// }

// - (void) setBusyOffHours: (BOOL) busyOffHours
// {
//   [userDefaults setBusyOffHours: busyOffHours];
// }

// - (BOOL) busyOffHours
// {
//   return [userDefaults busyOffHours];
// }

// - (NSArray *) whiteList
// {
//   SOGoUserSettings *us;
//   NSMutableDictionary *moduleSettings;
//   NSArray *whiteList;

//   us = [user userSettings];
//   moduleSettings = [us objectForKey: @"Calendar"];
//   whiteList = [moduleSettings objectForKey:@"PreventInvitationsWhitelist"];
//   return whiteList;
// }

// - (void) setWhiteList: (NSString *) whiteListString
// {
//   SOGoUserSettings *us;
//   NSMutableDictionary *moduleSettings;

//   us = [user userSettings];
//   moduleSettings = [us objectForKey: @"Calendar"];
//   [moduleSettings setObject: whiteListString forKey: @"PreventInvitationsWhitelist"];
//   [us synchronize];
// }

// - (void) setPreventInvitations: (BOOL) preventInvitations
// {
//   SOGoUserSettings *us;
//   NSMutableDictionary *moduleSettings;
//   us = [user userSettings];
//   moduleSettings = [us objectForKey: @"Calendar"];
//   [moduleSettings setObject: [NSNumber numberWithBool: preventInvitations] forKey: @"PreventInvitations"];
//   [us synchronize];
// }

// - (BOOL) preventInvitations
// {
//   SOGoUserSettings *us;
//   NSMutableDictionary *moduleSettings;
//   us = [user userSettings];
//   moduleSettings = [us objectForKey: @"Calendar"];
//   return [[moduleSettings objectForKey: @"PreventInvitations"] boolValue];
// }

- (NSArray *) shortWeekDaysList
{
  static NSArray *shortWeekDaysList = nil;

  if (!shortWeekDaysList)
    {
      shortWeekDaysList = [locale objectForKey: NSShortWeekDayNameArray];
      [shortWeekDaysList retain];
    }

  return shortWeekDaysList;
}

- (NSString *) valueForWeekDay
{
  unsigned int i;

  i = [[self shortWeekDaysList] indexOfObject: item];

  return iCalWeekDayString[i];
}

//
// Used by wox template
//
- (NSArray *) firstWeekList
{
  return [NSArray arrayWithObjects:
                    SOGoWeekStartJanuary1,
                  SOGoWeekStartFirst4DayWeek,
                  SOGoWeekStartFirstFullWeek,
                  nil];
}

//
// Used by wox template
//
- (NSString *) itemFirstWeekText
{
  return [self labelForKey: [NSString stringWithFormat: @"firstWeekOfYear_%@",
                                      item]];
}

// - (NSString *) userFirstWeek
// {
//   return [userDefaults firstWeekOfYear];
// }

// - (void) setUserFirstWeek: (NSString *) newFirstWeek
// {
//   [userDefaults setFirstWeekOfYear: newFirstWeek];
// }

/* Mailer */
// - (void) setAddOutgoingAddresses: (BOOL) addOutgoingAddresses
// {
//   [userDefaults setMailAddOutgoingAddresses: addOutgoingAddresses];
// }

// - (BOOL) addOutgoingAddresses
// {
//   return [userDefaults mailAddOutgoingAddresses];
// }

// - (void) setShowSubscribedFoldersOnly: (BOOL) showSubscribedFoldersOnly
// {
//   [userDefaults setMailShowSubscribedFoldersOnly: showSubscribedFoldersOnly];
// }

// - (BOOL) showSubscribedFoldersOnly
// {
//   return [userDefaults mailShowSubscribedFoldersOnly];
// }

// - (void) setSortByThreads: (BOOL) sortByThreads
// {
//   [userDefaults setMailSortByThreads: sortByThreads];
// }

// - (BOOL) sortByThreads
// {
//   return [userDefaults mailSortByThreads];
// }

//
// Used by wox template
//
- (NSArray *) addressBookList
{
  NSMutableArray *folders, *localAddressBooks;
  SOGoParentFolder *contactFolder;
  SOGoContactGCSFolder *addressbook;
  int i, count;
  BOOL collectedAlreadyExist;

  // Fetch all addressbooks
  contactFolder = [[[context activeUser] homeFolderInContext: context]
                     lookupName: @"Contacts"
                      inContext: context
                        acquire: NO];
  folders = [NSMutableArray arrayWithArray: [contactFolder subFolders]];
  count = [folders count];

  // Remove all public addressbooks
  for (count--; count >= 0; count--)
    {
      if (![[folders objectAtIndex: count] isKindOfClass: [SOGoContactGCSFolder class]])
        [folders removeObjectAtIndex: count];
    }

  // Build list of local addressbooks
  localAddressBooks = [NSMutableArray arrayWithCapacity: [folders count]];
  count = [folders count];
  collectedAlreadyExist = NO;

  for (i = 0; i < count ; i++)
    {
      addressbook = [folders objectAtIndex: i];
      [localAddressBooks addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                                    [addressbook nameInContainer], @"id",
                                                  [addressbook displayName], @"name",
                                                  nil]];
      if ([[addressbook nameInContainer] isEqualToString: @"collected"])
        collectedAlreadyExist = YES;
    }
  if (!collectedAlreadyExist)
    {
      [localAddressBooks addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                                    @"collected", @"id",
                                                  [self labelForKey: @"Collected Address Book"], @"name",
                                                  nil]];
    }

  return localAddressBooks;
}

// - (NSString *) userAddressBook
// {
//   return [userDefaults selectedAddressBook];
// }

// - (void) setUserAddressBook: (NSString *) newSelectedAddressBook
// {
//   [userDefaults setSelectedAddressBook: newSelectedAddressBook];
// }

//
// Used by wox template
//
- (NSArray *) refreshViewList
{
  NSArray *intervalsList;
  NSMutableArray *refreshViewList;
  NSString *value;
  int count, max, interval;

  intervalsList = [[user domainDefaults] refreshViewIntervals];
  refreshViewList = [NSMutableArray arrayWithObjects: @"manually", nil];
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
        [refreshViewList addObject: value];
    }

  return refreshViewList;
}

//
// Used by wox template
//
- (NSString *) itemRefreshViewCheckText
{
  return [self labelForKey: [NSString stringWithFormat: @"refreshview_%@", item]];
}

// - (NSString *) userRefreshViewCheck
// {
//   return [userDefaults refreshViewCheck];
// }

// - (void) setUserRefreshViewCheck: (NSString *) newRefreshViewCheck
// {
//   [userDefaults setRefreshViewCheck: newRefreshViewCheck];
// }

//
// Used by wox template
//
- (NSArray *) messageForwardingList
{
  return [NSArray arrayWithObjects: @"inline", @"attached", nil];
}

//
// Used by wox template
//
- (NSString *) itemMessageForwardingText
{
  return [self labelForKey:
                 [NSString stringWithFormat: @"messageforward_%@", item]];
}

// - (NSString *) userMessageForwarding
// {
//   return [userDefaults mailMessageForwarding];
// }

// - (void) setUserMessageForwarding: (NSString *) newMessageForwarding
// {
//   [userDefaults setMailMessageForwarding: newMessageForwarding];
// }

//
// Used by wox template
//
- (NSArray *) replyPlacementList
{
  return [NSArray arrayWithObjects: @"above", @"below", nil];
}

//
// Used by wox template
//
- (NSString *) itemReplyPlacementText
{
  return [self labelForKey:
                 [NSString stringWithFormat: @"replyplacement_%@", item]];
}

// - (NSString *) userReplyPlacement
// {
//   return [userDefaults mailReplyPlacement];
// }

// - (void) setUserReplyPlacement: (NSString *) newReplyPlacement
// {
//   [userDefaults setMailReplyPlacement: newReplyPlacement];
// }

//
// Used by wox template
//
- (NSString *) itemSignaturePlacementText
{
  return [self labelForKey:
                 [NSString stringWithFormat: @"signatureplacement_%@", item]];
}

//
// Used by wox template
//
- (NSArray *) signaturePlacementList
{
  return [NSArray arrayWithObjects: @"above", @"below", nil];
}

// - (void) setUserSignaturePlacement: (NSString *) newSignaturePlacement
// {
//   [userDefaults setMailSignaturePlacement: newSignaturePlacement];
// }

// - (NSString *) userSignaturePlacement
// {
//   return [userDefaults mailSignaturePlacement];
// }

//
// Used by wox template
//
- (NSArray *) composeMessagesType
{
  return [NSArray arrayWithObjects: @"text", @"html", nil];
}

//
// Used by wox template
//
- (NSString *) itemComposeMessagesText
{
  return [self labelForKey: [NSString stringWithFormat:
                                        @"composemessagestype_%@", item]];
}

// - (NSString *) userComposeMessagesType
// {
//   return [userDefaults mailComposeMessageType];
// }

// - (void) setUserComposeMessagesType: (NSString *) newType
// {
//   [userDefaults setMailComposeMessageType: newType];
// }

//
// Used by wox template
//
- (NSArray *) displayRemoteInlineImages
{
  return [NSArray arrayWithObjects: @"never", @"always", nil];
}

//
// Used by wox template
//
- (NSString *) itemDisplayRemoteInlineImagesText
{
  return [self labelForKey: [NSString stringWithFormat:
                                        @"displayremoteinlineimages_%@", item]];
}

// - (NSString *) userDisplayRemoteInlineImages
// {
//   return [userDefaults mailDisplayRemoteInlineImages];
// }

// - (void) setAutoSave: (NSString *) theValue
// {
//   [userDefaults setMailAutoSave: theValue];
// }

// - (NSString *) autoSave
// {
//   return [userDefaults mailAutoSave];
// }

// - (void) setUserDisplayRemoteInlineImages: (NSString *) newType
// {
//   [userDefaults setMailDisplayRemoteInlineImages: newType];
// }

//
// Used by wox template
//
- (BOOL) isSieveScriptsEnabled
{
  return [[user domainDefaults] sieveScriptsEnabled];
}

//
// Used by wox template
//
- (NSString *) sieveCapabilities
{
  static NSArray *capabilities = nil;

  if (!capabilities)
    {
      if ([self isSieveScriptsEnabled] && [self _sieveClient])
        capabilities = [[self _sieveClient] capabilities];
      else
        capabilities = [NSArray array];
      [capabilities retain];
    }

  return [capabilities jsonRepresentation];
}

//
// Used by wox template
//
- (BOOL) isVacationEnabled
{
  return [[user domainDefaults] vacationEnabled];
}

- (NSString *) vacationHeader
{
  NSString *path;

  path = [[user domainDefaults] vacationHeaderTemplateFile];

  return [self _vacationTextForTemplate: path];
}

- (NSString *) vacationFooter
{
  NSString *path;

  path = [[user domainDefaults] vacationFooterTemplateFile];

  return [self _vacationTextForTemplate: path];
}

- (NSString *) _vacationTextForTemplate: (NSString *) templateFilePath
{
  NSString *text;
  SOGoTextTemplateFile *templateFile;

  text = nil;
  if (templateFilePath)
    {
      templateFile = [SOGoTextTemplateFile textTemplateFromFile: templateFilePath];
      if (templateFile)
        text = [templateFile textForUser: user];
    }

  return text;
}

// - (void) setSieveFiltersValue: (NSString *) newValue
// {
//   sieveFilters = [newValue objectFromJSONString];
//   if (sieveFilters)
//     {
//       if ([sieveFilters isKindOfClass: [NSArray class]])
//         [sieveFilters retain];
//       else
//         sieveFilters = nil;
//     }
// }

// - (NSString *) sieveFiltersValue
// {
//   return [sieveFilters jsonRepresentation];
// }

// - (void) setEnableVacation: (BOOL) enableVacation
// {
//   [vacationOptions setObject: [NSNumber numberWithBool: enableVacation]
//                       forKey: @"enabled"];
// }

// - (BOOL) enableVacation
// {
//   return [[vacationOptions objectForKey: @"enabled"] boolValue];
// }

// - (void) setAutoReplyText: (NSString *) theText
// {
//   [vacationOptions setObject: theText forKey: @"autoReplyText"];
// }

// - (NSString *) autoReplyText
// {
//   return [vacationOptions objectForKey: @"autoReplyText"];
// }

// - (void) setAutoReplyEmailAddresses: (NSString *) theAddresses
// {
//   NSArray *addresses;

//   addresses = [[theAddresses componentsSeparatedByString: @","]
//                 trimmedComponents];
//   [vacationOptions setObject: addresses
// 		      forKey: @"autoReplyEmailAddresses"];
// }

//
// Used internally
//
- (NSString *) _defaultEmailAddresses
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

//
// Used internally
//
- (NSDictionary *) _localizedCategoryLabels
{
  NSArray *categoryLabels, *localizedCategoryLabels;
  NSDictionary *labelsDictionary;

  labelsDictionary = nil;
  localizedCategoryLabels = [[self labelForKey: @"calendar_category_labels"
                                   withResourceManager: [self resourceManager]]
                              componentsSeparatedByString: @","];
  categoryLabels = [[[self resourceManager]
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

//
// Used by templates
//
- (NSString *) defaultCalendarCategoriesColors
{
  NSArray *labels;
  NSDictionary *localizedLabels, *colors;
  NSMutableDictionary *defaultCategoriesColors;
  NSString *label, *localizedLabel, *color;
  unsigned int i;

  localizedLabels = [self _localizedCategoryLabels];
  labels = [[SOGoSystemDefaults sharedSystemDefaults] calendarCategories];
  colors = [[SOGoSystemDefaults sharedSystemDefaults] calendarCategoriesColors];

  if ([colors count] > [labels count])
    {
      [self errorWithFormat: @"Incomplete calendar_category_labels for translation %@", [[user userDefaults] language]];
    }

  defaultCategoriesColors = [NSMutableDictionary dictionary];
  for (i = 0; i < [colors count] && i < [labels count]; i++)
    {
      label = [labels objectAtIndex: i];
      color = [colors objectForKey: label];
      if (!(localizedLabel = [localizedLabels objectForKey: label]))
        {
          localizedLabel = label;
        }
      [defaultCategoriesColors setObject: color
                                  forKey: localizedLabel];
    }

  return [defaultCategoriesColors jsonRepresentation];
}

//
// Used by templates
//
- (NSString *) autoReplyEmailAddresses
{
  NSArray *addressesList;

  addressesList = [vacationOptions objectForKey: @"autoReplyEmailAddresses"];

  return (addressesList
          ? [addressesList componentsJoinedByString: @", "]
          : [self _defaultEmailAddresses]);
}

//
// Used by templates
//
- (NSArray *) fontSizesList
{
  static NSArray *fontSizes = nil;

  if (!fontSizes)
    {
      fontSizes = [NSArray arrayWithObjects: @"8", @"9", @"10", @"11", @"12", @"13", @"14", @"16", @"18",
                           @"20", @"22", @"24", @"26", @"28",
                           @"36",
                           @"48",
                           @"72",
                           nil];
      [fontSizes retain];
    }

  return fontSizes;
}

- (NSString *) itemFontSizeText
{
  return [NSString stringWithFormat: @"%@ px", item];
}

//
// Used by templates
//
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

// - (void) setDaysBetweenResponses: (NSNumber *) theDays
// {
//   [vacationOptions setObject: theDays
// 		      forKey: @"daysBetweenResponse"];
// }

// - (NSString *) daysBetweenResponses
// {
//   NSString *days;

//   days = [vacationOptions objectForKey: @"daysBetweenResponse"];
//   if (!days)
//     days = @"7"; // defaults to 7 days

//   return days;
// }

// - (void) setIgnoreLists: (BOOL) ignoreLists
// {
//   [vacationOptions setObject: [NSNumber numberWithBool: ignoreLists]
// 		      forKey: @"ignoreLists"];
// }

// - (BOOL) ignoreLists
// {
//   NSNumber *obj;
//   BOOL ignore;

//   obj = [vacationOptions objectForKey: @"ignoreLists"];

//   if (obj == nil)
//     ignore = YES; // defaults to YES
//   else
//     ignore = [obj boolValue];

//   return ignore;
// }

//
// See http://sogo.nu/bugs/view.php?id=2332 for details
//
// - (void) setAlwaysSend: (BOOL) ignoreLists
// {
//   [vacationOptions setObject: [NSNumber numberWithBool: ignoreLists]
// 		      forKey: @"alwaysSend"];
// }

// - (BOOL) alwaysSend
// {
//   NSNumber *obj;
//   BOOL ignore;

//   obj = [vacationOptions objectForKey: @"alwaysSend"];

//   if (obj == nil)
//     ignore = NO; // defaults to NO
//   else
//     ignore = [obj boolValue];

//   return ignore;
// }

// - (BOOL) enableVacationEndDate
// {
//   return [[vacationOptions objectForKey: @"endDateEnabled"] boolValue];
// }

// - (BOOL) disableVacationEndDate
// {
//   return ![self enableVacationEndDate];
// }

// - (void) setEnableVacationEndDate: (BOOL) enableVacationEndDate
// {
//   [vacationOptions setObject: [NSNumber numberWithBool: enableVacationEndDate]
//                       forKey: @"endDateEnabled"];
// }

// - (void) setVacationEndDate: (NSCalendarDate *) endDate
// {
//   NSNumber *time;

//   time = [NSNumber numberWithInt: [endDate timeIntervalSince1970]];

//   [vacationOptions setObject: time forKey: @"endDate"];
// }

// - (NSCalendarDate *) vacationEndDate
// {
//   int time;

//   time = [[vacationOptions objectForKey: @"endDate"] intValue];

//   if (time > 0)
//     return [NSCalendarDate dateWithTimeIntervalSince1970: time];
//   else
//     return [NSCalendarDate calendarDate];
// }

/* mail forward */

//
// Used by templates
//
- (BOOL) isForwardEnabled
{
  return [[user domainDefaults] forwardEnabled];
}

// - (void) setEnableForward: (BOOL) enableForward
// {
//   [forwardOptions setObject: [NSNumber numberWithBool: enableForward]
// 		     forKey: @"enabled"];
// }

// - (BOOL) enableForward
// {
//   return [[forwardOptions objectForKey: @"enabled"] boolValue];
// }

// - (void) setForwardAddress: (NSString *) forwardAddress
// {
//   NSArray *addresses;

//   addresses = [[forwardAddress componentsSeparatedByString: @","]
//                 trimmedComponents];
//   [forwardOptions setObject: addresses
// 		     forKey: @"forwardAddress"];
// }

// - (NSString *) forwardAddress
// {
//   id addresses;

//   addresses = [forwardOptions objectForKey: @"forwardAddress"];

//   return ([addresses respondsToSelector: @selector(componentsJoinedByString:)]
//           ? [(NSArray *)addresses componentsJoinedByString: @", "]
//           : (NSString *)addresses);
// }

// - (void) setForwardKeepCopy: (BOOL) keepCopy
// {
//   [forwardOptions setObject: [NSNumber numberWithBool: keepCopy]
// 		     forKey: @"keepCopy"];
// }

// - (BOOL) forwardKeepCopy
// {
//   return [[forwardOptions objectForKey: @"keepCopy"] boolValue];
// }

- (NSString *) forwardConstraints
{
  SOGoDomainDefaults *dd;

  dd = [[context activeUser] domainDefaults];

  return [NSString stringWithFormat: @"%d", [dd forwardConstraints]];
}

//
// Used by templates
//
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

//
// Used by templates
//
- (NSString *) itemModuleText
{
  return [self labelForKey: item];
}

- (BOOL) externalAvatarsEnabled
{
  return [[user domainDefaults] externalAvatarsEnabled];
}

- (NSArray *) alternateAvatar
{
  // See: https://en.gravatar.com/site/implement/images/
  return [NSArray arrayWithObjects: @"none", @"identicon", @"monsterid", @"wavatar", @"retro", nil];
}

- (NSString *) itemAlternateAvatarText
{
  return [self labelForKey: item];
}


// - (NSString *) userDefaultModule
// {
//   NSString *userDefaultModule;

//   if ([userDefaults rememberLastModule])
//     userDefaultModule = @"Last";
//   else
//     userDefaultModule = [userDefaults loginModule];

//   return userDefaultModule;
// }

// - (void) setUserDefaultModule: (NSString *) newValue
// {
//   if ([newValue isEqualToString: @"Last"])
//     [userDefaults setRememberLastModule: YES];
//   else
//     {
//       [userDefaults setRememberLastModule: NO];
//       [userDefaults setLoginModule: newValue];
//     }
// }

//
// Used by templates
//
- (NSString *) sogoVersion
{
  // The variable SOGoVersion comes from the import: SOGo/Build.h
  return [NSString stringWithString: SOGoVersion];
}

//
// Used internally
//
- (id) _sieveClient
{
  SOGoMailAccount *account;
  SOGoMailAccounts *folder;
  SOGoSieveManager *manager;

  if (!client)
    {
      folder = [[[context activeUser] homeFolderInContext: context] mailAccountsFolder: @"Mail" inContext: context];
      account = [folder lookupName: @"0" inContext: context acquire: NO];
      manager = [SOGoSieveManager sieveManagerForUser: [context activeUser]];
      client = [[manager clientForAccount: account] retain];
    }

  return client;
}

//
// Used internally
//
- (BOOL) _isSieveServerAvailable
{
  return (([(NGSieveClient *)[self _sieveClient] isConnected])
          ? YES
          : NO);
}

// - (id <WOActionResults>) defaultAction
// {
//   id <WOActionResults> results;
//   SOGoDomainDefaults *dd;
//   SOGoMailAccount *account;
//   SOGoMailAccounts *folder;
//   WORequest *request;

//   request = [context request];
//   if ([[request method] isEqualToString: @"POST"])
//     {
//       dd = [[context activeUser] domainDefaults];
//       if ([dd sieveScriptsEnabled])
//         [userDefaults setSieveFilters: sieveFilters];
//       if ([dd vacationEnabled])
//         [userDefaults setVacationOptions: vacationOptions];
//       if ([dd forwardEnabled])
//         [userDefaults setForwardOptions: forwardOptions];

//       if (!([dd sieveScriptsEnabled] || [dd vacationEnabled] || [dd forwardEnabled]) || [self _isSieveServerAvailable])
//         {
//           [userDefaults synchronize];
//           folder = [[self clientObject] mailAccountsFolder: @"Mail"
//                                                  inContext: context];
//           account = [folder lookupName: @"0" inContext: context acquire: NO];

//           if ([account updateFilters])
//             // If Sieve is not enabled, the SOGoSieveManager will immediatly return a positive answer
//             // See [SOGoSieveManager updateFiltersForAccount:withUsername:andPassword:]
//             results = (id <WOActionResults>)[self responseWithStatus: 200
//                          andJSONRepresentation: [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool:hasChanged], @"hasChanged", nil]];

//           else
//             results = (id <WOActionResults>)[self responseWithStatus: 502
//                          andJSONRepresentation: [NSDictionary dictionaryWithObjectsAndKeys: @"Connection error", @"textStatus", nil]];
//         }
//       else
//         results = (id <WOActionResults>)[self responseWithStatus: 503
//                      andJSONRepresentation: [NSDictionary dictionaryWithObjectsAndKeys: @"Service temporarily unavailable", @"textStatus", nil]];
//     }
//   else
//     results = self;

//   return results;
// }

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
                           inContext: (WOContext*) context
{
  return [[request method] isEqualToString: @"POST"];
}

//
// Used wox by template
//
- (BOOL) userHasCalendarAccess
{
  return [user canAccessModule: @"Calendar"];
}

//
// Used wox by template
//
- (BOOL) userHasMailAccess
{
  return [user canAccessModule: @"Mail"];
}

//
// Used wox by template
//
- (BOOL) shouldDisplayAdditionalPreferences
{
  return [[SOGoSystemDefaults sharedSystemDefaults]
           uixAdditionalPreferences];
}

//
// Used wox by template
//
- (BOOL) shouldDisplayPasswordChange
{
  return [[SOGoSystemDefaults sharedSystemDefaults]
           userCanChangePassword];
}

// - (NSString *) localeCode
// {
//   // WARNING : NSLocaleCode is not defined in <Foundation/NSUserDefaults.h>
//   return [locale objectForKey: @"NSLocaleCode"];
// }

// - (NSArray *) _languageCalendarCategories
// {
//   NSArray *categoryLabels;

//   categoryLabels = [[self labelForKey: @"calendar_category_labels"]
//                        componentsSeparatedByString: @","];

//   return [categoryLabels trimmedComponents];
// }

// - (NSArray *) calendarCategoryList
// {
//   if (!calendarCategories)
//     {
//       ASSIGN (calendarCategories, [userDefaults calendarCategories]);
//       if (!calendarCategories)
//         ASSIGN (calendarCategories, [self _languageCalendarCategories]);
//     }

//   return [calendarCategories
//            sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)];
// }

// - (SOGoMailLabel *) label
// {
//   return label;
// }

// - (void) setLabel: (SOGoMailLabel *) newLabel
// {
//   ASSIGN(label, newLabel);
// }

// - (NSArray *) mailLabelList
// {
//   if (!mailLabels)
//     {
//       NSDictionary *v;

//       v = [[[context activeUser] userDefaults] mailLabelsColors];
//       ASSIGN(mailLabels, [SOGoMailLabel labelsFromDefaults: v  component: self]);
//     }

//   return mailLabels;
// }

// - (NSString *) mailLabelsValue
// {
//   return @"";
// }

// - (void) setMailLabelsValue: (NSString *) value
// {
//   NSMutableDictionary *sanitizedLabels;
//   NSDictionary *newLabels;
//   NSArray *allKeys;
//   NSString *name;
//   int i;

//   newLabels = [value objectFromJSONString];
//   if (newLabels && [newLabels isKindOfClass: [NSDictionary class]])
//     {
//       // We encode correctly our keys
//       sanitizedLabels = [NSMutableDictionary dictionary];
//       allKeys = [newLabels allKeys];

//       for (i = 0; i < [allKeys count]; i++)
//         {
//           name = [allKeys objectAtIndex: i];

//           if (![name is7bitSafe])
//             name = [name stringByEncodingImap4FolderName];

//           name = [name lowercaseString];

//           [sanitizedLabels setObject: [newLabels objectForKey: [allKeys objectAtIndex: i]]
//                               forKey: name];
//         }

//       [userDefaults setMailLabelsColors: sanitizedLabels];
//     }
// }


// - (void) setCategory: (NSString *) newCategory
// {
//   ASSIGN (category, newCategory);
// }

// - (NSString *) category
// {
//   return category;
// }

// - (NSString *) categoryColor
// {
//   SOGoDomainDefaults *dd;
//   NSString *categoryColor;

//   if (!calendarCategoriesColors)
//     ASSIGN (calendarCategoriesColors, [userDefaults calendarCategoriesColors]);

//   categoryColor = [calendarCategoriesColors objectForKey: category];
//   if (!categoryColor)
//     {
//       if (!defaultCategoryColor)
//         {
//           dd = [[context activeUser] domainDefaults];
//           ASSIGN (defaultCategoryColor, [dd calendarDefaultCategoryColor]);
//         }
//       categoryColor = defaultCategoryColor;
//     }

//   return categoryColor;
// }

// - (NSString *) calendarCategoriesValue
// {
//   return @"";
// }

// - (void) setCalendarCategoriesValue: (NSString *) value
// {
//   NSDictionary *newColors;

//   newColors = [value objectFromJSONString];
//   if (newColors && [newColors isKindOfClass: [NSDictionary class]])
//     {
//       [userDefaults setCalendarCategories: [newColors allKeys]];
//       [userDefaults setCalendarCategoriesColors: newColors];
//     }
// }

// - (NSArray *) _languageContactsCategories
// {
//   NSArray *categoryLabels;

//   categoryLabels = [[self labelForKey: @"contacts_category_labels"]
//                        componentsSeparatedByString: @","];
//   if (!categoryLabels)
//     categoryLabels = [NSArray array];

//   return [categoryLabels trimmedComponents];
// }

// - (NSArray *) contactsCategoryList
// {
//   if (!contactsCategories)
//     {
//       ASSIGN (contactsCategories, [userDefaults contactsCategories]);
//       if (!contactsCategories)
//         ASSIGN (contactsCategories, [self _languageContactsCategories]);
//     }

//   return [contactsCategories
//            sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)];
// }

// - (NSString *) contactsCategoriesValue
// {
//   return @"";
// }

// - (void) setContactsCategoriesValue: (NSString *) value
// {
//   NSArray *newCategories;

//   newCategories = [value objectFromJSONString];
//   if (newCategories && [newCategories isKindOfClass: [NSArray class]])
//     [userDefaults setContactsCategories: newCategories];
// }

//
// Used by wox template
//
- (NSArray *) languages
{
  return [[SOGoSystemDefaults sharedSystemDefaults] supportedLanguages];
}

// - (NSString *) language
// {
//   return [userDefaults language];
// }

// - (void) setLanguage: (NSString *) newLanguage
// {
//   if ([[self languages] containsObject: newLanguage])
//     [userDefaults setLanguage: newLanguage];
// }

//
// Used by wox template
//
- (NSString *) languageText
{
  return [self labelForKey: item];
}

- (NSDictionary *) languageLocale
{
  WOResourceManager *rm;

  rm = [self pageResourceManager];

  return [rm localeForLanguageNamed: item];
}

//
// Used by wox template
//
- (BOOL) mailAuxiliaryUserAccountsEnabled
{
  return [[user domainDefaults] mailAuxiliaryUserAccountsEnabled];
}

//
// Used internally
//
- (void) _extractMainIdentity: (NSDictionary *) identity
                 inDictionary: (NSMutableDictionary *) target

{
  /* We perform some validation here as we have no guaranty on the input
     validity. */
  NSString *value;

  if ([identity isKindOfClass: [NSDictionary class]])
    {
      value = [identity objectForKey: @"signature"];

      if (value)
        [target setObject: value  forKey: @"SOGoMailSignature"];
      else
        [target removeObjectForKey: @"SOGoMailSignature"];

      if (mailCustomFromEnabled)
        {
          value = [[identity objectForKey: @"email"]
                    stringByTrimmingSpaces];

          /* We make sure that the "custom" value is different from the system email */
          if ([value length] == 0
              || [[user systemEmail] isEqualToString: value])
            value = nil;

          if (value)
            [target setObject: value  forKey: @"SOGoMailCustomEmail"];
          else
            [target removeObjectForKey: @"SOGoMailCustomEmail"];

          value = [[identity objectForKey: @"fullName"]
                    stringByTrimmingSpaces];
          if ([value length] == 0
              || [[user cn] isEqualToString: value])
            value = nil;

          if (value)
            [target setObject: value  forKey: @"SOGoMailCustomFullName"];
          else
            [target removeObjectForKey: @"SOGoMailCustomFullName"];
        }

      value = [[identity objectForKey: @"replyTo"]
                stringByTrimmingSpaces];

      if (value && [value length] > 0)
        [target setObject: value  forKey: @"SOGoMailReplyTo"];
      else
        [target removeObjectForKey: @"SOGoMailReplyTo"];
    }
}

//
// Used internally
//
- (BOOL) _validateReceiptAction: (NSString *) action
{
  return ([action isKindOfClass: [NSString class]]
          && ([action isEqualToString: @"ignore"]
              || [action isEqualToString: @"send"]
              || [action isEqualToString: @"ask"]));
}

//
// Used internally
//
- (void) _extractMainReceiptsPreferences: (NSDictionary *) receipts
                            inDictionary: (NSMutableDictionary *) target

{
  /* We perform some validation here as we have no guaranty on the input
     validity. */
  NSString *action;

  if ([receipts isKindOfClass: [NSDictionary class]])
    {
      action = [receipts objectForKey: @"receiptAction"];
      [target setObject: @"1" forKey: @"SOGoMailReceiptAllow"];

      action = [receipts objectForKey: @"receiptNonRecipientAction"];
      if ([self _validateReceiptAction: action])
        [target setObject: action  forKey: @"SOGoMailReceiptNonRecipientAction"];

      action = [receipts objectForKey: @"receiptOutsideDomainAction"];
      if ([self _validateReceiptAction: action])
        [target setObject: action  forKey: @"SOGoMailReceiptOutsideDomainAction"];

      action = [receipts objectForKey: @"receiptAnyAction"];
      if ([self _validateReceiptAction: action])
        [target setObject: action  forKey: @"SOGoMailReceiptAnyAction"];
    }
}

//
// Used internally
//
- (void) _extractMainSecurityPreferences: (NSDictionary *) security
                            inDictionary: (NSMutableDictionary *) target

{
  NSString *action;

  if ([security isKindOfClass: [NSDictionary class]])
    {
      action = [security objectForKey: @"alwaysSign"];
      if (action && [action boolValue])
        [target setObject: @"1" forKey: @"SOGoMailCertificateAlwaysSign"];

      action = [security objectForKey: @"alwaysEncrypt"];
      if (action && [action boolValue])
        [target setObject: @"1" forKey: @"SOGoMailCertificateAlwaysEncrypt"];
    }
}

//
// Used internally
//
- (void) _extractMainCustomFrom: (NSDictionary *) account
{
}

//
// Used internally
//
- (void) _extractMainReplyTo: (NSDictionary *) account
{
}

//
// Used internally
//
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

//
// Used internally
//
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
                           @"receipts", @"security", @"isNew",
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
          value = [account objectForKey: @"encryption"];
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

//
// Used internally
//
- (void) _extractMainAccountSettings: (NSDictionary *) account
                        inDictionary: (NSMutableDictionary *) target
{
  NSArray *identities;

  if ([account isKindOfClass: [NSDictionary class]])
    {
      identities = [account objectForKey: @"identities"];
      if ([identities isKindOfClass: [NSArray class]]
          && [identities count] > 0)
        [self _extractMainIdentity: [identities objectAtIndex: 0]  inDictionary: target];
      [self _extractMainReceiptsPreferences: [account objectForKey: @"receipts"]  inDictionary: target];
      [self _extractMainSecurityPreferences: [account objectForKey: @"security"]  inDictionary: target];
    }
}

//
// Used internally
//
- (NSArray *) _extractAuxiliaryAccounts: (NSArray *) accounts
{
  int count, max;
  NSMutableArray *auxAccounts;
  NSMutableDictionary *account;

  max = [accounts count];
  auxAccounts = [NSMutableArray arrayWithCapacity: max];

  for (count = 1; count < max; count++)
    {
      account = [accounts objectAtIndex: count];
      if ([self _validateAccount: account])
        {
          [self _updateAuxiliaryAccount: account];
          [auxAccounts addObject: account];
        }
    }

  return auxAccounts;
}

- (void) _updateAuxiliaryAccount: (NSMutableDictionary *) newAccount
{
  int count, oldMax;
  NSArray *oldAccounts, *comparisonAttributes;
  NSDictionary *oldAccount, *oldSecurity;
  NSEnumerator *comparisonAttributesList;
  NSMutableDictionary *newSecurity;
  NSString *comparisonAttribute, *password, *certificate;

  comparisonAttributes = [NSArray arrayWithObjects: @"serverName", @"userName", nil];
  oldAccounts = [user mailAccounts];
  oldAccount = nil;
  oldMax = [oldAccounts count];

  for (count = 1 /* skip system account */; !oldAccount && count < oldMax; count++)
    {
      oldAccount = [oldAccounts objectAtIndex: count];
      comparisonAttributesList = [comparisonAttributes objectEnumerator];
      while (oldAccount && (comparisonAttribute = [comparisonAttributesList nextObject]))
        {
          if (![[oldAccount objectForKey: comparisonAttribute]
                isEqualToString: [newAccount objectForKey: comparisonAttribute]])
            oldAccount = nil;
        }
    }

  if (oldAccount)
    {
      // Use previous password if none is provided
      password = [newAccount objectForKey: @"password"];
      if (!password)
        password = [oldAccount objectForKey: @"password"];
      if (!password)
        password = @"";
      [newAccount setObject: password forKey: @"password"];

      // Keep previous certificate
      oldSecurity = [oldAccount objectForKey: @"security"];
      if (oldSecurity)
        {
          certificate = [oldSecurity objectForKey: @"certificate"];
          if (certificate)
            {
              newSecurity = [newAccount objectForKey: @"security"];
              if (!newSecurity)
                {
                  newSecurity = [NSMutableDictionary dictionary];
                  [newAccount setObject: newSecurity forKey: @"security"];
                }
              [newSecurity setObject: certificate forKey: @"certificate"];
            }
        }
    }
}

// - (void) setMailAccounts: (NSString *) newMailAccounts
// {
//   NSArray *accounts;
//   int max;

//   accounts = [newMailAccounts objectFromJSONString];
//   if (accounts && [accounts isKindOfClass: [NSArray class]])
//     {
//       max = [accounts count];
//       if (max > 0)
//         {
//           [self _extractMainAccountSettings: [accounts objectAtIndex: 0]];
//           if ([self mailAuxiliaryUserAccountsEnabled])
//             [self _extractAuxiliaryAccounts: accounts];
//         }
//     }
// }

// - (NSString *) mailAccounts
// {
//   NSArray *accounts;
//   NSMutableDictionary *account;
//   int count, max;

//   accounts = [user mailAccounts];
//   max = [accounts count];
//   for (count = 0; count < max; count++)
//     {
//       account = [accounts objectAtIndex: count];
//       [account removeObjectForKey: @"password"];
//     }

//   return [accounts jsonRepresentation];
// }

- (NSString *) mailCustomFromEnabled
{
  return (mailCustomFromEnabled ? @"true" : @"false");
}

- (NSString *) forwardEnabled
{
  return (forwardEnabled ? @"true" : @"false");
}

/**
 * @api {post} /so/:username/Preferences/save Save user's defaults and settings
 * @apiVersion 1.0.0
 * @apiName PostPreferencesSave
 * @apiGroup Preferences
 * @apiDescription Save user's defaults and settings.
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Preferences/save \
 *          -H 'Content-Type: application/json' \
 *          -d '{ "defaults": { SOGoDayStartTime: "09:00", "SOGoDayEndTime": "18:00" }, \
 *                "settings": { Calendar: { ListState: "rise", EventsFilterState: "view_next7" } } }'
 *
 * @apiParam {Object} [defaults]              All attributes for user's defaults
 * @apiParam {Object} [settings]              All attributes for user's settings
 *
 * @apiError (Error 500) {Object} error       The error message
 */
- (id <WOActionResults>) saveAction
{
  id <WOActionResults> results;
  id o, v;

  o = [[[context request] contentAsString] objectFromJSONString];
  results = nil;

  // Proceed with data sanitization of the "defaults"
  if ((v = [o objectForKey: @"defaults"]))
    {
      NSMutableDictionary *sanitizedLabels;
      NSArray *allKeys, *accounts;
      NSDictionary *newLabels;
      NSString *name;
      id loginModule;

      int i;

      // We convert our object into a mutable one
      v = [[v mutableCopy] autorelease];

      if ([[v objectForKey: @"SOGoLoginModule"] isEqualToString: @"Last"])
        {
          [v setObject: [NSNumber numberWithBool: YES]  forKey: @"SOGoRememberLastModule"];
          loginModule = [[[user userDefaults] source] objectForKey: @"SOGoLoginModule"];
          if (loginModule)
            [v setObject: loginModule forKey: @"SOGoLoginModule"];
          else
            [v removeObjectForKey: @"SOGoLoginModule"];
        }
      else
        [v setObject: [NSNumber numberWithBool: NO]  forKey: @"SOGoRememberLastModule"];

      // We remove short/long date/time formats if they are default ones
      if ([[v objectForKey: @"SOGoShortDateFormat"] isEqualToString: @"default"])
        [v removeObjectForKey: @"SOGoShortDateFormat"];

      if ([[v objectForKey: @"SOGoLongDateFormat"] isEqualToString: @"default"])
        [v removeObjectForKey: @"SOGoLongDateFormat"];

      if ([[v objectForKey: @"SOGoTimeFormat"] isEqualToString: @"default"])
        [v removeObjectForKey: @"SOGoTimeFormat"];

      if (![self externalAvatarsEnabled])
        {
          [v removeObjectForKey: @"SOGoGravatarEnabled"];
          [[[user userDefaults] source] removeObjectForKey: @"SOGoGravatarEnabled"];
          [v removeObjectForKey: @"SOGoAlternateAvatar"];
          [[[user userDefaults] source] removeObjectForKey: @"SOGoAlternateAvatar"];
        }

      //
      // We sanitize mail labels
      //
      newLabels = [v objectForKey: @"SOGoMailLabelsColors"];
      if (newLabels && [newLabels isKindOfClass: [NSDictionary class]])
        {
          // We encode correctly our keys
          sanitizedLabels = [NSMutableDictionary dictionary];
          allKeys = [newLabels allKeys];

          for (i = 0; i < [allKeys count]; i++)
            {
              name = [allKeys objectAtIndex: i];

              if (![name is7bitSafe])
                name = [name stringByEncodingImap4FolderName];

              name = [name lowercaseString];

              [sanitizedLabels setObject: [newLabels objectForKey: [allKeys objectAtIndex: i]]
                                  forKey: name];
            }

          [v setObject: sanitizedLabels  forKey: @"SOGoMailLabelsColors"];
        }

      //
      // Keep the primary mail certificate
      //
      if ([[[user userDefaults] mailCertificate] length])
        [v setObject: [[user userDefaults] mailCertificate]  forKey: @"SOGoMailCertificate"];

      //
      // We sanitize our auxilary mail accounts
      //
      accounts = [v objectForKey: @"AuxiliaryMailAccounts"];
      if (accounts && [accounts isKindOfClass: [NSArray class]])
        {
          if ([accounts count] > 0)
            {
              // The first account is the main system account. The following mapping is required:
              // - identities[0].signature             => SOGoMailSignature
              // - identities[0].email                 => SOGoMailCustomEmail
              // - identities[0].fullName              => SOGoMailCustomFullName
              // - identities[0].replyTo               => SOGoMailReplyTo
              // - receipts.receiptAction              => SOGoMailReceiptAllow
              // - receipts.receiptNonRecipientAction  => SOGoMailReceiptNonRecipientAction
              // - receipts.receiptOutsideDomainAction => SOGoMailReceiptOutsideDomainAction
              // - receipts.receiptAnyAction           => SOGoMailReceiptAnyAction
              // - security.alwaysSign                 => SOGoMailCertificateAlwaysSign
              // - security.alwaysEncrypt              => SOGoMailCertificateAlwaysEncrypt
              [self _extractMainAccountSettings: [accounts objectAtIndex: 0]  inDictionary: v];
              if ([self mailAuxiliaryUserAccountsEnabled])
                accounts = [self _extractAuxiliaryAccounts: accounts];
              else
                accounts = [NSArray array];

              [v setObject: accounts  forKey: @"AuxiliaryMailAccounts"];
            }
        }

      [[[user userDefaults] source] setValues: v];

      if ([[user userDefaults] synchronize])
        {
          SOGoMailAccount *account;
          SOGoMailAccounts *folder;
          SOGoDomainDefaults *dd;

          dd = [[context activeUser] domainDefaults];

          // We check if the Sieve server is available *ONLY* if at least one of the option is enabled
          if (!([dd sieveScriptsEnabled] || [dd vacationEnabled] || [dd forwardEnabled]) || [self _isSieveServerAvailable])
            {

              folder = [[[context activeUser] homeFolderInContext: context]  mailAccountsFolder: @"Mail"
                                                                                      inContext: context];
              account = [folder lookupName: @"0" inContext: context acquire: NO];

              if (![account updateFilters])
                {
                  results = (id <WOActionResults>) [self responseWithStatus: 502
                           andJSONRepresentation: [NSDictionary dictionaryWithObjectsAndKeys: @"Connection error", @"message", nil]];
                }
            }
          else
            results = (id <WOActionResults>) [self responseWithStatus: 503
                         andJSONRepresentation: [NSDictionary dictionaryWithObjectsAndKeys: @"Service temporarily unavailable", @"message", nil]];
        }
    }

  if ((v = [o objectForKey: @"settings"]))
    {
      [[[user userSettings] source] setValues: v];
      [[user userSettings] synchronize];
    }

  if (!results)
    results = (id <WOActionResults>) [self responseWithStatus: 200];

  return results;
}

@end
