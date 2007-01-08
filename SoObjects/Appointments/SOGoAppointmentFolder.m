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

#import <GDLContentStore/GCSFolder.h>
#import <SaxObjC/SaxObjC.h>
#import <NGCards/NGCards.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGExtensions/NGCalendarDateRange.h>

#import <NGObjWeb/SoClassSecurityInfo.h>
#import <SOGo/SOGoCustomGroupFolder.h>
#import <SOGo/AgenorUserManager.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/NSString+Utilities.h>

#import "common.h"

#import "SOGoAppointmentObject.h"
#import "SOGoTaskObject.h"

#import "SOGoAppointmentFolder.h"

#if APPLE_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSDate(UsedPrivates)
- (id)initWithTimeIntervalSince1970:(NSTimeInterval)_interval;
@end
#endif

@implementation SOGoAppointmentFolder

static NGLogger   *logger    = nil;
static NSNumber   *sharedYes = nil;

+ (int) version
{
  return [super version] + 1 /* v1 */;
}

+ (void) initialize
{
  NGLoggerManager *lm;
  static BOOL     didInit = NO;
  SoClassSecurityInfo *securityInfo;

  if (didInit) return;
  didInit = YES;
  
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  lm      = [NGLoggerManager defaultLoggerManager];
  logger  = [lm loggerForDefaultKey:@"SOGoAppointmentFolderDebugEnabled"];

  securityInfo = [self soClassSecurityInfo];
  [securityInfo declareRole: SOGoRole_Delegate
                asDefaultForPermission: SoPerm_AddDocumentsImagesAndFiles];
  [securityInfo declareRole: SOGoRole_Delegate
                asDefaultForPermission: SoPerm_ChangeImagesAndFiles];
  [securityInfo declareRoles: [NSArray arrayWithObjects:
                                         SOGoRole_Delegate,
                                       SOGoRole_Assistant, nil]
                asDefaultForPermission: SoPerm_View];

  sharedYes = [[NSNumber numberWithBool:YES] retain];
}

- (void) dealloc
{
  [self->uidToFilename release];
  [super dealloc];
}

/* logging */

- (id) debugLogger
{
  return logger;
}

/* selection */

- (NSArray *) calendarUIDs 
{
  /* this is used for group calendars (this folder just returns itself) */
  NSString *s;
  
  s = [[self container] nameInContainer];
  return [s isNotNull] ? [NSArray arrayWithObjects:&s count:1] : nil;
}

/* name lookup */

- (BOOL) isValidAppointmentName: (NSString *)_key
{
  return ([_key length] != 0);
}

- (id) lookupActionForCalDAVMethod: (NSString *)_key
{
  SoSelectorInvocation *invocation;
  NSString *name;

  name = [NSString stringWithFormat: @"%@:", [_key davMethodToObjC]];

  invocation = [[SoSelectorInvocation alloc]
                 initWithSelectorNamed: name
                 addContextParameter: YES];
  [invocation autorelease];

  return invocation;
}

- (void) appendObject: (NSDictionary *) object
          withBaseURL: (NSString *) baseURL
     toREPORTResponse: (WOResponse *) r
{
  SOGoContentObject *ocsObject;
  NSString *c_name, *etagLine, *calString;

  c_name = [object objectForKey: @"c_name"];

  ocsObject = [SOGoContentObject objectWithName: c_name
                                 inContainer: self];

  [r appendContentString: @"  <D:response>\r\n"];
  [r appendContentString: @"    <D:href>"];
  [r appendContentString: baseURL];
  if (![baseURL hasSuffix: @"/"])
    [r appendContentString: @"/"];
  [r appendContentString: c_name];
  [r appendContentString: @"</D:href>\r\n"];

  [r appendContentString: @"    <D:propstat>\r\n"];
  [r appendContentString: @"      <D:prop>\r\n"];
  etagLine = [NSString stringWithFormat: @"        <D:getetag>%@</D:getetag>\r\n",
                       [ocsObject davEntityTag]];
  [r appendContentString: etagLine];
  [r appendContentString: @"      </D:prop>\r\n"];
  [r appendContentString: @"      <D:status>HTTP/1.1 200 OK</D:status>\r\n"];
  [r appendContentString: @"    </D:propstat>\r\n"];
  [r appendContentString: @"    <C:calendar-data>"];
  calString = [[ocsObject contentAsString] stringByEscapingXMLString];
  [r appendContentString: calString];
  [r appendContentString: @"</C:calendar-data>\r\n"];
  [r appendContentString: @"  </D:response>\r\n"];
}

