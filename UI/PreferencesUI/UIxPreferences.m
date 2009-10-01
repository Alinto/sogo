/* UIxPreferences.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2009 Inverse inc.
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
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSPropertyList.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import "../../Main/SOGo.h"

#import "UIxPreferences.h"

#warning this class is not finished
/* remaining:
   default event length
   default snooze length
   refresh calendar every X minutes
   workweek = from -> to
   identities */

static BOOL defaultsRead = NO;
static BOOL shouldDisplayPasswordChange = NO;
static BOOL shouldDisplayAdditionalPreferences = NO;
static BOOL defaultShowSubscribedFoldersOnly = NO;

@implementation UIxPreferences

+ (void) initialize
{
  NSUserDefaults *ud;

  if (!defaultsRead)
    {
      ud = [NSUserDefaults standardUserDefaults];
      shouldDisplayPasswordChange
	= [ud boolForKey: @"SOGoUIxUserCanChangePassword"];
      shouldDisplayAdditionalPreferences
	= [ud boolForKey: @"SOGoUIxAdditionalPreferences"];
      defaultShowSubscribedFoldersOnly
	= [ud boolForKey: @"SOGoMailShowSubscribedFoldersOnly"];
      defaultsRead = YES;
    }
}

- (id) init
{
  //NSDictionary *locale;
  NSString *language;
  
  if ((self = [super init]))
    {
      language = [[context activeUser] language];

      item = nil;
      hours = nil;
      ASSIGN (user, [context activeUser]);
      ASSIGN (userDefaults, [user userDefaults]);
      ASSIGN (today, [NSCalendarDate date]);
      //locale = [context valueForKey: @"locale"];
      ASSIGN (locale, [[WOApplication application] localeForLanguageNamed: language]);
      ASSIGN (daysOfWeek,
	      [locale objectForKey: NSWeekDayNameArray]);
      hasChanged = NO;
      composeMessageTypeHasChanged = NO;
    }

  return self;
}

- (void) dealloc
{
  [today release];
  [item release];
  [user release];
  [userDefaults release];
  [hours release];
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

- (NSString *) inTheOffice
{
  NSString *inTheOffice;

  inTheOffice = [userDefaults objectForKey: @"InTheOffice"];

  return ((!inTheOffice || [inTheOffice boolValue])
	  ? @"YES" : @"NO");
}

- (void) setInTheOffice: (NSString *) newValue
{
  [userDefaults setObject: newValue forKey: @"InTheOffice"];
}

- (void) setAutoReplyText: (NSString *) newAutoReplyText
{
  [userDefaults setObject: newAutoReplyText forKey: @"AutoReplyText"];
}

- (NSString *) autoReplyText
{
  return [userDefaults objectForKey: @"AutoReplyText"];
}

- (NSArray *) timeZonesList
{
  return [[NSTimeZone knownTimeZoneNames]
	   sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)];
}

- (NSString *) userTimeZone
{
  return [[user timeZone] timeZoneName];
}

- (void) setUserTimeZone: (NSString *) newUserTimeZone
{
  [userDefaults setObject: newUserTimeZone forKey: @"TimeZone"];
}

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

- (NSString *) itemShortDateFormatText
{
  return [today descriptionWithCalendarFormat: item
		locale: locale];
  //locale: [context valueForKey: @"locale"]];
}

- (NSString *) userShortDateFormat
{
  return [userDefaults objectForKey: @"ShortDateFormat"];
}

- (void) setUserShortDateFormat: (NSString *) newFormat
{
  [userDefaults setObject: newFormat forKey: @"ShortDateFormat"];
}

- (NSArray *) longDateFormatsList
{
  NSMutableArray *longDateFormatsList = nil;
  NSString *key, *currentFormat;
  unsigned int nbr;
  BOOL done;

  longDateFormatsList = [NSMutableArray array];

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

  return longDateFormatsList;
}

- (NSString *) itemLongDateFormatText
{
  return [today descriptionWithCalendarFormat: item
		locale: locale];
  //locale: [context valueForKey: @"locale"]];
}

- (NSString *) userLongDateFormat
{
  return [userDefaults objectForKey: @"LongDateFormat"];
}

- (void) setUserLongDateFormat: (NSString *) newFormat
{
  [userDefaults setObject: newFormat forKey: @"LongDateFormat"];
}

