/* UIxComponentEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2011 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSURL.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalByDayMask.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRepeatableEntityObject.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalTrigger.h>
#import <NGCards/NSString+NGCards.h>
#import <NGCards/NSCalendarDate+NGCards.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>

#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/iCalPerson+SOGo.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoWebAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoAppointmentObject.h>
#import <Appointments/SOGoAppointmentOccurence.h>
#import <Appointments/SOGoTaskObject.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoSource.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/WOResourceManager+SOGo.h>

#import "../../Main/SOGo.h"

#import "UIxComponentEditor.h"
#import "UIxDatePicker.h"

static NSArray *reminderItems = nil;
static NSArray *reminderValues = nil;

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
- (void) setRepeat##X: (NSString *) theValue { ASSIGN(repeat##X, theValue); } \

#define RANGE(X) \
- (NSString *) range##X { return range##X; } \
- (void) setRange##X: (NSString *) theValue { ASSIGN(range##X, theValue);  }

@implementation UIxComponentEditor

+ (void) initialize
{
  if (!reminderItems && !reminderValues)
    {
      reminderItems = [NSArray arrayWithObjects:
			       @"5_MINUTES_BEFORE",
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
      reminderValues = [NSArray arrayWithObjects:
				@"-PT5M",
				@"-PT10M",
				@"-PT15M",
				@"-PT30M",
				@"-PT45M",
				@"",
				@"-PT1H",
				@"-PT2H",
				@"-PT5H",
				@"-PT15H",
				@"",
				@"-P1D",
				@"-P2D",
				@"-P1W",
				@"",
				@"",
				nil];

      [reminderItems retain];
      [reminderValues retain];
    }
}

- (id) init
{
  UIxDatePicker *datePicker;

  if ((self = [super init]))
    {
      // We must instanciate a UIxDatePicker object to retrieve
      // the proper date format to use.
      datePicker = [[UIxDatePicker alloc] initWithContext: context];
      dateFormat = [datePicker dateFormat];
      [datePicker release];

      component = nil;
      componentCalendar = nil;
      classification = nil;
      [self setIsCycleEndNever];
      componentOwner = @"";
      organizer = nil;
      //organizerIdentity = nil;
      organizerProfile = nil;
      ownerAsAttendee = nil;
      attendee = nil;
      jsonAttendees = nil;
      calendarList = nil;
      repeat = nil;
      reminder = nil;
      reminderQuantity = nil;
      reminderUnit = nil;
      reminderRelation = nil;
      reminderReference = nil;
      reminderAction = nil;
      reminderEmailOrganizer = NO;
      reminderEmailAttendees = NO;
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
  //[organizerIdentity release];
  [organizerProfile release];
  [ownerAsAttendee release];
  [comment release];
  [priority release];
  [classification release];
  [categories release];
  [cycle release];
  [cycleEnd release];
  [attachUrl release];
  [attendee release];
  [jsonAttendees release];
  [calendarList release];

  [reminder release];
  [reminderQuantity release];
  [reminderUnit release];
  [reminderRelation release];
  [reminderReference release];

  [repeat release];
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
  [componentCalendar release];

  [super dealloc];
}

- (void) _loadAttendees
{
  NSEnumerator *attendees;
  NSMutableDictionary *currentAttendeeData;
  NSString *uid, *domain;
  NSArray *contacts;
  NSDictionary *contact;
  iCalPerson *currentAttendee;
  SOGoUserManager *um;
  NSObject <SOGoSource> *source;

  jsonAttendees = [NSMutableDictionary new];
  um = [SOGoUserManager sharedUserManager];

  attendees = [[component attendees] objectEnumerator];
  while ((currentAttendee = [attendees nextObject]))
    {
      currentAttendeeData = [NSMutableDictionary dictionary];

      if ([[currentAttendee cn] length])
	[currentAttendeeData setObject: [currentAttendee cn] 
				forKey: @"name"];

      [currentAttendeeData setObject: [currentAttendee rfc822Email] 
			      forKey: @"email"];
      
      uid = [um getUIDForEmail: [currentAttendee rfc822Email]];
      if (uid != nil)
	[currentAttendeeData setObject: uid 
				forKey: @"uid"];
      else
        {
          domain = [[context activeUser] domain];
          contacts = [um fetchContactsMatching: [currentAttendee rfc822Email] inDomain: domain];
          if ([contacts count] == 1)
            {
              contact = [contacts lastObject];
              source = [contact objectForKey: @"source"];
              if ([source conformsToProtocol: @protocol (SOGoDNSource)] &&
                  [[(NSObject <SOGoDNSource>*) source MSExchangeHostname] length])
                {
                  uid = [NSString stringWithFormat: @"%@:%@", [[context activeUser] login],
                              [contact valueForKey: @"c_uid"]];
                  [currentAttendeeData setObject: uid forKey: @"uid"];
                }
            }
        }

      [currentAttendeeData setObject: [[currentAttendee partStat] lowercaseString]
			      forKey: @"partstat"];
      [currentAttendeeData setObject: [[currentAttendee role] lowercaseString]
			      forKey: @"role"];

      if ([[currentAttendee delegatedTo] length])
	[currentAttendeeData setObject: [[currentAttendee delegatedTo] rfc822Email]
				forKey: @"delegated-to"];

      if ([[currentAttendee delegatedFrom] length])
	[currentAttendeeData setObject: [[currentAttendee delegatedFrom] rfc822Email]
				forKey: @"delegated-from"];

      [jsonAttendees setObject: currentAttendeeData
			forKey: [currentAttendee rfc822Email]];
    }
}

- (void) _loadCategories
{
  NSString *simpleCategory;
  NSArray *compCategories;

  compCategories = [component categories];
  if ([compCategories count] > 0)
    {
      simpleCategory = [compCategories objectAtIndex: 0];
      ASSIGN (category, simpleCategory);
    }
}

- (void) _loadRRules
{
  SOGoUserDefaults *ud;

  // We initialize our repeat ivars
  if ([component hasRecurrenceRules])
    {
      iCalRecurrenceRule *rule;

      [self setRepeat: @"CUSTOM"];
      
      rule = [[component recurrenceRules] lastObject];

      /* DAILY */
      if ([rule frequency] == iCalRecurrenceFrequenceDaily)
	{
	  repeatType = @"0";
	  
	  if ([[rule byDayMask] isWeekDays])
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

      /* WEEKLY */
      else if ([rule frequency] == iCalRecurrenceFrequenceWeekly)
	{
	  repeatType = @"1";
	  [self setRepeat1: [NSString stringWithFormat: @"%d", [rule repeatInterval]]];

	  if (![[rule byDay] length])
	    {
	      if ([rule repeatInterval] == 1)
		repeat = @"WEEKLY";
	      else if ([rule repeatInterval] == 2)
		repeat = @"BI-WEEKLY";
	    }
	  else
	    {
	      [self setRepeat2: [[rule byDayMask] asRuleStringWithIntegers]];
	    }
	}

      /* MONTHLY */
      else if ([rule frequency] == iCalRecurrenceFrequenceMonthly)
	{
	  repeatType = @"2";

	  if ([[rule byDay] length])
	    {
	      int firstOccurrence;
	      iCalByDayMask *dayMask;

	      dayMask = [rule byDayMask];
	      firstOccurrence = [dayMask firstOccurrence] - 1;
	      if (firstOccurrence < 0)
		firstOccurrence = 5;
	      
	      [self setRepeat2: @"0"];
	      [self setRepeat3: [NSString stringWithFormat: @"%d", firstOccurrence]];
	      [self setRepeat4: [NSString stringWithFormat: @"%d", [dayMask firstDay]]];
	    }
	  else if ([[rule byMonthDay] count])
	    {
	      NSArray *days;

	      days = [rule byMonthDay];
	      if ([days count] > 0 && [[days objectAtIndex: 0] intValue] < 0)
		{
		  // BYMONTHDAY=-1
		  [self setRepeat2: @"0"];
		  [self setRepeat3: @"5"]; // last ..
		  [self setRepeat4: @"7"]; //      .. day of the month
		}
	      else
		{
		  [self setRepeat2: @"1"];
		  [self setRepeat5: [[rule byMonthDay] componentsJoinedByString: @","]];
		}
	    }
	  else if ([rule repeatInterval] == 1)
	    repeat = @"MONTHLY";

	  [self setRepeat1: [NSString stringWithFormat: @"%d", [rule repeatInterval]]];
	}

      /* YEARLY */
      else
	{
	  repeatType = @"3";
	 
	  if ([[rule flattenedValuesForKey: @"bymonth"] length])
	    {
	      if ([[rule byDay] length])
		{
		  int firstOccurrence;
		  iCalByDayMask *dayMask;
		  
		  dayMask = [rule byDayMask];
		  firstOccurrence = [dayMask firstOccurrence] - 1;
		  if (firstOccurrence < 0)
		    firstOccurrence = 5;
		  
		  [self setRepeat2: @"1"];
		  [self setRepeat5: [NSString stringWithFormat: @"%d", firstOccurrence]];
		  [self setRepeat6: [NSString stringWithFormat: @"%d", [dayMask firstDay]]];
		  [self setRepeat7: [NSString stringWithFormat: @"%d", [[rule flattenedValuesForKey: @"bymonth"] intValue]-1]];
		}
	      else
		{
		  [self setRepeat2: @"0"];
		  [self setRepeat3: [rule flattenedValuesForKey: @"bymonthday"]];
		  [self setRepeat4: [NSString stringWithFormat: @"%d", [[rule flattenedValuesForKey: @"bymonth"] intValue]-1]];
		}
	    }
	  else if ([rule repeatInterval] == 1)
	    repeat = @"YEARLY";

	  [self setRepeat1: [NSString stringWithFormat: @"%d", [rule repeatInterval]]];
	}

      /* We decode the proper end date, recurrences count, etc. */
      if ([rule repeatCount])
	{
	  repeat = @"CUSTOM";
	  [self setRange1: @"1"];
	  [self setRange2: [rule flattenedValuesForKey: @"count"]];
	}
      else if ([rule untilDate])
	{
	  NSCalendarDate *date;
	  
	  repeat = @"CUSTOM";
	  date = [[rule untilDate] copy];

          ud = [[context activeUser] userDefaults];
	  [date setTimeZone: [ud timeZone]];
	  [self setRange1: @"2"];
	  [self setRange2: [date descriptionWithCalendarFormat: dateFormat]];
	  [date release];
	}
      else
	[self setRange1: @"0"];
    }
  else
    {
      DESTROY(repeat);
      repeatType = @"0";
      repeat1 = @"0";
      repeat2 = @"1";
    }
}