- (void) _appendTimeRange: (id <DOMElement>) timeRangeElement
                 toFilter: (NSMutableDictionary *) filter
{
  NSCalendarDate *parsedDate;

  parsedDate = [[timeRangeElement attribute: @"start"] asCalendarDate];
  [filter setObject: parsedDate forKey: @"start"];
  parsedDate = [[timeRangeElement attribute: @"end"] asCalendarDate];
  [filter setObject: parsedDate forKey: @"end"];
}

- (NSDictionary *) _parseCalendarFilter: (id <DOMElement>) filterElement
{
  NSMutableDictionary *filterData;
  id <DOMNode> parentNode;
  id <DOMNodeList> ranges;
  NSString *componentName;

  parentNode = [filterElement parentNode];
  if ([[parentNode tagName] isEqualToString: @"comp-filter"]
      && [[parentNode attribute: @"name"] isEqualToString: @"VCALENDAR"])
    {
      componentName = [[filterElement attribute: @"name"] lowercaseString];
      filterData = [NSMutableDictionary new];
      [filterData autorelease];
      [filterData setObject: componentName forKey: @"name"];
      ranges = [filterElement getElementsByTagName: @"time-range"];
      if ([ranges count])
        [self _appendTimeRange: [ranges objectAtIndex: 0]
              toFilter: filterData];
    }
  else
    filterData = nil;

  return filterData;
}

- (NSArray *) _parseCalendarFilters: (id <DOMElement>) parentNode
{
  NSEnumerator *children;
  id<DOMElement> node;
  NSMutableArray *filters;
  NSDictionary *filter;

  filters = [NSMutableArray new];

  children = [[parentNode getElementsByTagName: @"comp-filter"] objectEnumerator];
  node = [children nextObject];
  while (node)
    {
      filter = [self _parseCalendarFilter: node];
      if (filter)
        [filters addObject: filter];
      node = [children nextObject];
    }

  return filters;
}

- (void) _appendComponentsMatchingFilters: (NSArray *) filters
                               toResponse: (WOResponse *) response
                                inContext: (WOContext *) context
{
  NSArray *apts;
  unsigned int count, max;
  NSDictionary *currentFilter, *appointment;
  NSEnumerator *appointments;
  NSString *baseURL;

  baseURL = [self baseURLInContext: context];

  max = [filters count];
  for (count = 0; count < max; count++)
    {
      currentFilter = [filters objectAtIndex: 0];
      apts = [self fetchCoreInfosFrom: [currentFilter objectForKey: @"start"]
                   to: [currentFilter objectForKey: @"end"]
                   component: [currentFilter objectForKey: @"name"]];
      appointments = [apts objectEnumerator];
      appointment = [appointments nextObject];
      while (appointment)
        {
          [self appendObject: appointment
                withBaseURL: baseURL
                toREPORTResponse: response];
          appointment = [appointments nextObject];
        }
    }
}