- (NSArray *) timeFormatsList
{
  NSMutableArray *timeFormatsList = nil;
  NSString *key, *currentFormat;
  unsigned int nbr;
  BOOL done;

  timeFormatsList = [NSMutableArray array];

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
  return [today descriptionWithCalendarFormat: item
		locale: locale];
		//locale: [context valueForKey: @"locale"]];
}

- (NSString *) userTimeFormat
{
  return [userDefaults objectForKey: @"TimeFormat"];
}

- (void) setUserTimeFormat: (NSString *) newFormat
{
  [userDefaults setObject: newFormat forKey: @"TimeFormat"];
}

- (NSArray *) daysList
{
  NSMutableArray *daysList;
  unsigned int currentDay;

  daysList = [NSMutableArray new];
  [daysList autorelease];
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
  return [NSString stringWithFormat: @"%d", [user firstDayOfWeek]];;
}

- (void) setUserWeekStartDay: (NSString *) newDay
{
  [userDefaults setObject: newDay forKey: @"WeekStartDay"];
}

- (NSArray *) hoursList
{
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
  NSString *time;

  time = [userDefaults objectForKey: @"DayStartTime"];
  if (!time)
    time = @"08:00";

  return time;
}

- (void) setUserDayStartTime: (NSString *) newTime
{
  [userDefaults setObject: newTime forKey: @"DayStartTime"];
}

- (NSString *) userDayEndTime
{
  NSString *time;

  time = [userDefaults objectForKey: @"DayEndTime"];
  if (!time)
    time = @"18:00";

  return time;
}

- (void) setUserDayEndTime: (NSString *) newTime
{
  [userDefaults setObject: newTime forKey: @"DayEndTime"];
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
  return [userDefaults objectForKey: @"FirstWeek"];
}

- (void) setUserFirstWeek: (NSString *) newFirstWeek
{
  [userDefaults setObject: newFirstWeek forKey: @"FirstWeek"];
}

- (NSString *) reminderEnabled
{
  NSString *reminderEnabled;

  reminderEnabled = [userDefaults objectForKey: @"ReminderEnabled"];

  return ((!reminderEnabled || [reminderEnabled boolValue])
	  ? @"YES" : @"NO");
}

- (void) setReminderEnabled: (NSString *) newValue
{
  [userDefaults setObject: newValue forKey: @"ReminderEnabled"];
}

- (NSString *) remindWithASound
{
  NSString *remindWithASound;

  remindWithASound = [userDefaults objectForKey: @"RemindWithASound"];

  return ((!remindWithASound || [remindWithASound boolValue])
	  ? @"YES" : @"NO");
}

- (void) setRemindWithASound: (NSString *) newValue
{
  [userDefaults setObject: newValue forKey: @"RemindWithASound"];
}

- (NSArray *) reminderTimesList
{
  return [NSArray arrayWithObjects: @"0000", @"0005", @"0010", @"0015",
		  @"0030", @"0100", @"0200", @"0400", @"0800", @"1200",
		  @"2400", @"4800", nil];
}

- (NSString *) itemReminderTimeText
{
  return [self labelForKey:
		 [NSString stringWithFormat: @"reminderTime_%@", item]];
}

- (NSString *) userReminderTime
{
  return [userDefaults objectForKey: @"ReminderTime"];
}

- (void) setReminderTime: (NSString *) newTime
{
  [userDefaults setObject: newTime forKey: @"ReminderTime"];
}

/* Mailer */
- (void) setShowSubscribedFoldersOnly: (BOOL) showSubscribedFoldersOnly
{
  if (showSubscribedFoldersOnly)
    [userDefaults setBool: YES forKey: @"showSubscribedFoldersOnly"];
  else
    [userDefaults setBool: NO forKey: @"showSubscribedFoldersOnly"];
}

- (BOOL) showSubscribedFoldersOnly
{
  NSString *showSubscribedFoldersOnly;
  BOOL r;

  showSubscribedFoldersOnly = [userDefaults stringForKey: @"showSubscribedFoldersOnly"];
  if (showSubscribedFoldersOnly)
    r = [showSubscribedFoldersOnly boolValue];
  else
    r = defaultShowSubscribedFoldersOnly;

  return r;
}