- (void) _loadEMailAlarm: (iCalAlarm *) anAlarm
{
  NSArray *attendees;
  iCalPerson *aAttendee;
  SOGoUser *owner;
  NSString *ownerId, *email;
  int count, max;

  attendees = [anAlarm attendees];
  reminderEmailOrganizer = NO;
  reminderEmailAttendees = NO;

  ownerId = [[self clientObject] ownerInContext: nil];
  owner = [SOGoUser userWithLogin: ownerId];
  email = [[owner defaultIdentity] objectForKey: @"email"];

  max = [attendees count];
  for (count = 0;
       !(reminderEmailOrganizer && reminderEmailAttendees)
         && count < max;
       count++)
    {
      aAttendee = [attendees objectAtIndex: count];
      if ([[aAttendee rfc822Email] isEqualToString: email])
        reminderEmailOrganizer = YES;
      else
        reminderEmailAttendees = YES;
    }
}

- (void) _loadAlarms
{
  iCalAlarm *anAlarm;
  iCalTrigger *aTrigger;
  NSString *duration, *quantity;
  unichar c;
  unsigned int i;

  if ([component hasAlarms])
    {
      // We currently have the following limitations for alarms:
      // - only the first alarm is considered;
      // - the alarm's action must be of type DISPLAY;
      // - the alarm's trigger value type must be DURATION.

      anAlarm = [[component alarms] objectAtIndex: 0];
      aTrigger = [anAlarm trigger];
      ASSIGN (reminderAction, [[anAlarm action] lowercaseString]);
      if (([reminderAction isEqualToString: @"display"]
           || [reminderAction isEqualToString: @"email"])
	  && [[aTrigger valueType] caseInsensitiveCompare: @"DURATION"] == NSOrderedSame)
	{
	  duration = [aTrigger flattenedValuesForKey: @""];
	  i = [reminderValues indexOfObject: duration];

	  if (i == NSNotFound || [reminderAction isEqualToString: @"email"])
	    {
	      // Custom alarm
	      ASSIGN (reminder, @"CUSTOM");
	      ASSIGN (reminderRelation, [aTrigger relationType]);

	      i = 0;
	      c = [duration characterAtIndex: i];
	      if (c == '-')
		{
		  ASSIGN (reminderReference, @"BEFORE");
		  i++;
		}
	      else
		{
		  ASSIGN (reminderReference, @"AFTER");
		}
	      
	      c = [duration characterAtIndex: i];
	      if (c == 'P')
		{
		  quantity = @"";
		  // Parse duration -- ignore first character (P)
		  for (i++; i < [duration length]; i++)
		    {
		      c = [duration characterAtIndex: i];
		      if (c == 't' || c == 'T')
			// time -- ignore character
			continue;
		      else if (isdigit (c))
			quantity = [quantity stringByAppendingFormat: @"%c", c];
		      else
			{
			  switch (c)
			    {
			    case 'D': /* day  */
			      ASSIGN (reminderUnit, @"DAYS");
			      break;
			    case 'H': /* hour */
			      ASSIGN (reminderUnit, @"HOURS");
			      break;
			    case 'M': /* min  */
			      ASSIGN (reminderUnit, @"MINUTES");
			      break;
			    default:
			      NSLog(@"Cannot process duration unit: '%c'", c);
			      break;
			    }
			}
		    }
		  if ([quantity length])
		    ASSIGN (reminderQuantity, quantity);

                  if ([reminderAction isEqualToString: @"email"])
                    [self _loadEMailAlarm: anAlarm];
		}
	    }
	  else
	    // Matches one of the predefined alarms
	    ASSIGN (reminder, [reminderItems objectAtIndex: i]);
	}
    }
}