- (id) davCalendarQuery: (id) context
{
  WOResponse *r;
  NSArray *filters;
  id <DOMDocument> document;

  r = [context response];
  [r setStatus: 207];
  [r setContentEncoding: NSUTF8StringEncoding];
  [r setHeader: @"text/xml; charset=\"utf-8\"" forKey: @"content-type"];
  [r setHeader: @"no-cache" forKey: @"pragma"];
  [r setHeader: @"no-cache" forKey: @"cache-control"];
  [r appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n"];
  [r appendContentString: @"<D:multistatus xmlns:D=\"DAV:\""
     @" xmlns:C=\"urn:ietf:params:xml:ns:caldav\">\r\n"];

  document = [[context request] contentAsDOMDocument];
  filters = [self _parseCalendarFilters: [document documentElement]];
  [self _appendComponentsMatchingFilters: filters
        toResponse: r
        inContext: context];
  [r appendContentString:@"</D:multistatus>\r\n"];

  return r;
}

- (Class) objectClassForContent: (NSString *) content
{
  iCalCalendar *calendar;
  NSArray *elements;
  NSString *firstTag;
  Class objectClass;

  objectClass = Nil;

  calendar = [iCalCalendar parseSingleFromSource: content];
  if (calendar)
    {
      elements = [calendar allObjects];
      if ([elements count])
        {
          firstTag = [[[elements objectAtIndex: 0] tag] uppercaseString];
          if ([firstTag isEqualToString: @"VEVENT"])
            objectClass = [SOGoAppointmentObject class];
          else if ([firstTag isEqualToString: @"VTODO"])
            objectClass = [SOGoTaskObject class];
        }
    }

  return objectClass;
}

- (id) deduceObjectForName: (NSString *)_key
                 inContext: (id)_ctx
{
  WORequest *request;
  NSString *method;
  Class objectClass;
  id obj;

  request = [_ctx request];
  method = [request method];
  if ([method isEqualToString: @"PUT"])
    objectClass = [self objectClassForContent: [request contentAsString]];
  else
    objectClass = [self objectClassForResourceNamed: _key];

  if (objectClass)
    obj = [objectClass objectWithName: _key inContainer: self];
  else
    obj = nil;

  return obj;
}

- (BOOL) requestNamedIsHandledLater: (NSString *) name
                          inContext: (WOContext *) context
{
  return [name isEqualToString: @"OPTIONS"];
}

- (id) lookupName: (NSString *)_key
        inContext: (id)_ctx
          acquire: (BOOL)_flag
{
  id obj;
  NSString *url;
  BOOL handledLater;

  /* first check attributes directly bound to the application */
  handledLater = [self requestNamedIsHandledLater: _key inContext: _ctx];
  if (handledLater)
    obj = nil;
  else
    {
      obj = [super lookupName:_key inContext:_ctx acquire:NO];
      if (!obj)
        {
          if ([_key hasPrefix: @"{urn:ietf:params:xml:ns:caldav}"])
            obj
              = [self lookupActionForCalDAVMethod: [_key substringFromIndex: 31]];
          else if ([self isValidAppointmentName:_key])
            {
              url = [[[_ctx request] uri] urlWithoutParameters];
              if ([url hasSuffix: @"AsTask"])
                obj = [SOGoTaskObject objectWithName: _key
                                      inContainer: self];
              else if ([url hasSuffix: @"AsAppointment"])
                obj = [SOGoAppointmentObject objectWithName: _key
                                             inContainer: self];
              else
                obj = [self deduceObjectForName: _key
                            inContext: _ctx];
            }
        }
      if (!obj)
        obj = [NSException exceptionWithHTTPStatus:404 /* Not Found */];
    }

  return obj;
}

- (NSArray *) davComplianceClassesInContext: (id)_ctx
{
  NSMutableArray *classes;
  NSArray *primaryClasses;

  classes = [NSMutableArray new];
  [classes autorelease];

  primaryClasses = [super davComplianceClassesInContext: _ctx];
  if (primaryClasses)
    [classes addObjectsFromArray: primaryClasses];
  [classes addObject: @"access-control"];
  [classes addObject: @"calendar-access"];

  return classes;
}

- (NSString *) groupDavResourceType
{
  return @"vevent-collection";
}

/* vevent UID handling */

- (NSString *) resourceNameForEventUID: (NSString *)_u
                              inFolder: (GCSFolder *)_f
{
  static NSArray *nameFields = nil;
  EOQualifier *qualifier;
  NSArray     *records;
  
  if (![_u isNotNull]) return nil;
  if (_f == nil) {
    [self errorWithFormat:@"(%s): missing folder for fetch!",
	    __PRETTY_FUNCTION__];
    return nil;
  }
  
  if (nameFields == nil)
    nameFields = [[NSArray alloc] initWithObjects:@"c_name", nil];
  
  qualifier = [EOQualifier qualifierWithQualifierFormat:@"uid = %@", _u];
  records   = [_f fetchFields: nameFields matchingQualifier: qualifier];
  
  if ([records count] == 1)
    return [[records objectAtIndex:0] valueForKey:@"c_name"];
  if ([records count] == 0)
    return nil;
  
  [self errorWithFormat:
	  @"The storage contains more than file with the same UID!"];
  return [[records objectAtIndex:0] valueForKey:@"c_name"];
}

- (NSString *) resourceNameForEventUID: (NSString *) _uid
{
  /* caches UIDs */
  GCSFolder *folder;
  NSString  *rname;
  
  if (![_uid isNotNull])
    return nil;
  if ((rname = [self->uidToFilename objectForKey:_uid]) != nil)
    return [rname isNotNull] ? rname : nil;
  
  if ((folder = [self ocsFolder]) == nil) {
    [self errorWithFormat:@"(%s): missing folder for fetch!",
      __PRETTY_FUNCTION__];
    return nil;
  }

  if (self->uidToFilename == nil)
    self->uidToFilename = [[NSMutableDictionary alloc] initWithCapacity:16];
  
  if ((rname = [self resourceNameForEventUID:_uid inFolder:folder]) == nil)
    [self->uidToFilename setObject:[NSNull null] forKey:_uid];
  else
    [self->uidToFilename setObject:rname forKey:_uid];
  
  return rname;
}

- (Class) objectClassForResourceNamed: (NSString *) c_name
{
  EOQualifier *qualifier;
  NSArray *records;
  NSString *component;
  Class objectClass;

  qualifier = [EOQualifier qualifierWithQualifierFormat:@"c_name = %@", c_name];
  records = [[self ocsFolder] fetchFields: [NSArray arrayWithObject: @"component"]
                              matchingQualifier: qualifier];

  if ([records count])
    {
      component = [[records objectAtIndex:0] valueForKey: @"component"];
      if ([component isEqualToString: @"vevent"])
        objectClass = [SOGoAppointmentObject class];
      else if ([component isEqualToString: @"vtodo"])
        objectClass = [SOGoTaskObject class];
      else
        objectClass = Nil;
    }
  else
    objectClass = Nil;
  
  return objectClass;
}

/* fetching */

- (NSMutableDictionary *) fixupRecord: (NSDictionary *) _record
                           fetchRange: (NGCalendarDateRange *) _r
{
  NSMutableDictionary *md;
  id tmp;
  
  md = [[_record mutableCopy] autorelease];
 
  if ((tmp = [_record objectForKey:@"startdate"])) {
    tmp = [[NSCalendarDate alloc] initWithTimeIntervalSince1970:
          (NSTimeInterval)[tmp unsignedIntValue]];
    [tmp setTimeZone: [self userTimeZone]];
    if (tmp) [md setObject:tmp forKey:@"startDate"];
    [tmp release];
  }
  else
    [self logWithFormat:@"missing 'startdate' in record?"];

  if ((tmp = [_record objectForKey:@"enddate"])) {
    tmp = [[NSCalendarDate alloc] initWithTimeIntervalSince1970:
          (NSTimeInterval)[tmp unsignedIntValue]];
    [tmp setTimeZone: [self userTimeZone]];
    if (tmp) [md setObject:tmp forKey:@"endDate"];
    [tmp release];
  }
  else
    [self logWithFormat:@"missing 'enddate' in record?"];

  return md;
}

- (NSMutableDictionary *) fixupCycleRecord: (NSDictionary *) _record
                                cycleRange: (NGCalendarDateRange *) _r
{
  NSMutableDictionary *md;
  id tmp;
  
  md = [[_record mutableCopy] autorelease];
  
  /* cycle is in _r */
  tmp = [_r startDate];
  [tmp setTimeZone:[self userTimeZone]];
  [md setObject:tmp forKey:@"startDate"];
  tmp = [_r endDate];
  [tmp setTimeZone:[self userTimeZone]];
  [md setObject:tmp forKey:@"endDate"];
  
  return md;
}

- (void) _flattenCycleRecord: (NSDictionary *) _row
                    forRange: (NGCalendarDateRange *) _r
                   intoArray: (NSMutableArray *) _ma
{
  NSMutableDictionary *row;
  NSDictionary        *cycleinfo;
  NSCalendarDate      *startDate, *endDate;
  NGCalendarDateRange *fir;
  NSArray             *rules, *exRules, *exDates, *ranges;
  unsigned            i, count;

  cycleinfo  = [[_row objectForKey:@"cycleinfo"] propertyList];
  if (cycleinfo == nil) {
    [self errorWithFormat:@"cyclic record doesn't have cycleinfo -> %@", _row];
    return;
  }

  row = [self fixupRecord:_row fetchRange: _r];
  [row removeObjectForKey:@"cycleinfo"];
  [row setObject:sharedYes forKey:@"isRecurrentEvent"];

  startDate = [row objectForKey:@"startDate"];
  endDate   = [row objectForKey:@"endDate"];
  fir       = [NGCalendarDateRange calendarDateRangeWithStartDate:startDate
                                   endDate:endDate];
  rules     = [cycleinfo objectForKey:@"rules"];
  exRules   = [cycleinfo objectForKey:@"exRules"];
  exDates   = [cycleinfo objectForKey:@"exDates"];

  ranges = [iCalRecurrenceCalculator recurrenceRangesWithinCalendarDateRange:_r
                                     firstInstanceCalendarDateRange:fir
                                     recurrenceRules:rules
                                     exceptionRules:exRules
                                     exceptionDates:exDates];
  count = [ranges count];
  for (i = 0; i < count; i++) {
    NGCalendarDateRange *rRange;
    id fixedRow;
    
    rRange   = [ranges objectAtIndex:i];
    fixedRow = [self fixupCycleRecord:row cycleRange:rRange];
    if (fixedRow != nil) [_ma addObject:fixedRow];
  }
}

- (NSArray *) fixupRecords: (NSArray *) _records
                fetchRange: (NGCalendarDateRange *) _r
{
  // TODO: is the result supposed to be sorted by date?
  NSMutableArray *ma;
  unsigned i, count;

  if (_records == nil) return nil;
  if ((count = [_records count]) == 0)
    return _records;
  
  ma = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    id row; // TODO: what is the type of the record?
    
    row = [_records objectAtIndex:i];
    row = [self fixupRecord:row fetchRange:_r];
    if (row != nil) [ma addObject:row];
  }
  return ma;
}

