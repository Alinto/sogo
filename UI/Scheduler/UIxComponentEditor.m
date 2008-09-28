/* UIxComponentEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSURL.h>

#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRepeatableEntityObject.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/NSString+NGCards.h>
#import <NGCards/NSCalendarDate+NGCards.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>

#import <SoObjects/Appointments/iCalEntityObject+SOGo.h>
#import <SoObjects/Appointments/iCalPerson+SOGo.h>
#import <SoObjects/Appointments/SOGoAppointmentFolder.h>
#import <SoObjects/Appointments/SOGoAppointmentFolders.h>
#import <SoObjects/Appointments/SOGoAppointmentObject.h>
#import <SoObjects/Appointments/SOGoTaskObject.h>
#import <SoObjects/SOGo/iCalEntityObject+Utilities.h>
#import <SoObjects/SOGo/LDAPUserManager.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoPermissions.h>

#import "UIxComponentEditor.h"

#define iREPEAT(X) \
- (NSString *) repeat##X; \
- (void) setRepeat##X: (NSString *) theValue

#define iRANGE(X) \
- (NSString *) range##X; \
- (void) setRange##X: (NSString *) theValue

@interface UIxComponentEditor (Private)

iREPEAT(1);
iREPEAT(2);
iREPEAT(3);
iREPEAT(4);
iREPEAT(5);
iREPEAT(6);
iREPEAT(7);
iRANGE(1);
iRANGE(2);

@end

#define REPEAT(X) \
- (NSString *) repeat##X { return repeat##X; } \
- (void) setRepeat##X: (NSString *) theValue { NSLog(@"setRepeat%d %@", X, theValue); ASSIGN(repeat##X, theValue); } \

#define RANGE(X) \
- (NSString *) range##X { return range##X; } \
- (void) setRange##X: (NSString *) theValue { ASSIGN(range##X, theValue);  }

@implementation UIxComponentEditor

- (id) init
{
  if ((self = [super init]))
    {
      component = nil;
      [self setPrivacy: @"PUBLIC"];
      [self setIsCycleEndNever];
      componentOwner = @"";
      organizer = nil;
      organizerIdentity = nil;
      attendeesNames = nil;
      attendeesUIDs = nil;
      attendeesEmails = nil;
      attendeesStates = nil;
      calendarList = nil;
      repeat = nil;
      reminder = nil;
      repeatType = nil;
      repeat1 = nil;
      repeat2 = nil;
      repeat3 = nil;
      repeat4 = nil;
      repeat5 = nil;
      repeat6 = nil;
      repeat7 = nil;
      range1 = nil;
      range2 = nil;
    }

  return self;
}

- (void) dealloc
{
  [item release];
  [cycleUntilDate release];
  [title release];
  [location release];
  [organizer release];
  [organizerIdentity release];
  [comment release];
  [priority release];
  [categories release];
  [cycle release];
  [cycleEnd release];
  [url release];
  [attendeesNames release];
  [attendeesUIDs release];
  [attendeesEmails release];
  [attendeesStates release];
  [calendarList release];

  [repeat release];
  [reminder release];

  [repeatType release];
  [repeat1 release];
  [repeat2 release];
  [repeat3 release];
  [repeat4 release];
  [repeat5 release];
  [repeat6 release];
  [repeat7 release];
  [range1 release];
  [range2 release];
  
  [component release];

  [super dealloc];
}

- (void) _loadAttendees
{
  NSEnumerator *attendees;
  iCalPerson *currentAttendee;
  NSMutableString *names, *uids, *emails, *states;
  NSString *uid;
  LDAPUserManager *um;

  names = [NSMutableString new];
  uids = [NSMutableString new];
  emails = [NSMutableString new];
  states = [NSMutableString new];
  um = [LDAPUserManager sharedUserManager];

  attendees = [[component attendees] objectEnumerator];
  while ((currentAttendee = [attendees nextObject]))
    {
      [names appendFormat: @"%@,", [currentAttendee cn]];
      [emails appendFormat: @"%@,", [currentAttendee rfc822Email]];
      uid = [um getUIDForEmail: [currentAttendee rfc822Email]];
      if (uid != nil)
	[uids appendFormat: @"%@,", uid];
      else
	[uids appendString: @","];
      [states appendFormat: @"%@,",
	      [[currentAttendee partStat] lowercaseString]];
    }

  if ([names length] > 0)
    {
      ASSIGN (attendeesNames, [names substringToIndex: [names length] - 1]);
      ASSIGN (attendeesUIDs, [uids substringToIndex: [uids length] - 1]);
      ASSIGN (attendeesEmails,
	      [emails substringToIndex: [emails length] - 1]);
      ASSIGN (attendeesStates, [states substringToIndex: [states length] - 1]);
    }

  [names release];
  [emails release];
}

- (void) _loadCategories
{
  NSString *compCategories, *simpleCategory;

  compCategories = [component categories];
  if ([compCategories length] > 0)
    {
      simpleCategory = [[compCategories componentsSeparatedByString: @","]
			 objectAtIndex: 0];
      ASSIGN (category, [simpleCategory uppercaseString]);
    }
}

- (NSString *) _dayMaskToInteger: (unsigned int) theMask
{
  iCalWeekDay maskDays[] = {iCalWeekDaySunday, iCalWeekDayMonday,
			    iCalWeekDayTuesday, iCalWeekDayWednesday,
			    iCalWeekDayThursday, iCalWeekDayFriday,
			    iCalWeekDaySaturday};
  unsigned int i;
  NSMutableString *s;

  s = [NSMutableString string];

  for (i = 0; i < 7; i++)
    if ((theMask & maskDays[i]))
      [s appendFormat: @"%d,", i];
  [s deleteSuffix: @","];

  return s;
}

- (void) _loadRRules
{
  // We initialize our repeat ivars
  if ([component hasRecurrenceRules])
    {
      iCalRecurrenceRule *rule;

      [self setRepeat: @"CUSTOM"];
      
      rule = [[component recurrenceRules] lastObject];

      if ([rule frequency] == iCalRecurrenceFrequenceDaily)
	{
	  repeatType = @"0";
	  
	  if ([rule byDayMask] == (iCalWeekDayMonday
				   | iCalWeekDayTuesday
				   | iCalWeekDayWednesday
				   | iCalWeekDayThursday
				   | iCalWeekDayFriday))
	    {
	      if ([rule isInfinite])
		repeat = @"EVERY WEEKDAY";
	      repeat1 = @"1";
	    }
	  else
	    {
	      repeat1 = @"0";
	      
	      if ([rule repeatInterval] == 1 && [rule isInfinite])
		repeat = @"DAILY";

	      [self setRepeat2: [NSString stringWithFormat: @"%d", [rule repeatInterval]]];
	    }
	}
      else if ([rule frequency] == iCalRecurrenceFrequenceWeekly)
	{
	  repeatType = @"1";

	  if (![rule byDayMask])
	    {
	      if ([rule repeatInterval] == 1)
		repeat = @"WEEKLY";
	      else if ([rule repeatInterval] == 2)
		repeat = @"BI-WEEKLY";
	    }
	  else
	    {
	      [self setRepeat1: [NSString stringWithFormat: @"%d", [rule repeatInterval]]];
	      [self setRepeat2: [self _dayMaskToInteger: [rule byDayMask]]];
	    }
	}
      else if ([rule frequency] == iCalRecurrenceFrequenceMonthly)
	{
	  repeatType = @"2";

	  if ([rule byDayMask])
	    {
	      // TODO
	      [self setRepeat2: @"0"];
	    }
	  else if ([[rule byMonthDay] count])
	    {
	      [self setRepeat2: @"1"];
	      [self setRepeat5: [[rule byMonthDay] componentsJoinedByString: @","]];
	    }
	  else if ([rule repeatInterval] == 1)
	    repeat = @"MONTHLY";

	  [self setRepeat1: [NSString stringWithFormat: @"%d", [rule repeatInterval]]];
	}
      else
	{
	  repeatType = @"3";
	 
	  if ([rule namedValue: @"bymonth"])
	    {
	      if (![rule byDayMask])
		{
		  [self setRepeat2: @"0"];
		  [self setRepeat3: [rule namedValue: @"bymonthday"]];
		  [self setRepeat4: [NSString stringWithFormat: @"%d", [[rule namedValue: @"bymonth"] intValue]-1]];
		}
	      else
		{
		  // TODO
		  [self setRepeat2: @"1"];
		}
	    }
	  else if ([rule repeatInterval] == 1)
	    repeat = @"YEARLY";

	  [self setRepeat1: [NSString stringWithFormat: @"%d", [rule repeatInterval]]];
	}

      // We decode the proper end date, recurrences count, etc.
      if ([rule repeatCount])
	{
	  [self setRange1: @"1"];
	  [self setRange2: [rule namedValue: @"count"]];
	}
      else if ([rule untilDate])
	{
	  [self setRange1: @"2"];
	  [self setRange2: [[rule untilDate] descriptionWithCalendarFormat: @"%Y-%m-%d"]];
	}
      else
	[self setRange1: @"0"];
    }
  else
    DESTROY(repeat);
}

/* warning: we use this method which will be triggered by the template system
   when the page is instantiated, but we should find another and cleaner way of
   doing this... for example, when the clientObject is set */
