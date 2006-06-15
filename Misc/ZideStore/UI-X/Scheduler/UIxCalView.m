// $Id: UIxCalView.m 84 2004-06-29 22:34:55Z znek $

#include "UIxCalView.h"
#include "common.h"
#include <Backend/SxAptManager.h>
#include "UIxAppointmentFormatter.h"

@interface NSObject(UsedPrivates)
- (SxAptManager *)aptManagerInContext:(id)_ctx;
@end

@implementation UIxCalView

- (void)dealloc {
  [self->appointment  release];
  [self->appointments release];
  [self->currentDay release];
  [super dealloc];
}

/* accessors */


- (void)setAppointments:(NSArray *)_apts {
  ASSIGN(self->appointments, _apts);
}
- (NSArray *)appointments {
  return self->appointments;
}

- (void)setAppointment:(id)_apt {
  ASSIGN(self->appointment, _apt);
}
- (id)appointment {
  return self->appointment;
}

- (NSDictionary *)aptTypeDict {
    return nil;
}

- (NSString *)aptTypeLabel {
    return @"aptLabel";
}

- (NSString *)aptTypeIcon {
    return @"";
}

- (NSString *)shortTextForApt {
    UIxAppointmentFormatter *f;
    
    f = [UIxAppointmentFormatter formatterWithFormat:
        @"%S - %E;\n%T;\n%L;\n%5P;\n%50R"];
    [f setRelationDate:[self referenceDateForFormatter]];
    [f setShowFullNames:[self showFullNames]];
    if([self showAMPMDates])
        [f switchToAMPMTimes:YES];
    
    return [NSString stringWithFormat:@"%@:\n%@",
        [self aptTypeLabel],
        [f stringForObjectValue:self->appointment]];
}

- (NSString *)shortTitleForApt {
    NSString *title;
    
    title = [self->appointment valueForKey:@"title"];
    if([title length] > 12) {
        title = [NSString stringWithFormat:@"%@...",
            [title substringToIndex:11]];
    }
    return title;
}

- (NSCalendarDate *)referenceDateForFormatter {
    return [self selectedDate];
}

/* current day related */

- (void)setCurrentDay:(NSCalendarDate *)_day {
    ASSIGN(self->currentDay, _day);
}
- (NSCalendarDate *)currentDay {
    return self->currentDay;
}

- (NSString *)currentDayName {
    // TODO: this is slow, use locale dictionary to speed this up
    return [self->currentDay descriptionWithCalendarFormat:@"%A"];
}

- (BOOL)hasDayInfo {
    return [self hasHoldidayInfo] || ([[self allDayApts] count] != 0);
}

- (BOOL)hasHoldidayInfo {
    return NO;
}

- (NSArray *)allDayApts {
    return [NSArray array];
}


/* defaults */


- (BOOL)showFullNames {
    return YES;
}

- (BOOL)showAMPMDates {
    return NO;
}


/* URLs */

- (NSString *)appointmentViewURL {
  id pkey;
  
  if ((pkey = [[self appointment] valueForKey:@"dateId"]) == nil)
    return nil;
  
  return [NSString stringWithFormat:@"%@/view", pkey];
}


/* backend */

- (SxAptManager *)aptManager {
  return [[self clientObject] aptManagerInContext:[self context]];
}
- (SxAptSetIdentifier *)aptSetID {
  return [[self clientObject] aptSetID];
}

/* resource URLs (TODO?) */

- (NSString *)resourcePath {
  return @"/ZideStore.woa/WebServerResources/";
}

- (NSString *)favIconPath {
  return [[self resourcePath] stringByAppendingPathComponent:@"favicon.ico"];
}
- (NSString *)cssPath {
  NSString *path;
  
  // TODO: there should be reusable functionality for that!
  path = @"ControlPanel/Products/ZideStoreUI/Resources/zidestoreui.css";
  return [[self context] urlWithRequestHandlerKey:@"so"
			 path:path
			 queryString:nil];
}

- (NSString *)calCSSPath {
  NSString *path;
  
  // TODO: there should be reusable functionality for that!
  path = @"ControlPanel/Products/ZideStoreUI/Resources/calendar.css";
  return [[self context] urlWithRequestHandlerKey:@"so"
			 path:path
			 queryString:nil];
}

/* fetching */

- (NSCalendarDate *)startDate {
  return [self selectedDate];
}
- (NSCalendarDate *)endDate {
  return [[self startDate] tomorrow];
}

- (NSArray *)fetchGIDs {
  return [[self aptManager] gidsOfAppointmentSet:[self aptSetID]
                            from:[self startDate] to:[self endDate]];
}

- (NSArray *)fetchCoreInfos {
  NSArray *gids;
  
  if (self->appointments)
    return self->appointments;
  
  [self logWithFormat:@"fetching (%@ => %@) ...", 
	  [self startDate], [self endDate]];
  gids = [self fetchGIDs];
  [self logWithFormat:@"  %i GIDs ...", [gids count]];
  
  self->appointments = 
    [[[self aptManager] coreInfoOfAppointmentsWithGIDs:gids
                        inSet:[self aptSetID]] retain];
  
  [self logWithFormat:@"fetched %i records.", [self->appointments count]];
  return self->appointments;
}


/* date selection & conversion */


- (NSDictionary *)todayQueryParameters {
    NSCalendarDate *date;
    
    date = [NSCalendarDate date]; /* today */
    return [self queryParametersBySettingSelectedDate:date];
}

- (NSDictionary *)currentDayQueryParameters {
    return [self queryParametersBySettingSelectedDate:self->currentDay];
}

- (NSDictionary *)queryParametersBySettingSelectedDate:(NSCalendarDate *)_date {
    NSMutableDictionary *qp;
    
    qp = [[self queryParameters] mutableCopy];
    [self setSelectedDateQueryParameter:_date inDictionary:qp];
    return [qp autorelease];
}

- (void)setSelectedDateQueryParameter:(NSCalendarDate *)_newDate
        inDictionary:(NSMutableDictionary *)_qp;
{
    if(_newDate != nil)
        [_qp setObject:[self dateStringForDate:_newDate]
             forKey:@"day"];
    else
        [_qp removeObjectForKey:@"day"];
}

@end /* UIxCalView */