- (NSArray *) fixupCyclicRecords: (NSArray *) _records
                      fetchRange: (NGCalendarDateRange *) _r
{
  // TODO: is the result supposed to be sorted by date?
  NSMutableArray *ma;
  unsigned i, count;
  
  if (_records == nil) return nil;
  if ((count = [_records count]) == 0)
    return _records;
  
  ma = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    id row; // TODO: what is the type of the record?
    
    row = [_records objectAtIndex:i];
    [self _flattenCycleRecord:row forRange:_r intoArray:ma];
  }
  return ma;
}

- (NSString *) _sqlStringForComponent: (id) _component
{
  NSString *sqlString;
  NSArray *components;

  if (_component)
    {
      if ([_component isKindOfClass: [NSArray class]])
        components = _component;
      else
        components = [NSArray arrayWithObject: _component];

      sqlString
        = [NSString stringWithFormat: @" AND (component = '%@')",
                    [components componentsJoinedByString: @"' OR component = '"]];
    }
  else
    sqlString = @"";

  return sqlString;
}

- (NSString *) _sqlStringRangeFrom: (NSCalendarDate *) _startDate
                                to: (NSCalendarDate *) _endDate
{
  unsigned int start, end;

  start = (unsigned int) [_startDate timeIntervalSince1970];
  end = (unsigned int) [_endDate timeIntervalSince1970];

  return [NSString stringWithFormat:
                     @" AND (startdate <= %d) AND (enddate >= %d)",
                   end, start];
}