- (void) setComponent: (iCalRepeatableEntityObject *) newComponent
{
//   iCalRecurrenceRule *rrule;
  SOGoObject *co;

  if (!component)
    {
      ASSIGN (component, newComponent);

      co = [self clientObject];
      componentOwner = [co ownerInContext: nil];
      if (component)
	{
	  ASSIGN (title, [component summary]);
	  ASSIGN (location, [component location]);
	  ASSIGN (comment, [component comment]);
	  ASSIGN (url, [[component url] absoluteString]);
	  ASSIGN (privacy, [component accessClass]);
	  ASSIGN (priority, [component priority]);
	  ASSIGN (status, [component status]);
	  ASSIGN (categories,
		  [[component categories] componentsWithSafeSeparator: ',']);
	  ASSIGN (organizer, [component organizer]);
	  [self _loadCategories];
	  [self _loadAttendees];
	  [self _loadRRules];

	  componentCalendar = [co container];
	  if ([componentCalendar isKindOfClass: [SOGoCalendarComponent class]])
	    componentCalendar = [componentCalendar container];
	}
    }
//   /* cycles */
//   if ([component isRecurrent])
//     {
//       rrule = [[component recurrenceRules] objectAtIndex: 0];
//       [self adjustCycleControlsForRRule: rrule];
//     }
}

- (void) setSaveURL: (NSString *) newSaveURL
{
  saveURL = newSaveURL;
}

- (NSString *) saveURL
{
  return saveURL;
}

/* accessors */

- (BOOL) isChildOccurence
{
  return [[self clientObject] isKindOfClass: [SOGoComponentOccurence class]];
}

- (void) setItem: (id) _item
{
  ASSIGN (item, _item);
}

- (id) item
{
  return item;
}

- (NSString *) itemPriorityText
{
  return [self labelForKey: [NSString stringWithFormat: @"prio_%@", item]];
}

