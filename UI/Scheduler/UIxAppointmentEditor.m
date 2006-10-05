/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <NGCards/NSString+NGCards.h>
#import <NGCards/NSCalendarDate+NGCards.h>

#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGoUI/UIxComponent.h>

/* TODO: CLEAN UP */

@class NSString;
@class iCalPerson;
@class iCalRecurrenceRule;

@interface UIxAppointmentEditor : UIxComponent
{
  NSString *iCalString;
  NSString *errorText;
  id item;
  
  /* individual values */
  NSCalendarDate *startDate;
  NSCalendarDate *endDate;
  NSCalendarDate *cycleUntilDate;
  NSString *title;
  NSString *location;
  NSString *comment;
  iCalPerson *organizer;
  NSArray *participants;     /* array of iCalPerson's */
  NSArray *resources;        /* array of iCalPerson's */
  NSString *priority;
  NSArray *categories;
  NSString *accessClass;
  BOOL isPrivate;         /* default: NO */
  BOOL checkForConflicts; /* default: NO */
  NSDictionary *cycle;
  NSString *cycleEnd;
}

- (NSString *)iCalStringTemplate;
- (NSString *)iCalString;

- (void)setIsPrivate:(BOOL)_yn;
- (void)setAccessClass:(NSString *)_class;

- (void)setCheckForConflicts:(BOOL)_checkForConflicts;
- (BOOL)checkForConflicts;

- (BOOL)hasCycle;
- (iCalRecurrenceRule *)rrule;
- (void)adjustCycleControlsForRRule:(iCalRecurrenceRule *)_rrule;
- (NSDictionary *)cycleMatchingRRule:(iCalRecurrenceRule *)_rrule;

- (BOOL)isCycleEndUntil;
- (void)setIsCycleEndUntil;
- (void)setIsCycleEndNever;

- (NSString *)_completeURIForMethod:(NSString *)_method;

- (NSArray *)getICalPersonsFromFormValues:(NSArray *)_values
  treatAsResource:(BOOL)_isResource;

- (NSString *)iCalParticipantsAndResourcesStringFromQueryParameters;
- (NSString *)iCalParticipantsStringFromQueryParameters;
- (NSString *)iCalResourcesStringFromQueryParameters;
- (NSString *)iCalStringFromQueryParameter:(NSString *)_qp
              format:(NSString *)_format;
- (NSString *)iCalOrganizerString;

- (id)acceptOrDeclineAction:(BOOL)_accept;

@end

#import "common.h"
#import <NGCards/NGCards.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <SOGoUI/SOGoDateFormatter.h>
#import <SOGo/AgenorUserManager.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentObject.h>
#import "UIxComponent+Agenor.h"

@implementation UIxAppointmentEditor

+ (int)version {
  return [super version] + 0 /* v2 */;
}

+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)init {
  self = [super init];
  if(self) {
    [self setIsPrivate:NO];
    [self setCheckForConflicts:NO];
    [self setIsCycleEndNever];
  }
  return self;
}

- (void)dealloc {
  [iCalString release];
  [errorText release];
  [item release];

  [startDate release];
  [endDate release];
  [cycleUntilDate release];
  [title release];
  [location release];
  [organizer release];
  [comment release];
  [participants release];
  [resources release];
  [priority release];
  [categories release];
  [accessClass release];
  [cycle release];
  [cycleEnd release];
  [super dealloc];
}

/* accessors */

- (void)setItem:(id)_item {
  ASSIGN(item, _item);
}
- (id)item {
  return item;
}

- (void)setErrorText:(NSString *)_txt {
  ASSIGNCOPY(errorText, _txt);
}
- (NSString *)errorText {
  return errorText;
}
- (BOOL)hasErrorText {
  return [errorText length] > 0 ? YES : NO;
}

- (NSFormatter *)titleDateFormatter {
  SOGoDateFormatter *fmt;
  
  fmt = [[[SOGoDateFormatter alloc] initWithLocale:[self locale]] autorelease];
  [fmt setFullWeekdayNameAndDetails];
  return fmt;
}

