// $Id: UIxAppointmentView.m 84 2004-06-29 22:34:55Z znek $

#include "UIxAppointmentView.h"
#include "common.h"
#include <Backend/SxAptManager.h>
#include <SOGoLogic/SOGoAppointment.h>


@interface NSObject(UsedPrivates)
- (SxAptManager *)aptManagerInContext:(id)_ctx;
@end

@implementation UIxAppointmentView

- (void)dealloc {
  [self->appointment release];
  [self->attendee release];
  [super dealloc];
}


/* accessors */


- (NSString *)tabSelection {
    NSString *selection;
    
    selection = [self queryParameterForKey:@"tab"];
    if(! selection)
        selection = @"attributes";
    return selection;
}

- (void)setAttendee:(id)_attendee {
    ASSIGN(self->attendee, _attendee);
}
- (id)attendee {
    return self->attendee;
}


/* backend */


- (SxAptManager *)aptManager {
  return [[self clientObject] aptManagerInContext:[self context]];
}

- (SOGoAppointment *)appointment {
    if(self->appointment == nil) {
        NSString *iCalString;

        iCalString = [[self clientObject] valueForKey:@"iCalString"];
        self->appointment = [[SOGoAppointment alloc] initWithICalString:iCalString];
    }
    return self->appointment;
}

- (NSString *)formattedAptStartTime {
    NSCalendarDate *date;
    
    date = [[self appointment] startDate];
    /* TODO: convert this into display timeZone! */
    return [date descriptionWithCalendarFormat:@"%A, %Y-%m-%d %H:%M %Z"];
}

- (NSString *)formattedAptEndTime {
    NSCalendarDate *date;
    
    date = [[self appointment] endDate];
    /* TODO: convert this into display timeZone! */
    return [date descriptionWithCalendarFormat:@"%A, %Y-%m-%d %H:%M %Z"];
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

@end /* UIxAppointmentView */