- (NSString *) itemPrivacyText
{
  NSString *tag;

  tag = [[component tag] lowercaseString];

  return [self labelForKey: [NSString stringWithFormat: @"%@_%@", item, tag]];
}

- (NSString *) itemStatusText
{
  return [self labelForKey: [NSString stringWithFormat: @"status_%@", item]];
}

- (void) setTitle: (NSString *) _value
{
  ASSIGN (title, _value);
}

- (NSString *) title
{
  return title;
}

- (void) setUrl: (NSString *) _url
{
  ASSIGN (url, _url);
}

- (NSString *) url
{
  return url;
}

- (NSString *) organizerName
{
  return [organizer mailAddress];
}

- (BOOL) canBeOrganizer
{
  NSString *owner;
  SOGoObject <SOGoComponentOccurence> *co;
  SOGoUser *currentUser;
  BOOL hasOrganizer;
  SoSecurityManager *sm;

  co = [self clientObject];
  owner = [co ownerInContext: context];
  currentUser = [context activeUser];

  hasOrganizer = ([[organizer value: 0] length] > 0);

  sm = [SoSecurityManager sharedSecurityManager];
  
  return ([co isNew]
	  || (([owner isEqualToString: [currentUser login]]
	       || ![sm validatePermission: SOGoCalendarPerm_ModifyComponent
		       onObject: co
		       inContext: context])
	      && (!hasOrganizer || [component userIsOrganizer: currentUser])));
}

- (BOOL) hasOrganizer
{
  return ([[organizer value: 0] length] && ![self canBeOrganizer]);
}

- (void) setOrganizerIdentity: (NSDictionary *) newOrganizerIdentity
{
  ASSIGN (organizerIdentity, newOrganizerIdentity);
}

- (NSDictionary *) organizerIdentity
{
  NSArray *allIdentities;
  NSEnumerator *identities;
  NSDictionary *currentIdentity;
  NSString *orgEmail;

  orgEmail = [organizer rfc822Email];
  if (!organizerIdentity)
    {
      if ([orgEmail length])
	{
	  allIdentities = [[context activeUser] allIdentities];
	  identities = [allIdentities objectEnumerator];
	  while (!organizerIdentity
		 && ((currentIdentity = [identities nextObject])))
	    if ([[currentIdentity objectForKey: @"email"]
		  caseInsensitiveCompare: orgEmail]
		== NSOrderedSame)
	      ASSIGN (organizerIdentity, currentIdentity);
	}
    }

  return organizerIdentity;
}

- (NSArray *) organizerList
{
  return [[context activeUser] allIdentities];
}

- (NSString *) itemOrganizerText
{
  return [item keysWithFormat: @"%{fullName} <%{email}>"];
}

- (void) setAttendeesNames: (NSString *) newAttendeesNames
{
  ASSIGN (attendeesNames, newAttendeesNames);
}

- (NSString *) attendeesNames
{
  return attendeesNames;
}

- (void) setAttendeesUIDs: (NSString *) newAttendeesUIDs
{
  ASSIGN (attendeesUIDs, newAttendeesUIDs);
}

- (NSString *) attendeesUIDs
{
  return attendeesUIDs;
}

- (void) setAttendeesEmails: (NSString *) newAttendeesEmails
{
  ASSIGN (attendeesEmails, newAttendeesEmails);
}

- (NSString *) attendeesEmails
{
  return attendeesEmails;
}

- (void) setAttendeesStates: (NSString *) newAttendeesStates
{
  ASSIGN (attendeesStates, newAttendeesStates);
}

- (NSString *) attendeesStates
{
  return attendeesStates;
}

- (void) setLocation: (NSString *) _value
{
  ASSIGN (location, _value);
}

- (NSString *) location
{
  return location;
}

- (void) setComment: (NSString *) _value
{
  ASSIGN (comment, _value);
}

- (NSString *) comment
{
  return comment;
}

- (NSArray *) categoryList
{
  static NSArray *categoryItems = nil;

  if (!categoryItems)
    {
      categoryItems = [NSArray arrayWithObjects: @"ANNIVERSARY",
                               @"BIRTHDAY",
                               @"BUSINESS",
                               @"CALLS", 
                               @"CLIENTS",
                               @"COMPETITION",
                               @"CUSTOMER",
                               @"FAVORITES",
                               @"FOLLOW UP",
                               @"GIFTS",
                               @"HOLIDAYS",
                               @"IDEAS",
                               @"ISSUES",
                               @"MISCELLANEOUS",
                               @"PERSONAL",
                               @"PROJECTS",
                               @"PUBLIC HOLIDAY",
                               @"STATUS",
                               @"SUPPLIERS",
                               @"TRAVEL",
                               @"VACATION",
                              nil];
      [categoryItems retain];
    }

  return categoryItems;
}

- (void) setCategories: (NSArray *) _categories
{
  ASSIGN (categories, _categories);
}

- (NSArray *) categories
{
  return categories;
}

- (void) setCategory: (NSArray *) newCategory
{
  ASSIGN (category, newCategory);
}

- (NSString *) category
{
  return category;
}

- (NSString *) itemCategoryText
{
  return [self labelForKey:
		 [NSString stringWithFormat: @"category_%@", item]];
}

- (NSArray *) repeatList
{
  static NSArray *repeatItems = nil;

  if (!repeatItems)
    {
      repeatItems = [NSArray arrayWithObjects: @"DAILY",
                             @"WEEKLY",
                             @"BI-WEEKLY",
                             @"EVERY WEEKDAY",
                             @"MONTHLY",
                             @"YEARLY",
                             @"-",
                             @"CUSTOM",
                             nil];
      [repeatItems retain];
    }

  return repeatItems;
}

