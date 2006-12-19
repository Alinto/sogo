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
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSURL.h>

#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRepeatableEntityObject.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/NSString+NGCards.h>
#import <NGCards/NSCalendarDate+NGCards.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WORequest.h>

#import <SOGo/AgenorUserManager.h>
#import <SOGo/SOGoUser.h>
#import <SOGoUI/SOGoDateFormatter.h>
#import <SoObjects/Appointments/SOGoAppointmentObject.h>
#import <SoObjects/Appointments/SOGoTaskObject.h>

#import "UIxComponent+Agenor.h"

#import "UIxComponentEditor.h"

@implementation UIxComponentEditor

- (id) init
{
  if ((self = [super init]))
    {
      [self setPrivacy: @"PUBLIC"];
      [self setCheckForConflicts: NO];
      [self setIsCycleEndNever];
      componentOwner = @"";
      componentLoaded = NO;
    }

  return self;
}

- (void) dealloc
{
  [iCalString release];
  [errorText release];
  [item release];
  [startDate release];
  [cycleUntilDate release];
  [title release];
  [location release];
  [organizer release];
  [comment release];
  [participants release];
  [resources release];
  [priority release];
  [categories release];
  [cycle release];
  [cycleEnd release];
  [url release];

  [super dealloc];
}

/* accessors */

- (void) setItem: (id) _item
{
  ASSIGN(item, _item);
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
  return [self labelForKey: [NSString stringWithFormat: @"privacy_%@", item]];
}

- (NSString *) itemStatusText
{
  return [self labelForKey: [NSString stringWithFormat: @"status_%@", item]];
}

- (void) setErrorText: (NSString *) _txt
{
  ASSIGNCOPY(errorText, _txt);
}

- (NSString *) errorText
{
  return errorText;
}

- (BOOL) hasErrorText
{
  return [errorText length] > 0 ? YES : NO;
}

- (void) setStartDate: (NSCalendarDate *) _date
{
  ASSIGN(startDate, _date);
}

- (NSCalendarDate *) startDate
{
  return startDate;
}

- (void) setTitle: (NSString *) _value
{
  ASSIGNCOPY(title, _value);
}

- (NSString *) title
{
  return title;
}

- (void) setUrl: (NSString *) _url
{
  ASSIGNCOPY(url, _url);
}

- (NSString *) url
{
  return url;
}

- (void) setLocation: (NSString *) _value
{
  ASSIGNCOPY(location, _value);
}

- (NSString *) location
{
  return location;
}

- (void) setComment: (NSString *) _value
{
  ASSIGNCOPY(comment, _value);
}

- (NSString *) comment
{
  return comment;
}

- (NSArray *) categoryItems
{
  // TODO: make this configurable?
  /*
   Tasks categories will be modified as follow :
   – by default (a simple logo or no logo at all),
   – task,
   – outside,
   – meeting,
   – holidays,
   – phone.
  */
  static NSArray *categoryItems = nil;
  
  if (!categoryItems)
    {
      categoryItems = [NSArray arrayWithObjects: @"APPOINTMENT",
                               @"NOT IN OFFICE",
                               @"MEETING",
                               @"HOLIDAY",
                               @"PHONE CALL",
                               nil];
      [categoryItems retain];
    }

  return categoryItems;
}

- (void) setCategories: (NSArray *) _categories
{
  ASSIGN(categories, _categories);
}

- (NSArray *) categories
{
  return categories;
}

- (NSString *) itemCategoryText
{
  return [[self labelForKey: item] stringByEscapingHTMLString];
}

/* priorities */

- (NSArray *) priorities
{
  /* 0 == undefined
     5 == normal
     1 == high
  */
  static NSArray *priorities = nil;

  if (!priorities)
    {
      priorities = [NSArray arrayWithObjects:@"0", @"5", @"1", nil];
      [priorities retain];
    }

  return priorities;
}

- (void) setPriority: (NSString *) _priority
{
  ASSIGN(priority, _priority);
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
  ASSIGN(privacy, _privacy);
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
  ASSIGN(status, _status);
}

- (NSString *) status
{
  return status;
}

- (void) setParticipants: (NSArray *) _parts
{
  ASSIGN(participants, _parts);
}