- (NSArray *) fetchFields: (NSArray *) _fields
               fromFolder: (GCSFolder *) _folder
                     from: (NSCalendarDate *) _startDate
                       to: (NSCalendarDate *) _endDate 
                component: (id) _component
{
  EOQualifier *qualifier;
  NSMutableArray *fields, *ma = nil;
  NSArray *records;
  NSString *sql, *dateSqlString, *componentSqlString; /* , *owner; */
  NGCalendarDateRange *r;

  if (_folder == nil) {
    [self errorWithFormat:@"(%s): missing folder for fetch!",
            __PRETTY_FUNCTION__];
    return nil;
  }
  
  if (_startDate && _endDate)
    {
      r = [NGCalendarDateRange calendarDateRangeWithStartDate: _startDate
                               endDate: _endDate];
      dateSqlString = [self _sqlStringRangeFrom: _startDate to: _endDate];
    }
  else
    {
      r = nil;
      dateSqlString = @"";
    }

  componentSqlString = [self _sqlStringForComponent: _component];

  /* prepare mandatory fields */

  fields = [NSMutableArray arrayWithArray: _fields];
  [fields addObject: @"uid"];
  [fields addObject: @"startdate"];
  [fields addObject: @"enddate"];

  if (logger)
    [self debugWithFormat:@"should fetch (%@=>%@) ...", _startDate, _endDate];

  sql = [NSString stringWithFormat: @"(iscycle = 0)%@%@",
                  dateSqlString, componentSqlString];

  /* fetch non-recurrent apts first */
  qualifier = [EOQualifier qualifierWithQualifierFormat: sql];

  records = [_folder fetchFields: fields matchingQualifier: qualifier];
  if (records)
    {
      if (r)
        records = [self fixupRecords: records fetchRange: r];
      if (logger)
        [self debugWithFormat: @"fetched %i records: %@",
              [records count], records];
      ma = [NSMutableArray arrayWithArray: records];
    }

  /* fetch recurrent apts now */
  sql = [NSString stringWithFormat: @"(iscycle = 1)%@%@",
                  dateSqlString, componentSqlString];
  qualifier = [EOQualifier qualifierWithQualifierFormat: sql];

  [fields addObject: @"cycleinfo"];

  records = [_folder fetchFields: fields matchingQualifier: qualifier];
  if (records)
    {
      if (logger)
        [self debugWithFormat: @"fetched %i cyclic records: %@",
              [records count], records];
      if (r)
        records = [self fixupCyclicRecords: records fetchRange: r];
      if (!ma)
        ma = [NSMutableArray arrayWithCapacity: [records count]];

//       owner = [self ownerInContext: nil];
      [ma addObjectsFromArray: records];
    }
  else if (!ma)
    {
      [self errorWithFormat: @"(%s): fetch failed!", __PRETTY_FUNCTION__];
      return nil;
    }

  /* NOTE: why do we sort here?
     This probably belongs to UI but cannot be achieved as fast there as
     we can do it here because we're operating on a mutable array -
     having the apts sorted is never a bad idea, though
  */
  [ma sortUsingSelector: @selector (compareAptsAscending:)];
  if (logger)
    [self debugWithFormat:@"returning %i records", [ma count]];

//   [ma makeObjectsPerform: @selector (setObject:forKey:)
//       withObject: owner
//       withObject: @"owner"];

  return ma;
}