- (NSString *) itemRepeatText
{
  NSString *text;

  if ([item isEqualToString: @"-"])
    text = item;
  else
    text = [self labelForKey: [NSString stringWithFormat: @"repeat_%@", item]];

  return text;
}

- (NSArray *) reminderList
{
  static NSArray *reminderItems = nil;

  if (!reminderItems)
    {
      reminderItems = [NSArray arrayWithObjects: @"5_MINUTES_BEFORE",
                               @"10_MINUTES_BEFORE",
                               @"15_MINUTES_BEFORE",
                               @"30_MINUTES_BEFORE",
                               @"45_MINUTES_BEFORE",
                               @"-",
                               @"1_HOUR_BEFORE",
                               @"2_HOURS_BEFORE",
                               @"5_HOURS_BEFORE",
                               @"15_HOURS_BEFORE",
                               @"-",
                               @"1_DAY_BEFORE",
                               @"2_DAYS_BEFORE",
                               @"1_WEEK_BEFORE",
                               @"-",
                               @"CUSTOM",
                               nil];
      [reminderItems retain];
    }

  return reminderItems;
}

// - (void) setReminder: (NSString *) reminder
// {
//   ASSIGN(reminder, _reminder);
// }

// - (NSString *) reminder
// {
//   return reminder;
// }

- (NSString *) reminder
{
  return @"";
}

- (void) setReminder: (NSString *) newReminder
{
}

- (NSString *) itemReminderText
{
  NSString *text;

  if ([item isEqualToString: @"-"])
    text = item;
  else
    text = [self labelForKey: [NSString stringWithFormat: @"reminder_%@", item]];

  return text;
}

- (NSString *) repeat
{
  return repeat;
}

- (void) setRepeat: (NSString *) newRepeat
{
  ASSIGN(repeat, newRepeat);
}

- (NSString *) _permissionForEditing
{
  NSString *perm;

  if ([[self clientObject] isNew])
    perm = SoPerm_AddDocumentsImagesAndFiles;
  else
    {
      if ([privacy isEqualToString: @"PRIVATE"])
	perm = SOGoCalendarPerm_ModifyPrivateRecords;
      else if ([privacy isEqualToString: @"CONFIDENTIAL"])
	perm = SOGoCalendarPerm_ModifyConfidentialRecords;
      else
	perm = SOGoCalendarPerm_ModifyPublicRecords;
    }

  return perm;
}

- (NSArray *) calendarList
{
  SOGoAppointmentFolder *calendar, *currentCalendar;
  SOGoAppointmentFolders *calendarParent;
  NSEnumerator *allCalendars;
  SoSecurityManager *sm;
  NSString *perm;

  if (!calendarList)
    {
      calendarList = [NSMutableArray new];

      perm = [self _permissionForEditing];
      calendarParent
	= [[context activeUser] calendarsFolderInContext: context];
      sm = [SoSecurityManager sharedSecurityManager];
      calendar = [self componentCalendar];
      allCalendars = [[calendarParent subFolders] objectEnumerator];
      while ((currentCalendar = [allCalendars nextObject]))
	if ([calendar isEqual: currentCalendar] ||
	    ![sm validatePermission: perm
		 onObject: currentCalendar
		 inContext: context])
	  [calendarList addObject: currentCalendar];
    }

  return calendarList;
}

- (NSString *) calendarDisplayName
{
  NSString *fDisplayName;
  SOGoAppointmentFolder *folder;
  SOGoAppointmentFolders *parentFolder;

  fDisplayName = [item displayName];
  folder = [self componentCalendar];
  parentFolder = [folder container];
  if ([fDisplayName isEqualToString: [parentFolder defaultFolderName]])
    fDisplayName = [self labelForKey: fDisplayName];

  return fDisplayName;
}

- (NSString *) calendarsFoldersList
{
  NSArray *calendars;

  calendars = [[self calendarList] valueForKey: @"nameInContainer"];

  return [calendars componentsJoinedByString: @","];
}


- (SOGoAppointmentFolder *) componentCalendar
{
  return componentCalendar;
}

- (void) setComponentCalendar: (SOGoAppointmentFolder *) _componentCalendar
{
  ASSIGN (componentCalendar, _componentCalendar);
}

/* priorities */

- (NSArray *) priorities
{
  /* 0 == undefined
     9 == low
     5 == medium
     1 == high
  */
  static NSArray *priorities = nil;

  if (!priorities)
    {
      priorities = [NSArray arrayWithObjects: @"9", @"5", @"1", nil];
      [priorities retain];
    }

  return priorities;
}

- (void) setPriority: (NSString *) _priority
{
  ASSIGN (priority, _priority);
}

- (NSString *) priority
{
  return priority;
}

- (NSArray *) privacyClasses
{
  static NSArray *priorities = nil;

  if (!priorities)
    {
      priorities = [NSArray arrayWithObjects: @"PUBLIC",
                            @"CONFIDENTIAL", @"PRIVATE", nil];
      [priorities retain];
    }

  return priorities;
}

- (void) setPrivacy: (NSString *) _privacy
{
  ASSIGN (privacy, _privacy);
}

- (NSString *) privacy
{
  return privacy;
}

- (NSArray *) statusTypes
{
  static NSArray *priorities = nil;

  if (!priorities)
    {
      priorities = [NSArray arrayWithObjects: @"", @"TENTATIVE", @"CONFIRMED", @"CANCELLED", nil];
      [priorities retain];
    }

  return priorities;
}

