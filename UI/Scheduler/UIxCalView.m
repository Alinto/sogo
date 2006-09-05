// $Id: UIxCalView.m 885 2005-07-21 16:41:34Z znek $

#include "UIxCalView.h"
#include "common.h"
//#include <OGoContentStore/OCSFolder.h>
#include "SoObjects/Appointments/SOGoAppointmentFolder.h"
#include <NGObjWeb/SoUser.h>
#include <SOGoUI/SOGoAptFormatter.h>
#include <NGExtensions/NGCalendarDateRange.h>
#include <NGiCal/NGiCal.h>
#include "UIxComponent+Agenor.h"

@interface UIxCalView (PrivateAPI)
- (NSString *) _userFolderURI;
@end

@implementation UIxCalView

static BOOL shouldDisplayWeekend = NO;

+ (void) initialize
{
  static BOOL didInit = NO;
  NSUserDefaults *ud;

  if (didInit) return;

  ud = [NSUserDefaults standardUserDefaults];
  shouldDisplayWeekend = [ud boolForKey: @"SOGoShouldDisplayWeekend"];
  didInit = YES;
}

- (id) init
{
  self = [super init];
  if (self)
    {
      NSTimeZone *tz;

      tz = [self viewTimeZone];
      self->aptFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: tz];
      self->aptTooltipFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: tz];
      self->privateAptFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: tz];
      self->privateAptTooltipFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: tz];
      [self configureFormatters];
    }
  return self;
}

- (void) dealloc
{
  [self->appointments               release];
  [self->allDayApts                 release];
  [self->appointment                release];
  [self->currentDay                 release];
  [self->aptFormatter               release];
  [self->aptTooltipFormatter        release];
  [self->privateAptFormatter        release];
  [self->privateAptTooltipFormatter release];
  [super dealloc];
}

/* subclasses should override this */
- (void) configureFormatters
{
  NSString *title;

  [self->aptFormatter setFullDetails];
  [self->aptTooltipFormatter setTooltip];
  [self->privateAptFormatter setPrivateDetails];
  [self->privateAptTooltipFormatter setPrivateTooltip];

  title = [self labelForKey: @"empty title"];
  [self->aptFormatter setTitlePlaceholder: title];
  [self->aptTooltipFormatter setTitlePlaceholder: title];

  title = [self labelForKey: @"private appointment"];
  [self->privateAptFormatter setPrivateTitle: title];
  [self->privateAptTooltipFormatter setPrivateTitle: title];
}

- (NSArray *) filterAppointments:(NSArray *) _apts
{
  NSMutableArray *filtered;
  unsigned       i, count;
  NSString       *email;

  count = [_apts count];
  if (!count) return _apts;
  if ([self shouldDisplayRejectedAppointments]) return _apts;

  filtered = [[[NSMutableArray alloc] initWithCapacity: count] autorelease];
  email = [self emailForUser];

  for (i = 0; i < count; i++)
    {
      NSDictionary *info;
      NSArray      *partmails;
      unsigned     p, pCount;
      BOOL         shouldAdd;
    
      shouldAdd = YES;
      info = [_apts objectAtIndex: i];
      partmails = [[info objectForKey: @"partmails"]
                    componentsSeparatedByString: @"\n"];
      pCount = [partmails count];
      for (p = 0; p < pCount; p++)
        {
          NSString *pEmail;

          pEmail = [partmails objectAtIndex: p];
          if ([pEmail isEqualToString: email])
            {
              NSArray  *partstates;
              NSString *state;

              partstates = [[info objectForKey: @"partstates"]
                             componentsSeparatedByString: @"\n"];
              state = [partstates objectAtIndex: p];
              if ([state intValue] == iCalPersonPartStatDeclined)
                shouldAdd = NO;
              break;
            }
        }
      if (shouldAdd)
        [filtered addObject: info];
    }
  return filtered;
}

/* accessors */

- (void) setAppointments:(NSArray *) _apts
{
  _apts = [self filterAppointments: _apts];
  ASSIGN(self->appointments, _apts);
}
- (NSArray *) appointments
{
  return self->appointments;
}

- (void) setAppointment:(id) _apt
{
  NSString *mailtoChunk;
  NSString *myEmail;

  ASSIGN(self->appointment, _apt);

  /* cache some info about apt for faster access */
  
  mailtoChunk = [_apt valueForKey: @"orgmail"];
  myEmail = [self emailForUser];
  if ([mailtoChunk rangeOfString: myEmail].length > 0)
    {
      self->aptFlags.isMyApt = YES;
      self->aptFlags.canAccessApt = YES;
    }
  else
    {
      NSString *partmails;

      self->aptFlags.isMyApt = NO;

      partmails = [_apt valueForKey: @"partmails"];
      if ([partmails rangeOfString: myEmail].length)
        self->aptFlags.canAccessApt = YES;
      else
        self->aptFlags.canAccessApt = [[_apt valueForKey: @"ispublic"] boolValue];
    }
}

- (id) appointment
{
  return self->appointment;
}

- (BOOL) isMyApt
{
  return self->aptFlags.isMyApt ? YES : NO;
}