/* warning: we use this method which will be triggered by the template system
   when the page is instantiated, but we should find another and cleaner way of
   doing this... for example, when the clientObject is set */
- (void) setComponent: (iCalRepeatableEntityObject *) newComponent
{
  SOGoCalendarComponent *co;
  SOGoUserManager *um;
  NSString *owner, *ownerEmail;
  iCalRepeatableEntityObject *masterComponent;
  SOGoUserDefaults *defaults;
  NSString *tag;

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
	  ASSIGN (attachUrl, [[component attach] absoluteString]);
	  ASSIGN (classification, [component accessClass]);
          if ([co isNew] && [classification length] == 0)
            {
              defaults = [[context activeUser] userDefaults];
              tag = [co componentTag];
              [classification release];
              if ([tag isEqualToString: @"vevent"])
                classification = [defaults calendarEventsDefaultClassification];
              else
                classification = [defaults calendarTasksDefaultClassification];
              
              if ([classification length] == 0)
                classification = @"PUBLIC";
              [classification retain];
            }

	  ASSIGN (priority, [component priority]);
	  ASSIGN (status, [component status]);
          ASSIGN (categories, [component categories]);
	  if ([[[component organizer] rfc822Email] length])
	    {
	      ASSIGN (organizer, [component organizer]);
	    }
	  else
	    {
	      masterComponent = [[[component parent] allObjects] objectAtIndex: 0];
	      ASSIGN (organizer, [masterComponent organizer]);
	    }

	  [self _loadCategories];
          if (!jsonAttendees)
            [self _loadAttendees];
	  [self _loadRRules];
	  [self _loadAlarms];

 	  [componentCalendar release];
	  componentCalendar = [co container];
	  if ([componentCalendar isKindOfClass: [SOGoCalendarComponent class]])
	    componentCalendar = [componentCalendar container];
	  [componentCalendar retain];
	
	  um = [SOGoUserManager sharedUserManager];
	  owner = [componentCalendar ownerInContext: context];
	  ownerEmail = [um getEmailForUID: owner];
	  ASSIGN (ownerAsAttendee, [component findAttendeeWithEmail: (id)ownerEmail]);
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

- (NSString *) itemClassificationText
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
  SOGoCalendarComponent *co;
  NSString *tag;

  co = [self clientObject];
  if ([co isNew] && [co isKindOfClass: [SOGoCalendarComponent class]])
    {
      tag = [co componentTag];
      if ([tag isEqualToString: @"vevent"])
        [self setTitle: [self labelForKey: @"New Event"]];
      else if ([tag isEqualToString: @"vtodo"])
        [self setTitle: [self labelForKey: @"New Task"]];
    }

  return title;
}

- (void) setAttach: (NSString *) _attachUrl
{
  ASSIGN (attachUrl, _attachUrl);
}

- (NSString *) attach
{
  return attachUrl;
}

- (NSString *) organizerName
{
  return [organizer mailAddress];
}

// - (BOOL) canBeOrganizer
// {
//   NSString *owner;
//   SOGoObject <SOGoComponentOccurence> *co;
//   SOGoUser *currentUser;
//   BOOL hasOrganizer;
//   SoSecurityManager *sm;

//   co = [self clientObject];
//   owner = [co ownerInContext: context];
//   currentUser = [context activeUser];

//   hasOrganizer = ([[organizer value: 0] length] > 0);

//   sm = [SoSecurityManager sharedSecurityManager];
  
//   return ([co isNew]
// 	  || (([owner isEqualToString: [currentUser login]]
// 	       || ![sm validatePermission: SOGoCalendarPerm_ModifyComponent
// 		       onObject: co
// 		       inContext: context])
// 	      && (!hasOrganizer || [component userIsOrganizer: currentUser])));
// }

- (BOOL) hasOrganizer
{
  // We check if there's an organizer and if it's not ourself
  NSString *value;

  value = [organizer rfc822Email];

  if ([value length])
    {
      NSDictionary *currentIdentity;
      NSEnumerator *identities;
      NSArray *allIdentities;
      
      allIdentities = [[context activeUser] allIdentities];
      identities = [allIdentities objectEnumerator];
      currentIdentity = nil;

      while ((currentIdentity = [identities nextObject]))
	if ([[currentIdentity objectForKey: @"email"]
	      caseInsensitiveCompare: value]
	    == NSOrderedSame)
	  return NO;

      return YES;
    }

  return NO;

    //return ([[organizer value: 0] length] && ![self canBeOrganizer]);
}