- (NSArray *) participants
{
  return participants;
}

- (void) setResources: (NSArray *) _res
{
  ASSIGN(resources, _res);
}

- (NSArray *) resources
{
  return resources;
}

- (void) setCheckForConflicts: (BOOL) _checkForConflicts
{
  checkForConflicts = _checkForConflicts;
}

- (BOOL) checkForConflicts
{
  return checkForConflicts;
}

- (NSArray *) cycles
{
  NSBundle *bundle;
  NSString *path;
  static NSArray *cycles = nil;
  
  if (!cycles)
    {
      bundle = [NSBundle bundleForClass:[self class]];
      path   = [bundle pathForResource:@"cycles" ofType:@"plist"];
      NSAssert(path != nil, @"Cannot find cycles.plist!");
      cycles = [[NSArray arrayWithContentsOfFile:path] retain];
      NSAssert(cycles != nil, @"Cannot instantiate cycles from cycles.plist!");
    }

  return cycles;
}

- (void) setCycle: (NSDictionary *) _cycle
{
  ASSIGN(cycle, _cycle);
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
  
  key = [(NSDictionary *)item objectForKey:@"label"];

  return [self labelForKey:key];
}

- (void) setCycleUntilDate: (NSCalendarDate *) _cycleUntilDate
{
  NSCalendarDate *until;

  /* copy hour/minute/second from startDate */
  until = [_cycleUntilDate hour: [startDate hourOfDay]
                           minute: [startDate minuteOfHour]
                           second: [startDate secondOfMinute]];
  [until setTimeZone: [startDate timeZone]];
  ASSIGN(cycleUntilDate, until);
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
  ruleRep = [cycle objectForKey:@"rule"];
  rule = [iCalRecurrenceRule recurrenceRuleWithICalRepresentation:ruleRep];

  if (cycleUntilDate && [self isCycleEndUntil])
    [rule setUntilDate:cycleUntilDate];

  return rule;
}

- (void) adjustCycleControlsForRRule: (iCalRecurrenceRule *) _rrule
{
  NSDictionary *c;
  NSCalendarDate *until;
  
  c = [self cycleMatchingRRule:_rrule];
  [self setCycle:c];

  until = [[[_rrule untilDate] copy] autorelease];
  if (!until)
    until = startDate;
  else
    [self setIsCycleEndUntil];

  [until setTimeZone:[[self clientObject] userTimeZone]];
  [self setCycleUntilDate:until];
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
    cr = [c objectForKey:@"rule"];
    if ([cr isEqualToString:cycleRep])
      return c;
  }
  [self warnWithFormat:@"No default cycle for rrule found! -> %@", _rrule];
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
  ASSIGNCOPY(cycleEnd, _cycleEnd);
}

- (NSString *) cycleEnd
{
  return cycleEnd;
}

- (BOOL) isCycleEndUntil
{
  return (cycleEnd &&
          [cycleEnd isEqualToString:@"cycle_end_until"]);
}

- (void) setIsCycleEndUntil
{
  [self setCycleEnd:@"cycle_end_until"];
}

- (void) setIsCycleEndNever
{
  [self setCycleEnd:@"cycle_end_never"];
}

/* helpers */
- (NSFormatter *) titleDateFormatter
{
  SOGoDateFormatter *fmt;
  
  fmt = [[SOGoDateFormatter alloc] initWithLocale: [self locale]];
  [fmt autorelease];
  [fmt setFullWeekdayNameAndDetails];

  return fmt;
}

- (NSString *) completeURIForMethod: (NSString *) _method
{
  NSString *uri;
  NSRange r;
    
  uri = [[[self context] request] uri];
    
  /* first: identify query parameters */
  r = [uri rangeOfString:@"?" options:NSBackwardsSearch];
  if (r.length > 0)
    uri = [uri substringToIndex:r.location];
    
  /* next: append trailing slash */
  if (![uri hasSuffix:@"/"])
    uri = [uri stringByAppendingString:@"/"];
  
  /* next: append method */
  uri = [uri stringByAppendingString:_method];
    
  /* next: append query parameters */
  return [self completeHrefForMethod:uri];
}