- (BOOL) canAccessApt
{
  return self->aptFlags.canAccessApt ? YES : NO;
}

- (BOOL) canNotAccessApt
{
  return self->aptFlags.canAccessApt ? NO : YES;
}

- (NSDictionary *) aptTypeDict
{
  return nil;
}
- (NSString *) aptTypeLabel
{
  return @"aptLabel";
}
- (NSString *) aptTypeIcon
{
  return @"";
}

- (SOGoAptFormatter *) aptFormatter
{
  if (self->aptFlags.canAccessApt)
    return self->aptFormatter;
  return self->privateAptFormatter;
}

- (SOGoAptFormatter *) aptTooltipFormatter
{
  if (self->aptFlags.canAccessApt)
    return self->aptTooltipFormatter;
  return self->privateAptTooltipFormatter;
}

/* TODO: remove this */
- (NSString *) shortTextForApt
{
  [self warnWithFormat: @"%s IS DEPRECATED!", __PRETTY_FUNCTION__];
  if (![self canAccessApt])
    return @"";
  return [[self aptFormatter] stringForObjectValue: self->appointment];
}

- (NSString *) shortTitleForApt
{
  NSString *title;

  [self warnWithFormat: @"%s IS DEPRECATED!", __PRETTY_FUNCTION__];

  if (![self canAccessApt])
    return @"";
  title = [self->appointment valueForKey: @"title"];
  if ([title length] > 12)
    title = [[title substringToIndex: 11] stringByAppendingString: @"..."];
  
  return title;
}

- (NSString *) tooltipForApt
{
  [self warnWithFormat: @"%s IS DEPRECATED!", __PRETTY_FUNCTION__];
  return [[self aptTooltipFormatter] stringForObjectValue: self->appointment
                                     referenceDate: [self currentDay]];
}

- (NSString *) aptStyle
{
  return nil;
}

- (NSCalendarDate *) referenceDateForFormatter
{
  return [self selectedDate];
}

- (NSCalendarDate *) thisMonth
{
  return [self selectedDate];
}

- (NSCalendarDate *) nextMonth
{
  NSCalendarDate *date = [self thisMonth];
  return [date dateByAddingYears: 0 months: 1 days: 0
               hours: 0 minutes: 0 seconds: 0];
}

- (NSCalendarDate *) prevMonth
{
  NSCalendarDate *date = [self thisMonth];
  return [date dateByAddingYears: 0 months:-1 days: 0
               hours: 0 minutes: 0 seconds: 0];
}

- (NSString *) prevMonthAsString
{
  return [self dateStringForDate: [self prevMonth]];
}

- (NSString *) nextMonthAsString
{
  return [self dateStringForDate: [self nextMonth]];
}

/* current day related */

- (void) setCurrentDay:(NSCalendarDate *) _day
{
  [_day setTimeZone: [self viewTimeZone]];
  ASSIGN(self->currentDay, _day);
}

- (NSCalendarDate *) currentDay
{
  return self->currentDay;
}

- (NSString *) currentDayName
{
  return [self localizedNameForDayOfWeek: [self->currentDay dayOfWeek]];
}

- (id) holidayInfo
{
  return nil;
}

- (NSArray *) allDayApts
{
  NSArray        *apts;
  NSMutableArray *filtered;
  unsigned       i, count;

  if (self->allDayApts)
    return self->allDayApts;

  apts = [self appointments];
  count = [apts count];
  filtered = [[NSMutableArray alloc] initWithCapacity: 3];
  for (i = 0; i < count; i++)
    {
      id       apt;
      NSNumber *bv;

      apt = [apts objectAtIndex: i];
      bv = [apt valueForKey: @"isallday"];
      if ([bv boolValue])
        [filtered addObject: apt];
    }
    
  ASSIGN(self->allDayApts, filtered);
  [filtered release];
  return self->allDayApts;
}


/* special appointments */

- (BOOL) hasDayInfo
{
  return [self hasHoldidayInfo] || [self hasAllDayApts];
}

- (BOOL) hasHoldidayInfo
{
  return [self holidayInfo] != nil;
}

- (BOOL) hasAllDayApts
{
  return [[self allDayApts] count] != 0;
}


/* defaults */

- (BOOL) showFullNames
{
  return YES;
}

- (BOOL) showAMPMDates
{
  return NO;
}

- (unsigned) dayStartHour
{
  return 8;
}

- (unsigned) dayEndHour
{
  return 18;
}

- (BOOL) shouldDisplayWeekend
{
  return shouldDisplayWeekend;
}

- (BOOL) shouldHideWeekend
{
  return ![self shouldDisplayWeekend];
}


/* URLs */

- (NSString *) appointmentViewURL
{
  id pkey;
  
  if (![(pkey = [[self appointment] valueForKey: @"uid"]) isNotNull])
    return nil;
  
  return [[[self clientObject] baseURLForAptWithUID: [pkey stringValue]
                               inContext: [self context]]
           stringByAppendingString: @"/view"];
}

/* fetching */