- (NSArray *) messageCheckList
{
  NSArray *defaultList;
  NSMutableArray *rc;
  NSString *tmp;
  int i, count;

  defaultList = [NSMutableArray arrayWithArray: 
                 [[NSUserDefaults standardUserDefaults]
                  arrayForKey: @"SOGoMailPollingIntervals"]];
  if ([defaultList count] > 0)
    {
      rc = [NSMutableArray arrayWithObjects: @"manually", nil];
      count = [defaultList  count];
      for (i = 0; i < count; i++)
        {
          int value = [[defaultList objectAtIndex: i] intValue];
          tmp = nil;
          if (value == 1)
            tmp = @"every_minute";
          else if (value == 60)
            tmp = @"once_per_hour";
          else if (value == 2 || value == 5 || value == 10 
                   || value == 20 || value == 30)
            tmp = [NSString stringWithFormat: @"every_%d_minutes", value];
          if (tmp)
            [rc addObject: tmp];
        }
    }
  else
    rc = [NSArray arrayWithObjects: @"manually", @"every_minute",
		  @"every_2_minutes", @"every_5_minutes", @"every_10_minutes",
		  @"every_20_minutes", @"every_30_minutes", @"once_per_hour",
		  nil];

  return rc;
}

- (NSString *) itemMessageCheckText
{
  return [self labelForKey:
		 [NSString stringWithFormat: @"messagecheck_%@", item]];
}

- (NSString *) userMessageCheck
{
  return [userDefaults stringForKey: @"MessageCheck"];
}

- (void) setUserMessageCheck: (NSString *) newMessageCheck
{
  [userDefaults setObject: newMessageCheck forKey: @"MessageCheck"];
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
  return [userDefaults stringForKey: @"MessageForwarding"];
}

- (void) setUserMessageForwarding: (NSString *) newMessageForwarding
{
  [userDefaults setObject: newMessageForwarding forKey: @"MessageForwarding"];
}

// 	<label><var:string label:value="Default identity:"/>
// 	  <var:popup list="identitiesList" item="item"
// 	    string="itemIdentityText" selection="defaultIdentity"/></label>
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
}

- (NSString *) signature
{
  [user migrateSignature];
  return [userDefaults stringForKey: @"MailSignature"];
}

- (void) setSignature: (NSString *) newSignature
{
  [userDefaults setObject: newSignature forKey: @"MailSignature"];
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
  return [userDefaults stringForKey: @"ReplyPlacement"];
}

- (void) setUserReplyPlacement: (NSString *) newReplyPlacement
{
  [userDefaults setObject: newReplyPlacement forKey: @"ReplyPlacement"];
}

- (NSArray *) signaturePlacementList
{
  return [NSArray arrayWithObjects: @"above", @"below", nil];
}

- (NSString *) itemSignaturePlacementText
{
  return [self labelForKey:
		 [NSString stringWithFormat: @"signatureplacement_%@", item]];
}

- (NSString *) userSignaturePlacement
{
  return [userDefaults stringForKey: @"SignaturePlacement"];
}

- (NSArray *) composeMessagesType
{
  return [NSArray arrayWithObjects: @"text", @"html", nil];
}

- (NSString *) itemComposeMessagesText
{
  return [self labelForKey: [NSString stringWithFormat: @"composemessagestype_%@", item]];
}

- (NSString *) userComposeMessagesType
{
  NSString *userComposeMessagesType;

  userComposeMessagesType
    = [userDefaults stringForKey: @"ComposeMessagesType"];
  if (!userComposeMessagesType)
    userComposeMessagesType = @"text";

  return userComposeMessagesType;
}

- (void) setUserComposeMessagesType: (NSString *) newType
{
  if (![[self userComposeMessagesType] isEqualToString: newType])
    {
      composeMessageTypeHasChanged = YES;
      [userDefaults setObject: newType forKey: @"ComposeMessagesType"];
    }
}


- (void) setUserSignaturePlacement: (NSString *) newSignaturePlacement
{
  [userDefaults setObject: newSignaturePlacement forKey: @"SignaturePlacement"];
}