- (void) setStatus: (NSString *) _status
{
  ASSIGN (status, _status);
}

- (NSString *) status
{
  return status;
}

- (void) setRepeatType: (NSString *) theValue
{
  ASSIGN (repeatType, theValue);
}

- (NSString *) repeatType
{
  return repeatType;
}

REPEAT(1);
REPEAT(2);
REPEAT(3);
REPEAT(4);
REPEAT(5);
REPEAT(6);
REPEAT(7);
RANGE(1);
RANGE(2);

////////////////////////////////// JUNK ////////////////////////////////////////
////////////////////////////////// JUNK ////////////////////////////////////////
////////////////////////////////// JUNK ////////////////////////////////////////
- (NSArray *) cycles
{
  NSBundle *bundle;
  NSString *path;
  static NSArray *cycles = nil;
  
  if (!cycles)
    {
      bundle = [NSBundle bundleForClass:[self class]];
      path   = [bundle pathForResource: @"cycles" ofType: @"plist"];
      NSAssert(path != nil, @"Cannot find cycles.plist!");
      cycles = [[NSArray arrayWithContentsOfFile:path] retain];
      NSAssert(cycles != nil, @"Cannot instantiate cycles from cycles.plist!");
    }

  return cycles;
}

- (void) setCycle: (NSDictionary *) _cycle
{
  ASSIGN (cycle, _cycle);
}

- (NSDictionary *) cycle
{
  return cycle;
}

- (BOOL) hasCycle
{
  return ([cycle objectForKey: @"rule"] != nil);
}

- (NSString *) cycleLabel
{
  NSString *key;
  
  key = [(NSDictionary *)item objectForKey: @"label"];

  return [self labelForKey:key];
}

- (void) setCycleUntilDate: (NSCalendarDate *) _cycleUntilDate
{
//   NSCalendarDate *until;

//   /* copy hour/minute/second from startDate */
//   until = [_cycleUntilDate hour: [startDate hourOfDay]
//                            minute: [startDate minuteOfHour]
//                            second: [startDate secondOfMinute]];
//   [until setTimeZone: [startDate timeZone]];
//   ASSIGN (cycleUntilDate, until);
}

- (NSCalendarDate *) cycleUntilDate
{
  return cycleUntilDate;
}

- (iCalRecurrenceRule *) rrule
{
  NSString *ruleRep;
  iCalRecurrenceRule *rule;

  if (![self hasCycle])
    return nil;
  ruleRep = [cycle objectForKey: @"rule"];
  rule = [iCalRecurrenceRule recurrenceRuleWithICalRepresentation:ruleRep];

  if (cycleUntilDate && [self isCycleEndUntil])
    [rule setUntilDate:cycleUntilDate];

  return rule;
}

- (void) adjustCycleControlsForRRule: (iCalRecurrenceRule *) _rrule
{
//   NSDictionary *c;
//   NSCalendarDate *until;
  
//   c = [self cycleMatchingRRule:_rrule];
//   [self setCycle:c];

//   until = [[[_rrule untilDate] copy] autorelease];
//   if (!until)
//     until = startDate;
//   else
//     [self setIsCycleEndUntil];

//   [until setTimeZone:[[self clientObject] userTimeZone]];
//   [self setCycleUntilDate:until];
}

/*
 This method is necessary, because we have a fixed sets of cycles in the UI.
 The model is able to represent arbitrary rules, however.
 There SHOULD be a different UI, similar to iCal.app, to allow modelling
 of more complex rules.
 
 This method obviously cannot map all existing rules back to the fixed list
 in cycles.plist. This should be fixed in a future version when interop
 becomes more important.
 */
- (NSDictionary *) cycleMatchingRRule: (iCalRecurrenceRule *) _rrule
{
  NSString *cycleRep;
  NSArray *cycles;
  unsigned i, count;

  if (!_rrule)
    return [[self cycles] objectAtIndex:0];

  cycleRep = [_rrule versitString];
  cycles   = [self cycles];
  count    = [cycles count];
  for (i = 1; i < count; i++) {
    NSDictionary *c;
    NSString *cr;

    c  = [cycles objectAtIndex:i];
    cr = [c objectForKey: @"rule"];
    if ([cr isEqualToString:cycleRep])
      return c;
  }
  [self warnWithFormat: @"No default cycle for rrule found! -> %@", _rrule];
  return nil;
}

/* cycle "ends" - supposed to be 'never', 'COUNT' or 'UNTIL' */
- (NSArray *) cycleEnds
{
  static NSArray *ends = nil;
  
  if (!ends)
    {
      ends = [NSArray arrayWithObjects: @"cycle_end_never",
                      @"cycle_end_until", nil];
      [ends retain];
    }

  return ends;
}

- (void) setCycleEnd: (NSString *) _cycleEnd
{
  ASSIGN (cycleEnd, _cycleEnd);
}

- (NSString *) cycleEnd
{
  return cycleEnd;
}

- (BOOL) isCycleEndUntil
{
  return (cycleEnd && [cycleEnd isEqualToString: @"cycle_end_until"]);
}

- (void) setIsCycleEndUntil
{
  [self setCycleEnd: @"cycle_end_until"];
}

- (void) setIsCycleEndNever
{
  [self setCycleEnd: @"cycle_end_never"];
}
////////////////////////////////// JUNK ////////////////////////////////////////
////////////////////////////////// JUNK ////////////////////////////////////////
////////////////////////////////// JUNK ////////////////////////////////////////


