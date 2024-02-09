/* UIxPreferences.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2022 Inverse inc.
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
#import <SOGo/NSString+Crypto.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoSieveManager.h>
#import <SOGo/SOGoSource.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoParentFolder.h>
#import <SOGo/SOGoTextTemplateFile.h>
#import <SOGo/WOResourceManager+SOGo.h>
#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoPasswordPolicy.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>

#import <Contacts/SOGoContactGCSFolder.h>

#import "UIxPreferences.h"

#if defined(MFA_CONFIG)
#include <liboath/oath.h>
#endif

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

  if ([dd notificationEnabled])
	{
	  notificationOptions = [[userDefaults notificationOptions] mutableCopy];
	  if (!notificationOptions)
            notificationOptions = [NSMutableDictionary new];
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
  [forwardOptions release];
  [notificationOptions release];
  [daysOfWeek release];
  [addressBooksIDWithDisplayName release];
  [client release];
  [super dealloc];
}

- (NSString *) moduleName
{
  return [self commonLabelForKey: @"Preferences"];
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

//
// Used by wox template
//
- (NSArray *) passwordPolicy
{
  NSObject <SOGoSource> *userSource;
  NSMutableDictionary *translations = [[NSMutableDictionary alloc] init];
  NSDictionary *policy;
  NSDictionary *translatedUserPolicy;
  
  userSource = [user authenticationSource];
  
  for(policy in [userSource userPasswordPolicy]) {
    [translations setObject:[self labelForKey:[policy objectForKey:@"label"]] 
                     forKey: [policy objectForKey:@"label"]];
  }
  translatedUserPolicy = [SOGoPasswordPolicy createPasswordPolicyLabels: [userSource userPasswordPolicy] 
                                                                     withTranslations: translations];
  [translations release];
  
  return translatedUserPolicy;
}

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

- (NSArray *) shortWeekDaysList
{
  NSArray *shortWeekDaysList = nil;

  shortWeekDaysList = [locale objectForKey: NSShortWeekDayNameArray];

  return shortWeekDaysList;
}

- (NSString *) valueForWeekDay
{
  unsigned int i;

  i = [[self shortWeekDaysList] indexOfObject: item];

  return iCalWeekDayString[i];
}

- (int) numberForWeekDay
{
  unsigned int i;

  i = [[self shortWeekDaysList] indexOfObject: item];

  return i;
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

- (BOOL) isVacationPeriodEnabled
{
  return [[user domainDefaults] vacationPeriodEnabled];
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

//
// Used internally
//
- (NSString *) defaultEmailAddresses
{
  return [[[user allEmails] uniqueObjects] jsonRepresentation];
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
- (NSDictionary *) _localizedContactsLabels
{
  NSArray *categoryLabels, *localizedCategoryLabels;
  NSDictionary *labelsDictionary;

  labelsDictionary = nil;
  localizedCategoryLabels = [[self labelForKey: @"contacts_category_labels"
                                   withResourceManager: [self resourceManager]]
                              componentsSeparatedByString: @","];
  categoryLabels = [[[self resourceManager]
                                      stringForKey: @"contacts_category_labels"
                                      inTableNamed: nil
                                  withDefaultValue: @""
                                         languages: [NSArray arrayWithObject: @"English"]]
                                      componentsSeparatedByString: @","];

  if ([localizedCategoryLabels count] == [categoryLabels count])
    labelsDictionary = [NSDictionary dictionaryWithObjects: localizedCategoryLabels
                                                   forKeys: categoryLabels];
  else
    [self logWithFormat: @"ERROR: localizable strings contacts_category_labels is incorrect for language %@",
          [[[context activeUser] userDefaults] language]];

  return labelsDictionary;
}

- (NSString *) defaultContactsCategories
{
  NSArray *labels;
  NSDictionary *localizedLabels;
  NSMutableArray *defaultCategoriesLabels;
  NSString *label, *localizedLabel;
  unsigned int i;

  localizedLabels = [self _localizedContactsLabels];
  labels = [[SOGoSystemDefaults sharedSystemDefaults] contactsCategories];
  defaultCategoriesLabels = [NSMutableArray array];

  if(labels)
  {
    for (i = 0; i < [labels count]; i++)
    {
      label = [labels objectAtIndex: i];
      if (!(localizedLabel = [localizedLabels objectForKey: label]))
      {
        localizedLabel = label;
      }
      [defaultCategoriesLabels addObject: localizedLabel];
    }
  }
  else
  {
    defaultCategoriesLabels = [localizedLabels allValues];
  }


  return [defaultCategoriesLabels jsonRepresentation];
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

/* mail forward */

