/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OGo

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
// $Id: UIxAppointmentEditor.m 90 2004-06-30 01:07:58Z znek $


#include "common.h"
#include <Common/UIxComponent.h>
#include <SOGoLogic/SOGoAppointment.h>
#include <NGiCal/NGiCal.h>


/* TODO: CLEAN THIS MESS UP */


@interface NSObject (AppointmentHack)
- (BOOL)isAppointment;
@end

@implementation NSObject (AppointmentHack)
- (BOOL)isAppointment {
  return [self isKindOfClass:NSClassFromString(@"SxAppointment")];
}
@end

@interface iCalPerson (Convenience)
- (NSString *)rfc822Email;
@end

@implementation iCalPerson (Convenience)
- (NSString *)rfc822Email {
    NSString *_email = [self email];
    NSRange colon = [_email rangeOfString:@":"];
    if(colon.location != NSNotFound) {
        return [_email substringFromIndex:colon.location + 1];
    }
    return _email;
}
@end

@interface UIxAppointmentEditor : UIxComponent
{
    id appointment;
    id participants;
}

- (SOGoAppointment *)appointment;
- (NSString *)iCalStringTemplate;
- (NSString *)iCalString;
- (BOOL)isNewAppointment;

@end

@implementation UIxAppointmentEditor

- (void)dealloc {
    [self->appointment release];
    [self->participants release];
    [super dealloc];
}


/* accessors */


- (NSString *)formattedAptStartTime {
    NSCalendarDate *date;
    
    date = [[self appointment] startDate];
    /* TODO: convert this into display timeZone! */
    return [date descriptionWithCalendarFormat:@"%A, %Y-%m-%d %H:%M %Z"];
}

- (BOOL)isNewAppointment {
    return ! [[self clientObject] isAppointment];
}

- (NSString *)iCalString {
    if([self isNewAppointment]) {
        return [self iCalStringTemplate];
    }
    else {
        return [[self clientObject] valueForKey:@"iCalString"];
    }
}

- (NSString *)iCalStringTemplate {
    static NSString *iCalStringTemplate = \
    @"BEGIN:VCALENDAR\nMETHOD:REQUEST\nPRODID:OpenGroupware.org ZideStore 1.2\n" \
    @"VERSION:2.0\nBEGIN:VEVENT\nCLASS:PRIVATE\nSTATUS:CONFIRMED\n" \
    @"DTSTART:%@\nDTEND:%@\n" \
    @"TRANSP:OPAQUE\n" \
    @"END:VEVENT\nEND:VCALENDAR";
    NSCalendarDate *startDate, *endDate;
    NSString *template;
    
    startDate = [self selectedDate];
    endDate = [startDate dateByAddingYears:0 months:0 days:0
                         hours:1 minutes:0 seconds:0];
    
    template = [NSString stringWithFormat:iCalStringTemplate,
                                          [startDate icalString],
                                          [endDate icalString]];
    
    return template;
}


/* backend */


- (SOGoAppointment *)appointment {
    if(self->appointment == nil) {
        self->appointment = [[SOGoAppointment alloc]
          initWithICalString:[self iCalString]];
    }
    return self->appointment;
}

- (id)participants {
    if(self->participants == nil) {
        NSArray *attendees;
        NSMutableArray *emailAddresses;
        unsigned i, count;

        attendees = [self->appointment attendees];
        count = [attendees count];
        emailAddresses = [[NSMutableArray alloc] initWithCapacity:count];
        for(i = 0; i < count; i++) {
            NSString *email;
            
            email = [[attendees objectAtIndex:i] rfc822Email];
            if(email)
                [emailAddresses addObject:email];
        }
        self->participants = [[emailAddresses componentsJoinedByString:@"\n"]
            retain];
        [emailAddresses release];
    }
    return self->participants;
}


/* helper */

- (NSString *)uriAsFormat {
    NSString *uri, *qp;
    NSRange r;

    uri = [[[self context] request] uri];
    
    /* first: identify query parameters */
    r = [uri rangeOfString:@"?" options:NSBackwardsSearch];
    if (r.length > 0) {
        uri = [uri substringToIndex:r.location];
        qp = [uri substringFromIndex:r.location];
    }
    else {
        qp = nil;
    }
    
    /* next: strip trailing slash */
    if([uri hasSuffix:@"/"])
        uri = [uri substringToIndex:([uri length] - 1)];
    r = [uri rangeOfString:@"/" options:NSBackwardsSearch];
    
    /* then: cut of last path component */
    if(r.location == NSNotFound) { // no slash? are we at root?
        uri = @"/";
    }
    else {
        uri = [uri substringToIndex:(r.location + 1)];
    }
    /* next: append format token */
    uri = [uri stringByAppendingString:@"%@"];
    if(qp != nil)
        uri = [uri stringByAppendingString:qp];
    return uri;
}


/* save */


- (id)saveAction {
    SOGoAppointment *apt;
    NSString *iCalString, *summary, *location, *nextMethod, *uri, *uriFormat;
    NSCalendarDate *sd, *ed;
    NSArray *ps;
    unsigned i, count;
    WOResponse *r;
    WORequest *req;

    req = [[self context] request];

    /* get iCalString from hidden input */
    iCalString = [req formValueForKey:@"ical"];
    apt = [[SOGoAppointment alloc] initWithICalString:iCalString];

    /* merge in form values */
    sd = [NSCalendarDate dateWithString:[req formValueForKey:@"startDate"]
                         calendarFormat:@"%Y-%m-%d %H:%M"];
    [apt setStartDate:sd];
    ed = [NSCalendarDate dateWithString:[req formValueForKey:@"endDate"]
                         calendarFormat:@"%Y-%m-%d %H:%M"];
    [apt setEndDate:ed];
    summary = [req formValueForKey:@"summary"];
    [apt setSummary:title];
    location = [req formValueForKey:@"location"];
    [apt setLocation:location];

    [apt removeAllAttendees]; /* clean up */
    ps = [[req formValueForKey:@"participants"]
        componentsSeparatedByString:@"\n"];
    count = [ps count];
    for(i = 0; i < count; i++) {
        NSString *email;
        
        email = [ps objectAtIndex:i];
        if([email length] > 0) {
            iCalPerson *p;
            NSRange cnr;

            p = [[iCalPerson alloc] init];
            [p setEmail:[NSString stringWithFormat:@"mailto:%@", email]];
            /* construct a fake CN */
            cnr = [email rangeOfString:@"@"];
            if(cnr.location != NSNotFound) {
                [p setCn:[email substringToIndex:cnr.location]];
            }
            [apt addToAttendees:p];
            [p release];
        }
    }

    /* receive current representation for save operation */
    iCalString = [apt iCalString];
    [apt release];
    

    /* determine what's to do and where to go next */
    if([self isNewAppointment]) {
        nextMethod = @"duhduh";
    }
    else {
        nextMethod = @"view";
    }

    NSLog(@"%s new iCalString:\n%@", __PRETTY_FUNCTION__, iCalString);

    uriFormat = [self uriAsFormat];
    uri = [NSString stringWithFormat:uriFormat, nextMethod];

    r = [WOResponse responseWithRequest:req];
    [r setStatus:302 /* moved */];
    [r setHeader:uri forKey:@"location"];
    return r;
}

@end