- (BOOL) isWriteableClientObject
{
  return [[self clientObject] 
	        respondsToSelector:@selector(saveContentString:)];
}

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) _rq
                           inContext: (WOContext*) _c
{
  return YES;
}

- (BOOL) containsConflict: (id) _component
{
  [self subclassResponsibility: _cmd];

  return NO;
}

/* access */

#if 0
- (iCalPerson *) getOrganizer
{
  iCalPerson *p;
  NSString *emailProp;
  
  emailProp = [@"MAILTO:" stringByAppendingString:[self emailForUser]];
  p = [[[iCalPerson alloc] init] autorelease];
  [p setEmail:emailProp];
  [p setCn:[self cnForUser]];
  return p;
}
#endif

- (BOOL) isMyComponent
{
  // TODO: this should check a set of emails against the SoUser
  return ([[organizer rfc822Email] isEqualToString: [self emailForUser]]);
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

/* subclasses */
- (NSCalendarDate *) newStartDate
{
  NSCalendarDate *newStartDate, *now;
  int hour;

  newStartDate = [self selectedDate];
  if ([[self queryParameterForKey: @"hm"] length] == 0)
    {
      now = [NSCalendarDate calendarDate];
      [now setTimeZone: [[self clientObject] userTimeZone]];
      if (!([[now hour: 8 minute: 0] earlierDate: newStartDate] == newStartDate))
        {
          hour = [now hourOfDay];
          if (hour < 8)
            newStartDate = [now hour: 8 minute: 0];
          else if (hour > 18)
            newStartDate = [[now tomorrow] hour: 8 minute: 0];
          else
            newStartDate = now;
        }
    }

  return newStartDate;
}

- (void) loadValuesFromComponent: (iCalRepeatableEntityObject *) component
{
  iCalRecurrenceRule *rrule;
  NSTimeZone *uTZ;
  SOGoObject *co;

  co = [self clientObject];
  componentOwner = [co ownerInContext: nil];
  componentLoaded = YES;

  startDate = [component startDate];
//   if ((startDate = [component startDate]) == nil)
//     startDate = [[NSCalendarDate date] hour:11 minute:0];
  uTZ = [co userTimeZone];
  if (startDate)
    {
      [startDate setTimeZone: uTZ];
      [startDate retain];
    }

  title        = [[component summary] copy];
  location     = [[component location] copy];
  comment      = [[component comment] copy];
  url          = [[[component url] absoluteString] copy];
  privacy      = [[component accessClass] copy];
  priority     = [[component priority] copy];
  status       = [[component status] copy];
  categories   = [[[component categories] commaSeparatedValues] retain];
  organizer    = [[component organizer] retain];
  participants = [[component participants] retain];
  resources    = [[component resources] retain];

  /* cycles */
  if ([component isRecurrent])
    {
      rrule = [[component recurrenceRules] objectAtIndex: 0];
      [self adjustCycleControlsForRRule: rrule];
    }
}

- (NSString *) iCalStringTemplate
{
  [self subclassResponsibility: _cmd];

  return @"";
}

- (NSString *) iCalParticipantsAndResourcesStringFromQueryParameters
{
  NSString *s;
  
  s = [self iCalParticipantsStringFromQueryParameters];
  return [s stringByAppendingString:
              [self iCalResourcesStringFromQueryParameters]];
}

- (NSString *) iCalParticipantsStringFromQueryParameters
{
  static NSString *iCalParticipantString = \
    @"ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;CN=\"%@\":MAILTO:%@\r\n";
  
  return [self iCalStringFromQueryParameter: @"ps"
               format: iCalParticipantString];
}

- (NSString *) iCalResourcesStringFromQueryParameters
{
  static NSString *iCalResourceString = \
    @"ATTENDEE;ROLE=NON-PARTICIPANT;CN=\"%@\":MAILTO:%@\r\n";

  return [self iCalStringFromQueryParameter: @"rs"
               format: iCalResourceString];
}

- (NSString *) iCalStringFromQueryParameter: (NSString *) _qp
                                     format: (NSString *) _format
{
  AgenorUserManager *um;
  NSMutableString *iCalRep;
  NSString *s;

  um = [AgenorUserManager sharedUserManager];
  iCalRep = (NSMutableString *)[NSMutableString string];
  s = [self queryParameterForKey:_qp];
  if(s && [s length] > 0) {
    NSArray *es;
    unsigned i, count;
    
    es = [s componentsSeparatedByString:@","];
    count = [es count];
    for(i = 0; i < count; i++) {
      NSString *email, *cn;
      
      email = [es objectAtIndex:i];
      cn = [um getCNForUID:[um getUIDForEmail:email]];
      [iCalRep appendFormat:_format, cn, email];
    }
  }
  return iCalRep;
}

- (NSString *) iCalOrganizerString
{
  return [NSString stringWithFormat: @"ORGANIZER;CN=\"%@\":MAILTO:%@\r\n",
                   [self cnForUser], [self emailForUser]];
}

- (NSString *) saveUrl
{
  [self subclassResponsibility: _cmd];

  return @"";
}

- (NSException *) validateObjectForStatusChange
{
  id co;

  co = [self clientObject];
  if (![co
         respondsToSelector: @selector(changeParticipationStatus:inContext:)])
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
                        reason:
                          @"method cannot be invoked on the specified object"];

  return nil;
}