//
// Used by templates
//
- (BOOL) isForwardEnabled
{
  return [[user domainDefaults] forwardEnabled];
}

- (NSString *) forwardConstraints
{
  SOGoDomainDefaults *dd;

  dd = [[context activeUser] domainDefaults];

  return [NSString stringWithFormat: @"%d", [dd forwardConstraints]];
}

- (NSString *) forwardConstraintsDomains
{
  NSMutableArray *domains;
  SOGoDomainDefaults *dd;

  dd = [[context activeUser] domainDefaults];
  domains = [NSMutableArray array];
  [domains addObjectsFromArray: [dd forwardConstraintsDomains]];

  return [domains jsonRepresentation];
}

/* mail notifications */
//
// Used by templates
//
- (BOOL) isNotificationEnabled
{
  return [[user domainDefaults] notificationEnabled];
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

//
// Used by templates
//
- (NSString *) sogoVersion
{
  // The variable SOGoVersion comes from the import: SOGo/Build.h
  return [NSString stringWithString: SOGoVersion];
}

- (BOOL) isTotpEnabled
{
#if defined(MFA_CONFIG)
  return YES;
#else
  return NO;
#endif
}

- (NSString *) totpKey
{
  return [[context activeUser] totpKey];
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


//
// Used by wox template
//
- (NSArray *) languages
{
  return [[[SOGoSystemDefaults sharedSystemDefaults] supportedLanguages] sortedArrayUsingFunction: languageSort context: self];
}

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
      action = [[receipts objectForKey: @"receiptAction"] isEqualToString: @"ignore"] ? @"0" : @"1";
      [target setObject: action forKey: @"SOGoMailReceiptAllow"];

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
                           @"signature", @"replyTo", @"isDefault", nil];
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
      knownKeys = [NSArray arrayWithObjects: @"id", @"name", @"serverName", @"port",
                           @"smtpServerName", @"smtpPort", @"smtpEncryption", @"smtpAuth",
                           @"userName", @"password", @"encryption", @"replyTo",
                           @"identities", @"mailboxes", @"forceDefaultIdentity",
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
- (NSException *) _extractMainAccountSettings: (NSDictionary *) account
                        inDictionary: (NSMutableDictionary *) target
{
  NSArray *identities;
  SOGoDomainDefaults *dd;
  NSMutableArray *previousIdentities, *newIdentities;
  NSMutableDictionary *identity, *previousIdentity, *newIdentitiesAsDict;
  NSException *error;
  int i;
  BOOL isDefault, found;

  error = nil;

  if ([account isKindOfClass: [NSDictionary class]])
    {
      
      identities = [account objectForKey: @"identities"];
      
      dd = [[context activeUser] domainDefaults];
      if ([self _validateAccountIdentities: identities]) {
        // Disable identity creation for users in preferences
        if ([dd createIdentitiesDisabled]) {
          // If create identities is disabled, user can only modify full name and signature
          previousIdentities = [NSMutableArray arrayWithArray: [[user accountWithName: [account objectForKey: @"name"]] objectForKey: @"identities"]];
          newIdentities = [NSMutableArray arrayWithArray: identities];

          if ([newIdentities count] <= [previousIdentities count]) {
            newIdentitiesAsDict = [[NSMutableDictionary alloc] init];
            for (NSDictionary *identity in identities) {
              [newIdentitiesAsDict setObject: identity forKey: [identity objectForKey:@"email"]];
              // Check if email has been changed (unauthorized)
              if ([identity objectForKey:@"email"]) {
                found = NO;
                for (previousIdentity in previousIdentities) {
                  if ([[identity objectForKey:@"email"] isEqualToString: [previousIdentity objectForKey:@"email"]]) {
                    found = YES;
                  }
                }
                if (!found) {
                  error = [NSException exceptionWithName: @"SOGOPreferencesException"
                                      reason: @"Invalid operation"
                                    userInfo: nil];;
                  return error; // Break
                }
              }
              
              // Check if replyTo has been changed (unauthorized)
              if ([identity objectForKey:@"replyTo"]) {
                found = NO;
                for (previousIdentity in previousIdentities) {
                  if ([[identity objectForKey:@"replyTo"] isEqualToString: [previousIdentity objectForKey:@"replyTo"]]) {
                    found = YES;
                  }
                }
                if (!found) {
                  error = [NSException exceptionWithName: @"SOGOPreferencesException"
                                      reason: @"Invalid operation"
                                    userInfo: nil];;
                  return error; // Break
                }
              }
            }

            i = 0;
            // Remove existing deleted identities
            for (identity in [user allIdentities]) {
              // Identity deleted and at least one identity and not the default identity
              if ([identity objectForKey:@"isDefault"]) {
                isDefault = [[identity objectForKey:@"isDefault"] boolValue];
              } else {
                isDefault = NO;
              }
              
              if (![newIdentitiesAsDict objectForKey: [identity objectForKey:@"email"]] 
                    && [previousIdentities count] > 1
                    && !isDefault) {
                [previousIdentities removeObjectAtIndex: i];
                i--;
              }
              i++;
            }

            // Update full name, signature and default for existing identities
            for (identity in previousIdentities) {
              if ([newIdentitiesAsDict objectForKey: [identity objectForKey:@"email"]]) {
                  [identity setObject: [[newIdentitiesAsDict objectForKey: [identity objectForKey:@"email"]] objectForKey:@"fullName"] forKey: @"fullName"];
                  if (newIdentitiesAsDict 
                      && [newIdentitiesAsDict objectForKey: [identity objectForKey:@"email"]] 
                      && [[newIdentitiesAsDict objectForKey: [identity objectForKey:@"email"]] objectForKey:@"signature"]) {
                    [identity setObject: [[newIdentitiesAsDict objectForKey: [identity objectForKey:@"email"]] objectForKey:@"signature"] forKey: @"signature"];
                  }
                  if (newIdentitiesAsDict 
                      && [newIdentitiesAsDict objectForKey: [identity objectForKey:@"email"]] 
                      && [[newIdentitiesAsDict objectForKey: [identity objectForKey:@"email"]] objectForKey:@"isDefault"]) {
                    [identity setObject: [NSNumber numberWithBool: YES] forKey: @"isDefault"];
                  } else {
                    [identity setObject: [NSNumber numberWithBool: NO] forKey: @"isDefault"];
                  }
              }
            }
            [newIdentitiesAsDict release];
          }

          [target setObject: previousIdentities forKey: @"SOGoMailIdentities"];
        } else {
            [target setObject: identities forKey: @"SOGoMailIdentities"];
        }
      }

      if ([[account objectForKey: @"forceDefaultIdentity"] boolValue])
        [target setObject: [NSNumber numberWithBool: YES] forKey: @"SOGoMailForceDefaultIdentity"];
      else if ([target objectForKey: @"SOGoMailForceDefaultIdentity"])
        [target removeObjectForKey: @"SOGoMailForceDefaultIdentity"];
      [self _extractMainReceiptsPreferences: [account objectForKey: @"receipts"]  inDictionary: target];
      [self _extractMainSecurityPreferences: [account objectForKey: @"security"]  inDictionary: target];
    }

    return error;
}

//
// Used internally
//
- (NSArray *) _extractAuxiliaryAccounts: (NSArray *) accounts
{
  int count, max;
  NSMutableArray *auxAccounts;
  NSMutableDictionary *account;
  NSString *sogoSecret, *password;

  max = [accounts count];
  auxAccounts = [NSMutableArray arrayWithCapacity: max];

  for (count = 1; count < max; count++)
    {
      account = [accounts objectAtIndex: count];
      if ([self _validateAccount: account])
        {
          [self _updateAuxiliaryAccount: account];

          //Encrypt password if needed
          sogoSecret = [[SOGoSystemDefaults sharedSystemDefaults] sogoSecretValue];
          //Note that password here will always be a string and not a dictionnary of gcm encryption as it comes from the saveAction Request
          password = [account objectForKey: @"password"];
          if(sogoSecret && [password length] > 0)
          {
            NSDictionary* newPassword;
            NSException* exception = nil;
            newPassword = [password encryptAES256GCM: sogoSecret exception:&exception];
            if(exception)
              [self errorWithFormat:@"Can't encrypt the password: %@", [exception reason]];
            else
              [account setObject: newPassword forKey: @"password"];
          }
          else
            [self warnWithFormat:@"Password for auxiliary accounts are not stored encrypted see SOGoSecretType"];

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
  NSString *comparisonAttribute, *password, *certificate, *sogoSecret, *decryptedPassword;

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
      {
        if([oldAccount objectForKey: @"password"])
        {
          if([[oldAccount objectForKey: @"password"] isKindOfClass: [NSDictionary class]])
          {
            //Old password is encrypted, decrypt it first as it will be encrypt again after
            NSDictionary *accountPassword;
            NSString *encryptedPassword, *iv, *tag;
            accountPassword = [oldAccount objectForKey: @"password"];
            encryptedPassword = [accountPassword objectForKey: @"cypher"];
            iv = [accountPassword objectForKey: @"iv"];
            tag = [accountPassword objectForKey: @"tag"];
            sogoSecret = [[SOGoSystemDefaults sharedSystemDefaults] sogoSecretValue];
            if(sogoSecret)
            {
              NSException* exception = nil;
              NS_DURING
                decryptedPassword = [encryptedPassword decryptAES256GCM: sogoSecret iv: iv tag: tag exception:&exception];
                if(exception)
                {
                  [self errorWithFormat:@"Can't decrypt the password for auxiliary account %@: %@",
                          [oldAccount objectForKey: @"name"], [exception reason]];
                  decryptedPassword = @"";
                }
                else if(!decryptedPassword)
                  [self errorWithFormat:@"No exception but decrypted password is empty for account %@",[oldAccount objectForKey: @"name"]];
                else
                  password = decryptedPassword;
              NS_HANDLER
                [self errorWithFormat:@"Can't decrypt the password for auxiliary account %@, probably wrong key",
                            [oldAccount objectForKey: @"name"]];
                decryptedPassword = @"";
              NS_ENDHANDLER
              [newAccount setObject: decryptedPassword forKey: @"password"];
            }
            else
            {
              [self errorWithFormat:@"Password currently stored for account %@ is encrypted but there is a no secret SOGoSecretValue to decrypt with",
                            [newAccount objectForKey: @"name"]];
              [newAccount setObject: @"" forKey: @"password"];
            }
          }
          else
          {
            //Old password is not encrypted, nothing to do
            [newAccount setObject: [oldAccount objectForKey: @"password"] forKey: @"password"];
          }
        }
        else {
          //No password for this account, weird choice but possible
          [newAccount setObject: @"" forKey: @"password"];
        }
      }

    
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

- (NSString *) mailCustomFromEnabled
{
  return (mailCustomFromEnabled ? @"true" : @"false");
}

- (NSString *) forwardEnabled
{
  return (forwardEnabled ? @"true" : @"false");
}

- (BOOL) doForwardsMatchTheConstraints: (NSArray *) forwardMails
{
  NSArray *allUserMails, *domainConstraints;
  NSMutableArray *allUserDomains;
  NSString *currentMail, *currentDomain, *userMail;
  SOGoDomainDefaults *dd;
  int constraint;
  
  dd = [[context activeUser] domainDefaults];
  constraint = [dd forwardConstraints];

  if(constraint > 0)
  {
    allUserMails = [[user allEmails] uniqueObjects];
    allUserDomains = [NSMutableArray array];
    for(userMail in allUserMails)
    {
      [allUserDomains push: [userMail mailDomain]];
    }
    for(currentMail in forwardMails)
    {
      currentDomain = [currentMail mailDomain];
      domainConstraints = [dd forwardConstraintsDomains];
      if (constraint == 1 && [allUserDomains indexOfObject: currentDomain] == NSNotFound)
        return NO;
      else if (constraint == 2 && [allUserDomains indexOfObject: currentDomain] != NSNotFound)
        return NO;
      else if (constraint == 2 && (!domainConstraints || [domainConstraints indexOfObject: currentDomain] == NSNotFound))
        return NO;
      else if (constraint == 3 && 
              [allUserDomains indexOfObject: currentDomain] == NSNotFound &&
                (!domainConstraints || [domainConstraints indexOfObject: currentDomain] == NSNotFound))
        return NO;
    }
  }
  return YES;
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
      NSArray *allKeys, *accounts, *identities, *forwardMails;
      NSDictionary *newLabels, *forwardPref;
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
      
      //We check if there are forward constraints
      forwardPref = [v objectForKey: @"Forward"];
      if(forwardPref && [forwardPref isKindOfClass: [NSDictionary class]]
                     && [forwardPref objectForKey: @"enabled"]
                     && [[forwardPref objectForKey: @"enabled"] boolValue])
      {
        BOOL doForward = NO;
        forwardMails = [forwardPref objectForKey: @"forwardAddress"];
        if (forwardMails && [forwardMails isKindOfClass: [NSArray class]] && [forwardMails count]>0)
          doForward = [self doForwardsMatchTheConstraints: [forwardPref objectForKey: @"forwardAddress"]];
        if(!doForward)
          [v removeObjectForKey: @"Forward"];
      }

      if ([self userHasMailAccess])
        {
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
          // Keep the original mail identities if none is provided
          //
          identities = [v objectForKey: @"SOGoMailIdentities"];
          if (!identities || ![identities isKindOfClass: [NSArray class]])
            {
              identities = [[user userDefaults] mailIdentities];
              if ([identities count])
                [v setObject: identities  forKey: @"SOGoMailIdentities"];
            }

          //
          // We sanitize our auxiliary mail accounts
          //
          accounts = [v objectForKey: @"AuxiliaryMailAccounts"];
          if (accounts && [accounts isKindOfClass: [NSArray class]])
            {
              if ([accounts count] > 0)
                {
                  // The first account is the main system account. The following mapping is required:
                  // - forceDefaultIdentity                => SOGoMailForceDefaultIdentity
                  // - receipts.receiptAction              => SOGoMailReceiptAllow
                  // - receipts.receiptNonRecipientAction  => SOGoMailReceiptNonRecipientAction
                  // - receipts.receiptOutsideDomaforwardAddressinAction => SOGoMailReceiptOutsideDomainAction
                  // - receipts.receiptAnyAction           => SOGoMailReceiptAnyAction
                  // - security.alwaysSign                 => SOGoMailCertificateAlwaysSign
                  // - security.alwaysEncrypt              => SOGoMailCertificateAlwaysEncrypt
                  if ([self _extractMainAccountSettings: [accounts objectAtIndex: 0]  inDictionary: v]) {
                    return [self responseWithStatus: 403
                              andString: @"Invalid operation"];
                  }

                  if ([self mailAuxiliaryUserAccountsEnabled])
                    accounts = [self _extractAuxiliaryAccounts: accounts];
                  else
                    accounts = [NSArray array];

                  [v setObject: accounts  forKey: @"AuxiliaryMailAccounts"];
                }
            }
        }


#if defined(MFA_CONFIG)
      // Check TOTP token
      NSString *verificationCode;

      if ([v objectForKey: @"SOGoTOTPEnabled"]
          && 1 == [[v objectForKey: @"SOGoTOTPEnabled"] intValue]
          && ![[user userDefaults] totpEnabled]) {
        
        verificationCode = [v objectForKey: @"totpVerificationCode"];

        if ([verificationCode length] == 6 && [verificationCode unsignedIntValue] > 0)
            {
              unsigned int code;
              const char *real_secret;
              char *secret;

              size_t secret_len;

              const auto time_step = OATH_TOTP_DEFAULT_TIME_STEP_SIZE;
              const auto digits = 6;

              real_secret = [[user totpKey] UTF8String];

              auto result = oath_init();
              auto t = time(NULL);
              auto left = time_step - (t % time_step);

              char otp[digits + 1];

              oath_base32_decode (real_secret,
                                  strlen(real_secret),
                                  &secret, &secret_len);

              result = oath_totp_generate2(secret,
                                           secret_len,
                                           t,
                                           time_step,
                                           OATH_TOTP_DEFAULT_START_TIME,
                                           digits,
                                           0,
                                           otp);

              sscanf(otp, "%u", &code);

              oath_done();
              free(secret);

              if (code != [verificationCode unsignedIntValue])
                {
                  results = (id <WOActionResults>) [self responseWithStatus: 485
                         andJSONRepresentation: [NSDictionary dictionaryWithObjectsAndKeys: @"Invalid TOTP verification code", @"message", nil]];
                  return results;
                }
            } else {
              results = (id <WOActionResults>) [self responseWithStatus: 485
                         andJSONRepresentation: [NSDictionary dictionaryWithObjectsAndKeys: @"Invalid TOTP verification code", @"message", nil]];
              return results;
            }
      }
      [v removeObjectForKey: @"totpVerificationCode"];
#endif

      [[[user userDefaults] source] setValues: v];

      if ([[user userDefaults] synchronize] && [self userHasMailAccess])
        {
          NSException *error;
          SOGoMailAccount *account;
          SOGoMailAccounts *folder;
          SOGoDomainDefaults *dd;

          dd = [[context activeUser] domainDefaults];

          // We check if the Sieve server is available *ONLY* if at least one of the option is enabled
          if (!([dd sieveScriptsEnabled] || [dd vacationEnabled] || [dd forwardEnabled] || [dd notificationEnabled]) 
                  || [self _isSieveServerAvailable])
            {
              BOOL forceActivation = ![[v objectForKey: @"hasActiveExternalSieveScripts"] boolValue];

              folder = [[[context activeUser] homeFolderInContext: context]  mailAccountsFolder: @"Mail"
                                                                                      inContext: context];
              account = [folder lookupName: @"0" inContext: context acquire: NO];

              if ((error = [account updateFiltersAndForceActivation: forceActivation]))
                {
                  results = (id <WOActionResults>) [self responseWithStatus: 500
                                                      andJSONRepresentation: [NSDictionary dictionaryWithObjectsAndKeys: [error reason], @"message", nil]];
                }
            }
          else
            results = (id <WOActionResults>) [self responseWithStatus: 503
                         andJSONRepresentation: [NSDictionary dictionaryWithObjectsAndKeys: @"Service temporarily unavailable", @"message", nil]];
        } else {
          results = (id <WOActionResults>) [self responseWithStatus: 500
                         andJSONRepresentation: [NSDictionary dictionaryWithObjectsAndKeys: @"Error during the validation", @"message", nil]];
        }
    }

  if ((v = [o objectForKey: @"settings"]))
    {
      // Remove ReloadWebCalendars if necessary
      NSMutableDictionary *calendarModule = [o objectForKey: @"Calendar"];
      if (calendarModule && [calendarModule objectForKey: @"ReloadWebCalendars"] == nil)
        {
          calendarModule = [[user userSettings] objectForKey: @"Calendar"];
          [calendarModule removeObjectForKey: @"ReloadWebCalendars"];
        }

      [[[user userSettings] source] setValues: v];
      [[user userSettings] synchronize];
    }

  if (!results)
    results = (id <WOActionResults>) [self responseWithStatus: 200];

  return results;
}

// Password recovery

- (NSArray *) passwordRecoveryList
{
  return [NSArray arrayWithObjects:
                    SOGoPasswordRecoveryDisabled,
                  SOGoPasswordRecoveryQuestion,
                  SOGoPasswordRecoverySecondaryEmail,
                  nil];
}

- (NSArray *) passwordRecoveryQuestionList
{
  return [NSArray arrayWithObjects:
                  SOGoPasswordRecoveryQuestion1,
                  SOGoPasswordRecoveryQuestion2,
                  SOGoPasswordRecoveryQuestion3,
                  nil];
}

- (NSString *) itemPasswordRecoveryText
{
  return [self commonLabelForKey: [NSString stringWithFormat: @"passwordRecovery_%@",
                                      item]];
}

- (BOOL) shouldDisplayPasswordRecovery
{
  return [[SOGoSystemDefaults sharedSystemDefaults] isPasswordRecoveryEnabled];
}

- (BOOL) shouldDisplayPasswordSection
{
  return [self shouldDisplayPasswordRecovery] || [self shouldDisplayPasswordChange];
}

- (BOOL) isEasUIEnabled
{
  return ![[SOGoSystemDefaults sharedSystemDefaults] isEasUIDisabled];
}

- (BOOL) showCreateIdentity
{
  SOGoDomainDefaults *dd;
  dd = [[context activeUser] domainDefaults];

  return ![dd createIdentitiesDisabled];
}

@end
