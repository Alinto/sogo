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

#import "UIxTaskView.h"
#import <NGCards/NGCards.h>
#import <SOGo/WOContext+Agenor.h>
#import <Appointments/SOGoTaskObject.h>
#import <SOGoUI/SOGoDateFormatter.h>
#import "UIxComponent+Agenor.h"
#import "common.h"

@interface UIxTaskView (PrivateAPI)
- (BOOL)isAttendeeActiveUser;
@end

@implementation UIxTaskView

- (void)dealloc {
  [task   release];
  [attendee      release];
  [dateFormatter release];
  [item          release];
  [super dealloc];
}

/* accessors */

- (NSString *)tabSelection {
  NSString *selection;
    
  selection = [self queryParameterForKey:@"tab"];
  if (selection == nil)
    selection = @"attributes";
  return selection;
}

- (void)setAttendee:(id)_attendee {
  ASSIGN(attendee, _attendee);
}
- (id)attendee {
  return attendee;
}

- (BOOL)isAttendeeActiveUser {
  NSString *email, *attEmail;

  email    = [[[self context] activeUser] email];
  attendee = [self attendee];
  attEmail = [attendee rfc822Email];

  return [email isEqualToString: attEmail];
}

- (BOOL)showAcceptButton {
  return [[self attendee] participationStatus] != iCalPersonPartStatAccepted;
}
- (BOOL)showRejectButton {
  return [[self attendee] participationStatus] != iCalPersonPartStatDeclined;
}
- (NSString *)attendeeStatusColspan {
  return [self isAttendeeActiveUser] ? @"1" : @"2";
}

- (void)setItem:(id)_item {
  ASSIGN(item, _item);
}
- (id)item {
  return item;
}

- (SOGoDateFormatter *)dateFormatter {
  if (dateFormatter == nil) {
    dateFormatter =
      [[SOGoDateFormatter alloc] initWithLocale:[self locale]];
    [dateFormatter setFullWeekdayNameAndDetails];
  }
  return dateFormatter;
}

- (NSCalendarDate *)startTime {
  NSCalendarDate *date;
    
  date = [[self task] startDate];
  [date setTimeZone:[[self clientObject] userTimeZone]];
  return date;
}

- (NSCalendarDate *)endTime {
  NSCalendarDate *date;
  
  date = [[self task] due];
  [date setTimeZone:[[self clientObject] userTimeZone]];
  return date;
}

- (NSString *)resourcesAsString {
  NSArray *resources, *cns;

  resources = [[self task] resources];
  cns = [resources valueForKey:@"cnForDisplay"];
  return [cns componentsJoinedByString:@"<br />"];
}

- (NSString *) categoriesAsString
{
  NSEnumerator *categories;
  NSArray *rawCategories;
  NSMutableArray *l10nCategories;
  NSString *currentCategory, *l10nCategory;

  rawCategories
    = [[task categories] componentsSeparatedByString: @","];
  l10nCategories = [NSMutableArray arrayWithCapacity: [rawCategories count]];
  categories = [rawCategories objectEnumerator];
  currentCategory = [categories nextObject];
  while (currentCategory)
    {
      l10nCategory
        = [self labelForKey: [currentCategory stringByTrimmingSpaces]];
      if (l10nCategory)
        [l10nCategories addObject: l10nCategory];
      currentCategory = [categories nextObject];
    }

  return [l10nCategories componentsJoinedByString: @", "];
}

// task.organizer.cnForDisplay
- (NSString *) eventOrganizer
{
  CardElement *organizer;

  organizer = [[self task] uniqueChildWithTag: @"organizer"];

  return [organizer value: 0 ofAttribute: @"cn"];
}

- (NSString *) priorityLabelKey
{
  return [NSString stringWithFormat: @"prio_%@", [task priority]];
}

/* backend */

- (iCalToDo *) task
{
  SOGoTaskObject *clientObject;

  if (!task)
    {
      clientObject = [self clientObject];
      task = (iCalToDo *) [clientObject component: NO];
      [task retain];
    }

  return task;
}

/* hrefs */

- (NSString *)attributesTabLink {
  return [self completeHrefForMethod:[self ownMethodName]
	       withParameter:@"attributes"
	       forKey:@"tab"];
}

- (NSString *)participantsTabLink {
    return [self completeHrefForMethod:[self ownMethodName]
                 withParameter:@"participants"
                 forKey:@"tab"];
}

- (NSString *)debugTabLink {
  return [self completeHrefForMethod:[self ownMethodName]
	       withParameter:@"debug"
	       forKey:@"tab"];
}

- (NSString *)completeHrefForMethod:(NSString *)_method
  withParameter:(NSString *)_param
  forKey:(NSString *)_key
{
  NSString *href;

  [self setQueryParameter:_param forKey:_key];
  href = [self completeHrefForMethod:[self ownMethodName]];
  [self setQueryParameter:nil forKey:_key];
  return href;
}


/* access */

- (BOOL)isMyApt {
  NSString   *email;
  iCalPerson *organizer;

  email     = [[[self context] activeUser] email];
  organizer = [[self task] organizer];
  if (!organizer) return YES; // assume this is correct to do, right?
  return [[organizer rfc822Email] isEqualToString:email];
}

- (BOOL)canAccessApt {
  NSString *email;
  NSArray  *partMails;

  if ([self isMyApt])
    return YES;
  
  /* not my apt - can access if it's public */
  if ([[[self task] accessClass] isEqualToString: @"PUBLIC"])
    return YES;

  /* can access it if I'm invited :-) */
  email     = [[[self context] activeUser] email];
  partMails = [[[self task] participants] valueForKey:@"rfc822Email"];
  return [partMails containsObject:email];
}

- (BOOL)canEditApt {
  return [self isMyApt];
}


/* action */

- (id<WOActionResults>)defaultAction {
  if ([self task] == nil) {
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			reason:@"could not locate task"];
  }
  
  return self;
}

- (BOOL)isDeletableClientObject {
  return [[self clientObject] respondsToSelector:@selector(delete)];
}

- (id)deleteAction {
  NSException *ex;
  id url;

  if ([self task] == nil) {
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			reason:@"could not locate task"];
  }

  if (![self isDeletableClientObject]) {
    /* return 400 == Bad Request */
    return [NSException exceptionWithHTTPStatus:400
                        reason:@"method cannot be invoked on "
                               @"the specified object"];
  }
  
  if ((ex = [[self clientObject] delete]) != nil) {
    // TODO: improve error handling
    [self debugWithFormat:@"failed to delete: %@", ex];
    return ex;
  }
  
  url = [[[self clientObject] container] baseURLInContext:[self context]];
  return [self redirectToLocation:url];
}

@end /* UIxTaskView */