- (void)setAptStartDate:(NSCalendarDate *)_date {
  ASSIGN(startDate, _date);
}
- (NSCalendarDate *)aptStartDate {
  return startDate;
}
- (void)setAptEndDate:(NSCalendarDate *)_date {
  ASSIGN(endDate, _date);
}
- (NSCalendarDate *)aptEndDate {
  return endDate;
}

- (void)setTitle:(NSString *)_value {
  ASSIGNCOPY(title, _value);
}
- (NSString *)title {
  return title;
}
- (void)setLocation:(NSString *)_value {
  ASSIGNCOPY(location, _value);
}
- (NSString *)location {
  return location;
}
- (void)setComment:(NSString *)_value {
  ASSIGNCOPY(comment, _value);
}
- (NSString *)comment {
  return comment;
}

- (void)setParticipants:(NSArray *)_parts {
  ASSIGN(participants, _parts);
}
- (NSArray *)participants {
  return participants;
}
- (void)setResources:(NSArray *)_res {
  ASSIGN(resources, _res);
}
- (NSArray *)resources {
  return resources;
}

/* priorities */

- (NSArray *)priorities {
  /* 0 == undefined
     5 == normal
     1 == high
  */
  static NSArray *priorities = nil;

  if (!priorities)
    priorities = [[NSArray arrayWithObjects:@"0", @"5", @"1", nil] retain];
  return priorities;
}

- (NSString *)itemPriorityText {
  NSString *key;
  
  key = [NSString stringWithFormat:@"prio_%@", item];
  return [self labelForKey:key];
}

- (void)setPriority:(NSString *)_priority {
  ASSIGN(priority, _priority);
}
- (NSString *)priority {
  return priority;
}


/* categories */

- (NSArray *)categoryItems {
  // TODO: make this configurable?
  /*
   Tasks categories will be modified as follow :
   – by default (a simple logo or no logo at all),
   – appointment,
   – outside,
   – meeting,
   – holidays,
   – phone.
  */
  static NSArray *categoryItems = nil;
  
  if (!categoryItems) {
    categoryItems = [[NSArray arrayWithObjects:@"APPOINTMENT",
                                               @"NOT IN OFFICE",
                                               @"MEETING",
                                               @"HOLIDAY",
                                               @"PHONE CALL",
                                               nil] retain];
  }
  return categoryItems;
}

- (NSString *) itemCategoryText {
  return [[self labelForKey: item] stringByEscapingHTMLString];
}

- (void)setCategories:(NSArray *)_categories {
  ASSIGN(categories, _categories);
}

- (NSArray *)categories {
  return categories;
}

/* class */

#if 0
- (NSArray *)accessClassItems {
  static NSArray classItems = nil;
  
  if (!classItems) {
    return [[NSArray arrayWithObjects:@"PUBLIC", @"PRIVATE", nil] retain];
  }
  return classItems;
}
#endif

- (void)setAccessClass:(NSString *)_class {
  ASSIGN(accessClass, _class);
}
- (NSString *)accessClass {
  return accessClass;
}

- (void)setIsPrivate:(BOOL)_yn {
  if (_yn)
    [self setAccessClass:@"PRIVATE"];
  else
    [self setAccessClass:@"PUBLIC"];
  isPrivate = _yn;
}
- (BOOL)isPrivate {
  return isPrivate;
}

- (void)setCheckForConflicts:(BOOL)_checkForConflicts {
  checkForConflicts = _checkForConflicts;
}
- (BOOL)checkForConflicts {
  return checkForConflicts;
}

- (NSArray *)cycles {
  static NSArray *cycles = nil;
  
  if (!cycles) {
    NSBundle *bundle;
    NSString *path;

    bundle = [NSBundle bundleForClass:[self class]];
    path   = [bundle pathForResource:@"cycles" ofType:@"plist"];
    NSAssert(path != nil, @"Cannot find cycles.plist!");
    cycles = [[NSArray arrayWithContentsOfFile:path] retain];
    NSAssert(cycles != nil, @"Cannot instantiate cycles from cycles.plist!");
  }
  return cycles;
}