- (NSArray *) availableModules
{
  NSMutableArray *rc, *modules;
  int i, count;

  modules = [NSMutableArray arrayWithObjects: @"Calendar", @"Mail", nil];
  rc = [NSMutableArray arrayWithObjects: @"Last", @"Contacts", nil];
  count = [modules count];

  for (i = 0; i < count; i++)
    if ([user canAccessModule: [modules objectAtIndex: i]])
      [rc addObject: [modules objectAtIndex: i]];

  return rc;
}

- (NSString *) itemModuleText
{
  return [self labelForKey: item];
}

- (NSString *) userDefaultModule
{
  NSUserDefaults *ud;
  ud = [user userDefaults];

  return [ud stringForKey: @"SOGoUIxDefaultModule"];
}

- (void) setUserDefaultModule: (NSString *) newValue
{
  NSUserDefaults *ud;
  ud = [user userDefaults];
  [ud setObject: newValue forKey: @"SOGoUIxDefaultModule"];
}

- (id <WOActionResults>) defaultAction
{
  id <WOActionResults> results;
  WORequest *request;
  NSString *method;

  request = [context request];
  if ([[request method] isEqualToString: @"POST"])
    {
      [userDefaults synchronize];
      if (composeMessageTypeHasChanged)
	// Due to a limitation of CKEDITOR, we reload the page when the user
	// changes the composition mode to avoid Javascript errors.
	results = self;
      else
	{
	  if (hasChanged)
	    method = @"window.location.reload()";
	  else
	    method = nil;
	  results = [self jsCloseWithRefreshMethod: method];
	}
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
  return shouldDisplayAdditionalPreferences;
}

- (BOOL) shouldDisplayPasswordChange
{
  return shouldDisplayPasswordChange;
}

- (NSString *) nameLabel
{
  return [self labelForKey: @"Name"];
}

- (NSString *) colorLabel
{
  return [self labelForKey: @"Color"];
}

- (NSArray *) categories
{
  NSDictionary *element;
  NSArray *k, *v, *names;
  NSMutableArray *rc, *colors;
  int i, count;

  names = [userDefaults arrayForKey: @"CalendarCategories"];
  if (names)
    colors = [NSMutableArray arrayWithArray: 
                  [userDefaults arrayForKey: @"CalendarCategoriesColors"]];
  else
    {
      names = [[self labelForKey: @"category_labels"]
                componentsSeparatedByString: @","];
      
      count = [names count];
      colors = [NSMutableArray arrayWithCapacity: count];
      for (i = 0; i < count; i++)
        [colors addObject: @"#F0F0F0"];
    }

  rc = [NSMutableArray array];
  k = [NSArray arrayWithObjects: @"name", @"color", nil];

  count = [names count];
  for (i = 0; i < count; i++)
    {
      v = [NSArray arrayWithObjects: [names objectAtIndex: i],
                                     [colors objectAtIndex: i], nil];

      element = [NSDictionary dictionaryWithObjects: v
                                         forKeys: k];
      [rc addObject: element];
    }

  return rc;
}


- (NSString *) categoriesValue
{
  return @"";
}

- (void) setCategoriesValue: (NSString *) value
{
  NSData *data;
  NSString *error;
  NSPropertyListFormat format;
  NSArray *plist;

  data = [value dataUsingEncoding: NSUTF8StringEncoding];
  plist = [NSPropertyListSerialization propertyListFromData: data
                                           mutabilityOption: NSPropertyListImmutable
                                                     format: &format
                                           errorDescription: &error];
  
  if(!plist)
    {
      NSLog(error);
      [error release];
    }
  else
    {
      [userDefaults setObject: [plist objectAtIndex: 0] 
                       forKey: @"CalendarCategories"];
      [userDefaults setObject: [plist objectAtIndex: 1] 
                       forKey: @"CalendarCategoriesColors"];
      NSLog ([plist description]);
    }
  
}

- (NSArray *) languages
{
  return [NSArray arrayWithObjects: @"Czech", @"Dutch", @"English", @"French", 
          @"German", @"Hungarian", @"Italian", @"BrazilianPortuguese", 
          @"Russian", @"Spanish", @"Welsh", nil];
}

- (NSString *) language
{
  return [userDefaults objectForKey: @"Language"];
}

- (void) setLanguage: (NSString *) newLanguage
{
  if ([[self languages] containsObject: newLanguage])
    [userDefaults setObject: newLanguage forKey: @"Language"];
}

- (NSString *) languageText
{
  return [self labelForKey: item];
}

@end