/* helpers */
- (NSString *) completeURIForMethod: (NSString *) _method
{
  NSString *uri;
  NSRange r;
    
  uri = [[[self context] request] uri];
    
  /* first: identify query parameters */
  r = [uri rangeOfString: @"?" options:NSBackwardsSearch];
  if (r.length > 0)
    uri = [uri substringToIndex:r.location];
    
  /* next: append trailing slash */
  if (![uri hasSuffix: @"/"])
    uri = [uri stringByAppendingString: @"/"];
  
  /* next: append method */
  uri = [uri stringByAppendingString:_method];
    
  /* next: append query parameters */
  return [self completeHrefForMethod:uri];
}

- (BOOL) isWriteableClientObject
{
  return [[self clientObject]
	   respondsToSelector: @selector(saveContentString:)];
}

/* access */

- (BOOL) isMyComponent
{
  return ([[context activeUser] hasEmail: [organizer rfc822Email]]);
}

- (BOOL) canEditComponent
{
  return [self isMyComponent];
}

/* response generation */

- (NSString *) initialCycleVisibility
{
  return ([self hasCycle]
          ? @"visibility: visible;"
          : @"visibility: hidden;");
}

- (NSString *) initialCycleEndUntilVisibility {
  return ([self isCycleEndUntil]
          ? @"visibility: visible;"
          : @"visibility: hidden;");
}

// - (NSString *) iCalParticipantsAndResourcesStringFromQueryParameters
// {
//   NSString *s;
  
//   s = [self iCalParticipantsStringFromQueryParameters];
//   return [s stringByAppendingString:
//               [self iCalResourcesStringFromQueryParameters]];
// }

// - (NSString *) iCalParticipantsStringFromQueryParameters
// {
//   static NSString *iCalParticipantString = @"ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;CN=\"%@\":MAILTO:%@\r\n";
  
//   return [self iCalStringFromQueryParameter: @"ps"
//                format: iCalParticipantString];
// }

// - (NSString *) iCalResourcesStringFromQueryParameters
// {
//   static NSString *iCalResourceString = @"ATTENDEE;ROLE=NON-PARTICIPANT;CN=\"%@\":MAILTO:%@\r\n";

//   return [self iCalStringFromQueryParameter: @"rs"
//                format: iCalResourceString];
// }

// - (NSString *) iCalStringFromQueryParameter: (NSString *) _qp
//                                      format: (NSString *) _format
// {
//   LDAPUserManager *um;
//   NSMutableString *iCalRep;
//   NSString *s;

//   um = [LDAPUserManager sharedUserManager];
//   iCalRep = (NSMutableString *)[NSMutableString string];
//   s = [self queryParameterForKey:_qp];
//   if(s && [s length] > 0) {
//     NSArray *es;
//     unsigned i, count;
    
//     es = [s componentsSeparatedByString: @","];
//     count = [es count];
//     for(i = 0; i < count; i++) {
//       NSString *email, *cn;
      
//       email = [es objectAtIndex:i];
//       cn = [um getCNForUID:[um getUIDForEmail:email]];
//       [iCalRep appendFormat:_format, cn, email];
//     }
//   }
//   return iCalRep;
// }

- (NSException *) validateObjectForStatusChange
{
  id co;

  co = [self clientObject];
  if (![co respondsToSelector: @selector(changeParticipationStatus:)])
    return [NSException exceptionWithHTTPStatus: 400 /* Bad Request */
                        reason:
                          @"method cannot be invoked on the specified object"];

  return nil;
}

/* contact editor compatibility */

- (NSString *) urlButtonClasses
{
  NSString *classes;

  if ([url length])
    classes = @"button";
  else
    classes = @"button _disabled";

  return classes;
}

- (void) _handleAttendeesEdition
{
  NSArray *names, *emails;
  NSMutableArray *newAttendees;
  unsigned int count, max;
  NSString *currentEmail;
  iCalPerson *currentAttendee;

  newAttendees = [NSMutableArray new];
  if ([attendeesNames length] > 0)
    {
      names = [attendeesNames componentsSeparatedByString: @","];
      emails = [attendeesEmails componentsSeparatedByString: @","];
      max = [emails count];
      for (count = 0; count < max; count++)
	{
	  currentEmail = [emails objectAtIndex: count];
	  currentAttendee = [component findParticipantWithEmail: currentEmail];
	  if (!currentAttendee)
	    {
	      currentAttendee = [iCalPerson elementWithTag: @"attendee"];
	      [currentAttendee setCn: [names objectAtIndex: count]];
	      [currentAttendee setEmail: currentEmail];
	      [currentAttendee setRole: @"REQ-PARTICIPANT"];
	      [currentAttendee setRsvp: @"TRUE"];
	      [currentAttendee
		setParticipationStatus: iCalPersonPartStatNeedsAction];
	    }
	  [newAttendees addObject: currentAttendee];
	}
    }

  [component setAttendees: newAttendees];
  [newAttendees release];
}

- (void) _handleOrganizer
{
  NSString *organizerEmail;
  NSString *owner, *login;
  BOOL isOwner, hasOrganizer, hasAttendees;

  owner = [[self clientObject] ownerInContext: context];
  login = [[context activeUser] login];
  isOwner = [owner isEqualToString: login];
  hasAttendees = ([[component attendees] count] > 0);
  organizerEmail = [[component organizer] email];
  hasOrganizer = ([organizerEmail length] > 0);

  if (hasOrganizer)
    {
      if (isOwner && !hasAttendees)
	{
	  ASSIGN (organizer, [iCalPerson elementWithTag: @"organizer"]);
	  [component setOrganizer: organizer];
	}
    }
  else
    {
      if (!isOwner || hasAttendees)
	{
	  ASSIGN (organizer, [iCalPerson elementWithTag: @"organizer"]);
	  [organizer setCn: [organizerIdentity objectForKey: @"fullName"]];
	  [organizer setEmail: [organizerIdentity objectForKey: @"email"]];
	  [component setOrganizer: organizer];
	}
    }
}