- (void)setCycle:(NSDictionary *)_cycle {
  ASSIGN(cycle, _cycle);
}
- (NSDictionary *)cycle {
  return cycle;
}
- (BOOL)hasCycle {
  [self debugWithFormat:@"cycle: %@", cycle];
  if (![cycle objectForKey:@"rule"])
    return NO;
  return YES;
}
- (NSString *)cycleLabel {
  NSString *key;
  
  key = [(NSDictionary *)item objectForKey:@"label"];
  return [self labelForKey:key];
}


- (void)setCycleUntilDate:(NSCalendarDate *)_cycleUntilDate {
  NSCalendarDate *until;

  /* copy hour/minute/second from startDate */
  until = [_cycleUntilDate hour:[startDate hourOfDay]
                           minute:[startDate minuteOfHour]
                           second:[startDate secondOfMinute]];
  [until setTimeZone:[startDate timeZone]];
  ASSIGN(cycleUntilDate, until);
}
- (NSCalendarDate *)cycleUntilDate {
  return cycleUntilDate;
}

- (iCalRecurrenceRule *)rrule {
  NSString *ruleRep;
  iCalRecurrenceRule *rule;

  if (![self hasCycle])
    return nil;
  ruleRep = [cycle objectForKey:@"rule"];
  rule    = [iCalRecurrenceRule recurrenceRuleWithICalRepresentation:ruleRep];

  if (cycleUntilDate && [self isCycleEndUntil])
    [rule setUntilDate:cycleUntilDate];
  return rule;
}