//- (void) setOrganizerIdentity: (NSDictionary *) newOrganizerIdentity
//{
//  ASSIGN (organizerIdentity, newOrganizerIdentity);
//}

// - (NSDictionary *) organizerIdentity
// {
//   NSArray *allIdentities;
//   NSEnumerator *identities;
//   NSDictionary *currentIdentity;
//   NSString *orgEmail;

//   orgEmail = [organizer rfc822Email];
//   if (!organizerIdentity)
//     {
//       if ([orgEmail length])
// 	{
// 	  allIdentities = [[context activeUser] allIdentities];
// 	  identities = [allIdentities objectEnumerator];
// 	  while (!organizerIdentity
// 		 && ((currentIdentity = [identities nextObject])))
// 	    if ([[currentIdentity objectForKey: @"email"]
// 		  caseInsensitiveCompare: orgEmail]
// 		== NSOrderedSame)
// 	      ASSIGN (organizerIdentity, currentIdentity);
// 	}
//     }

//   return organizerIdentity;
// }

//- (NSArray *) organizerList
//{
//  return [[context activeUser] allIdentities];
//}

//- (NSString *) itemOrganizerText
//{
//  return [item keysWithFormat: @"%{fullName} <%{email}>"];
//}

- (BOOL) hasAttendees
{
  return ([[component attendees] count] > 0);
}

- (void) setAttendee: (id) _attendee
{
  ASSIGN (attendee, _attendee);
}

- (id) attendee
{
  return attendee;
}

- (NSString *) attendeeForDisplay
{
  NSString *fn, *result;

  fn = [attendee cnWithoutQuotes];
  if ([fn length])
    result = fn;
  else
    result = [attendee rfc822Email];
  
  return result;
}

- (NSString *) jsonAttendees
{
  return [jsonAttendees jsonRepresentation];
}

- (NSDictionary *) organizerProfile
{
  NSMutableDictionary *profile;
  NSDictionary *ownerIdentity;
  NSString *uid, *name, *email, *partstat, *role;
  SOGoUserManager *um;
  SOGoCalendarComponent *co;
  SOGoUser *ownerUser;

  if (organizerProfile == nil)
    {
      profile = [NSMutableDictionary dictionary];
      email = [organizer rfc822Email];
      role = nil;
      partstat = nil;
      
      if ([email length])
	{
	  um = [SOGoUserManager sharedUserManager];
	  
	  name = [organizer cn];
	  uid = [um getUIDForEmail: email];
	  
	  partstat = [[organizer partStat] lowercaseString];
	  role = [[organizer role] lowercaseString];
	}
      else
	{
	  // No organizer defined in vEvent; use calendar owner
	  co = [self clientObject];
	  uid = [[co container] ownerInContext: context];
	  ownerUser = [SOGoUser userWithLogin: uid roles: nil];
	  ownerIdentity = [ownerUser defaultIdentity];
	  
	  name = [ownerIdentity objectForKey: @"fullName"];
	  email = [ownerIdentity  objectForKey: @"email"];
	}
      
      if (uid != nil)
	[profile setObject: uid 
		    forKey: @"uid"];
      else
	uid = email;
      
      [profile setObject: name
			   forKey: @"name"];
      
      [profile setObject: email
			   forKey: @"email"];
      
      if (partstat == nil || ![partstat length])
	partstat = @"accepted";
      [profile setObject: partstat
			   forKey: @"partstat"];
      
      if (role == nil || ![role length])
	role = @"chair";
      [profile setObject: role
			   forKey: @"role"];
      
      organizerProfile = [NSDictionary dictionaryWithObject: profile forKey: uid];
      [organizerProfile retain];
    }

  return organizerProfile;
}

- (NSString *) jsonOrganizer
{
  return [[[[self organizerProfile] allValues] lastObject] jsonRepresentation];
}

- (void) setLocation: (NSString *) _value
{
  ASSIGN (location, _value);
}

- (NSString *) location
{
  return location;
}

- (BOOL) hasLocation
{
  return [location length] > 0;
}

- (void) setComment: (NSString *) _value
{
#warning should we do the same for "location" and "summary"? What about ContactsUI?
  ASSIGN (comment, [_value stringByReplacingString: @"\r\n" withString: @"\n"]);
}

- (NSString *) comment
{
  return [comment stringByReplacingString: @"\n" withString: @"\r\n"];
}

- (BOOL) hasComment
{
  return [comment length] > 0;
}

- (NSArray *) categoryList
{
  NSMutableArray *categoryList;
  NSArray *categoryLabels;
  SOGoUserDefaults *defaults;

  defaults = [[context activeUser] userDefaults];
  categoryLabels = [defaults calendarCategories];
  if (!categoryLabels)
    categoryLabels = [[self labelForKey: @"category_labels"]
                       componentsSeparatedByString: @","];
  categoryList
    = [NSMutableArray arrayWithCapacity: [categoryLabels count] + 1];
  if ([category length] && ![categoryLabels containsObject: category])
    [categoryList addObject: category];
  [categoryList addObjectsFromArray:
                  [categoryLabels sortedArrayUsingSelector:
                                    @selector (localizedCaseInsensitiveCompare:)]];

  return categoryList;
}

- (void) setCategories: (NSArray *) _categories
{
  ASSIGN (categories, _categories);
}

- (NSArray *) categories
{
  return categories;
}

- (void) setCategory: (NSString *) newCategory
{
  if (newCategory)
    ASSIGN (categories, [NSArray arrayWithObject: newCategory]);
  else
    {
      [categories release];
      categories = nil;
    }
}

- (NSString *) category
{
  return category;
}