/* override this in subclasses */
- (NSArray *) fetchFields: (NSArray *) _fields
                     from: (NSCalendarDate *) _startDate
                       to: (NSCalendarDate *) _endDate 
                component: (id) _component
{
  GCSFolder *folder;
  
  if ((folder = [self ocsFolder]) == nil) {
    [self errorWithFormat:@"(%s): missing folder for fetch!",
      __PRETTY_FUNCTION__];
    return nil;
  }

  return [self fetchFields: _fields fromFolder: folder
               from: _startDate to: _endDate
               component: _component];
}


- (NSArray *) fetchFreeBusyInfosFrom: (NSCalendarDate *) _startDate
                                  to: (NSCalendarDate *) _endDate
{
  static NSArray *infos = nil; // TODO: move to a plist file
  
  if (!infos)
    infos = [[NSArray alloc] initWithObjects: @"partmails", @"partstates",
                             @"isopaque", @"status", nil];

  return [self fetchFields: infos from: _startDate to: _endDate
               component: @"vevent"];
}

- (NSArray *) fetchCoreInfosFrom: (NSCalendarDate *) _startDate
                              to: (NSCalendarDate *) _endDate
                       component: (id) _component
{
  static NSArray *infos = nil; // TODO: move to a plist file

  if (!infos)
    infos = [[NSArray alloc] initWithObjects:
                               @"c_name", @"component",
                             @"title", @"location", @"orgmail",
                             @"status", @"ispublic",
                             @"isallday", @"isopaque",
                             @"participants", @"partmails",
                             @"partstates", @"sequence", @"priority", nil];

  return [self fetchFields: infos from: _startDate to: _endDate component: _component];
}

