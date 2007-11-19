/* UIxComponentEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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
#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoPermissions.h>

#import "UIxComponent+Scheduler.h"

#import "UIxComponentEditor.h"

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
      attendeesNames = nil;
      attendeesUIDs = nil;
      attendeesEmails = nil;
      calendarList = nil;
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
  [comment release];
  [priority release];
  [categories release];
  [cycle release];
  [cycleEnd release];
  [url release];
  [attendeesNames release];
  [attendeesUIDs release];
  [attendeesEmails release];
  [calendarList release];

  [super dealloc];
}

- (void) _loadAttendees
{
  NSEnumerator *attendees;
  iCalPerson *currentAttendee;
  NSMutableString *names, *uids, *emails;
  NSString *uid;
  LDAPUserManager *um;

  names = [NSMutableString new];
  uids = [NSMutableString new];
  emails = [NSMutableString new];
  um = [LDAPUserManager sharedUserManager];

  attendees = [[component attendees] objectEnumerator];
  currentAttendee = [attendees nextObject];
  while (currentAttendee)
    {
      [names appendFormat: @"%@,", [currentAttendee cn]];
      [emails appendFormat: @"%@,", [currentAttendee rfc822Email]];
      uid = [um getUIDForEmail: [currentAttendee rfc822Email]];
      if (uid != nil)
	[uids appendFormat: @"%@,", uid];
      else
	[uids appendString: @","];
      currentAttendee = [attendees nextObject];
    }

  if ([names length] > 0)
    {
      ASSIGN (attendeesNames, [names substringToIndex: [names length] - 1]);
      ASSIGN (attendeesUIDs, [uids substringToIndex: [uids length] - 1]);
      ASSIGN (attendeesEmails,
	      [emails substringToIndex: [emails length] - 1]);
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

/* warning: we use this method which will be triggered by the template system
   when the page is instantiated, but we should find another and cleaner way of
   doing this... for example, when the clientObject is set */
- (void) setComponent: (iCalRepeatableEntityObject *) newComponent
{
//   iCalRecurrenceRule *rrule;
  SOGoObject *co;

  if (!component)
    {
      component = newComponent;

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
	  ASSIGN (categories, [[component categories] commaSeparatedValues]);
	  ASSIGN (organizer, [component organizer]);
	  [self _loadCategories];
	  [self _loadAttendees];
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

  tag = [[self clientObject] componentTag];

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

- (BOOL) hasOrganizer
{
  return (![organizer isVoid]);
}

- (NSString *) organizerName
{
  return [organizer mailAddress];
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
  SOGoAppointmentFolder *currentCalendar;
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
      allCalendars = [[calendarParent subFolders] objectEnumerator];
      while ((currentCalendar = [allCalendars nextObject]))
	if (![sm validatePermission: perm
		 onObject: currentCalendar
		 inContext: context])
	  [calendarList addObject: currentCalendar];
    }

  return calendarList;
}

- (NSString *) calendarsFoldersList
{
  NSArray *calendars;

  calendars = [[self calendarList] valueForKey: @"nameInContainer"];

  return [calendars componentsJoinedByString: @","];
}

- (SOGoAppointmentFolder *) componentCalendar
{
  SOGoAppointmentFolder *calendar;

  calendar = [[self clientObject] container];
  
  return calendar;
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
//   AgenorUserManager *um;
//   NSMutableString *iCalRep;
//   NSString *s;

//   um = [AgenorUserManager sharedUserManager];
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
  SOGoUser *activeUser;
  NSDictionary *primaryIdentity;

  organizerEmail = [[component organizer] email];
  if ([organizerEmail length] == 0)
    {
      if ([[component attendees] count] > 0)
	{
	  ASSIGN (organizer, [iCalPerson elementWithTag: @"organizer"]);
	  activeUser = [context activeUser];
	  primaryIdentity = [activeUser primaryIdentity];
	  [organizer setCn: [activeUser cn]];
	  [organizer setEmail: [primaryIdentity objectForKey: @"email"]];
	  [component setOrganizer: organizer];
	}
    }
  else
    {
      if ([[component attendees] count] == 0)
	{
	  ASSIGN (organizer, [iCalPerson elementWithTag: @"organizer"]);
	  [component setOrganizer: organizer];
	}
    }
}

- (void) takeValuesFromRequest: (WORequest *) _rq
                     inContext: (WOContext *) _ctx
{
  NSCalendarDate *now;
  SOGoCalendarComponent *clientObject;

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
      [component setUid: [clientObject nameInContainer]];
      [component setCreated: now];
      [component setTimeStampAsDate: now];
    }
  [component setPriority: priority];
  [component setLastModified: now];
}

#warning the following methods probably share some code...
- (NSString *) _toolbarForOwner: (SOGoUser *) ownerUser
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
      if ([component isKindOfClass: [iCalEvent class]])
	toolbarFilename = @"SOGoAppointmentObject.toolbar";
      else
	toolbarFilename = @"SOGoTaskObject.toolbar";
    }

  return toolbarFilename;
}

- (NSString *) _toolbarForDelegate: (SOGoUser *) ownerUser
{
  SOGoCalendarComponent *clientObject;
  SoSecurityManager *sm;
  NSString *toolbarFilename, *adminToolbar;
  iCalPersonPartStat participationStatus;

  clientObject = [self clientObject];

  if ([component isKindOfClass: [iCalEvent class]])
    adminToolbar = @"SOGoAppointmentObject.toolbar";
  else
    adminToolbar = @"SOGoTaskObject.toolbar";

  sm = [SoSecurityManager sharedSecurityManager];
  if ([[component attendees] count])
    {
      if ([component userIsOrganizer: ownerUser]
	  && ![sm validatePermission: SOGoCalendarPerm_ModifyComponent
		  onObject: clientObject
		  inContext: context])
	toolbarFilename = adminToolbar;
      else if ([component userIsParticipant: ownerUser]
	       && ![sm validatePermission: SOGoCalendarPerm_RespondToComponent
		       onObject: clientObject
		       inContext: context])
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
    }
  else
    {
      if (![sm validatePermission: SOGoCalendarPerm_ModifyComponent
	       onObject: clientObject
	       inContext: context])
	toolbarFilename = adminToolbar;
      else
	toolbarFilename = @"SOGoComponentClose.toolbar";
    }

  return toolbarFilename;
}

- (NSString *) toolbar
{
  SOGoCalendarComponent *clientObject;
  NSString *toolbarFilename;
  SOGoUser *ownerUser;

  clientObject = [self clientObject];
  ownerUser = [SOGoUser userWithLogin: [clientObject ownerInContext: context]
			roles: nil];

  if ([ownerUser isEqual: [context activeUser]])
    toolbarFilename = [self _toolbarForOwner: ownerUser];
  else
    toolbarFilename = [self _toolbarForDelegate: ownerUser];


  return toolbarFilename;
}

@end
