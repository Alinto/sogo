/* UIxPreferences.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>

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
      defaultsRead = YES;
    }
}

- (id) init
{
  NSDictionary *locale;
  
  if ((self = [super init]))
    {
      item = nil;
      hours = nil;
      ASSIGN (user, [context activeUser]);
      ASSIGN (userDefaults, [user userDefaults]);
      ASSIGN (today, [NSCalendarDate date]);
      locale = [context valueForKey: @"locale"];
      ASSIGN (daysOfWeek,
	      [locale objectForKey: NSWeekDayNameArray]);
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
  [hours release];
  [daysOfWeek release];
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
		locale: [context valueForKey: @"locale"]];
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
		locale: [context valueForKey: @"locale"]];
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
		locale: [context valueForKey: @"locale"]];
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
  return [userDefaults objectForKey: @"WeekStartDay"];
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
- (NSArray *) messageCheckList
{
  return [NSArray arrayWithObjects: @"manually", @"every_minute",
		  @"every_2_minutes", @"every_5_minutes", @"every_10_minutes",
		  @"every_20_minutes", @"every_30_minutes", @"once_per_hour",
		  nil];
}

- (NSString *) itemMessageCheckText
{
  return [self labelForKey:
		 [NSString stringWithFormat: @"messagecheck_%@", item]];
}

- (NSString *) userMessageCheck
{
  return [user messageCheck];
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
  return [user messageForwarding];
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
  return [[user defaultIdentity] objectForKey: @"signature"];
}

- (void) setSignature: (NSString *) newSignature
{
  [[user defaultIdentity] setObject: newSignature
			  forKey: @"signature"];
  [user saveMailAccounts];
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
  return shouldDisplayAdditionalPreferences;
}

- (BOOL) shouldDisplayPasswordChange
{
  return shouldDisplayPasswordChange;
}

@end