- (void) deleteEntriesWithIds: (NSArray *) ids
{
  Class objectClass;
  unsigned int count, max;
  NSString *currentId, *currentUser;
  WOContext *context;
  id deleteObject;

  context = [[WOApplication application] context];
  currentUser = [[context activeUser] login];

  max = [ids count];
  for (count = 0; count < max; count++)
    {
      currentId = [ids objectAtIndex: count];
      objectClass
        = [self objectClassForResourceNamed: currentId];
      deleteObject = [objectClass objectWithName: currentId
                                  inContainer: self];
      if ([currentUser isEqualToString: [deleteObject ownerInContext: nil]])
        {
          [deleteObject delete];
          [deleteObject primaryDelete];
        }
    }
}

/* URL generation */

- (NSString *) baseURLForAptWithUID: (NSString *)_uid
                          inContext: (id)_ctx
{
  // TODO: who calls this?
  NSString *url;
  
  if ([_uid length] == 0)
    return nil;
  
  url = [self baseURLInContext:_ctx];
  if (![url hasSuffix:@"/"])
    url = [url stringByAppendingString:@"/"];
  
  // TODO: this should run a query to determine the uid!
  return [url stringByAppendingString:_uid];
}

/* folder management */

- (id) lookupHomeFolderForUID: (NSString *) _uid
                    inContext: (id)_ctx
{
  // TODO: DUP to SOGoGroupFolder
  NSException *error = nil;
  NSArray     *path;
  id          ctx, result;

  if (![_uid isNotNull])
    return nil;
  
  if (_ctx == nil) _ctx = [[WOApplication application] context];
  
  /* create subcontext, so that we don't destroy our environment */
  
  if ((ctx = [_ctx createSubContext]) == nil) {
    [self errorWithFormat:@"could not create SOPE subcontext!"];
    return nil;
  }
  
  /* build path */
  
  path = _uid != nil ? [NSArray arrayWithObjects:&_uid count:1] : nil;
  
  /* traverse path */
  
  result = [[ctx application] traversePathArray:path inContext:ctx
			      error:&error acquire:NO];
  if (error != nil) {
    [self errorWithFormat:@"folder lookup failed (uid=%@): %@",
            _uid, error];
    return nil;
  }
  
  [self debugWithFormat:@"Note: got folder for uid %@ path %@: %@",
	  _uid, [path componentsJoinedByString:@"=>"], result];
  return result;
}

- (SOGoAppointmentFolder *) lookupCalendarFolderForUID: (NSString *) uid
{
  SOGoFolder *upperContainer;
  SOGoUserFolder *userFolder;
  SOGoAppointmentFolder *calendarFolder;

  upperContainer = [[self container] container];
  userFolder = [SOGoUserFolder objectWithName: uid
                               inContainer: upperContainer];
  calendarFolder = [SOGoAppointmentFolder objectWithName: @"Calendar"
                                          inContainer: userFolder];
  [calendarFolder
    setOCSPath: [NSString stringWithFormat: @"/Users/%@/Calendar", uid]];
  [calendarFolder setOwner: uid];

  return calendarFolder;
}

- (NSArray *) lookupCalendarFoldersForUIDs: (NSArray *) _uids
                                 inContext: (id)_ctx
{
  /* Note: can return NSNull objects in the array! */
  NSMutableArray *folders;
  NSEnumerator *e;
  NSString     *uid;
  
  if ([_uids count] == 0) return nil;
  folders = [NSMutableArray arrayWithCapacity:16];
  e = [_uids objectEnumerator];
  while ((uid = [e nextObject])) {
    id folder;
    
    folder = [self lookupCalendarFolderForUID: uid];
    if (![folder isNotNull])
      [self logWithFormat:@"Note: did not find folder for uid: '%@'", uid];
    
    /* Note: intentionally add 'null' folders to allow a mapping */
    [folders addObject:folder ? folder : [NSNull null]];
  }
  return folders;
}

