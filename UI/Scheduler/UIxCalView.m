// $Id: UIxCalView.m 1031 2007-03-07 22:52:32Z wolfgang $

#import "common.h"
//#import <OGoContentStore/OCSFolder.h>

#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/SoUser.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGCards/NGCards.h>

#import <SOGoUI/SOGoAptFormatter.h>
#import "UIxComponent+Agenor.h"

#import "SoObjects/Appointments/SOGoAppointmentFolder.h"
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoObject.h>

#import "UIxCalView.h"

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

      tz = [[self clientObject] userTimeZone];
      aptFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: tz];
      aptTooltipFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: tz];
      privateAptFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: tz];
      privateAptTooltipFormatter
        = [[SOGoAptFormatter alloc] initWithDisplayTimeZone: tz];
      [self configureFormatters];
      componentsData = [NSMutableDictionary new];
    }
  return self;
}

- (void) dealloc
{
  [componentsData release];
  [appointments               release];
  [allDayApts                 release];
  [appointment                release];
  [currentDay                 release];
  [aptFormatter               release];
  [aptTooltipFormatter        release];
  [privateAptFormatter        release];
  [privateAptTooltipFormatter release];
  [super dealloc];
}

/* subclasses should override this */
- (void) configureFormatters
{
  NSString *title;

  [aptFormatter setFullDetails];
  [aptTooltipFormatter setTooltip];
  [privateAptFormatter setPrivateDetails];
  [privateAptTooltipFormatter setPrivateTooltip];

  title = [self labelForKey: @"empty title"];
  [aptFormatter setTitlePlaceholder: title];
  [aptTooltipFormatter setTitlePlaceholder: title];

  title = [self labelForKey: @"private appointment"];
  [privateAptFormatter setPrivateTitle: title];
  [privateAptTooltipFormatter setPrivateTitle: title];
}

- (NSArray *) filterAppointments:(NSArray *) _apts
{
  NSMutableArray *filtered;
  unsigned i, count;
  NSString *email;
  NSDictionary *info;
  NSArray *partmails;
  unsigned p, pCount;
  BOOL shouldAdd;
  NSString *partmailsString;
  NSArray  *partstates;
  NSString *state;
  NSString *pEmail;

  if ([self shouldDisplayRejectedAppointments])
    return _apts;
  {
    count = [_apts count];
    filtered = [[[NSMutableArray alloc] initWithCapacity: count] autorelease];
    email = [self emailForUser];

    for (i = 0; i < count; i++)
      {
        shouldAdd = YES;
        info = [_apts objectAtIndex: i];
        partmailsString = [info objectForKey: @"partmails"];
        if ([partmailsString isNotNull])
          {
            partmails = [partmailsString componentsSeparatedByString: @"\n"];
            pCount = [partmails count];
            for (p = 0; p < pCount; p++)
              {
                pEmail = [partmails objectAtIndex: p];
                if ([pEmail isEqualToString: email])
                  {
                    partstates = [[info objectForKey: @"partstates"]
                                   componentsSeparatedByString: @"\n"];
                    state = [partstates objectAtIndex: p];
                    if ([state intValue] == iCalPersonPartStatDeclined)
                      shouldAdd = NO;
                    break;
                  }
              }
          }
        if (shouldAdd)
          [filtered addObject: info];
      }
  }

  return filtered;
}

/* accessors */

- (void) setAppointments:(NSArray *) _apts
{
  _apts = [self filterAppointments: _apts];
  ASSIGN(appointments, _apts);
}

- (NSArray *) appointments
{
  return appointments;
}

- (void) setAppointment:(id) _apt
{
  NSString *mailtoChunk;
  NSString *myEmail;

  ASSIGN(appointment, _apt);

  /* cache some info about apt for faster access */
  
  mailtoChunk = [_apt valueForKey: @"orgmail"];
  myEmail = [self emailForUser];
  if ([mailtoChunk rangeOfString: myEmail].length > 0)
    {
      aptFlags.isMyApt = YES;
      aptFlags.canAccessApt = YES;
    }
  else
    {
      NSString *partmails;

      aptFlags.isMyApt = NO;

      partmails = [_apt valueForKey: @"partmails"];
      if ([partmails rangeOfString: myEmail].length)
        aptFlags.canAccessApt = YES;
      else
        aptFlags.canAccessApt
          = ([[_apt valueForKey: @"classification"] intValue]
             == iCalAccessPublic);
    }
}

- (void) setTasks: (NSArray *) _tasks
{
  ASSIGN(tasks, _tasks);
}

- (NSArray *) tasks
{
  return tasks;
}

- (id) appointment
{
  return appointment;
}

- (BOOL) isMyApt
{
  return aptFlags.isMyApt ? YES : NO;
}