- (void) _handleCustomRRule: (iCalRecurrenceRule *) theRule

{
  int type, range;

  // We decode the range
  range = [[self range1] intValue];

  // Create X appointments
  if (range == 1)
    {
      [theRule setRepeatCount: [[self range2] intValue]];
    }
  // Repeat until date
  else if (range == 2)
    {
      [theRule setUntilDate: [NSCalendarDate dateWithString: [self range2]
					     calendarFormat: @"%Y-%m-%d"]];
    }
  // No end date.
  else
    {
      // Do nothing?
    }


  // We decode the type and the rest accordingly.
  type = [[self repeatType] intValue];

  switch (type)
    {
      // DAILY:
      //
      // repeat1 holds the value of the radio button:
      //   0 -> Every X days
      //   1 -> Every weekday
      //
      // repeat2 holds the value of X when repeat1 equals 0
      //
    case 0:
      {
	[theRule setFrequency: iCalRecurrenceFrequenceDaily];

	if ([[self repeat1] intValue] == 0)
	  {
	    [theRule setInterval: [self repeat2]];
	  }
	else
	  {
	    [theRule setByDayMask: (iCalWeekDayMonday
				    |iCalWeekDayTuesday
				    |iCalWeekDayWednesday
				    |iCalWeekDayThursday
				    |iCalWeekDayFriday)];
	  }
      }
      break;
      
      // WEEKLY
      //
      // repeat1 holds the value of "Every X week(s)" 
      //
      // repeat2 holds which days are part of the recurrence rule
      //  1 -> Monday
      //  2 -> Tuesday .. and so on.
      //  The list is separated by commas, like: 1,3,4
    case 1:
      {
	NSArray *v;
	int c, mask;

	[theRule setFrequency: iCalRecurrenceFrequenceWeekly];
	[theRule setInterval: [self repeat1]];

	v = [[self repeat2] componentsSeparatedByString: @","];
	c = [v count];
	mask = 0;

	while (c--)
	  mask |= 1 << ([[v objectAtIndex: c] intValue]);
	
	[theRule setByDayMask: mask];
      }
      break;
      
      // MONTHLY
      //
      // repeat1 holds the value of "Every X month(s)"
      //
      // repeat2 holds the value of the radio-button "The" / "Recur on day(s)"
      //  0 -> The
      //  1 -> Recur on day(s)
      //
      // repeat3 holds the value of the first popup
      //  0 -> First
      //  1 -> Second ... and so on.
      //
      // repeat4 holds the value of the second popop
      //  0 -> Sunday
      //  1 -> Monday ... and so on.
      //  7 -> Day of the month
      //
      // repeat5 holds the selected days when "Recur on day(s)"
      // is chosen. The value starts at 1.
      //
    case 2:
      {
	[theRule setFrequency: iCalRecurrenceFrequenceMonthly];
	[theRule setInterval: [self repeat1]];

	// We recur on specific days...
	if ([[self repeat2] intValue] == 1)
	  {
	    [theRule setNamedValue: @"bymonthday" to: [self repeat5]];
	  }
	else
	  {
	    // TODO
	  }
      }
      break;

      // YEARLY
      //
      // repeat1 holds the value of "Every X year(s)"
      //
      // repeat2 holds the value of the radio-button "Every" / "Every .. of .."
      //  0 -> Every
      //  1 -> Every .. of ..
      //
      // repeat3 holds the value of the DAY parameter
      // repeat4 holds the value of the MONTH parameter (0 -> January, 1 -> February ... )
      //  ex: 3 February
      //
      // repeat5 holds the value of the OCCURENCE parameter (0 -> First, 1 -> Second ..)
      // repeat6 holds the value of the DAY parameter (0 -> Sunday, 1 -> Monday, etc..)
      // repeat7 holds the value of the MONTH parameter (0 -> January, 1 -> February ... )
      // 
    case 3:
    default:
      {
	[theRule setFrequency: iCalRecurrenceFrequenceYearly];
	[theRule setInterval: [self repeat1]];

	// We recur Every .. of ..
	if ([[self repeat2] intValue] == 1)
	  {
	    // TODO
	  }
	else
	  {
	    [theRule setNamedValue: @"bymonthday"  to: [self repeat3]];
	    [theRule setNamedValue: @"bymonth" 
		     to: [NSString stringWithFormat: @"%d", ([[self repeat4] intValue]+1)]];
	  }
      }
      break;
    }
}