- (BOOL) hasCategory
{
  return [category length] > 0;
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

- (NSString *) repeatLabel
{
  NSString *rc;

  if ([self repeat])
    rc = [self labelForKey: [NSString stringWithFormat: @"repeat_%@", [self repeat]]];
  else
    rc = [self labelForKey: @"repeat_NEVER"];

  return rc;
}

- (NSArray *) reminderList
{
  return reminderItems;
}

 - (void) setReminder: (NSString *) theReminder
 {
   ASSIGN(reminder, theReminder);
 }

- (NSString *) reminder
 {
   return reminder;
 }

 - (void) setReminderQuantity: (NSString *) theReminderQuantity
 {
   ASSIGN(reminderQuantity, theReminderQuantity);
 }

- (NSString *) reminderQuantity
 {
   return reminderQuantity;
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

- (void) setReminderAction: (NSString *) newValue
{
  ASSIGN (reminderAction, newValue);
}

- (NSString *) reminderAction
{
  return reminderAction;
}

- (void) setReminderEmailOrganizer: (NSString *) newValue
{
  reminderEmailOrganizer = [newValue isEqualToString: @"true"];
}

- (NSString *) reminderEmailOrganizer
{
  return (reminderEmailOrganizer ? @"true" : @"false");
}

- (void) setReminderEmailAttendees: (NSString *) newValue
{
  reminderEmailAttendees = [newValue isEqualToString: @"true"];
}

- (NSString *) reminderEmailAttendees
{
  return (reminderEmailAttendees ? @"true" : @"false");
}

- (NSString *) repeat
{
  return repeat;
}

- (void) setRepeat: (NSString *) newRepeat
{
  ASSIGN(repeat, newRepeat);
}

- (BOOL) hasRepeat
{
  return [repeat length] > 0;
}

- (NSString *) itemReplyText
{
  NSString *word;

  switch ([item intValue])
    {
    case iCalPersonPartStatAccepted: 
      word = @"ACCEPTED";
      break;
    case iCalPersonPartStatDeclined:
      word = @"DECLINED";
      break;
    case iCalPersonPartStatNeedsAction:
      word = @"NEEDS-ACTION";
      break;
    case iCalPersonPartStatTentative:
      word = @"TENTATIVE";
      break;
    case iCalPersonPartStatDelegated:
      word = @"DELEGATED";
      break;
    default:
      word = @"UNKNOWN";
    }

  return [self labelForKey: [NSString stringWithFormat: @"partStat_%@", word]];
}

- (NSArray *) replyList
{
  return [NSArray arrayWithObjects: 
                    [NSNumber numberWithInt: iCalPersonPartStatAccepted], 
	   [NSNumber numberWithInt: iCalPersonPartStatDeclined],
	   [NSNumber numberWithInt: iCalPersonPartStatNeedsAction],
	   [NSNumber numberWithInt: iCalPersonPartStatTentative],
	   [NSNumber numberWithInt: iCalPersonPartStatDelegated],
		  nil];
}

- (NSNumber *) reply
{
  iCalPersonPartStat participationStatus;

  participationStatus = [ownerAsAttendee participationStatus];

  return [NSNumber numberWithInt: participationStatus];
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
      calendar = [self componentCalendar];
      sm = [SoSecurityManager sharedSecurityManager];

      perm = SoPerm_DeleteObjects;
      if ([sm validatePermission: perm
			onObject: calendar
		       inContext: context])
	{
	  // User can't delete components from this calendar;
	  // don't add any calendar other than the current one
	  [calendarList addObject: calendar];
	}
      else
	{
	  // Find which calendars user has creation rights
	  perm = SoPerm_AddDocumentsImagesAndFiles;
	  calendarParent
	    = [[context activeUser] calendarsFolderInContext: context];
	  allCalendars = [[calendarParent subFolders] objectEnumerator];
	  while ((currentCalendar = [allCalendars nextObject]))
	    if ([calendar isEqual: currentCalendar] ||
		![sm validatePermission: perm
			       onObject: currentCalendar
			      inContext: context])
	      [calendarList addObject: currentCalendar];
	}
    }

  return calendarList;
}

/**
 * This method is called from the wox template and uses to display the event
 * organizer in the edition window of the attendees.
 * Returns an array of the two elements :
 *  - array of calendar owners
 *  - dictionary of owners profiles
 */
- (NSArray *) calendarOwnerList
{
  NSArray *calendars;
  NSMutableArray *owners;
  NSDictionary *currentOwnerIdentity;
  NSMutableDictionary *profiles, *currentOwnerProfile;
  NSString *currentOwner;
  SOGoAppointmentFolder *currentCalendar;
  SOGoUser *currentUser;
  unsigned i;

  calendars = [self calendarList];
  owners = [NSMutableArray arrayWithCapacity: [calendars count]];
  profiles = [NSMutableDictionary dictionaryWithDictionary: [self organizerProfile]];
  
  for (i = 0; i < [calendars count]; i++)
    {
      currentCalendar = [calendars objectAtIndex: i];
      currentOwner = [currentCalendar ownerInContext: context];
      [owners addObject: currentOwner];

      if ([profiles objectForKey: currentOwner] == nil)
	{
	  currentUser = [SOGoUser userWithLogin: currentOwner roles: nil];
	  currentOwnerIdentity = [currentUser defaultIdentity];

	  currentOwnerProfile = [NSMutableDictionary dictionary];
	  [currentOwnerProfile setObject: ([currentOwnerIdentity objectForKey: @"fullName"] == nil ? @"" : [currentOwnerIdentity objectForKey: @"fullName"])
				  forKey: @"name"];
	  [currentOwnerProfile setObject: ([currentOwnerIdentity objectForKey: @"email"] == nil ? @"" : [currentOwnerIdentity objectForKey: @"email"])
				  forKey: @"email"];
	  [currentOwnerProfile setObject: @"accepted"
				  forKey: @"partstat"];
	  [currentOwnerProfile setObject: @"chair"
				  forKey: @"role"];

	  [profiles setObject: currentOwnerProfile forKey: currentOwner];
	}
    }
  
  return [NSArray arrayWithObjects: owners, profiles, nil];
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

- (NSString *) componentCalendarName
{
  return [componentCalendar displayName];
}

- (void) setComponentCalendar: (SOGoAppointmentFolder *) _componentCalendar
{
  ASSIGN(componentCalendar, _componentCalendar);
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

- (BOOL) hasPriority
{
  return [priority length] > 0;
}

- (NSArray *) classificationClasses
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

- (void) setClassification: (NSString *) _classification
{
  ASSIGN (classification, _classification);
}

- (NSString *) classification
{
  return classification;
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

/*- (NSString *) urlButtonClasses
{
  NSString *classes;

  if ([url length])
    classes = @"button";
  else
    classes = @"button _disabled";

  return classes;
  }*/

- (void) _handleAttendeesEdition
{
  NSMutableArray *newAttendees;
  unsigned int count, max;
  NSString *currentEmail;
  iCalPerson *currentAttendee;
  NSString *json, *role, *partstat;
  NSDictionary *attendeesData;
  NSArray *attendees;
  NSDictionary *currentData;
  WORequest *request;

  request = [context request];
  json = [request formValueForKey: @"attendees"];
  if ([json length])
    {
      attendees = [NSArray array];
      attendeesData = [json objectFromJSONString];
      if (attendeesData && [attendeesData isKindOfClass: [NSDictionary class]])
	{
	  newAttendees = [NSMutableArray array];
	  attendees = [attendeesData allValues];
	  max = [attendees count];
	  for (count = 0; count < max; count++)
	    {
	      currentData = [attendees objectAtIndex: count];
	      currentEmail = [currentData objectForKey: @"email"];
              role = [[currentData objectForKey: @"role"] uppercaseString];
              if (!role)
                role = @"REQ-PARTICIPANT";
              if ([role isEqualToString: @"NON-PARTICIPANT"])
                partstat = @"";
              else
                {
                  partstat = [[currentData objectForKey: @"partstat"]
                               uppercaseString];
                  if (!partstat)
                    partstat = @"NEEDS-ACTION";
                }
	      currentAttendee = [component findAttendeeWithEmail: currentEmail];
	      if (!currentAttendee)
		{
		  currentAttendee = [iCalPerson elementWithTag: @"attendee"];
		  [currentAttendee setCn: [currentData objectForKey: @"name"]];
		  [currentAttendee setEmail: currentEmail];
		  // [currentAttendee
		  //   setParticipationStatus: iCalPersonPartStatNeedsAction];
		}
              [currentAttendee
                    setRsvp: ([role isEqualToString: @"NON-PARTICIPANT"]
                              ? @"FALSE"
                              : @"TRUE")];
              [currentAttendee setRole: role];
              [currentAttendee setPartStat: partstat];
	      [newAttendees addObject: currentAttendee];
	    }
	  [component setAttendees: newAttendees];
	}
      else
	NSLog(@"Error scanning following JSON:\n%@", json);  
    }
}

- (void) _handleOrganizer
{
  NSString *owner, *login;
  BOOL isOwner, hasAttendees;

  //owner = [[self clientObject] ownerInContext: context];
  owner = [componentCalendar ownerInContext: context];
  login = [[context activeUser] login];
  isOwner = [owner isEqualToString: login];
  hasAttendees = [self hasAttendees];

#if 1
  if (hasAttendees)
    {
      SOGoUser *user;
      id identity;

      ASSIGN (organizer, [iCalPerson elementWithTag: @"organizer"]);
      [component setOrganizer: organizer];

      user = [SOGoUser userWithLogin: owner roles: nil];
      identity = [user defaultIdentity];
      [organizer setCn: [identity objectForKey: @"fullName"]]; 
      [organizer setEmail: [identity  objectForKey: @"email"]];

      if (!isOwner)
	{
	  NSString *currentEmail, *quotedEmail;
	  
	  currentEmail = [[[context activeUser] allEmails] objectAtIndex: 0];
          quotedEmail = [NSString stringWithFormat: @"\"MAILTO:%@\"",
                                  currentEmail];
          [organizer setValue: 0 ofAttribute: @"SENT-BY"
                           to: quotedEmail];
	}
    }
  else
    {
      organizer = nil;
    }
  [component setOrganizer: organizer];
#else 
  NSString *organizerEmail;
  BOOL hasOrganizer;
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
#endif
}

- (void) _handleCustomRRule: (iCalRecurrenceRule *) theRule

{
  int type, range;
  NSMutableArray *values;

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
      NSCalendarDate *date;
      SOGoUserDefaults *ud;
      NSDictionary *locale;

      ud = [[context activeUser] userDefaults];
      locale = [[self resourceManager]
                 localeForLanguageNamed: [ud language]];
      date = [NSCalendarDate dateWithString: [self range2]
			     calendarFormat: dateFormat
                                     locale: locale];
      [theRule setUntilDate: date];
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
      // DAILY (0)
      //
      // repeat1 holds the value of the frequency radio button:
      //   0 -> Every X days
      //   1 -> Every weekday
      //
      // repeat2 holds the value of X when repeat1 equals 0
      //
    case 0:
      {
	[theRule setFrequency: iCalRecurrenceFrequenceDaily];
	
	if ([[self repeat1] intValue] > 0)
	  {
	    [theRule setByDayMask: [iCalByDayMask byDayMaskWithWeekDays]];
	  }
	else
	  {
	    // Make sure we haven't received any junk....
	    if ([[self repeat2] intValue] < 1)
	      [self setRepeat2: @"1"];
	    
	    [theRule setInterval: [self repeat2]];
	  }
      }
      break;
      
      // WEEKLY (1)
      //
      // repeat1 holds the value of "Every X week(s)" 
      //
      // repeat2 holds which days are part of the recurrence rule
      //  1 -> Monday
      //  2 -> Tuesday .. and so on.
      //  The list is separated by commas, like: 1,3,4
    case 1:
      {
	if ([[self repeat1] intValue] > 0)
	  {
	    NSArray *v;
	    int c, day;
	    iCalWeekOccurrences days;

	    [theRule setFrequency: iCalRecurrenceFrequenceWeekly];
	    [theRule setInterval: [self repeat1]];

	    if ([[self repeat2] length])
	      {
		v = [[self repeat2] componentsSeparatedByString: @","];
		c = [v count];
		memset(days, 0, 7 * sizeof(iCalWeekOccurrence));
		
		while (c--)
		  {
		    day = [[v objectAtIndex: c] intValue];
		    if (day >= 0 && day <= 7)
		      days[day] = iCalWeekOccurrenceAll;
		  }
		[theRule setByDayMask: [iCalByDayMask byDayMaskWithDays: days]];
	      }
	  }
      }
      break;
      
      // MONTHLY (2)
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
	if ([[self repeat1] intValue] > 0)
	  {
	    [theRule setFrequency: iCalRecurrenceFrequenceMonthly];
	    [theRule setInterval: [self repeat1]];

	    // We recur on specific days...
	    if ([[self repeat2] intValue] == 0)
              {
                NSString *day;
                int occurence;
		
                day = [theRule iCalRepresentationForWeekDay: [[self repeat4] intValue]];
                occurence = [[self repeat3] intValue] + 1;
		if (occurence > 5)  // the first/second/third/fourth/fifth ..
		  occurence = -1;   // the last ..
                [theRule setSingleValue: [NSString stringWithFormat: @"%d%@",
                                                  occurence, day]
                                 forKey: @"byday"];
              }
            else
              {
                if ([[self repeat5] intValue] > 0)
                  {
                    values = [[[self repeat5]
                                componentsSeparatedByString: @","]
                               mutableCopy];
                    [theRule setValues: values
                             atIndex: 0 forKey: @"bymonthday"];
                    [values release];
                  }
 	      }
	  }
      }
      break;

      // YEARLY (3)
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
      // repeat5 holds the value of the OCCURENCE parameter (0 -> First, 1 -> Second .., 5 -> Last)
      // repeat6 holds the value of the DAY parameter (0 -> Sunday, 1 -> Monday, etc..)
      // repeat7 holds the value of the MONTH parameter (0 -> January, 1 -> February ... )
      // 
    case 3:
    default:
      {
	if ([[self repeat1] intValue] > 0)
	  {
	    [theRule setFrequency: iCalRecurrenceFrequenceYearly];
	    [theRule setInterval: [self repeat1]];

	    // We recur Every .. of ..
	    if ([[self repeat2] intValue] == 1)
	      {
                NSString *day;
                int occurence;
		
                day = [theRule iCalRepresentationForWeekDay: [[self repeat6] intValue]];
                occurence = [[self repeat5] intValue] + 1;
		if (occurence > 5)  // the first/second/third/fourth/fifth ..
		  occurence = -1;   // the last ..
                [theRule setSingleValue: [NSString stringWithFormat: @"%d%@",
                                                  occurence, day]
                                 forKey: @"byday"];
                [theRule setSingleValue: [NSString stringWithFormat: @"%d",
                                                   [[self repeat7] intValue] + 1]
                                 forKey: @"bymonth"];
	      }
	    else
	      {
		if ([[self repeat3] intValue] > 0
		    && [[self repeat4] intValue] > 0)
		  {
                    values = [[[self repeat3]
                                componentsSeparatedByString: @","]
                               mutableCopy];
		    [theRule setValues: values atIndex: 0
                                forKey: @"bymonthday"];
                    [values release];
                    [theRule setSingleValue: [NSString stringWithFormat: @"%d",
                                                       [[self repeat4] intValue] + 1]
                                     forKey: @"bymonth"];
		  }
	      }
	  }
      }
      break;
    }
}

- (void) _appendAttendees: (NSArray *) attendees
             toEmailAlarm: (iCalAlarm *) alarm
{
  NSMutableArray *aAttendees;
  int count, max;
  iCalPerson *currentAttendee, *aAttendee;

  max = [attendees count];
  aAttendees = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      currentAttendee = [attendees objectAtIndex: count];
      aAttendee = [iCalPerson elementWithTag: @"attendee"];
      [aAttendee setCn: [currentAttendee cn]];
      [aAttendee setEmail: [currentAttendee rfc822Email]];
      [aAttendees addObject: aAttendee];
    }
  [alarm setAttendees: aAttendees];
}

- (void) _appendOrganizerToEmailAlarm: (iCalAlarm *) alarm
{
  NSString *uid;
  NSDictionary *ownerIdentity;
  iCalPerson *aAttendee;

  uid = [[self clientObject] ownerInContext: context];
  ownerIdentity = [[SOGoUser userWithLogin: uid roles: nil]
                    defaultIdentity];
  aAttendee = [iCalPerson elementWithTag: @"attendee"];
  [aAttendee setCn: [ownerIdentity objectForKey: @"fullName"]];
  [aAttendee setEmail: [ownerIdentity objectForKey: @"email"]];
  [alarm addChild: aAttendee];
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
  [component setAttach: attachUrl];
  [component setAccessClass: classification];
  [component setCategories: categories];
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

  if (!reminder || [reminder caseInsensitiveCompare: @"-"] == NSOrderedSame)
    // No alarm selected -- if there was an unsupported alarm defined in
    // the event, it will be deleted.
    [component removeAllAlarms];
  else
    {
      iCalTrigger *aTrigger;
      iCalAlarm *anAlarm;
      NSString *aValue;
      unsigned int index;

      anAlarm = [iCalAlarm new];

      index = [reminderItems indexOfObject: reminder];

      aTrigger = [iCalTrigger elementWithTag: @"TRIGGER"];
      [aTrigger setValueType: @"DURATION"];
      [anAlarm setTrigger: aTrigger];
      
      aValue = [reminderValues objectAtIndex: index];
      if ([aValue length]) {
	// Predefined alarm
        [anAlarm setAction: @"DISPLAY"];
	[aTrigger setSingleValue: aValue forKey: @""];
      }
      else {
	// Custom alarm
        if ([reminderAction length] > 0 && [reminderUnit length] > 0)
          {
            [anAlarm setAction: [reminderAction uppercaseString]];
            if ([reminderAction isEqualToString: @"email"])
              {
                [anAlarm removeAllAttendees];
                if (reminderEmailAttendees)
                  [self _appendAttendees: [component attendees]
                        toEmailAlarm: anAlarm];
                if (reminderEmailOrganizer)
                  [self _appendOrganizerToEmailAlarm: anAlarm];
                [anAlarm setSummary: [component summary]];
                [anAlarm setComment: [component comment]];
              }
            
            if ([reminderReference caseInsensitiveCompare: @"BEFORE"] == NSOrderedSame)
              aValue = [NSString stringWithString: @"-P"];
            else
              aValue = [NSString stringWithString: @"P"];
            
            if ([reminderUnit caseInsensitiveCompare: @"MINUTES"] == NSOrderedSame ||
                [reminderUnit caseInsensitiveCompare: @"HOURS"] == NSOrderedSame)
              aValue = [aValue stringByAppendingString: @"T"];
            
            aValue = [aValue stringByAppendingFormat: @"%i%@",			 
                             [reminderQuantity intValue],
                             [reminderUnit substringToIndex: 1]];
            [aTrigger setSingleValue: aValue forKey: @""];
            [aTrigger setRelationType: reminderRelation];
          }
        else
          {
            [anAlarm release];
            anAlarm = nil;
          }
      }
      if (anAlarm)
        {
          [component removeAllAlarms];
          [component addToAlarms: anAlarm];
          [anAlarm release];
        }
    }
  
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
	      [rule setByDayMask: [iCalByDayMask byDayMaskWithWeekDays]];
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
  BOOL isOrganizer;

  // We determine if we're the organizer of the component beeing modified.
  // If we created an event on behalf of someone else -userIsOrganizer will
  // return us YES. This is OK because we're in the SENT-BY. But, Alice
  // should be able to accept/decline an invitation if she created the event
  // in Bob's calendar and added herself in the attendee list.
  isOrganizer = [component userIsOrganizer: ownerUser];

  if (isOrganizer)
    isOrganizer = ![ownerUser hasEmail: [[component organizer] sentBy]];

  if ([componentCalendar isKindOfClass: [SOGoWebAppointmentFolder class]]
      || ([component userIsAttendee: ownerUser]
	  && !isOrganizer
	  // Lightning does not manage participation status within tasks,
	  // so we also ignore the participation status of tasks in the
	  // web interface.
	  && ![[component tag] isEqualToString: @"VTODO"]))
    toolbarFilename = @"SOGoEmpty.toolbar";
  else
    {
      if ([clientObject isKindOfClass: [SOGoAppointmentObject class]]
	  || [clientObject isKindOfClass: [SOGoAppointmentOccurence class]])
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
  NSString *toolbarFilename;

  sm = [SoSecurityManager sharedSecurityManager];

  if (![sm validatePermission: SOGoCalendarPerm_ModifyComponent
                     onObject: clientObject
                    inContext: context])
    toolbarFilename = [self _toolbarForOwner: ownerUser
                             andClientObject: clientObject];
  else
    toolbarFilename = @"SOGoEmpty.toolbar";

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


- (int) ownerIsAttendee: (SOGoUser *) ownerUser
        andClientObject: (SOGoContentObject
                          <SOGoComponentOccurence> *) clientObject
{
  BOOL isOrganizer;
  iCalPerson *ownerAttendee;
  int rc;

  rc = 0;

  isOrganizer = [component userIsOrganizer: ownerUser];
  if (isOrganizer)
    isOrganizer = ![ownerUser hasEmail: [[component organizer] sentBy]];

  if (!isOrganizer && ![[component tag] isEqualToString: @"VTODO"])
    {
      ownerAttendee = [component userAsAttendee: ownerUser];
      if (ownerAttendee)
        {
          if ([[ownerAttendee rsvp] isEqualToString: @"true"])
            rc = 1;
          else
            rc = 2;
        }
    }

  return rc;
}

- (int) delegateIsAttendee: (SOGoUser *) ownerUser
           andClientObject: (SOGoContentObject
                             <SOGoComponentOccurence> *) clientObject
{
  SoSecurityManager *sm;
  iCalPerson *ownerAttendee;
  int rc;

  rc = 0;

  sm = [SoSecurityManager sharedSecurityManager];
  if (![sm validatePermission: SOGoCalendarPerm_ModifyComponent
                     onObject: clientObject
                    inContext: context])
    rc = [self ownerIsAttendee: ownerUser
               andClientObject: clientObject];
  else if (![sm validatePermission: SOGoCalendarPerm_RespondToComponent
                          onObject: clientObject
                         inContext: context])
    {
      ownerAttendee = [component userAsAttendee: ownerUser];
      if ([[ownerAttendee rsvp] isEqualToString: @"true"]
          && ![component userIsOrganizer: ownerUser])
        rc = 1;
      else
        rc = 2;
    }
  else
    rc = 2; // not invited, just RO

  return rc;
}

- (int) getEventRWType
{
  SOGoContentObject <SOGoComponentOccurence> *clientObject;
  SOGoUser *ownerUser;
  int rc;

  clientObject = [self clientObject];
  ownerUser
    = [SOGoUser userWithLogin: [clientObject ownerInContext: context]];
  if ([componentCalendar isKindOfClass: [SOGoWebAppointmentFolder class]])
    rc = 2;
  else
    {
      if ([ownerUser isEqual: [context activeUser]])
        rc = [self ownerIsAttendee: ownerUser
                   andClientObject: clientObject];
      else
        rc = [self delegateIsAttendee: ownerUser
                      andClientObject: clientObject];
    }

  return rc;
}

- (BOOL) eventIsReadOnly
{
  return [self getEventRWType] != 0;
}

- (NSString *) emailAlarmsEnabled
{
  SOGoSystemDefaults *sd;

  sd = [SOGoSystemDefaults sharedSystemDefaults];

  return ([sd enableEMailAlarms]
          ? @"true"
          : @"false");
}

- (BOOL) userHasRSVP
{
  return ([self getEventRWType] == 1);
}

- (NSString *) currentAttendeeClasses
{
  NSMutableArray *classes;
  iCalPerson *ownerAttendee;
  SOGoUser *ownerUser;
  NSString *role, *partStat;
  SOGoCalendarComponent *co;

  classes = [NSMutableArray arrayWithCapacity: 5];

  /* rsvp class */
  if (![[attendee rsvp] isEqualToString: @"true"])
    [classes addObject: @"not-rsvp"];

  /* partstat class */
  partStat = [[attendee partStat] lowercaseString];
  if (![partStat length])
    partStat = @"no-partstat";
  [classes addObject: partStat];

  /* role class */
  role = [[attendee role] lowercaseString];
  if (![partStat length])
    role = @"no-role";
  [classes addObject: role];

  /* attendee class */
  if ([[attendee delegatedFrom] length] > 0)
    [classes addObject: @"delegate"];

  /* current attendee class */
  co = [self clientObject];
  ownerUser = [SOGoUser userWithLogin: [co ownerInContext: context]];
  ownerAttendee = [component userAsAttendee: ownerUser];
  if (attendee == ownerAttendee)
    [classes addObject: @"attendeeUser"];

  return [classes componentsJoinedByString: @" "];
}

- (NSString *) ownerLogin
{
  return [[self clientObject] ownerInContext: context];
}

@end