- (BOOL) canAccessApt
{
  return aptFlags.canAccessApt ? YES : NO;
}

- (BOOL) canNotAccessApt
{
  return aptFlags.canAccessApt ? NO : YES;
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
  if (aptFlags.canAccessApt)
    return aptFormatter;
  return privateAptFormatter;
}

- (SOGoAptFormatter *) aptTooltipFormatter
{
  if (aptFlags.canAccessApt)
    return aptTooltipFormatter;
  return privateAptTooltipFormatter;
}

/* TODO: remove this */
- (NSString *) shortTextForApt
{
  [self warnWithFormat: @"%s IS DEPRECATED!", __PRETTY_FUNCTION__];
  if (![self canAccessApt])
    return @"";
  return [[self aptFormatter] stringForObjectValue: appointment];
}

- (NSString *) shortTitleForApt
{
  NSString *title;

  [self warnWithFormat: @"%s IS DEPRECATED!", __PRETTY_FUNCTION__];

  if (![self canAccessApt])
    return @"";
  title = [appointment valueForKey: @"title"];
  if ([title length] > 12)
    title = [[title substringToIndex: 11] stringByAppendingString: @"..."];
  
  return title;
}

- (NSString *) tooltipForApt
{
  [self warnWithFormat: @"%s IS DEPRECATED!", __PRETTY_FUNCTION__];
  return [[self aptTooltipFormatter] stringForObjectValue: appointment
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
  [_day setTimeZone: [[self clientObject] userTimeZone]];
  ASSIGN(currentDay, _day);
}

- (NSCalendarDate *) currentDay
{
  return currentDay;
}

- (NSString *) currentDayName
{
  return [self localizedNameForDayOfWeek: [currentDay dayOfWeek]];
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

  if (allDayApts)
    return allDayApts;

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
    
  ASSIGN(allDayApts, filtered);
  [filtered release];
  return allDayApts;
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
  return 0;
}

- (unsigned) dayEndHour
{
  return 23;
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

- (NSArray *) activeCalendarFolders
{
  NSUserDefaults *ud;
  NSEnumerator *calendarUIDs;
  SOGoAppointmentFolder *currentFolder;
  NSMutableArray *folders;
  NSString *currentUID;
  SoSecurityManager *securityManager;

  securityManager = [SoSecurityManager sharedSecurityManager];

  folders = [NSMutableArray array];
  ud = [[context activeUser] userDefaults];
  calendarUIDs = [[[ud stringForKey: @"calendaruids"]
                    componentsSeparatedByString: @","] objectEnumerator];
  currentUID = [calendarUIDs nextObject];
  while (currentUID)
    {
      if (![currentUID hasPrefix: @"-"])
        {
          currentFolder = [[self clientObject] lookupCalendarFolderForUID: currentUID];
          if (currentFolder
              && ![securityManager validatePermission: SoPerm_AccessContentsInformation
                                   onObject: currentFolder
                                   inContext: context])
            [folders addObject: currentFolder];
        }
      currentUID = [calendarUIDs nextObject];
    }

  return folders;
}

- (NSArray *) _fetchCoreInfosForComponent: (NSString *) component
{
  NSArray *currentInfos;
  NSMutableArray *infos;
  NSEnumerator *folders;
  SOGoAppointmentFolder *currentFolder;

  infos = [componentsData objectForKey: component];
  if (!infos)
    {
      infos = [NSMutableArray array];
      folders = [[self activeCalendarFolders] objectEnumerator];
      currentFolder = [folders nextObject];
      while (currentFolder)
        {
          currentInfos = [currentFolder fetchCoreInfosFrom: [[self startDate] beginOfDay]
                                        to: [[self endDate] endOfDay]
                                        component: component];
          [currentInfos makeObjectsPerform: @selector (setObject:forKey:)
                        withObject: [currentFolder ownerInContext: nil]
                        withObject: @"owner"];
          [infos addObjectsFromArray: currentInfos];
          currentFolder = [folders nextObject];
        }
      [componentsData setObject: infos forKey: component];
    }

  return infos;
}

- (NSArray *) fetchCoreAppointmentsInfos
{
  if (!appointments)
    [self setAppointments: [self _fetchCoreInfosForComponent: @"vevent"]];
  
  return appointments;
}

- (NSArray *) fetchCoreTasksInfos
{
  if (!tasks)
    [self setTasks: [self _fetchCoreInfosForComponent: @"vtodo"]];
  
  return tasks;
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
  return [self queryParametersBySettingSelectedDate: [NSCalendarDate date]];
}

- (NSDictionary *) currentDayQueryParameters
{
  return [self queryParametersBySettingSelectedDate: currentDay];
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
  uidsString = [uidsString stringByTrimmingSpaces];
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