- (void) takeValuesFromRequest: (WORequest *) _rq
                     inContext: (WOContext *) _ctx
{
  SOGoCalendarComponent *clientObject;
  iCalRecurrenceRule *rule;
  NSCalendarDate *now;

  [super takeValuesFromRequest: _rq inContext: _ctx];

  now = [NSCalendarDate calendarDate];
  [component setSummary: title];
  [component setLocation: location];
  [component setComment: comment];
  [component setUrl: url];
  [component setAccessClass: privacy];
  [component setCategories: [category capitalizedString]];
  [self _handleAttendeesEdition];
  [self _handleOrganizer];
  clientObject = [self clientObject];
  if ([clientObject isNew])
    {
      [component setCreated: now];
      [component setTimeStampAsDate: now];
    }
  [component setPriority: priority];
  [component setLastModified: now];

  if (![self isChildOccurence])
    {
      // We remove any repeat rules
      if (!repeat && [component hasRecurrenceRules])
	[component removeAllRecurrenceRules];
      else if ([repeat caseInsensitiveCompare: @"-"] != NSOrderedSame)
	{
	  rule = [iCalRecurrenceRule new];

	  [rule setInterval: @"1"];

	  if ([repeat caseInsensitiveCompare: @"BI-WEEKLY"] == NSOrderedSame)
	    {
	      [rule setFrequency: iCalRecurrenceFrequenceWeekly];
	      [rule setInterval: @"2"];
	    }
	  else if ([repeat caseInsensitiveCompare: @"EVERY WEEKDAY"] == NSOrderedSame)
	    {
	      [rule setByDayMask: (iCalWeekDayMonday
				   |iCalWeekDayTuesday
				   |iCalWeekDayWednesday
				   |iCalWeekDayThursday
				   |iCalWeekDayFriday)];
	      [rule setFrequency: iCalRecurrenceFrequenceDaily];
	    }
	  else if ([repeat caseInsensitiveCompare: @"MONTHLY"] == NSOrderedSame
		   || [repeat caseInsensitiveCompare: @"DAILY"] == NSOrderedSame
		   || [repeat caseInsensitiveCompare: @"WEEKLY"] == NSOrderedSame
		   || [repeat caseInsensitiveCompare: @"YEARLY"] == NSOrderedSame)
	    {
	      [rule setInterval: @"1"];
	      [rule setFrequency:
		      (iCalRecurrenceFrequency) [rule valueForFrequency: repeat]];
	    }
	  else
	    {
	      // We have a CUSTOM recurrence. Let's decode what kind of custome recurrence
	      // we have and set that.
	      [self _handleCustomRRule: rule];
	    }

	  [component setRecurrenceRules: [NSArray arrayWithObject: rule]];
	  [rule release];
	}
    }
}

#warning the following methods probably share some code...
- (NSString *) _toolbarForOwner: (SOGoUser *) ownerUser
		andClientObject: (SOGoContentObject
				  <SOGoComponentOccurence> *) clientObject
{
  NSString *toolbarFilename;
  iCalPersonPartStat participationStatus;

  if ([[component attendees] count]
      && [component userIsParticipant: ownerUser]
      && ![component userIsOrganizer: ownerUser])
    {
      participationStatus
	= [[component findParticipant: ownerUser] participationStatus];
      /* Lightning does not manage participation status within tasks */
      if (participationStatus == iCalPersonPartStatAccepted)
	toolbarFilename = @"SOGoAppointmentObjectDecline.toolbar";
      else if (participationStatus == iCalPersonPartStatDeclined)
	toolbarFilename = @"SOGoAppointmentObjectAccept.toolbar";
      else
	toolbarFilename = @"SOGoAppointmentObjectAcceptOrDecline.toolbar";
    }
  else
    {
      if ([clientObject isKindOfClass: [SOGoAppointmentObject class]])
	toolbarFilename = @"SOGoAppointmentObject.toolbar";
      else
	toolbarFilename = @"SOGoTaskObject.toolbar";
    }

  return toolbarFilename;
}

- (NSString *) _toolbarForDelegate: (SOGoUser *) ownerUser
		   andClientObject: (SOGoContentObject
				     <SOGoComponentOccurence> *) clientObject
{
  SoSecurityManager *sm;
  NSString *toolbarFilename, *adminToolbar;
  iCalPersonPartStat participationStatus;
  SOGoUser *currentUser;

  if ([clientObject isKindOfClass: [SOGoAppointmentObject class]])
    adminToolbar = @"SOGoAppointmentObject.toolbar";
  else
    adminToolbar = @"SOGoTaskObject.toolbar";

  currentUser = [context activeUser];
  sm = [SoSecurityManager sharedSecurityManager];

  if (![sm validatePermission: SOGoCalendarPerm_ModifyComponent
	   onObject: clientObject
	   inContext: context])
    toolbarFilename = [self _toolbarForOwner: ownerUser
			    andClientObject: clientObject];
  else if (![sm validatePermission: SOGoCalendarPerm_RespondToComponent
		onObject: clientObject
		inContext: context]
	   && [[component attendees] count]
	   && [component userIsParticipant: ownerUser]
	   && ![component userIsOrganizer: ownerUser])
    {
      participationStatus
	= [[component findParticipant: ownerUser] participationStatus];
      /* Lightning does not manage participation status within tasks */
      if (participationStatus == iCalPersonPartStatAccepted)
	toolbarFilename = @"SOGoAppointmentObjectDecline.toolbar";
      else if (participationStatus == iCalPersonPartStatDeclined)
	toolbarFilename = @"SOGoAppointmentObjectAccept.toolbar";
      else
	toolbarFilename = @"SOGoAppointmentObjectAcceptOrDecline.toolbar";
    }
  else
    toolbarFilename = @"SOGoComponentClose.toolbar";

  return toolbarFilename;
}

- (NSString *) toolbar
{
  SOGoContentObject <SOGoComponentOccurence> *clientObject;
  NSString *toolbarFilename;
  SOGoUser *ownerUser;

  clientObject = [self clientObject];
  ownerUser = [SOGoUser userWithLogin: [clientObject ownerInContext: context]
			roles: nil];

  if ([ownerUser isEqual: [context activeUser]])
    toolbarFilename = [self _toolbarForOwner: ownerUser
			    andClientObject: clientObject];
  else
    toolbarFilename = [self _toolbarForDelegate: ownerUser
			    andClientObject: clientObject];


  return toolbarFilename;
}

@end