/* contact editor compatibility */

- (void) setICalString: (NSString *) _s
{
  ASSIGNCOPY(iCalString, _s);
}

- (NSString *) iCalString
{
  return iCalString;
}


- (NSArray *) availableCalendars
{
  NSEnumerator *rawContacts;
  NSString *list, *currentId;
  NSMutableArray *calendars;
  SOGoUser *user;

  calendars = [NSMutableArray array];

  user = [context activeUser];
  list = [[user userDefaults] stringForKey: @"calendaruids"];
  if ([list length] == 0)
    list = [self shortUserNameForDisplay];

  rawContacts
    = [[list componentsSeparatedByString: @","] objectEnumerator];
  currentId = [rawContacts nextObject];
  while (currentId)
    {
      if ([currentId hasPrefix: @"-"])
        [calendars addObject: [currentId substringFromIndex: 1]];
      else
        [calendars addObject: currentId];
      currentId = [rawContacts nextObject];
    }

  return calendars;
}

- (NSString *) componentOwner
{
  return componentOwner;
}

- (NSString *) urlButtonClasses
{
  NSString *classes;

  if ([url length])
    classes = @"button";
  else
    classes = @"button _disabled";

  return classes;
}

- (NSString *) _toolbarForCalObject: (iCalEntityObject *) calObject
{
  NSString *filename, *myEmail;
  iCalPerson *person;
  NSEnumerator *persons;
  iCalPersonPartStat myParticipationStatus;
  BOOL found;

  myEmail = [[[self context] activeUser] email];
  if ([[organizer rfc822Email] isEqualToString: myEmail])
    filename = @"SOGoAppointmentObject.toolbar";
  else
    {
      filename = @"";
      found = NO;
      persons = [participants objectEnumerator];
      person = [persons nextObject];
      while (person && !found)
        if ([[person rfc822Email] isEqualToString: myEmail])
          {
            found = YES;
            myParticipationStatus = [person participationStatus];
            if (myParticipationStatus == iCalPersonPartStatAccepted)
              filename = @"SOGoAppointmentObjectDecline.toolbar";
            else if (myParticipationStatus == iCalPersonPartStatDeclined)
              filename = @"SOGoAppointmentObjectAccept.toolbar";
            else
              filename = @"SOGoAppointmentObjectAcceptOrDecline.toolbar";
          }
        else
          person = [persons nextObject];
    }

  return filename;
}

- (NSString *) toolbar
{
  NSString *filename;
  iCalEntityObject *calObject;
  id co;

  if (componentLoaded)
    {
      co = [self clientObject];
      if ([co isKindOfClass: [SOGoAppointmentObject class]])
        {
          calObject = (iCalEntityObject *) [co event];
          filename = [self _toolbarForCalObject: calObject];
        }
      else if ([co isKindOfClass: [SOGoTaskObject class]])
        {
          calObject = (iCalEntityObject *) [co task];
          filename = [self _toolbarForCalObject: calObject];
        }
      else
        filename = @"";
    }
  else
    filename = @"";

  return filename;
}

@end
