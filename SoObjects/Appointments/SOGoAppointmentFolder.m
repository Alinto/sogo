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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOMessage.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NGLoggerManager.h>
#import <NGExtensions/NSString+misc.h>
#import <GDLContentStore/GCSFolder.h>
#import <DOM/DOMProtocols.h>
#import <EOControl/EOQualifier.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRecurrenceCalculator.h>
#import <NGCards/NSString+NGCards.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SaxObjC/SaxObjC.h>
#import <SaxObjC/XMLNamespaces.h>

// #import <NGObjWeb/SoClassSecurityInfo.h>
#import <SOGo/SOGoCustomGroupFolder.h>
#import <SOGo/LDAPUserManager.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>

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
//   SoClassSecurityInfo *securityInfo;

  if (didInit) return;
  didInit = YES;
  
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  lm      = [NGLoggerManager defaultLoggerManager];
  logger  = [lm loggerForDefaultKey: @"SOGoAppointmentFolderDebugEnabled"];

//   securityInfo = [self soClassSecurityInfo];
//   [securityInfo declareRole: SOGoRole_Delegate
//                 asDefaultForPermission: SoPerm_AddDocumentsImagesAndFiles];
//   [securityInfo declareRole: SOGoRole_Delegate
//                 asDefaultForPermission: SoPerm_ChangeImagesAndFiles];
//   [securityInfo declareRoles: [NSArray arrayWithObjects:
//                                          SOGoRole_Delegate,
//                                        SOGoRole_Assistant, nil]
//                 asDefaultForPermission: SoPerm_View];

  sharedYes = [[NSNumber numberWithBool: YES] retain];
}

- (id) initWithName: (NSString *) name
	inContainer: (id) newContainer
{
  if ((self = [super initWithName: name inContainer: newContainer]))
    {
      timeZone = [[context activeUser] timeZone];
    }

  return self;
}

- (void) dealloc
{
  [uidToFilename release];
  [super dealloc];
}

/* logging */

- (id) debugLogger
{
  return logger;
}

- (BOOL) folderIsMandatory
{
  return YES;
}

/* selection */

- (NSArray *) calendarUIDs 
{
  /* this is used for group calendars (this folder just returns itself) */
  NSString *s;
  
  s = [[self container] nameInContainer];
//   [self logWithFormat:@"CAL UID: %@", s];
  return [s isNotNull] ? [NSArray arrayWithObjects:&s count:1] : nil;
}

/* name lookup */

- (BOOL) isValidAppointmentName: (NSString *)_key
{
  return ([_key length] != 0);
}