- (void)adjustCycleControlsForRRule:(iCalRecurrenceRule *)_rrule {
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
- (NSDictionary *)cycleMatchingRRule:(iCalRecurrenceRule *)_rrule {
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
- (NSArray *)cycleEnds {
  static NSArray *ends = nil;
  
  if (!ends) {
    ends = [[NSArray alloc] initWithObjects:@"cycle_end_never",
                                            @"cycle_end_until",
                                            nil];
  }
  return ends;
}

- (void)setCycleEnd:(NSString *)_cycleEnd {
  ASSIGNCOPY(cycleEnd, _cycleEnd);
}
- (NSString *)cycleEnd {
  return cycleEnd;
}
- (BOOL)isCycleEndUntil {
  return (cycleEnd &&
          [cycleEnd isEqualToString:@"cycle_end_until"]);
}
- (void)setIsCycleEndUntil {
  [self setCycleEnd:@"cycle_end_until"];
}
- (void)setIsCycleEndNever {
  [self setCycleEnd:@"cycle_end_never"];
}

/* transparency */

- (NSString *)transparency {
  return @"TRANSPARENT";
}


/* iCal */

- (void)setICalString:(NSString *)_s {
  ASSIGNCOPY(iCalString, _s);
}
- (NSString *)iCalString {
  return iCalString;
}

- (NSString *)iCalStringTemplate {
  static NSString *iCalStringTemplate = \
    @"BEGIN:VCALENDAR\r\n"
    @"METHOD:REQUEST\r\n"
    @"PRODID:OpenGroupware.org SOGo 0.9\r\n"
    @"VERSION:2.0\r\n"
    @"BEGIN:VEVENT\r\n"
    @"UID:%@\r\n"
    @"CLASS:PUBLIC\r\n"
    @"STATUS:CONFIRMED\r\n" /* confirmed by default */
    @"DTSTAMP:%@Z\r\n"
    @"DTSTART:%@\r\n"
    @"DTEND:%@\r\n"
    @"TRANSP:%@\r\n"
    @"SEQUENCE:1\r\n"
    @"PRIORITY:5\r\n"
    @"%@"                   /* organizer */
    @"%@"                   /* participants and resources */
    @"END:VEVENT\r\n"
    @"END:VCALENDAR";

  NSCalendarDate *lStartDate, *lEndDate, *stamp;
  NSString *template, *s;
  unsigned minutes;

  s = [self queryParameterForKey:@"dur"];
  if(s && [s length] > 0) {
    minutes = [s intValue];
  }
  else {
    minutes = 60;
  }
  lStartDate = [self selectedDate];
  lEndDate   = [lStartDate dateByAddingYears:0 months:0 days:0
                           hours:0 minutes:minutes seconds:0];

  stamp = [NSCalendarDate calendarDate];
  [stamp setTimeZone: [NSTimeZone timeZoneWithName: @"GMT"]];
  
  s          = [self iCalParticipantsAndResourcesStringFromQueryParameters];
  template   = [NSString stringWithFormat:iCalStringTemplate,
                         [[self clientObject] nameInContainer],
                         [stamp iCalFormattedDateTimeString],
                         [lStartDate iCalFormattedDateTimeString],
                         [lEndDate iCalFormattedDateTimeString],
                         [self transparency],
                         [self iCalOrganizerString],
                         s];
  return template;
}

- (NSString *)iCalParticipantsAndResourcesStringFromQueryParameters {
  NSString *s;
  
  s = [self iCalParticipantsStringFromQueryParameters];
  return [s stringByAppendingString:
            [self iCalResourcesStringFromQueryParameters]];
}

- (NSString *)iCalParticipantsStringFromQueryParameters {
  static NSString *iCalParticipantString = \
    @"ATTENDEE;ROLE=REQ-PARTICIPANT;CN=\"%@\":mailto:%@\r\n";
  
  return [self iCalStringFromQueryParameter:@"ps"
               format:iCalParticipantString];
}

- (NSString *)iCalResourcesStringFromQueryParameters {
  static NSString *iCalResourceString = \
    @"ATTENDEE;ROLE=NON-PARTICIPANT;CN=\"%@\":mailto:%@\r\n";

  return [self iCalStringFromQueryParameter:@"rs"
               format:iCalResourceString];
}

- (NSString *)iCalStringFromQueryParameter:(NSString *)_qp
              format:(NSString *)_format
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

- (NSString *)iCalOrganizerString {
  static NSString *fmt = @"ORGANIZER;CN=\"%@\":mailto:%@\r\n";
  return [NSString stringWithFormat:fmt,
                                      [self cnForUser],
                                      [self emailForUser]];
}

#if 0
- (iCalPerson *)getOrganizer {
  iCalPerson *p;
  NSString *emailProp;
  
  emailProp = [@"mailto:" stringByAppendingString:[self emailForUser]];
  p = [[[iCalPerson alloc] init] autorelease];
  [p setEmail:emailProp];
  [p setCn:[self cnForUser]];
  return p;
}
#endif


/* helper */

- (NSString *)_completeURIForMethod:(NSString *)_method {
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

/* new */

- (id)newAction {
  /*
    This method creates a unique ID and redirects to the "edit" method on the
    new ID.
    It is actually a folder method and should be defined on the folder.
    
    Note: 'clientObject' is the SOGoAppointmentFolder!
          Update: remember that there are group folders as well.
  */
  NSString *uri, *objectId, *method, *ps;

  objectId = [NSClassFromString(@"SOGoAppointmentFolder")
			       globallyUniqueObjectId];
  if ([objectId length] == 0) {
    return [NSException exceptionWithHTTPStatus:500 /* Internal Error */
			reason:@"could not create a unique ID"];
  }

  method = [NSString stringWithFormat:@"Calendar/%@/edit", objectId];
  method = [[self userFolderPath] stringByAppendingPathComponent:method];

  /* check if participants have already been provided */
  ps     = [self queryParameterForKey:@"ps"];
//   if (ps) {
//     [self setQueryParameter:ps forKey:@"ps"];
//   }
 if (!ps
     && [[self clientObject] respondsToSelector:@selector(calendarUIDs)]) {
    AgenorUserManager *um;
    NSArray *uids;
    NSMutableArray *emails;
    unsigned i, count;

    /* add all current calendarUIDs as default participants */

    um     = [AgenorUserManager sharedUserManager];
    uids   = [[self clientObject] calendarUIDs];
    count  = [uids count];
    emails = [NSMutableArray arrayWithCapacity:count];
    
    for (i = 0; i < count; i++) {
      NSString *email;
      
      email = [um getEmailForUID:[uids objectAtIndex:i]];
      if (email)
        [emails addObject:email];
    }
    ps = [emails componentsJoinedByString:@","];
    [self setQueryParameter:ps forKey:@"ps"];
  }
  uri = [self completeHrefForMethod:method];
  return [self redirectToLocation:uri];
}

/* save */

/* returned dates are in GMT */
- (NSArray *)getICalPersonsFromFormValues:(NSArray *)_values
  treatAsResource:(BOOL)_isResource
{
  unsigned i, count;
  NSMutableArray *result;

  count = [_values count];
  result = [[NSMutableArray alloc] initWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSString *pString, *email, *cn;
    NSRange r;
    iCalPerson *p;
    
    pString = [_values objectAtIndex:i];
    if ([pString length] == 0)
      continue;
    
    /* delimiter between email and cn */
    r = [pString rangeOfString:@";"];
    if (r.length > 0) {
      email = [pString substringToIndex:r.location];
      cn = (r.location + 1 < [pString length])
	? [pString substringFromIndex:r.location + 1]
	: nil;
    }
    else {
      email = pString;
      cn    = nil;
    }
    if (cn == nil) {
      /* fallback */
      AgenorUserManager *um = [AgenorUserManager sharedUserManager];
      cn = [um getCNForUID:[um getUIDForEmail:email]];
    }
    
    p = [[iCalPerson alloc] init];
    [p setEmail:[@"mailto:" stringByAppendingString:email]];
    if ([cn isNotNull]) [p setCn:cn];
    
    /* see RFC2445, sect. 4.2.16 for details */
    [p setRole:_isResource ? @"NON-PARTICIPANT" : @"REQ-PARTICIPANT"];
    [result addObject:p];
    [p release];
  }
  return [result autorelease];
}

- (BOOL)isWriteableClientObject {
  return [[self clientObject] 
	        respondsToSelector:@selector(saveContentString:)];
}

- (NSException *)validateObjectForStatusChange {
  BOOL ok;
  id co;

  co = [self clientObject];
  ok = [co respondsToSelector:@selector(changeParticipationStatus:inContext:)];
  if (!ok) {
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
                        reason:
                          @"method cannot be invoked on the specified object"];
  }
  return nil;
}

- (void)loadValuesFromAppointment: (iCalEvent *)_appointment
{
  NSString *s;
  iCalRecurrenceRule *rrule;
  NSTimeZone *uTZ;

  if ((startDate = [_appointment startDate]) == nil)
    startDate = [[NSCalendarDate date] hour:11 minute:0];
  if ((endDate = [_appointment endDate]) == nil) {
    endDate =
      [startDate hour:[startDate hourOfDay] + 1 minute:0];
  }

  uTZ = [[self clientObject] userTimeZone];
  [startDate setTimeZone: uTZ];
  [endDate setTimeZone: uTZ];
//   startDate = [startDate adjustedDate];
//   endDate = [endDate adjustedDate];
  [startDate retain];
  [endDate retain];

  title        = [[_appointment summary]  copy];
  location     = [[_appointment location] copy];
  comment      = [[_appointment comment]  copy];
  priority     = [[_appointment priority] copy];
  categories   = [[[_appointment categories] commaSeparatedValues] retain];
  organizer    = [[_appointment organizer]    retain];
  participants = [[_appointment participants] retain];
  resources    = [[_appointment resources]    retain];

//   NSLog (@"summary ���: '%@'", title);

  s                  = [_appointment accessClass];
  if(!s || [s isEqualToString:@"PUBLIC"])
    [self setIsPrivate:NO];
  else
    [self setIsPrivate:YES]; /* we're possibly loosing information here */

  /* cycles */
  if ([_appointment isRecurrent])
    {
      rrule = [[_appointment recurrenceRules] objectAtIndex: 0];
      [self adjustCycleControlsForRRule:rrule];
    }
}

- (void)saveValuesIntoAppointment:(iCalEvent *)_appointment {
  /* merge in form values */
  NSArray *attendees, *lResources;
  iCalRecurrenceRule *rrule;
  
  [_appointment setStartDate:[self aptStartDate]];
  [_appointment setEndDate:[self aptEndDate]];

  [_appointment setSummary: [self title]];
  [_appointment setLocation: [self location]];
  [_appointment setComment: [self comment]];
  [_appointment setPriority:[self priority]];
  [_appointment setCategories: [[self categories] componentsJoinedByString: @","]];
  
  [_appointment setAccessClass:[self accessClass]];
  [_appointment setTransparency:[self transparency]];

#if 0
  /*
    Note: bad, bad, bad!
    Organizer is no form value, thus we MUST NOT change it
  */
  [_appointment setOrganizer:organizer];
#endif
  attendees  = [self participants];
  lResources = [self resources];
  if ([lResources count] > 0) {
    attendees = ([attendees count] > 0)
      ? [attendees arrayByAddingObjectsFromArray:lResources]
      : lResources;
  }
  [attendees makeObjectsPerformSelector: @selector (setTag:)
             withObject: @"attendee"];
  [_appointment setAttendees:attendees];

  /* cycles */
  [_appointment removeAllRecurrenceRules];
  rrule = [self rrule];
  if (rrule)
    [_appointment addToRecurrenceRules: rrule];
}

- (iCalEvent *) appointmentFromString: (NSString *) _iCalString
{
  iCalCalendar *calendar;
  iCalEvent *appointment;
  SOGoAppointmentObject *clientObject;

  clientObject = [self clientObject];
  calendar = [iCalCalendar parseSingleFromSource: _iCalString];
  appointment = [clientObject firstEventFromCalendar: calendar];

  return appointment;
}

/* contact editor compatibility */

- (void)setContentString:(NSString *)_s {
  [self setICalString:_s];
}
- (NSString *)contentStringTemplate {
  return [self iCalStringTemplate];
}

/* access */

- (BOOL) isMyApt
{
  // TODO: this should check a set of emails against the SoUser
  return (![[organizer email] length]
          || [[organizer rfc822Email] isEqualToString: [self emailForUser]]);
}

- (BOOL)canAccessApt {
  return [self isMyApt];
}

- (BOOL)canEditApt {
  return [self isMyApt];
}


/* conflict management */

- (BOOL)containsConflict:(iCalEvent *)_apt {
  NSArray *attendees, *uids;
  SOGoAppointmentFolder *groupCalendar;
  NSArray *infos;
  NSArray *ranges;
  id folder;

  [self logWithFormat:@"search from %@ to %@", 
	  [_apt startDate], [_apt endDate]];

  folder    = [[self clientObject] container];
  attendees = [_apt attendees];
  uids      = [folder uidsFromICalPersons:attendees];
  if ([uids count] == 0) {
    [self logWithFormat:@"Note: no UIDs selected."];
    return NO;
  }

  groupCalendar = [folder lookupGroupCalendarFolderForUIDs:uids
                          inContext:[self context]];
  [self debugWithFormat:@"group calendar: %@", groupCalendar];
  
  if (![groupCalendar respondsToSelector:@selector(fetchFreebusyInfosFrom:to:)]) {
    [self errorWithFormat:@"invalid folder to run freebusy query on!"];
    return NO;
  }

  infos = [groupCalendar fetchFreebusyInfosFrom:[_apt startDate]
                         to:[_apt endDate]];
  [self debugWithFormat:@"  process: %d events", [infos count]];

  ranges = [infos arrayByCreatingDateRangesFromObjectsWithStartDateKey:@"startDate"
                  andEndDateKey:@"endDate"];
  ranges = [ranges arrayByCompactingContainedDateRanges];
  [self debugWithFormat:@"  blocked ranges: %@", ranges];

  return [ranges count] != 0 ? YES : NO;
}

/* response generation */

- (NSString *)initialCycleVisibility {
  if (![self hasCycle])
    return @"visibility: hidden;";
  return @"visibility: visible;";
}

- (NSString *)initialCycleEndUntilVisibility {
  if ([self isCycleEndUntil])
    return @"visibility: visible;";
  return @"visibility: hidden;";
}


/* actions */

- (BOOL)shouldTakeValuesFromRequest:(WORequest *)_rq inContext:(WOContext*)_c{
  return YES;
}

- (id)testAction {
  /* for testing only */
  WORequest *req;
  iCalEvent *apt;
  NSString *content;

  req = [[self context] request];
  apt = [self appointmentFromString: [self iCalString]];
  [self saveValuesIntoAppointment:apt];
  content = [[apt parent] versitString];
  [self logWithFormat:@"%s -- iCal:\n%@",
    __PRETTY_FUNCTION__,
    content];

  return self;
}

- (id<WOActionResults>)defaultAction {
  NSString *ical;
  
  /* load iCalendar file */
  
  // TODO: can't we use [clientObject contentAsString]?
//   ical = [[self clientObject] valueForKey:@"iCalString"];
  ical = [[self clientObject] contentAsString];
  if ([ical length] == 0) /* a new appointment */
    ical = [self contentStringTemplate];
  
  [self setContentString:ical];
  [self loadValuesFromAppointment: [self appointmentFromString: ical]];
  
  if (![self canEditApt]) {
    /* TODO: we need proper ACLs */
    return [self redirectToLocation:[self _completeURIForMethod:@"../view"]];
  }
  return self;
}

- (id)saveAction {
  iCalEvent *apt;
  iCalPerson *p;
  NSString *content;
  NSException *ex;

  if (![self isWriteableClientObject]) {
    /* return 400 == Bad Request */
    return [NSException exceptionWithHTTPStatus:400
                        reason:@"method cannot be invoked on "
                               @"the specified object"];
  }
  
  apt = [self appointmentFromString: [self iCalString]];
  if (apt == nil) {
    NSString *s;
    
    s = [self labelForKey:@"Invalid iCal data!"];
    [self setErrorText:s];
    return self;
  }
  
  [self saveValuesIntoAppointment:apt];
  p = [apt findParticipantWithEmail:[self emailForUser]];
  if (p) {
    [p setParticipationStatus:iCalPersonPartStatAccepted];
  }

  if ([self checkForConflicts]) {
    if ([self containsConflict:apt]) {
      NSString *s;
      
      s = [self labelForKey:@"Conflicts found!"];
      [self setErrorText:s];

      return self;
    }
  }
  content = [[apt parent] versitString];
//   [apt release]; apt = nil;
  
  if (content == nil) {
    NSString *s;
    
    s = [self labelForKey:@"Could not create iCal data!"];
    [self setErrorText:s];
    return self;
  }
  
  ex = [[self clientObject] saveContentString:content];
  if (ex != nil) {
    [self setErrorText:[ex reason]];
    return self;
  }
  
  return [self redirectToLocation:[self _completeURIForMethod:@".."]];
}

- (id)acceptAction {
  return [self acceptOrDeclineAction:YES];
}

- (id)declineAction {
  return [self acceptOrDeclineAction:NO];
}

// TODO: add tentatively

- (id)acceptOrDeclineAction:(BOOL)_accept {
  // TODO: this should live in the SoObjects
  NSException *ex;

  if ((ex = [self validateObjectForStatusChange]) != nil)
    return ex;
  
  ex = [[self clientObject] changeParticipationStatus:
                              _accept ? @"ACCEPTED" : @"DECLINED"
                            inContext:[self context]];
  if (ex != nil) return ex;
  
  return [self redirectToLocation:[self _completeURIForMethod:@"../view"]];
}

@end /* UIxAppointmentEditor */
