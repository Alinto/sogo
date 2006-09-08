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

#include "UIxAppointmentView.h"
#include <NGiCal/NGiCal.h>
#include <SOGo/SOGoAppointment.h>
#include <SOGo/WOContext+Agenor.h>
#include <Appointments/SOGoAppointmentObject.h>
#include <SOGoUI/SOGoDateFormatter.h>
#include "UIxComponent+Agenor.h"
#include "common.h"

@interface UIxAppointmentView (PrivateAPI)
- (BOOL)isAttendeeActiveUser;
@end

@implementation UIxAppointmentView

- (void)dealloc {
  [self->appointment   release];
  [self->attendee      release];
  [self->dateFormatter release];
  [self->item          release];
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
  ASSIGN(self->attendee, _attendee);
}
- (id)attendee {
  return self->attendee;
}

- (BOOL)isAttendeeActiveUser {
  NSString *email, *attEmail;
  
  email    = [[[self context] activeUser] email];
  attEmail = [[self attendee] rfc822Email];
  return [email isEqualToString:attEmail];
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
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (SOGoDateFormatter *)dateFormatter {
  if (self->dateFormatter == nil) {
    self->dateFormatter =
      [[SOGoDateFormatter alloc] initWithLocale:[self locale]];
    [self->dateFormatter setFullWeekdayNameAndDetails];
  }
  return self->dateFormatter;
}

- (NSCalendarDate *)startTime {
  NSCalendarDate *date;
    
  date = [[self appointment] startDate];
  [date setTimeZone:[[self clientObject] userTimeZone]];
  return date;
}

- (NSCalendarDate *)endTime {
  NSCalendarDate *date;
  
  date = [[self appointment] endDate];
  [date setTimeZone:[[self clientObject] userTimeZone]];
  return date;
}

- (NSString *)resourcesAsString {
  NSArray *resources, *cns;

  resources = [[self appointment] resources];
  cns = [resources valueForKey:@"cnForDisplay"];
  return [cns componentsJoinedByString:@"<br />"];
}

- (NSString *)categoriesAsString {
  unsigned i, count;
  NSArray *cats;
  NSMutableString *s;
  
  s = [NSMutableString stringWithCapacity:32];
  cats = [((SOGoAppointment *)self->appointment) categories];
  count = [cats count];
  for(i = 0; i < count; i++) {
    NSString *cat, *label;

    cat = [cats objectAtIndex:i];
    label = [self labelForKey:cat];
    [s appendString:label];
    if(i != (count - 1))
      [s appendString:@", "];
  }
  return s;
}

/* backend */

- (SOGoAppointment *)appointment {
  NSString *iCalString;
    
  if (self->appointment != nil)
    return self->appointment;
    
  iCalString = [[self clientObject] valueForKey:@"iCalString"];
  if (![iCalString isNotNull] || [iCalString length] == 0) {
    [self errorWithFormat:@"(%s): missing iCal string!", 
            __PRETTY_FUNCTION__];
    return nil;
  }
    
  self->appointment = [[SOGoAppointment alloc] initWithICalString:iCalString];
  return self->appointment;
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
  organizer = [[self appointment] organizer];
  if (!organizer) return YES; // assume this is correct to do, right?
  return [[organizer rfc822Email] isEqualToString:email];
}

- (BOOL)canAccessApt {
  NSString *email;
  NSArray  *partMails;

  if ([self isMyApt])
    return YES;
  
  /* not my apt - can access if it's public */
  if ([[self appointment] isPublic])
    return YES;

  /* can access it if I'm invited :-) */
  email     = [[[self context] activeUser] email];
  partMails = [[[self appointment] participants] valueForKey:@"rfc822Email"];
  return [partMails containsObject:email];
}

- (BOOL)canEditApt {
  return [self isMyApt];
}


/* action */

- (id<WOActionResults>)defaultAction {
  if ([self appointment] == nil) {
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			reason:@"could not locate appointment"];
  }
  
  return self;
}

- (BOOL)isDeletableClientObject {
  return [[self clientObject] respondsToSelector:@selector(delete)];
}

- (id)deleteAction {
  NSException *ex;
  id url;

  if ([self appointment] == nil) {
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			reason:@"could not locate appointment"];
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

@end /* UIxAppointmentView */