- (NSArray *) lookupFreeBusyObjectsForUIDs: (NSArray *) _uids
                                 inContext: (id) _ctx
{
  /* Note: can return NSNull objects in the array! */
  NSMutableArray *objs;
  NSEnumerator   *e;
  NSString       *uid;
  
  if ([_uids count] == 0) return nil;
  objs = [NSMutableArray arrayWithCapacity:16];
  e    = [_uids objectEnumerator];
  while ((uid = [e nextObject])) {
    id obj;
    
    obj = [self lookupHomeFolderForUID:uid inContext:nil];
    if ([obj isNotNull]) {
      obj = [obj lookupName:@"freebusy.ifb" inContext:nil acquire:NO];
      if ([obj isKindOfClass:[NSException class]])
	obj = nil;
    }
    if (![obj isNotNull])
      [self logWithFormat:@"Note: did not find freebusy.ifb for uid: '%@'", uid];
    
    /* Note: intentionally add 'null' folders to allow a mapping */
    [objs addObject:obj ? obj : [NSNull null]];
  }
  return objs;
}

- (NSArray *) uidsFromICalPersons: (NSArray *) _persons
{
  /* Note: can return NSNull objects in the array! */
  NSMutableArray    *uids;
  AgenorUserManager *um;
  unsigned          i, count;
  
  if (_persons == nil)
    return nil;

  count = [_persons count];
  uids  = [NSMutableArray arrayWithCapacity:count + 1];
  um    = [AgenorUserManager sharedUserManager];
  
  for (i = 0; i < count; i++) {
    iCalPerson *person;
    NSString   *email;
    NSString   *uid;
    
    person = [_persons objectAtIndex:i];
    email  = [person rfc822Email];
    if ([email isNotNull]) {
      uid = [um getUIDForEmail:email];
    }
    else
      uid = nil;
    
    [uids addObject:(uid != nil ? uid : (id)[NSNull null])];
  }
  return uids;
}

- (NSArray *)lookupCalendarFoldersForICalPerson: (NSArray *) _persons
                                      inContext: (id) _ctx
{
  /* Note: can return NSNull objects in the array! */
  NSArray *uids;

  if ((uids = [self uidsFromICalPersons:_persons]) == nil)
    return nil;
  
  return [self lookupCalendarFoldersForUIDs:uids inContext:_ctx];
}

- (id) lookupGroupFolderForUIDs: (NSArray *) _uids
                      inContext: (id)_ctx
{
  SOGoCustomGroupFolder *folder;
  
  if (_uids == nil)
    return nil;

  folder = [[SOGoCustomGroupFolder alloc] initWithUIDs:_uids inContainer:self];
  return [folder autorelease];
}

- (id) lookupGroupCalendarFolderForUIDs: (NSArray *) _uids
                              inContext: (id) _ctx
{
  SOGoCustomGroupFolder *folder;
  
  if ((folder = [self lookupGroupFolderForUIDs:_uids inContext:_ctx]) == nil)
    return nil;
  
  folder = [folder lookupName:@"Calendar" inContext:_ctx acquire:NO];
  if (![folder isNotNull])
    return nil;
  if ([folder isKindOfClass:[NSException class]]) {
    [self debugWithFormat:@"Note: could not lookup 'Calendar' in folder: %@",
	    folder];
    return nil;
  }
  
  return folder;
}

/* bulk fetches */

- (NSArray *) fetchAllSOGoAppointments
{
  /* 
     Note: very expensive method, do not use unless absolutely required.
           returns an array of SOGoAppointment objects.
	   
     Note that we can leave out the filenames, supposed to be stored
     in the 'uid' field of the iCalendar object!
  */
  NSMutableArray *events;
  NSDictionary *files;
  NSEnumerator *contents;
  NSString     *content;
  
  /* fetch all raw contents */
  
  files = [self fetchContentStringsAndNamesOfAllObjects];
  if (![files isNotNull]) return nil;
  if ([files isKindOfClass:[NSException class]]) return (id)files;
  
  /* transform to SOGo appointments */
  
  events   = [NSMutableArray arrayWithCapacity:[files count]];
  contents = [files objectEnumerator];
  while ((content = [contents nextObject]) != nil)
    [events addObject: [iCalCalendar parseSingleFromSource: content]];
  
  return events;
}

/* folder type */

- (NSString *) outlookFolderClass
{
  return @"IPF.Appointment";
}

@end /* SOGoAppointmentFolder */