- (void) appendObject: (NSDictionary *) object
          withBaseURL: (NSString *) baseURL
     toREPORTResponse: (WOResponse *) r
{
  SOGoCalendarComponent *component;
  Class componentClass;
  NSString *name, *etagLine, *calString;

  name = [object objectForKey: @"c_name"];

  if ([[object objectForKey: @"c_component"] isEqualToString: @"vevent"])
    componentClass = [SOGoAppointmentObject class];
  else
    componentClass = [SOGoTaskObject class];

  component = [componentClass objectWithName: name inContainer: self];

  [r appendContentString: @"  <D:response>\r\n"];
  [r appendContentString: @"    <D:href>"];
  [r appendContentString: baseURL];
  if (![baseURL hasSuffix: @"/"])
    [r appendContentString: @"/"];
  [r appendContentString: name];
  [r appendContentString: @"</D:href>\r\n"];

  [r appendContentString: @"    <D:propstat>\r\n"];
  [r appendContentString: @"      <D:prop>\r\n"];
  etagLine = [NSString stringWithFormat: @"        <D:getetag>%@</D:getetag>\r\n",
                       [component davEntityTag]];
  [r appendContentString: etagLine];
  [r appendContentString: @"      </D:prop>\r\n"];
  [r appendContentString: @"      <D:status>HTTP/1.1 200 OK</D:status>\r\n"];
  [r appendContentString: @"    </D:propstat>\r\n"];
  [r appendContentString: @"    <C:calendar-data>"];
  calString = [[component contentAsString] stringByEscapingXMLString];
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

  children = [[parentNode getElementsByTagName: @"comp-filter"]
	       objectEnumerator];
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

- (NSArray *) davNamespaces
{
  return [NSArray arrayWithObject: @"urn:ietf:params:xml:ns:caldav"];
}

- (id) davCalendarQuery: (id) queryContext
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
        toResponse: r];
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
  handledLater = [self requestNamedIsHandledLater: _key];
  if (handledLater)
    obj = nil;
  else
    {
      obj = [super lookupName:_key inContext:_ctx acquire:NO];
      if (!obj)
        {
	  if ([self isValidAppointmentName:_key])
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

- (NSArray *) groupDavResourceType
{
  return [NSArray arrayWithObjects: @"vevent-collection",
		  @"vtodo-collection", nil];
}

- (NSArray *) davResourceType
{
  static NSArray *colType = nil;
  NSArray *cdCol, *gdRT, *gdVEventCol, *gdVTodoCol;

  if (!colType)
    {
      gdRT = [self groupDavResourceType];
      gdVEventCol = [NSArray arrayWithObjects: [gdRT objectAtIndex: 0],
			     XMLNS_GROUPDAV, nil];
      gdVTodoCol = [NSArray arrayWithObjects: [gdRT objectAtIndex: 1],
			    XMLNS_GROUPDAV, nil];
      cdCol = [NSArray arrayWithObjects: @"calendar", XMLNS_CALDAV, nil];
      colType = [NSArray arrayWithObjects: @"collection", cdCol,
			 gdVEventCol, gdVTodoCol, nil];
      [colType retain];
    }

  return colType;
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
    nameFields = [[NSArray alloc] initWithObjects: @"c_name", nil];
  
  qualifier = [EOQualifier qualifierWithQualifierFormat:@"c_uid = %@", _u];
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
  if ((rname = [uidToFilename objectForKey:_uid]) != nil)
    return [rname isNotNull] ? rname : nil;
  
  if ((folder = [self ocsFolder]) == nil) {
    [self errorWithFormat:@"(%s): missing folder for fetch!",
      __PRETTY_FUNCTION__];
    return nil;
  }

  if (uidToFilename == nil)
    uidToFilename = [[NSMutableDictionary alloc] initWithCapacity:16];
  
  if ((rname = [self resourceNameForEventUID:_uid inFolder:folder]) == nil)
    [uidToFilename setObject:[NSNull null] forKey:_uid];
  else
    [uidToFilename setObject:rname forKey:_uid];
  
  return rname;
}

- (Class) objectClassForResourceNamed: (NSString *) name
{
  EOQualifier *qualifier;
  NSArray *records;
  NSString *component;
  Class objectClass;

  qualifier = [EOQualifier qualifierWithQualifierFormat:@"c_name = %@", name];
  records = [[self ocsFolder] fetchFields: [NSArray arrayWithObject: @"c_component"]
                              matchingQualifier: qualifier];

  if ([records count])
    {
      component = [[records objectAtIndex:0] valueForKey: @"c_component"];
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
 
  if ((tmp = [_record objectForKey:@"c_startdate"])) {
    tmp = [[NSCalendarDate alloc] initWithTimeIntervalSince1970:
          (NSTimeInterval)[tmp unsignedIntValue]];
    [tmp setTimeZone: timeZone];
    if (tmp) [md setObject:tmp forKey:@"startDate"];
    [tmp release];
  }
  else
    [self logWithFormat:@"missing 'startdate' in record?"];

  if ((tmp = [_record objectForKey:@"c_enddate"])) {
    tmp = [[NSCalendarDate alloc] initWithTimeIntervalSince1970:
          (NSTimeInterval)[tmp unsignedIntValue]];
    [tmp setTimeZone: timeZone];
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
  [tmp setTimeZone: timeZone];
  [md setObject:tmp forKey:@"startDate"];
  tmp = [_r endDate];
  [tmp setTimeZone: timeZone];
  [md setObject:tmp forKey:@"endDate"];
  
  return md;
}

- (NSArray *) fixupRecords: (NSArray *) records
                fetchRange: (NGCalendarDateRange *) r
{
  // TODO: is the result supposed to be sorted by date?
  NSMutableArray *ma;
  unsigned count, max;
  id row; // TODO: what is the type of the record?

  if (records)
    {
      max = [records count];
      ma = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
	{
	  row = [self fixupRecord: [records objectAtIndex: count]
		      fetchRange: r];
	  if (row)
	    [ma addObject: row];
	}
    }
  else
    ma = nil;

  return ma;
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

  cycleinfo  = [[_row objectForKey:@"c_cycleinfo"] propertyList];
  if (cycleinfo == nil) {
    [self errorWithFormat:@"cyclic record doesn't have cycleinfo -> %@", _row];
    return;
  }

  row = [self fixupRecord:_row fetchRange: _r];
  [row removeObjectForKey: @"c_cycleinfo"];
  [row setObject: sharedYes forKey:@"isRecurrentEvent"];

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
        = [NSString stringWithFormat: @" AND (c_component = '%@')",
                    [components componentsJoinedByString: @"' OR c_component = '"]];
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
                     @" AND (c_startdate <= %u) AND (c_enddate >= %u)",
                   end, start];
}

- (NSString *) _privacyClassificationStringsForUID: (NSString *) uid
{
  NSMutableString *classificationString;
  NSString *currentRole;
  unsigned int counter;
  iCalAccessClass classes[] = {iCalAccessPublic, iCalAccessPrivate,
			       iCalAccessConfidential};

  classificationString = [NSMutableString string];
  for (counter = 0; counter < 3; counter++)
    {
      currentRole = [self roleForComponentsWithAccessClass: classes[counter]
			  forUser: uid];
      if ([currentRole length] > 0)
	[classificationString appendFormat: @"c_classification = %d or ",
			      classes[counter]];
    }

  return classificationString;
}

- (NSString *) _privacySqlString
{
  NSString *privacySqlString, *login, *email;
  SOGoUser *activeUser;

  activeUser = [context activeUser];
  login = [activeUser login];

  if ([login isEqualToString: owner])
    privacySqlString = @"";
  else if ([login isEqualToString: @"freebusy"])
    privacySqlString = @"and (c_isopaque = 1)";
  else
    {
#warning we do not manage all the user's possible emails
      email = [[activeUser primaryIdentity] objectForKey: @"email"];
      
      privacySqlString
        = [NSString stringWithFormat:
                      @"(%@(c_orgmail = '%@')"
		    @" or ((c_partmails caseInsensitiveLike '%@%%'"
		    @" or c_partmails caseInsensitiveLike '%%\n%@%%')))",
		    [self _privacyClassificationStringsForUID: login],
		    email, email, email];
    }
  
  return privacySqlString;
}

- (NSString *) roleForComponentsWithAccessClass: (iCalAccessClass) accessClass
					forUser: (NSString *) uid
{
  NSString *accessRole, *prefix, *currentRole, *suffix;
  NSEnumerator *acls;

  accessRole = nil;

  if (accessClass == iCalAccessPublic)
    prefix = @"Public";
  else if (accessClass == iCalAccessPrivate)
    prefix = @"Private";
  else
    prefix = @"Confidential";

  acls = [[self aclsForUser: uid] objectEnumerator];
  currentRole = [acls nextObject];
  while (currentRole && !accessRole)
    if ([currentRole hasPrefix: prefix])
      {
	suffix = [currentRole substringFromIndex: [prefix length]];
	accessRole = [NSString stringWithFormat: @"Component%@", suffix];
      }
    else
      currentRole = [acls nextObject];

  return accessRole;
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
  NSString *sql, *dateSqlString, *componentSqlString, *privacySqlString;
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
  privacySqlString = [self _privacySqlString];

  /* prepare mandatory fields */

  fields = [NSMutableArray arrayWithArray: _fields];
  [fields addObject: @"c_uid"];
  [fields addObject: @"c_startdate"];
  [fields addObject: @"c_enddate"];

  if (logger)
    [self debugWithFormat:@"should fetch (%@=>%@) ...", _startDate, _endDate];

  sql = [NSString stringWithFormat: @"(c_iscycle = 0)%@%@%@",
                  dateSqlString, componentSqlString, privacySqlString];

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
  sql = [NSString stringWithFormat: @"(c_iscycle = 1)%@%@%@",
                  dateSqlString, componentSqlString, privacySqlString];
  qualifier = [EOQualifier qualifierWithQualifierFormat: sql];

  [fields addObject: @"c_cycleinfo"];

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

      [ma addObjectsFromArray: records];
    }
  else if (!ma)
    {
      [self errorWithFormat: @"(%s): fetch failed!", __PRETTY_FUNCTION__];
      return nil;
    }

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
    infos = [[NSArray alloc] initWithObjects: @"c_partmails", @"c_partstates",
                             @"c_isopaque", @"c_status", nil];

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
                               @"c_name", @"c_component",
                             @"c_title", @"c_location", @"c_orgmail",
                             @"c_status", @"c_classification",
                             @"c_isallday", @"c_isopaque",
                             @"c_participants", @"c_partmails",
                             @"c_partstates", @"c_sequence", @"c_priority",
			     nil];

  return [self fetchFields: infos from: _startDate to: _endDate
               component: _component];
}

- (void) deleteEntriesWithIds: (NSArray *) ids
{
  Class objectClass;
  unsigned int count, max;
  NSString *currentId;
  id deleteObject;

  max = [ids count];
  for (count = 0; count < max; count++)
    {
      currentId = [ids objectAtIndex: count];
      objectClass
        = [self objectClassForResourceNamed: currentId];
      deleteObject = [objectClass objectWithName: currentId
                                  inContainer: self];
      [deleteObject delete];
      [deleteObject primaryDelete];
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
  if (![url hasSuffix: @"/"])
    url = [url stringByAppendingString: @"/"];
  
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

  /* create subcontext, so that we don't destroy our environment */
  
  if ((ctx = [context createSubContext]) == nil) {
    [self errorWithFormat:@"could not create SOPE subcontext!"];
    return nil;
  }
  
  /* build path */
  
  path = _uid != nil ? [NSArray arrayWithObjects:&_uid count:1] : nil;
  
  /* traverse path */
  
  result = [[ctx application] traversePathArray:path inContext:ctx
			      error:&error acquire:NO];
  if (error != nil) {
    [self errorWithFormat: @"folder lookup failed (c_uid=%@): %@",
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
    setOCSPath: [NSString stringWithFormat: @"/Users/%@/Calendar/personal", uid]];
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
  LDAPUserManager *um;
  unsigned          i, count;
  
  if (_persons == nil)
    return nil;

  count = [_persons count];
  uids  = [NSMutableArray arrayWithCapacity:count + 1];
  um    = [LDAPUserManager sharedUserManager];
  
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

#warning We only support ONE calendar per user at this time
- (BOOL) _appendSubscribedFolders: (NSDictionary *) subscribedFolders
		     toFolderList: (NSMutableArray *) calendarFolders
{
  NSEnumerator *keys;
  NSString *currentKey;
  NSMutableDictionary *currentCalendar;
  BOOL firstShouldBeActive;
  unsigned int count;

  firstShouldBeActive = YES;

  keys = [[subscribedFolders allKeys] objectEnumerator];
  currentKey = [keys nextObject];
  count = 1;
  while (currentKey)
    {
      currentCalendar = [NSMutableDictionary new];
      [currentCalendar autorelease];
      [currentCalendar
	setDictionary: [subscribedFolders objectForKey: currentKey]];
      [currentCalendar setObject: currentKey forKey: @"folder"];
      [calendarFolders addObject: currentCalendar];
      if ([[currentCalendar objectForKey: @"active"] boolValue])
	firstShouldBeActive = NO;
      count++;
      currentKey = [keys nextObject];
    }

  return firstShouldBeActive;
}

- (NSArray *) calendarFolders
{
  NSMutableDictionary *userCalendar, *calendarDict;
  NSMutableArray *calendarFolders;
  SOGoUser *calendarUser;
  BOOL firstActive;

  calendarFolders = [NSMutableArray new];
  [calendarFolders autorelease];

  calendarUser = [SOGoUser userWithLogin: [self ownerInContext: context]
			   roles: nil];
  userCalendar = [NSMutableDictionary new];
  [userCalendar autorelease];
  [userCalendar setObject: @"/" forKey: @"folder"];
  [userCalendar setObject: @"Calendar" forKey: @"displayName"];
  [calendarFolders addObject: userCalendar];

  calendarDict = [[calendarUser userSettings] objectForKey: @"Calendar"];
  firstActive = [[calendarDict objectForKey: @"activateUserFolder"] boolValue];
  firstActive = ([self _appendSubscribedFolders:
			 [calendarDict objectForKey: @"SubscribedFolders"]
		       toFolderList: calendarFolders]
		 || firstActive);
  [userCalendar setObject: [NSNumber numberWithBool: firstActive]
		forKey: @"active"];

  return calendarFolders;
}

// - (NSArray *) fetchContentObjectNames
// {
//   NSMutableArray *objectNames;
//   NSArray *records;
//   NSCalendarDate *today, *startDate, *endDate;

// #warning this should be user-configurable
//   objectNames = [NSMutableArray array];
//   today = [[NSCalendarDate calendarDate] beginOfDay];
//   [today setTimeZone: timeZone];

//   startDate = [today dateByAddingYears: 0 months: 0 days: -1
//                      hours: 0 minutes: 0 seconds: 0];
//   endDate = [startDate dateByAddingYears: 0 months: 0 days: 2
//                        hours: 0 minutes: 0 seconds: 0];
//   records = [self fetchFields: [NSArray arrayWithObject: @"c_name"]
// 		  from: startDate to: endDate
// 		  component: @"vevent"];
//   [objectNames addObjectsFromArray: [records valueForKey: @"c_name"]];
//   records = [self fetchFields: [NSArray arrayWithObject: @"c_name"]
// 		  from: startDate to: endDate
// 		  component: @"vtodo"];
//   [objectNames addObjectsFromArray: [records valueForKey: @"c_name"]];

//   return objectNames;
// }

/* folder type */

- (NSString *) folderType
{
  return @"Appointment";
}

- (NSString *) outlookFolderClass
{
  return @"IPF.Appointment";
}

/* hack until we permit more than 1 cal per user */
- (NSArray *) _fixedPath: (NSArray *) objectPath
{
  NSMutableArray *newPath;

  newPath = [NSMutableArray arrayWithArray: objectPath];
  if ([newPath count] > 2)
    {
      if (![[newPath objectAtIndex: 2] isEqualToString: @"personal"])
	[newPath insertObject: @"personal" atIndex: 2];
    }
  else
    [newPath addObject: @"personal"];

  return newPath;
}

- (NSArray *) aclUsersForObjectAtPath: (NSArray *) objectPathArray
{
  return [super aclUsersForObjectAtPath: [self _fixedPath: objectPathArray]];
}

- (NSArray *) aclsForUser: (NSString *) uid
          forObjectAtPath: (NSArray *) objectPathArray
{
  return [super aclsForUser: uid
		forObjectAtPath: [self _fixedPath: objectPathArray]];
}

- (void) setRoles: (NSArray *) roles
          forUser: (NSString *) uid
  forObjectAtPath: (NSArray *) objectPathArray
{
  [super setRoles: roles
	 forUser: uid
	 forObjectAtPath: [self _fixedPath: objectPathArray]];
}

- (void) removeAclsForUsers: (NSArray *) users
            forObjectAtPath: (NSArray *) objectPathArray
{
  [super removeAclsForUsers: users
	 forObjectAtPath: [self _fixedPath: objectPathArray]];
}

@end /* SOGoAppointmentFolder */