- (NSCalendarDate *) startDate
{
  return [self selectedDate];
}
- (NSCalendarDate *) endDate
{
  return [[self startDate] tomorrow];
}

- (NSArray *) fetchCoreInfos
{
  if (!self->appointments)
    {
      id             folder;
      NSCalendarDate *sd, *ed;

      folder = [self clientObject];
      sd = [self startDate];
      ed = [self endDate];
      [self setAppointments: [folder fetchOverviewInfosFrom: sd to: ed]];
    }

  return self->appointments;
}

/* query parameters */

- (BOOL) shouldDisplayRejectedAppointments
{
  NSString *bv;
  
  bv = [self queryParameterForKey: @"dr"];
  if (!bv) return NO;
  return [bv boolValue];
}

- (NSDictionary *) toggleShowRejectedAptsQueryParameters
{
  NSMutableDictionary *qp;
  BOOL                shouldDisplay;
  
  shouldDisplay = ![self shouldDisplayRejectedAppointments];
  qp = [[[self queryParameters] mutableCopy] autorelease];
  [qp setObject: shouldDisplay ? @"1" : @"0" forKey: @"dr"];
  return qp;
}

- (NSString *) toggleShowRejectedAptsLabel
{
  if (![self shouldDisplayRejectedAppointments])
    return @"show_rejected_apts";
  return @"hide_rejected_apts";
}

/* date selection & conversion */

- (NSDictionary *) _dateQueryParametersWithOffset: (int) daysOffset
{
  NSCalendarDate *date;
  
  date = [[self startDate] dateByAddingYears: 0 months: 0
                           days: daysOffset
                           hours: 0 minutes: 0 seconds: 0];
  return [self queryParametersBySettingSelectedDate: date];
}

- (NSDictionary *) todayQueryParameters
{
  NSCalendarDate *date;
    
  date = [NSCalendarDate date]; /* today */
  return [self queryParametersBySettingSelectedDate: date];
}

- (NSDictionary *) currentDayQueryParameters
{
  return [self queryParametersBySettingSelectedDate: self->currentDay];
}

/* calendarUIDs */

- (NSString *) formattedCalendarUIDs
{
  return [[[self clientObject] calendarUIDs]
           componentsJoinedByString: @", "];
}

/* Actions */

- (NSString *) _userFolderURI
{
  WOContext *ctx;
  id        obj;
  NSURL     *url;

  ctx = [self context];
  obj = [[ctx objectTraversalStack] objectAtIndex: 1];
  url = [NSURL URLWithString: [obj baseURLInContext: ctx]];
  return [[url path] stringByUnescapingURL];
}

- (id) redirectForUIDsAction
{
  NSMutableString *uri;
  NSString *uidsString, *loc, *prevMethod, *userFolderID;
  id <WOActionResults> r;
  BOOL useGroups;
  unsigned index;

  uidsString = [self queryParameterForKey: @"userUIDString"];
  uidsString = [uidsString stringByTrimmingWhiteSpaces];
  [self setQueryParameter: nil forKey: @"userUIDString"];

  prevMethod = [self queryParameterForKey: @"previousMethod"];
  if (prevMethod == nil)
    prevMethod = @"";

  uri = [[NSMutableString alloc] initWithString: [self _userFolderURI]];
  /* if we have more than one entry, use groups - otherwise don't */
  useGroups = [uidsString rangeOfString: @","].length > 0;
  userFolderID = [uri lastPathComponent];
  if (useGroups)
    {
      NSArray *uids;

      uids = [uidsString componentsSeparatedByString: @","];
      /* guarantee that our id is the first */
      if (((index = [uids indexOfObject: userFolderID]) != NSNotFound)
          && (index != 0))
        {
          uids = [[uids mutableCopy] autorelease];
          [(NSMutableArray *) uids removeObjectAtIndex: index];
          [(NSMutableArray *) uids insertObject: userFolderID atIndex: 0];
          uidsString = [uids componentsJoinedByString: @","];
        }
      [uri appendString: @"Groups/_custom_"];
      [uri appendString: uidsString];
      [uri appendString: @"/"];
      NSLog (@"Group URI = '%@'", uri);
    }
  else
    {
      /* check if lastPathComponent is the base that we want to have */
      if ((([uidsString length] != 0)
           && (![userFolderID isEqualToString: uidsString])))
        {
          NSRange r;
          
          /* uri ends with an '/', so we have to adjust the range a little */
          r = NSMakeRange(0, [uri length] - 1);
          r = [uri rangeOfString: @"/"
                   options: NSBackwardsSearch
                   range: r];
          r = NSMakeRange(r.location + 1, [uri length] - r.location - 2);
          [uri replaceCharactersInRange: r withString: uidsString];
        }
    }
  [uri appendString: @"Calendar/"];
  [uri appendString: prevMethod];

#if 0
  NSLog(@"%s redirect uri:%@",
        __PRETTY_FUNCTION__,
        uri);
#endif
  loc = [self completeHrefForMethod: uri]; /* this might return uri! */
  r = [self redirectToLocation: loc];
  [uri release];
  return r;
}

@end /* UIxCalView */
