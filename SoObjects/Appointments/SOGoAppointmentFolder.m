/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2007-2008 Inverse inc.

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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOMessage.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NGLoggerManager.h>
#import <NGExtensions/NSString+misc.h>
#import <GDLContentStore/GCSFolder.h>
#import <DOM/DOMNode.h>
#import <DOM/DOMProtocols.h>
#import <EOControl/EOFetchSpecification.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalFreeBusy.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRecurrenceCalculator.h>
#import <NGCards/NSString+NGCards.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SaxObjC/XMLNamespaces.h>

// #import <NGObjWeb/SoClassSecurityInfo.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoCache.h>
// #import <SOGo/SOGoCustomGroupFolder.h>
#import <SOGo/LDAPUserManager.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoWebDAVAclManager.h>

#import "iCalEntityObject+SOGo.h"
#import "SOGoAppointmentObject.h"
#import "SOGoAppointmentFolders.h"
#import "SOGoFreeBusyObject.h"
#import "SOGoTaskObject.h"

#import "SOGoAppointmentFolder.h"

#define defaultColor @"#AAAAAA"

@implementation SOGoAppointmentFolder

static NGLogger *logger = nil;
static NSNumber *sharedYes = nil;
static NSArray *reportQueryFields = nil;

static Class sogoAppointmentFolderKlass = Nil;

+ (void) initialize
{
  NGLoggerManager *lm;
  static BOOL     didInit = NO;
//   SoClassSecurityInfo *securityInfo;

  if (didInit) return;
  didInit = YES;
  
  if (!sogoAppointmentFolderKlass)
    {
      sogoAppointmentFolderKlass = self;
      [iCalEntityObject initializeSOGoExtensions];
    }

  if (!reportQueryFields)
    reportQueryFields = [[NSArray alloc] initWithObjects: @"c_name",
					 @"c_content", @"c_creationdate",
					 @"c_lastmodified", @"c_version",
					 @"c_component", nil];

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

+ (SOGoWebDAVAclManager *) webdavAclManager
{
  SOGoWebDAVAclManager *aclManager = nil;
  NSString *nsI;

  if (!aclManager)
    {
      nsI = @"urn:inverse:params:xml:ns:inverse-dav";

      aclManager = [SOGoWebDAVAclManager new];
      [aclManager registerDAVPermission: davElement (@"read", XMLNS_WEBDAV)
		  abstract: YES
		  withEquivalent: SoPerm_WebDAVAccess
		  asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"read-current-user-privilege-set", XMLNS_WEBDAV)
		  abstract: YES
		  withEquivalent: SoPerm_WebDAVAccess
		  asChildOf: davElement (@"read", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"read-free-busy", XMLNS_WEBDAV)
		  abstract: NO
		  withEquivalent: SoPerm_AccessContentsInformation
		  asChildOf: davElement (@"read", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"write", XMLNS_WEBDAV)
		  abstract: YES
		  withEquivalent: nil
		  asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"bind", XMLNS_WEBDAV)
		  abstract: NO
		  withEquivalent: SoPerm_AddDocumentsImagesAndFiles
		  asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"schedule",
						     XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"bind", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"schedule-post",
						     XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-post-vevent", XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule-post", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-post-vtodo", XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule-post", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-post-vjournal", XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule-post", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-post-vfreebusy", XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule-post", XMLNS_CALDAV)];
      [aclManager registerDAVPermission: davElement (@"schedule-deliver",
						     XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-deliver-vevent", XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule-deliver", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-deliver-vtodo", XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule-deliver", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-deliver-vjournal", XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule-deliver", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-deliver-vfreebusy", XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule-deliver", XMLNS_CALDAV)];
      [aclManager registerDAVPermission: davElement (@"schedule-respond",
						     XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-respond-vevent", XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule-respond", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-respond-vtodo", XMLNS_CALDAV)
		  abstract: NO
		  withEquivalent: nil
		  asChildOf: davElement (@"schedule-respond", XMLNS_CALDAV)];
      [aclManager registerDAVPermission: davElement (@"unbind", XMLNS_WEBDAV)
		  abstract: NO
		  withEquivalent: SoPerm_DeleteObjects
		  asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager
	registerDAVPermission: davElement (@"write-properties", XMLNS_WEBDAV)
	abstract: YES
	withEquivalent: SoPerm_ChangePermissions /* hackish */
	asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager
	registerDAVPermission: davElement (@"write-content", XMLNS_WEBDAV)
	abstract: YES
	withEquivalent: nil
	asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"admin", nsI)
		  abstract: YES
		  withEquivalent: nil
		  asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"read-acl", XMLNS_WEBDAV)
		  abstract: YES
		  withEquivalent: SOGoPerm_ReadAcls
		  asChildOf: davElement (@"admin", nsI)];
      [aclManager registerDAVPermission: davElement (@"write-acl", XMLNS_WEBDAV)
		  abstract: YES
		  withEquivalent: SoPerm_ChangePermissions
		  asChildOf: davElement (@"admin", nsI)];
    }

  return aclManager;
}

- (id) initWithName: (NSString *) name
	inContainer: (id) newContainer
{
  if ((self = [super initWithName: name inContainer: newContainer]))
    {
      timeZone = [[context activeUser] timeZone];
      aclMatrix = [NSMutableDictionary new];
      stripFields = nil;
      uidToFilename = nil;
    }

  return self;
}

- (void) dealloc
{
  [aclMatrix release];
  [stripFields release];
  [uidToFilename release];
  [super dealloc];
}

- (Class) objectClassForComponentName: (NSString *) componentName
{
  Class objectClass;

  if ([componentName isEqualToString: @"vevent"])
    objectClass = [SOGoAppointmentObject class];
  else if ([componentName isEqualToString: @"vtodo"])
    objectClass = [SOGoTaskObject class];
  else
    objectClass = Nil;

  return objectClass;
}

- (NSString *) calendarColor
{
  NSUserDefaults *settings;
  NSDictionary *colors;
  NSString *color;

  settings = [[context activeUser] userSettings];
  colors = [[settings objectForKey: @"Calendar"]
	     objectForKey: @"FolderColors"];
  color = [colors objectForKey: [self folderReference]];
  if (!color)
    color = defaultColor;

  return color;
}

- (void) setCalendarColor: (NSString *) newColor
{
  NSUserDefaults *settings;
  NSMutableDictionary *calendarSettings;
  NSMutableDictionary *colors;

  settings = [[context activeUser] userSettings];
  calendarSettings = [settings objectForKey: @"Calendar"];
  if (!calendarSettings)
    {
      calendarSettings = [NSMutableDictionary dictionary];
      [settings setObject: calendarSettings
		forKey: @"Calendar"];
    }
  colors = [calendarSettings objectForKey: @"FolderColors"];
  if (!colors)
    {
      colors = [NSMutableDictionary dictionary];
      [calendarSettings setObject: colors forKey: @"FolderColors"];
    }
  [colors setObject: newColor forKey: [self folderReference]];
  [settings synchronize];
}

- (NSString *) syncTag
{
  NSUserDefaults *settings;
  NSDictionary *syncTags;
  NSString *syncTag;

  settings = [[context activeUser] userSettings];
  syncTags = [[settings objectForKey: @"Calendar"]
	       objectForKey: @"FolderSyncTags"];
  syncTag = [syncTags objectForKey: [self folderReference]];
  if (!syncTag)
    syncTag = @"";

  return syncTag;
}

#warning this code shares a lot with the colour code
- (void) setSyncTag: (NSString *) newSyncTag
{
  NSUserDefaults *settings;
  NSMutableDictionary *calendarSettings;
  NSMutableDictionary *syncTags;

  settings = [[context activeUser] userSettings];
  calendarSettings = [settings objectForKey: @"Calendar"];
  if (!calendarSettings)
    {
      calendarSettings = [NSMutableDictionary dictionary];
      [settings setObject: calendarSettings
		forKey: @"Calendar"];
    }
  syncTags = [calendarSettings objectForKey: @"FolderSyncTags"];
  if (!syncTags)
    {
      syncTags = [NSMutableDictionary dictionary];
      [calendarSettings setObject: syncTags forKey: @"FolderSyncTags"];
    }
  [syncTags setObject: newSyncTag forKey: [self folderReference]];
  [settings synchronize];
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
//   [self logWithFormat:@"CAL UID: %@", s];
  return [s isNotNull] ? [NSArray arrayWithObjects:&s count:1] : nil;
}

/* fetching */

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
        = [NSString stringWithFormat: @"AND (c_component = '%@')",
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
  NSString *privacySqlString, *email, *login;
  SOGoUser *activeUser;

  activeUser = [context activeUser];

  if (activeUserIsOwner
      || [[self ownerInContext: context] isEqualToString: [[context activeUser] login]]
      || [[activeUser rolesForObject: self inContext: context]
	   containsObject: SoRole_Owner])
    privacySqlString = @"";
  else if ([[activeUser login] isEqualToString: @"freebusy"])
    privacySqlString = @"and (c_isopaque = 1)";
  else
    {
#warning we do not manage all the possible user emails
      email = [[activeUser primaryIdentity] objectForKey: @"email"];
      login = [activeUser login];

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

- (NSArray *) bareFetchFields: (NSArray *) fields
			 from: (NSCalendarDate *) startDate
			   to: (NSCalendarDate *) endDate 
			title: (NSString *) title
		    component: (id) component
	    additionalFilters: (NSString *) filters
{
  EOQualifier *qualifier;
  GCSFolder *folder;
  NSString *sql, *dateSqlString, *titleSqlString, *componentSqlString,
    *filterSqlString;

  folder = [self ocsFolder];
  if (startDate && endDate)
    dateSqlString = [self _sqlStringRangeFrom: startDate to: endDate];
  else
    dateSqlString = @"";

  if ([title length])
    titleSqlString = [NSString stringWithFormat: @"AND (c_title"
			       @" isCaseInsensitiveLike: '%%%@%%')", title];
  else
    titleSqlString = @"";

  componentSqlString = [self _sqlStringForComponent: component];
  if (filters)
    filterSqlString = [NSString stringWithFormat: @"AND (%@)", filters];
  else
    filterSqlString = @"";

  /* prepare mandatory fields */

  sql = [[NSString stringWithFormat: @"%@%@%@%@",
		   dateSqlString, titleSqlString, componentSqlString,
		   filterSqlString] substringFromIndex: 4];

  /* fetch non-recurrent apts first */
  qualifier = [EOQualifier qualifierWithQualifierFormat: sql];

  return [folder fetchFields: fields matchingQualifier: qualifier];
}

- (BOOL) _checkIfWeCanRememberRecords: (NSArray *) fields
{
  return ([fields containsObject: @"c_name"]
	  && [fields containsObject: @"c_version"]
	  && [fields containsObject: @"c_lastmodified"]
	  && [fields containsObject: @"c_creationdate"]
	  && [fields containsObject: @"c_component"]);
}

- (void) _rememberRecords: (NSArray *) records
{
  NSEnumerator *recordsEnum;
  NSDictionary *currentRecord;

  recordsEnum = [records objectEnumerator];
  while ((currentRecord = [recordsEnum nextObject]))
    [childRecords setObject: currentRecord
		  forKey: [currentRecord objectForKey: @"c_name"]];
}

- (NSMutableDictionary *) fixupRecord: (NSDictionary *) _record
{
  NSMutableDictionary *md;
  static NSString *fields[] = { @"c_startdate", @"startDate",
				@"c_enddate", @"endDate" };
  unsigned int count;
  NSCalendarDate *date;
  NSNumber *dateValue;
  BOOL isAllDay;

  isAllDay = [[_record objectForKey: @"c_isallday"] boolValue];

  md = [[_record mutableCopy] autorelease];
  for (count = 0; count < 2; count++)
    {
      dateValue = [_record objectForKey: fields[count * 2]];
      if (dateValue)
	{
	  date = [NSCalendarDate dateWithTimeIntervalSince1970: [dateValue unsignedIntValue]];
	  if (date)
	    {
	      [date setTimeZone: timeZone];
	      [md setObject: date forKey: fields[count * 2 + 1]];
	    }
	}
      else
	[self logWithFormat: @"missing '%@' in record?", fields[count * 2]];
    }

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
	  row = [self fixupRecord: [records objectAtIndex: count]];
	  if (row)
	    [ma addObject: row];
	}
    }
  else
    ma = nil;

  return ma;
}

- (NSMutableDictionary *) fixupCycleRecord: (NSDictionary *) _record
                                cycleRange: (NGCalendarDateRange *) _r
{
  NSMutableDictionary *md;
  NSNumber *dateSecs;
  id tmp;
  
  md = [[_record mutableCopy] autorelease];

  /* cycle is in _r. We also have to override the c_startdate/c_enddate with the date values of
     the reccurence since we use those when displaying events in SOGo Web */
  tmp = [_r startDate];
  [tmp setTimeZone: timeZone];
  [md setObject: tmp forKey: @"startDate"];
  dateSecs = [NSNumber numberWithInt: [tmp timeIntervalSince1970]];
  [md setObject: dateSecs forKey: @"c_startdate"];
  [md setObject: dateSecs forKey: @"c_recurrence_id"];

  tmp = [_r endDate];
  [tmp setTimeZone: timeZone];
  [md setObject: tmp forKey: @"endDate"];
  dateSecs = [NSNumber numberWithInt: [tmp timeIntervalSince1970]];
  [md setObject: dateSecs forKey: @"c_enddate"];
  
  return md;
}

- (int) _indexOfRecordMatchingDate: (NSCalendarDate *) matchDate
			   inArray: (NSArray *) recordArray
{
  int count, max, recordIndex;
  NSDictionary *currentRecord;

  recordIndex = -1;

  count = 0;
  max = [recordArray count];
  while (recordIndex == -1 && count < max)
    {
      currentRecord = [recordArray objectAtIndex: count];
      if ([[currentRecord objectForKey: @"startDate"]
	    isEqual: matchDate])
	recordIndex = count;
      else
	count++;
    }

  return recordIndex;
}

- (void) _fixExceptionRecord: (NSMutableDictionary *) recRecord
		     fromRow: (NSDictionary *) row
{
  NSArray *objects;
  static NSArray *fields = nil;

  if (!fields)
    {
      fields = [NSArray arrayWithObjects: @"c_name", nil];
      [fields retain];
    }

  objects = [row objectsForKeys: fields notFoundMarker: @""];
  [recRecord setObjects: objects forKeys: fields];
}

- (void) _appendCycleException: (iCalRepeatableEntityObject *) component
		       fromRow: (NSDictionary *) row
		      forRange: (NGCalendarDateRange *) dateRange
		       toArray: (NSMutableArray *) ma
{
  NSCalendarDate *startDate, *recurrenceId;
  NSMutableDictionary *newRecord;
  NSDictionary *oldRecord;
  NGCalendarDateRange *newRecordRange;
  int recordIndex;

  newRecord = nil;
  recurrenceId = [component recurrenceId];
  if ([dateRange containsDate: recurrenceId])
    {
      recordIndex = [self _indexOfRecordMatchingDate: recurrenceId
			  inArray: ma];
      if (recordIndex > -1)
	{
	  startDate = [component startDate];
	  if ([dateRange containsDate: startDate])
	    {
	      newRecord = [self fixupRecord: [component quickRecord]];
	      [newRecord setObject: [NSNumber numberWithInt: 1]
			 forKey: @"c_iscycle"];
	      oldRecord = [ma objectAtIndex: recordIndex];
	      [newRecord setObject: [oldRecord objectForKey: @"c_recurrence_id"]
			 forKey: @"c_recurrence_id"];
	      [ma replaceObjectAtIndex: recordIndex withObject: newRecord];
	    }
	  else
	    [ma removeObjectAtIndex: recordIndex];
	}
      else
	[self errorWithFormat:
		@"missing exception record for recurrence-id: %@",
	      recurrenceId];
    }
  else
    {
      newRecord = [self fixupRecord: [component quickRecord]];
      newRecordRange = [NGCalendarDateRange calendarDateRangeWithStartDate:
					      [newRecord objectForKey:
							   @"startDate"]
					    endDate: [newRecord objectForKey:
								  @"endDate"]];
      if ([dateRange doesIntersectWithDateRange: newRecordRange])
	[ma addObject: newRecord];
    }

  if (newRecord)
    [self _fixExceptionRecord: newRecord fromRow: row];
}

- (void) _appendCycleExceptionsFromRow: (NSDictionary *) row
			      forRange: (NGCalendarDateRange *) dateRange
			       toArray: (NSMutableArray *) ma
{
  NSArray *elements, *components;
  unsigned int count, max;
  NSString *content;

  content = [row objectForKey: @"c_content"];
  if ([content length])
    {
      elements = [iCalCalendar parseFromSource: content];
      if ([elements count])
	{
	  components = [[elements objectAtIndex: 0] allObjects];
	  max = [components count];
	  for (count = 1; count < max; count++)
	    [self _appendCycleException: [components objectAtIndex: count]
		  fromRow: row
		  forRange: dateRange
		  toArray: ma];
	}
    }
}

- (void) _flattenCycleRecord: (NSDictionary *) _row
                    forRange: (NGCalendarDateRange *) _r
                   intoArray: (NSMutableArray *) _ma
{
  NSMutableDictionary *row, *fixedRow;
  NSMutableArray *recordArray;
  NSDictionary        *cycleinfo;
  NSCalendarDate      *startDate, *endDate;
  NGCalendarDateRange *fir, *rRange;
  NSArray             *rules, *exRules, *exDates, *ranges;
  unsigned            i, count;
  NSString *content;

  recordArray = [NSMutableArray array];

  content = [_row objectForKey: @"c_cycleinfo"];
  if (![content isNotNull])
    {
      [self errorWithFormat:@"cyclic record doesn't have cycleinfo -> %@",
	    _row];
      return;
    }

  cycleinfo = [content propertyList];
  if (!cycleinfo)
    {
      [self errorWithFormat:@"cyclic record doesn't have cycleinfo -> %@",
	    _row];
      return;
    }

  row = [self fixupRecord: _row];
  [row removeObjectForKey: @"c_cycleinfo"];
  [row setObject: sharedYes forKey: @"isRecurrentEvent"];

  startDate = [row objectForKey: @"startDate"];
  endDate   = [row objectForKey: @"endDate"];
  fir       = [NGCalendarDateRange calendarDateRangeWithStartDate: startDate
                                   endDate: endDate];
  rules     = [cycleinfo objectForKey: @"rules"];
  exRules   = [cycleinfo objectForKey: @"exRules"];
  exDates   = [cycleinfo objectForKey: @"exDates"];
  
  ranges = [iCalRecurrenceCalculator recurrenceRangesWithinCalendarDateRange: _r
                                     firstInstanceCalendarDateRange: fir
                                     recurrenceRules: rules
                                     exceptionRules: exRules
                                     exceptionDates: exDates];
  count = [ranges count];
  for (i = 0; i < count; i++)
    {
      rRange = [ranges objectAtIndex: i];
      fixedRow = [self fixupCycleRecord: row cycleRange: rRange];
      if (fixedRow)
	[recordArray addObject: fixedRow];
    }

  [self _appendCycleExceptionsFromRow: row
	forRange: _r
	toArray: recordArray];

  [_ma addObjectsFromArray: recordArray];
}

- (NSArray *) fixupCyclicRecords: (NSArray *) _records
                      fetchRange: (NGCalendarDateRange *) _r
{
  // TODO: is the result supposed to be sorted by date?
  NSMutableArray *ma;
  NSDictionary *row;
  unsigned int count, max;

  max = [_records count];
  ma = [NSMutableArray arrayWithCapacity: max];

  for (count = 0; count < max; count++)
    {
      row = [_records objectAtIndex: count];
      [self _flattenCycleRecord: row forRange: _r intoArray: ma];
    }

  return ma;
}

- (void) _buildStripFieldsFromFields: (NSArray *) fields
{
  stripFields = [[NSMutableArray alloc] initWithCapacity: [fields count]];
  [stripFields setArray: fields];
  [stripFields removeObjectsInArray: [NSArray arrayWithObjects: @"c_name",
					      @"c_uid", @"c_startdate",
					      @"c_enddate", @"c_isallday",
					      @"c_iscycle",
					      @"c_classification",
					      @"c_component", nil]];
}

- (void) _fixupProtectedInformation: (NSEnumerator *) ma
			   inFields: (NSArray *) fields
			    forUser: (NSString *) uid
{
  NSMutableDictionary *currentRecord;
  NSString *roles[] = {nil, nil, nil};
  iCalAccessClass accessClass;
  NSString *fullRole, *role;

  if (!stripFields)
    [self _buildStripFieldsFromFields: fields];

#warning we do not take the participation status into account
  while ((currentRecord = [ma nextObject]))
    {
      accessClass
	= [[currentRecord objectForKey: @"c_classification"] intValue];
      role = roles[accessClass];
      if (!role)
	{
	  fullRole = [self roleForComponentsWithAccessClass: accessClass
			   forUser: uid];
	  if ([fullRole length] > 9)
	    role = [fullRole substringFromIndex: 9];
	  roles[accessClass] = role;
	}
      if ([role isEqualToString: @"DAndTViewer"])
	[currentRecord removeObjectsForKeys: stripFields];
    }
}

- (NSArray *) fetchFields: (NSArray *) _fields
                     from: (NSCalendarDate *) _startDate
                       to: (NSCalendarDate *) _endDate 
		    title: (NSString *) title
                component: (id) _component
	additionalFilters: (NSString *) filters
{
  EOQualifier *qualifier;
  GCSFolder *folder;
  NSMutableArray *fields, *ma = nil;
  NSArray *records;
  NSString *sql, *dateSqlString, *titleSqlString, *componentSqlString,
    *privacySqlString, *currentLogin, *filterSqlString;
  NSCalendarDate *endDate;
  NGCalendarDateRange *r;
  BOOL rememberRecords;

  rememberRecords = [self _checkIfWeCanRememberRecords: _fields];
//   if (rememberRecords)
//     NSLog (@"we will remember those records!");

  folder = [self ocsFolder];
  if (!folder)
    {
      [self errorWithFormat:@"(%s): missing folder for fetch!",
            __PRETTY_FUNCTION__];
      return nil;
    }

  if (_startDate)
    {
      if (_endDate)
	endDate = _endDate;
      else
	endDate = [NSCalendarDate distantFuture];
      r = [NGCalendarDateRange calendarDateRangeWithStartDate: _startDate
                               endDate: endDate];
      dateSqlString = [self _sqlStringRangeFrom: _startDate to: endDate];
    }
  else
    {
      r = nil;
      dateSqlString = @"";
    }

  if ([title length])
    titleSqlString = [NSString stringWithFormat: @"AND (c_title"
			       @" isCaseInsensitiveLike: '%%%@%%')", title];
  else
    titleSqlString = @"";

  componentSqlString = [self _sqlStringForComponent: _component];
  privacySqlString = [self _privacySqlString];
  if (filters)
    filterSqlString = [NSString stringWithFormat: @"AND (%@)", filters];
  else
    filterSqlString = @"";

  /* prepare mandatory fields */

  fields = [NSMutableArray arrayWithArray: _fields];
  [fields addObjectUniquely: @"c_name"];
  [fields addObjectUniquely: @"c_uid"];
  [fields addObjectUniquely: @"c_startdate"];
  [fields addObjectUniquely: @"c_enddate"];
  [fields addObjectUniquely: @"c_isallday"];

  if (logger)
    [self debugWithFormat:@"should fetch (%@=>%@) ...", _startDate, endDate];

  sql = [NSString stringWithFormat: @"(c_iscycle = 0) %@ %@ %@ %@ %@",
                  dateSqlString, titleSqlString, componentSqlString,
                  privacySqlString, filterSqlString];

  /* fetch non-recurrent apts first */
  qualifier = [EOQualifier qualifierWithQualifierFormat: sql];

  records = [folder fetchFields: fields matchingQualifier: qualifier];
  if (records)
    {
      if (r)
        records = [self fixupRecords: records fetchRange: r];
      if (logger)
        [self debugWithFormat: @"fetched %i records: %@",
              [records count], records];
      ma = [NSMutableArray arrayWithArray: records];
    }

  /* fetch recurrent apts now. we do NOT consider events with no cycle end. */
  if (_endDate || filters)
    {
      sql = [NSString stringWithFormat: @"(c_iscycle = 1) %@ %@ %@ %@", titleSqlString,
		      componentSqlString, privacySqlString, filterSqlString];
      
      qualifier = [EOQualifier qualifierWithQualifierFormat: sql];
      
      records = [folder fetchFields: fields matchingQualifier: qualifier];
      if (records)
	{
	  if (r)
	    records = [self fixupCyclicRecords: records fetchRange: r];
	  if (ma)
	    [ma addObjectsFromArray: records];
	  else
	    ma = [NSMutableArray arrayWithArray: records];
	}
    }
  if (!ma)
    {
      [self errorWithFormat: @"(%s): fetch failed!", __PRETTY_FUNCTION__];
      return nil;
    }

  if (logger)
    [self debugWithFormat:@"returning %i records", [ma count]];

  currentLogin = [[context activeUser] login];
  if (![currentLogin isEqualToString: owner])
    [self _fixupProtectedInformation: [ma objectEnumerator]
	  inFields: _fields
	  forUser: currentLogin];
//   [ma makeObjectsPerform: @selector (setObject:forKey:)
//       withObject: owner
//       withObject: @"owner"];

  if (rememberRecords)
    [self _rememberRecords: ma];

  return ma;
}

- (void) _appendPropstat: (NSDictionary *) propstat
                toBuffer: (NSMutableString *) r
{
  NSArray *properties;
  unsigned int count, max;

  [r appendString: @"<D:propstat><D:prop>"];
  properties = [propstat objectForKey: @"properties"];
  max = [properties count];
  for (count = 0; count < max; count++)
    [r appendString: [properties objectAtIndex: count]];
  [r appendString: @"</D:prop><D:status>"];
  [r appendString: [propstat objectForKey: @"status"]];
  [r appendString: @"</D:status></D:propstat>"];
}

#warning we should use the EOFetchSpecification for that!!! (see doPROPFIND:)

#warning components in calendar-data query are ignored

#warning the two following methods should be replaced with the new dav rendering mechanism
- (NSString *) _nodeTagForProperty: (NSString *) property
{
  NSString *namespace, *nodeName, *nsRep;
  NSRange nsEnd;

  nsEnd = [property rangeOfString: @"}"];
  namespace
    = [property substringFromRange: NSMakeRange (1, nsEnd.location - 1)];
  nodeName = [property substringFromIndex: nsEnd.location + 1];
  if ([namespace isEqualToString: XMLNS_CALDAV])
    nsRep = @"C";
  else
    nsRep = @"D";

  return [NSString stringWithFormat: @"%@:%@", nsRep, nodeName];
}

- (NSString *) _nodeTag: (NSString *) property
{
  static NSMutableDictionary *tags = nil;
  NSString *nodeTag;

  if (!tags)
    tags = [NSMutableDictionary new];
  nodeTag = [tags objectForKey: property];
  if (!nodeTag)
    {
      nodeTag = [self _nodeTagForProperty: property];
      [tags setObject: nodeTag forKey: property];
    }

  return nodeTag;
}

- (NSString **) _properties: (NSString **) properties
                   ofObject: (NSDictionary *) object
{
  SOGoCalendarComponent *sogoObject;
  NSString **currentProperty;
  NSString **values, **currentValue;
  SoSecurityManager *mgr;
  SEL methodSel;
  Class c;

#warning things may crash here...
  values = calloc (100, sizeof (NSMutableString *));

//   NSLog (@"_properties:ofObject:: %@", [NSDate date]);

#warning this check should be done directly in the query... we should fix this sometime
  mgr = [SoSecurityManager sharedSecurityManager];
  
  //c = [self objectClassForComponentName: [object objectForKey: @"c_component"]];
  sogoObject = [SOGoCalendarComponent objectWithRecord: object  inContainer: self];
  [sogoObject setComponentTag: [object objectForKey: @"c_component"]];
  //sogoObject = [self _createChildComponentWithRecord: object];

  if (activeUserIsOwner
      || [[self ownerInContext: context]
	   isEqualToString: [[context activeUser] login]]
      || !([mgr validatePermission: SOGoPerm_AccessObject
		onObject: sogoObject
		inContext: context]))
    {
      currentProperty = properties;
      currentValue = values;
      while (*currentProperty)
	{
	  methodSel = SOGoSelectorForPropertyGetter (*currentProperty);
	  if (methodSel && [sogoObject respondsToSelector: methodSel])
	    *currentValue = [[sogoObject performSelector: methodSel]
			      stringByEscapingXMLString];
	  currentProperty++;
	  currentValue++;
	}
    }

//    NSLog (@"/_properties:ofObject:: %@", [NSDate date]);

  return values;
}

- (NSArray *) _propstats: (NSString **) properties
		ofObject: (NSDictionary *) object
{
  NSMutableArray *propstats, *properties200, *properties404, *propDict;
  NSString **property, **values, **currentValue;
  NSString *propertyValue, *nodeTag;

//   NSLog (@"_propstats:ofObject:: %@", [NSDate date]);

  propstats = [NSMutableArray array];

  properties200 = [NSMutableArray new];
  properties404 = [NSMutableArray new];

  values = [self _properties: properties ofObject: object];
  currentValue = values;

  property = properties;
  while (*property)
    {
      nodeTag = [self _nodeTag: *property];
      if (*currentValue)
	{
	  propertyValue = [NSString stringWithFormat: @"<%@>%@</%@>",
				    nodeTag, *currentValue, nodeTag];
	  propDict = properties200;
	}
      else
	{
	  propertyValue = [NSString stringWithFormat: @"<%@/>", nodeTag];
	  propDict = properties404;
	}
      [propDict addObject: propertyValue];
      property++;
      currentValue++;
    }
  free (values);

  if ([properties200 count])
    [propstats addObject: [NSDictionary dictionaryWithObjectsAndKeys:
					  properties200, @"properties",
					@"HTTP/1.1 200 OK", @"status",
					nil]];
  [properties200 release];
  
  if ([properties404 count])
    [propstats addObject: [NSDictionary dictionaryWithObjectsAndKeys:
					  properties404, @"properties",
					@"HTTP/1.1 404 Not Found", @"status",
					nil]];
  [properties404 release];

//    NSLog (@"/_propstats:ofObject:: %@", [NSDate date]);

  return propstats;
}

#warning We need to use the new DAV utilities here...
#warning this is baddddd because we return a single-valued dictionary containing \
  a cname which may not event exist... the logic behind appendObject:... should be \
  rethought, especially since we may start using SQL views

- (void) appendObject: (NSDictionary *) object
	   properties: (NSString **) properties
          withBaseURL: (NSString *) baseURL
	     toBuffer: (NSMutableString *) r
{
  NSArray *propstats;
  unsigned int count, max;

  [r appendFormat: @"<D:response><D:href>"];
  [r appendString: baseURL];
//   if (![baseURL hasSuffix: @"/"])
//     [r appendContentString: @"/"];
  [r appendString: [object objectForKey: @"c_name"]];
  [r appendString: @"</D:href>"];

//   NSLog (@"(appendPropstats...): %@", [NSDate date]);
  propstats = [self _propstats: properties ofObject: object];
  max = [propstats count];
  for (count = 0; count < max; count++)
    [self _appendPropstat: [propstats objectAtIndex: count]
	  toBuffer: r];
//   NSLog (@"/(appendPropstats...): %@", [NSDate date]);

  [r appendString: @"</D:response>"];
}

- (void) appendMissingObjectRef: (NSString *) href
		       toBuffer: (NSMutableString *) r
{
  [r appendString: @"<D:response><D:href>"];
  [r appendString: href];
  [r appendString: @"</D:href><D:status>HTTP/1.1 404 Not Found</D:status></D:response>"];
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

#warning This method lacks support for timeranges
- (void) _appendPropertyFilter: (id <DOMElement>) propFilter
		      toFilter: (NSMutableDictionary *) filter
{
  NSString *propName, *textMatch;
  id <DOMNodeList> matches;

  propName = [[propFilter attribute: @"name"] lowercaseString];
  matches = [propFilter getElementsByTagName: @"text-match"];
  if ([matches length])
    textMatch = [[matches objectAtIndex: 0] textValue];
  else
    {
      matches = [propFilter getElementsByTagName: @"is-not-defined"];
      if ([matches length])
	textMatch = @"NULL";
      else
	textMatch = @"";
    }

  [filter setObject: textMatch forKey: propName];
}

- (NSDictionary *) _parseCalendarFilter: (id <DOMElement>) filterElement
{
  NSMutableDictionary *filterData;
  id <DOMElement> parentNode;
  id <DOMNodeList> elements;
  NSString *componentName;

  parentNode = (id <DOMElement>) [filterElement parentNode];
  if ([[parentNode tagName] isEqualToString: @"comp-filter"]
      && [[parentNode attribute: @"name"] isEqualToString: @"VCALENDAR"])
    {
      componentName = [[filterElement attribute: @"name"] lowercaseString];
      filterData = [NSMutableDictionary dictionary];
      [filterData setObject: componentName forKey: @"name"];
      elements = [filterElement getElementsByTagName: @"time-range"];
      if ([elements length])
        [self _appendTimeRange: [elements objectAtIndex: 0]
              toFilter: filterData];

      elements = [filterElement getElementsByTagName: @"prop-filter"];
      if ([elements length])
        [self _appendPropertyFilter: [elements objectAtIndex: 0]
              toFilter: filterData];
    }
  else
    filterData = nil;

  return filterData;
}

- (NSArray *) _parseRequestedProperties: (id <DOMElement>) parentNode
{
  NSMutableArray *properties;
  NSObject <DOMNodeList> *propList, *children;
  NSObject <DOMNode> *currentChild;
  unsigned int count, max, count2, max2;
  NSString *flatProperty;

//   NSLog (@"parseRequestProperties: %@", [NSDate date]);
  properties = [NSMutableArray array];

  propList = [parentNode getElementsByTagName: @"prop"];
  max = [propList length];
  for (count = 0; count < max; count++)
    {
      children = [[propList objectAtIndex: count] childNodes];
      max2 = [children length];
      for (count2 = 0; count2 < max2; count2++)
	{
	  currentChild = [children objectAtIndex: count2];
	  if ([currentChild conformsToProtocol: @protocol (DOMElement)])
	    {
	      flatProperty = [NSString stringWithFormat: @"{%@}%@",
				       [currentChild namespaceURI],
				       [currentChild nodeName]];
	      [properties addObject: flatProperty];
	    }
	}

//       while ([children hasChildNodes])
// 	[properties addObject: [children next]];
    }
//   NSLog (@"/parseRequestProperties: %@", [NSDate date]);

  return properties;
}

- (NSArray *) _parseCalendarFilters: (id <DOMElement>) parentNode
{
  id <DOMNodeList> children;
  id <DOMElement> node;
  NSMutableArray *filters;
  NSDictionary *filter;
  unsigned int count, max;

//   NSLog (@"parseCalendarFilter: %@", [NSDate date]);

  filters = [NSMutableArray array];
  children = [parentNode getElementsByTagName: @"comp-filter"];
  max = [children length];
  for (count = 0; count < max; count++)
    {
      node = [children objectAtIndex: count];
      filter = [self _parseCalendarFilter: node];
      if (filter)
	[filters addObject: filter];
    }
//   NSLog (@"/parseCalendarFilter: %@", [NSDate date]);

  return filters;
}

- (NSString *) _additionalFilterKey: (NSString *) key
			      value: (NSString *) value
{
  NSString *filterString;

  if ([value length])
    {
      if ([value isEqualToString: @"NULL"])
	filterString = [NSString stringWithFormat: @"(%@ = '')", key];
      else
	filterString
	  = [NSString stringWithFormat: @"(%@ like '%%%@%%')", key, value];
    }
  else
    filterString = [NSString stringWithFormat: @"(%@ != '')", key];

  return filterString;
}

- (NSString *) _composeAdditionalFilters: (NSDictionary *) filter
{
  NSString *additionalFilter;
  NSEnumerator *keys;
  NSString *currentKey, *keyField, *filterString;
  static NSArray *fields = nil;
  NSMutableArray *filters;

#warning the list of fields should be taken from the .ocs description file
  if (!fields)
    {
      fields = [NSArray arrayWithObject: @"c_uid"];
      [fields retain];
    }

  filters = [NSMutableArray new];
  keys = [[filter allKeys] objectEnumerator];
  while ((currentKey = [keys nextObject]))
    {
      keyField = [NSString stringWithFormat: @"c_%@", currentKey];
      if ([fields containsObject: keyField])
	{
	  filterString = [self _additionalFilterKey: keyField
			       value: [filter objectForKey: currentKey]];
	  [filters addObject: filterString];
	}
    }

  if ([filters count])
    additionalFilter = [filters componentsJoinedByString: @" and "];
  else
    additionalFilter = nil;
  [filters release];

  return additionalFilter;
}

- (NSString *) davCalendarColor
{
  NSString *color;

  color = [[self calendarColor] uppercaseString];

  return [NSString stringWithFormat: @"%@FF", color];
}

- (NSException *) setDavCalendarColor: (NSString *) newColor
{
  NSException *error;
  NSString *realColor;

  if ([newColor length] == 9
      && [newColor hasPrefix: @"#"])
    {
      realColor = [newColor substringToIndex: 7];
      [self setCalendarColor: realColor];
      error = nil;
    }
  else
    error = [NSException exceptionWithHTTPStatus: 400
			 reason: @"Bad color format (should be '#XXXXXXXX')."];

  return error;
}

- (NSString *) davCalendarOrder
{
  unsigned int order;

  order = [[container subFolders] indexOfObject: self];

  return [NSString stringWithFormat: @"%d", order];
}

- (NSException *) setDavCalendarOrder: (NSString *) newColor
{
  return nil;
}

- (SOGoWebDAVValue *) davCalendarFreeBusySet
{
  NSEnumerator *subFolders;
  SOGoAppointmentFolder *currentFolder;
  NSMutableArray *response;
  SOGoWebDAVValue *responseValue;

  response = [NSMutableArray new];
  subFolders = [[container subFolders] objectEnumerator];
  while ((currentFolder = [subFolders nextObject]))
    [response addObject: davElementWithContent (@"href", XMLNS_WEBDAV,
						[currentFolder davURL])];
  responseValue = [davElementWithContent (@"calendar-free-busy-set", XMLNS_CALDAV, response)
					 asWebDAVValue];
  [response release];

  return responseValue;
}

/* This method is ignored but we must return a success value. */
- (NSException *) setDavCalendarFreeBusySet: (NSString *) newFreeBusySet
{
  return nil;
}


- (void) _appendComponentProperties: (NSString **) properties
		    matchingFilters: (NSArray *) filters
			 toResponse: (WOResponse *) response
{
  NSArray *apts, *fields;
  NSDictionary *currentFilter;
  NSEnumerator *filterList;
  NSString *additionalFilters, *baseURL;
  NSMutableString *buffer;
  unsigned int count, max;

  baseURL = [[self davURL] absoluteString];
  
  // We check if we need to fetch all fields. If the DAV client
  // has only asked for {DAV:}getetag with no other properties,
  // we do not load the c_content and other fields from the
  // database as this can be pretty costly.
#if 0
  // FOR AN UNKNOWN REASON FOR NOW, THIS GENERATES EMPTY ETAGS (ALL HAVE GCS0000000 VALUE)
  if ([*properties caseInsensitiveCompare: @"{DAV:}getetag"] == NSOrderedSame &&
      !*(properties+1))
    fields =  [NSArray arrayWithObjects: @"c_name", @"c_creationdate",
		       @"c_lastmodified", @"c_version",
		       @"c_component", nil];
  else
#endif
    fields = reportQueryFields;

  filterList = [filters objectEnumerator];
  while ((currentFilter = [filterList nextObject]))
    {
      additionalFilters = [self _composeAdditionalFilters: currentFilter];
      //NSLog(@"query");
      apts = [self bareFetchFields: fields
		   from: [currentFilter objectForKey: @"start"]
                   to: [currentFilter objectForKey: @"end"]
		   title: [currentFilter objectForKey: @"title"]
                   component: [currentFilter objectForKey: @"name"]
		   additionalFilters: additionalFilters];
      //NSLog(@"adding properties");
      max = [apts count];
      buffer = [[NSMutableString alloc] initWithCapacity: max*512];
      for (count = 0; count < max; count++)
	[self appendObject: [apts objectAtIndex: count]
	      properties: properties
	      withBaseURL: baseURL
	      toBuffer: buffer];
      //NSLog(@"done");
      [response appendContentString: buffer];
      [buffer release];
    }
}

- (id) davCalendarQuery: (id) queryContext
{
  WOResponse *r;
  id <DOMDocument> document;
  id <DOMElement> documentElement;
  NSString **properties;

  r = [context response];
  [r setStatus: 207];
  [r setContentEncoding: NSUTF8StringEncoding];
  [r setHeader: @"text/xml; charset=\"utf-8\"" forKey: @"content-type"];
  [r setHeader: @"no-cache" forKey: @"pragma"];
  [r setHeader: @"no-cache" forKey: @"cache-control"];
  [r appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [r appendContentString: @"<D:multistatus xmlns:D=\"DAV:\""
     @" xmlns:C=\"urn:ietf:params:xml:ns:caldav\">"];

  document = [[context request] contentAsDOMDocument];
  documentElement = [document documentElement];
  properties = [[self _parseRequestedProperties: documentElement]
		 asPointersOfObjects];
  [self _appendComponentProperties: properties
	matchingFilters: [self _parseCalendarFilters: documentElement]
        toResponse: r];
  [r appendContentString:@"</D:multistatus>"];
  free (properties);

  return r;
}

- (NSDictionary *) _deduceObjectNamesFromURLs: (NSArray *) urls
{
  unsigned int count, max;
  NSString *url, *componentURLPath, *cName, *baseURLString;
  NSMutableDictionary *cNames;
  NSURL *componentURL, *baseURL;
  NSArray *urlComponents;

  max = [urls count];
  cNames = [NSMutableDictionary dictionaryWithCapacity: max];
  baseURL = [self davURL];
  baseURLString = [baseURL absoluteString];

  for (count = 0; count < max; count++)
    {
      url = [urls objectAtIndex: count];
      componentURL = [[NSURL URLWithString: url relativeToURL: baseURL]
		       standardizedURL];
      componentURLPath = [componentURL absoluteString];
      if ([componentURLPath rangeOfString: baseURLString].location
	  != NSNotFound)
	{
	  urlComponents = [componentURLPath componentsSeparatedByString: @"/"];
	  cName = [urlComponents objectAtIndex: [urlComponents count] - 1];
	  [cNames setObject: url forKey: cName];
	}
    }

  return cNames;
}

- (NSArray *) _fetchComponentsWithNames: (NSArray *) cNames
{
  NSMutableString *filterString;
  NSArray *records;

//   NSLog (@"fetchComponentsWithNames");
  filterString = [NSMutableString new];
  [filterString appendFormat: @"c_name='%@'",
		[cNames componentsJoinedByString: @"' OR c_name='"]];
//   NSLog (@"fetchComponentsWithNames: query");
  records = [self bareFetchFields: reportQueryFields
		  from: nil
		  to: nil
		  title: nil
		  component: nil
		  additionalFilters: filterString];
  [filterString release];
//   NSLog (@"/fetchComponentsWithNames");

  return records;
}

#define maxQuerySize 2500
#define baseQuerySize 160
#define idQueryOverhead 13

- (NSArray *) _fetchComponentsMatchingObjectNames: (NSArray *) cNames
{
  NSMutableArray *components;
  NSArray *records;
  NSMutableArray *currentNames;
  unsigned int count, max, currentSize, queryNameLength;
  NSString *currentName;

//   NSLog (@"fetching components matching names");

  currentNames = [NSMutableArray new];
  currentSize = baseQuerySize;

  max = [cNames count];
  components = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      currentName = [cNames objectAtIndex: count];
      queryNameLength = idQueryOverhead + [currentName length];
      if ((currentSize + queryNameLength)
	  > maxQuerySize)
	{
	  records = [self _fetchComponentsWithNames: currentNames];
	  [components addObjectsFromArray: records];
	  [currentNames removeAllObjects];
	  currentSize = baseQuerySize;
	}
      [currentNames addObject: currentName];
      currentSize += queryNameLength;
    }

  records = [self _fetchComponentsWithNames: currentNames];
  [components addObjectsFromArray: records];
  [currentNames release];

//   NSLog (@"/fetching components matching names");

  return components;
}

- (NSDictionary *) _fetchComponentsMatchingURLs: (NSArray *) urls
{
  NSMutableDictionary *components;
  NSDictionary *cnames, *record;
  NSString *recordURL;
  NSArray *records;
  unsigned int count, max;

  components = [NSMutableDictionary dictionary];

  cnames = [self _deduceObjectNamesFromURLs: urls];
  records = [self _fetchComponentsMatchingObjectNames: [cnames allKeys]];
  max = [records count];
  for (count = 0; count < max; count++)
    {
      record = [records objectAtIndex: count];
      recordURL = [cnames objectForKey: [record objectForKey: @"c_name"]];
      [components setObject: record forKey: recordURL];
    }

  return components;
}

- (void) _appendComponentProperties: (NSString **) properties
		       matchingURLs: (id <DOMNodeList>) refs
			 toResponse: (WOResponse *) response
{
  NSObject <DOMElement> *element;
  NSDictionary *currentComponent, *components;
  NSString *currentURL, *baseURL;
  NSMutableArray *urls;
  NSMutableString *buffer;
  unsigned int count, max;

  baseURL = [[self davURL] absoluteString];

  urls = [NSMutableArray new];
  max = [refs length];
  for (count = 0; count < max; count++)
    {
      element = [refs objectAtIndex: count];
      currentURL = [[element firstChild] nodeValue];
      [urls addObject: currentURL];
    }

  components = [self _fetchComponentsMatchingURLs: urls];
  max = [urls count];
//   NSLog (@"adding properties with url");
  buffer = [[NSMutableString alloc] initWithCapacity: max*512];
  for (count = 0; count < max; count++)
    {
      currentComponent
	= [components objectForKey: [urls objectAtIndex: count]];
      if (currentComponent)
	[self appendObject: currentComponent
	      properties: properties
	      withBaseURL: baseURL
	      toBuffer: buffer];
      else
	[self appendMissingObjectRef: currentURL
	      toBuffer: buffer];
    }
  [response appendContentString: buffer];
  [buffer release];
//   NSLog (@"/adding properties with url");

  [urls release];
}

- (id) davCalendarMultiget: (id) queryContext
{
  WOResponse *r;
  id <DOMDocument> document;
  id <DOMElement> documentElement;
  NSString **properties;

  r = [context response];
  [r setStatus: 207];
  [r setContentEncoding: NSUTF8StringEncoding];
  [r setHeader: @"text/xml; charset=\"utf-8\"" forKey: @"content-type"];
  [r setHeader: @"no-cache" forKey: @"pragma"];
  [r setHeader: @"no-cache" forKey: @"cache-control"];
  [r appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [r appendContentString: @"<D:multistatus xmlns:D=\"DAV:\""
     @" xmlns:C=\"urn:ietf:params:xml:ns:caldav\">"];

  document = [[context request] contentAsDOMDocument];
  documentElement = [document documentElement];
  properties = [[self _parseRequestedProperties: documentElement]
		 asPointersOfObjects];
  [self _appendComponentProperties: properties
	matchingURLs: [documentElement getElementsByTagName: @"href"]
        toResponse: r];
  [r appendContentString:@"</D:multistatus>"];
  free (properties);

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

- (BOOL) requestNamedIsHandledLater: (NSString *) name
{
  return [name isEqualToString: @"OPTIONS"];
}

- (id) lookupComponentByUID: (NSString *) uid
{
  NSString *filename;
  id component;

  filename = [self resourceNameForEventUID: uid];
  if (filename)
    {
      component = [self lookupName: filename inContext: context acquire: NO];
      if ([component isKindOfClass: [NSException class]])
	component = nil;
    }
  else
    component = nil;

  return nil;
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
	  if ([self isValidContentName:_key])
            {
	      url = [[[_ctx request] uri] urlWithoutParameters];
	      if ([url hasSuffix: @"AsTask"])
		obj = [SOGoTaskObject objectWithName: _key
				      inContainer: self];
	      else if ([url hasSuffix: @"AsAppointment"])
		obj = [SOGoAppointmentObject objectWithName: _key
					     inContainer: self];
	      [obj setIsNew: YES];
            }
        }
      if (!obj)
        obj = [NSException exceptionWithHTTPStatus:404 /* Not Found */];
    }

  if (obj)
    [[SOGoCache sharedCache] registerObject: obj
			     withName: _key
			     inContainer: container];

  return obj;
}

- (NSDictionary *) freebusyResponseForRecipient: (NSString *) recipient
				       withUser: (SOGoUser *) user
				andCalendarData: (NSString *) calendarData
{
  NSDictionary *response;
  NSMutableArray *content;

  content = [NSMutableArray new];

  [content addObject: davElementWithContent (@"recipient", XMLNS_CALDAV, recipient)];
  if (user)
    {
      [content addObject: davElementWithContent (@"request-status", XMLNS_CALDAV,
						 @"2.0;Success")];
      [content addObject: davElementWithContent (@"calendar-data", XMLNS_CALDAV,
						 calendarData)];
    }
  else
      [content addObject:
		 davElementWithContent (@"request-status", XMLNS_CALDAV,
					@"3.7;Invalid Calendar User")];
  response = davElementWithContent (@"response", XMLNS_CALDAV, content);
  [content release];

  return response;
}

- (NSDictionary *) caldavFreeBusyRequestOnRecipient: (NSString *) recipient
					       from: (NSCalendarDate *) start
						 to: (NSCalendarDate *) to
{
  LDAPUserManager *um;
  SOGoUser *user;
  NSString *lRecipient, *login, *calendarData;
  SOGoFreeBusyObject *freebusy;

  user = nil;
  calendarData = nil;

  lRecipient = [recipient lowercaseString];
  if ([lRecipient hasPrefix: @"mailto:"])
    {
      um = [LDAPUserManager sharedUserManager];
      login = [um getUIDForEmail: [lRecipient substringFromIndex: 7]];
      if ([login length])
	{
	  user = [SOGoUser userWithLogin: login roles: nil];
	  freebusy = [[user homeFolderInContext: context]
		       freeBusyObject: @"freebusy.ifb"
		       inContext: context];
	  calendarData = [freebusy contentAsStringWithMethod: @"REPLY"
				   from: start to: to];
	}
    }

  return [self freebusyResponseForRecipient: recipient
	       withUser: user
	       andCalendarData: calendarData];
}

- (NSDictionary *) caldavFreeBusyRequest: (iCalFreeBusy *) freebusy
				    from: (NSString *) originator
				      to: (NSArray *) recipients
{
  NSDictionary *responseElement;
  NSMutableArray *elements;
  NSString *recipient;
  NSEnumerator *allRecipients;
  NSCalendarDate *startDate, *endDate;

  elements = [NSMutableArray new];
  [freebusy fillStartDate: &startDate andEndDate: &endDate];
  allRecipients = [recipients objectEnumerator];
  while ((recipient = [allRecipients nextObject]))
    [elements addObject: [self caldavFreeBusyRequestOnRecipient: recipient
			       from: startDate to: endDate]];
  responseElement = davElementWithContent (@"schedule-response",
					   XMLNS_CALDAV, elements);
  [elements release];

  return responseElement;
}

#warning we should merge this code with the code from the iTIP interpreter in MailPartViewer
- (NSDictionary *) caldavEventRequest: (iCalEvent *) event
			  withContent: (NSString *) iCalString
				 from: (NSString *) originator
				   to: (NSArray *) recipients
{
  NSDictionary *responseElement;
  NSArray *elements;
  NSString *method, *filename;
  SOGoAppointmentObject *apt;
  
  filename = [NSString stringWithFormat: @"%@.ics", [event uid]];
  apt = [SOGoAppointmentObject objectWithName: filename
			       andContent: iCalString
			       inContainer: self];
  method = [[event parent] method];
  if ([method isEqualToString: @"REQUEST"])
    elements = [apt postCalDAVEventRequestTo: recipients  from: originator];
  else if ([method isEqualToString: @"REPLY"])
    elements = [apt postCalDAVEventReplyTo: recipients  from: originator];
  else if ([method isEqualToString: @"CANCEL"])
    elements = [apt postCalDAVEventCancelTo: recipients  from: originator];
  else
    elements = nil;

  if (elements)
    responseElement = davElementWithContent (@"schedule-response",
					     XMLNS_CALDAV, elements);
  else
    responseElement = nil;

  return responseElement;
}

- (WOResponse *) _caldavScheduleResponse: (NSDictionary *) tags
{
  WOResponse *response;

  response = [context response];
  if (tags)
    {
      [response setStatus: 200];
      [response appendContentString:@"<?xml version=\"1.0\""
		@" encoding=\"utf-8\"?>"];
      [response setHeader: @"application/xml; charset=utf-8"
		forKey: @"Content-Type"];
      [response appendContentString:
		  [tags asWebDavStringWithNamespaces: nil]];
    }
  else
    [response setStatus: 415];

  return response;
}

- (WOResponse *) caldavScheduleRequest: (NSString *) iCalString
				  from: (NSString *) originator
				    to: (NSArray *) recipients
{
  NSString *tag;
  iCalCalendar *calendar;
  iCalEntityObject *element;
  NSDictionary *tags;

#warning needs to handle errors
  calendar = [iCalCalendar parseSingleFromSource: iCalString];
  element = [[calendar allObjects] objectAtIndex: 0];
  tag = [[element tag] uppercaseString];
  if ([tag isEqualToString: @"VFREEBUSY"])
    tags = [self caldavFreeBusyRequest: (iCalFreeBusy *) element
		 from: originator to: recipients];
  else if ([tag isEqualToString: @"VEVENT"])
    tags = [self caldavEventRequest: (iCalEvent *) element
		 withContent: iCalString
		 from: originator to: recipients];
  else
    tags = nil;

  return [self _caldavScheduleResponse: tags];
}

- (id) davPOSTRequest: (WORequest *) request
      withContentType: (NSString *) cType
	    inContext: (WOContext *) localContext
{
  id obj;
  NSString *originator;
  NSArray *recipients;

  if ([cType hasPrefix: @"text/calendar"])
    {
      originator = [request headerForKey: @"originator"];

      if ([[originator lowercaseString] hasPrefix: @"mailto:"])
	originator = [originator substringFromIndex: 7];  

      recipients = [[request headerForKey: @"recipient"]
		     componentsSeparatedByString: @", "];
      obj = [self caldavScheduleRequest: [request contentAsString]
		  from: originator to: recipients];
    }
  else
    obj = [super davPOSTRequest: request withContentType: cType
		 inContext: localContext];

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
  [classes addObject: @"calendar-access"];
  [classes addObject: @"calendar-schedule"];

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

- (NSString *) davCollectionTag
{
  NSArray *records;
  GCSFolder *folder;
  static EOFetchSpecification *cTagSpec = nil;
  EOSortOrdering *ordering;
  NSNumber *lastModified;
  NSString *cTag;

  folder = [self ocsFolder];
  ordering = [EOSortOrdering sortOrderingWithKey: @"c_lastmodified"
			     selector: EOCompareDescending];
  cTagSpec = [EOFetchSpecification
	       fetchSpecificationWithEntityName: [folder folderName]
	       qualifier: nil
	       sortOrderings: [NSArray arrayWithObject: ordering]];

  records = [folder fetchFields: [NSArray arrayWithObject: @"c_lastmodified"]
		    fetchSpecification: cTagSpec
		    ignoreDeleted: NO];
  if ([records count])
    {
      lastModified = [[records objectAtIndex: 0] objectForKey: @"c_lastmodified"];
      cTag = [lastModified stringValue];
    }
  else
    cTag = @"-1";

  return cTag;
}

- (NSString *) davDescription
{
  return @"";
}

/* vevent UID handling */

- (NSString *) resourceNameForEventUID: (NSString *) uid
                              inFolder: (GCSFolder *) folder
{
  static NSArray *nameFields = nil;
  EOQualifier *qualifier;
  NSArray *records;
  NSString *filename;
  unsigned int count;

  filename = nil;

  if (!nameFields)
    nameFields = [[NSArray alloc] initWithObjects: @"c_name", nil];

  if (uid && folder)
    {
      qualifier = [EOQualifier qualifierWithQualifierFormat: @"c_uid = %@",
			       uid];
      records = [folder fetchFields: nameFields matchingQualifier: qualifier];
      count = [records count];
      if (count)
	{
	  filename = [[records objectAtIndex:0] valueForKey:@"c_name"];
	  if (count > 1)
	    [self errorWithFormat:
		    @"The storage contains more than file with UID '%@'",
		  uid];
	}
    }

  return filename;
}

- (NSString *) resourceNameForEventUID: (NSString *) uid
{
  /* caches UIDs */
  GCSFolder *folder;
  NSString  *rname;

  rname = nil;
  if (uid)
    {
      if (!uidToFilename)
	uidToFilename = [NSMutableDictionary new];
      rname = [uidToFilename objectForKey: uid];
      if (!rname)
	{
	  folder = [self ocsFolder];
	  rname = [self resourceNameForEventUID: uid inFolder: folder];
	  if (rname)
	    [uidToFilename setObject: rname forKey: uid];
	}
    }

  return rname;
}

- (NSArray *) subscriptionRoles
{
  return [NSArray arrayWithObjects:
		    SOGoRole_ObjectCreator, SOGoRole_ObjectEraser,
		  SOGoCalendarRole_PublicResponder,
		  SOGoCalendarRole_PublicModifier,
		  SOGoCalendarRole_PublicViewer,
		  SOGoCalendarRole_PublicDAndTViewer,
		  SOGoCalendarRole_PrivateResponder,
		  SOGoCalendarRole_PrivateModifier,
		  SOGoCalendarRole_PrivateViewer,
		  SOGoCalendarRole_PrivateDAndTViewer,
		  SOGoCalendarRole_ConfidentialResponder,
		  SOGoCalendarRole_ConfidentialModifier,
		  SOGoCalendarRole_ConfidentialViewer,
		  SOGoCalendarRole_ConfidentialDAndTViewer, nil];
}

- (NSString *) roleForComponentsWithAccessClass: (iCalAccessClass) accessClass
					forUser: (NSString *) uid
{
  NSString *accessRole, *prefix, *currentRole, *suffix;
  NSEnumerator *acls;
  NSMutableDictionary *userRoles;

  accessRole = nil;

  if (accessClass == iCalAccessPublic)
    prefix = @"Public";
  else if (accessClass == iCalAccessPrivate)
    prefix = @"Private";
  else
    prefix = @"Confidential";

  userRoles = [aclMatrix objectForKey: uid];
  if (!userRoles)
    {
      userRoles = [NSMutableDictionary dictionaryWithCapacity: 3];
      [aclMatrix setObject: userRoles forKey: uid];
    }

  accessRole = [userRoles objectForKey: prefix];
  if (!accessRole)
    {
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
      if (!accessRole)
	accessRole = @"";
      [userRoles setObject: accessRole forKey: prefix];
    }

  return accessRole;
}

- (NSArray *) fetchFreeBusyInfosFrom: (NSCalendarDate *) _startDate
                                  to: (NSCalendarDate *) _endDate
{
  static NSArray *infos = nil; // TODO: move to a plist file
  
  if (!infos)
    infos = [[NSArray alloc] initWithObjects: @"c_partmails", @"c_partstates",
                             @"c_isopaque", @"c_status", @"c_cycleinfo", @"c_orgmail", nil];

  return [self fetchFields: infos
	       from: _startDate to: _endDate
	       title: nil
               component: @"vevent"
	       additionalFilters: nil];
}

- (NSArray *) fetchCoreInfosFrom: (NSCalendarDate *) _startDate
                              to: (NSCalendarDate *) _endDate
			   title: (NSString *) title
                       component: (id) _component
{
  return [self fetchCoreInfosFrom: _startDate to: _endDate title: title
	       component: _component additionalFilters: nil];
}

- (NSArray *) fetchCoreInfosFrom: (NSCalendarDate *) _startDate
                              to: (NSCalendarDate *) _endDate
			   title: (NSString *) title
                       component: (id) _component
	       additionalFilters: (NSString *) filters
{
  static NSArray *infos = nil; // TODO: move to a plist file

  if (!infos)
    infos = [[NSArray alloc] initWithObjects: @"c_name", @"c_content",
			     @"c_creationdate", @"c_lastmodified",
			     @"c_version", @"c_component", @"c_title",
			     @"c_location", @"c_orgmail", @"c_status",
			     @"c_classification", @"c_isallday",
			     @"c_isopaque", @"c_participants", @"c_partmails",
			     @"c_partstates", @"c_sequence", @"c_priority",
			     @"c_cycleinfo", @"c_iscycle", nil];

  return [self fetchFields: infos from: _startDate to: _endDate title: title
               component: _component
	       additionalFilters: filters];
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
- (BOOL) create
{
  BOOL rc;
  NSUserDefaults *userSettings;
  NSMutableDictionary *calendarSettings;
  SOGoUser *ownerUser;

  rc = [super create];
  if (rc)
    {
      ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]
			    roles: nil];
      userSettings = [ownerUser userSettings];
      calendarSettings = [userSettings objectForKey: @"Calendar"];
      if (!calendarSettings)
	{
	  calendarSettings = [NSMutableDictionary dictionary];
	  [userSettings setObject: calendarSettings forKey: @"Calendar"];
	}
      [userSettings synchronize];
    }

  return rc;
}

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
  SOGoFolder *currentContainer;
  SOGoAppointmentFolders *parent;
  NSException *error;

  currentContainer = [[container container] container];
  currentContainer = [currentContainer lookupName: uid
				       inContext: context
				       acquire: NO];
  parent = [currentContainer lookupName: @"Calendar" inContext: context
			     acquire: NO];
  currentContainer = [parent lookupName: @"personal" inContext: context
			     acquire: NO];
  if (!currentContainer)
    {
      error = [parent newFolderWithName: [parent defaultFolderName]
		      andNameInContainer: @"personal"];
      if (!error)
	currentContainer = [parent lookupName: @"personal"
				   inContext: context
				   acquire: NO];
    }

  return (SOGoAppointmentFolder *) currentContainer;
}

- (NSArray *) lookupCalendarFoldersForUIDs: (NSArray *) _uids
                                 inContext: (id)_ctx
{
  /* Note: can return NSNull objects in the array! */
  NSMutableArray *folders;
  NSEnumerator *e;
  NSString *uid, *ownerLogin;
  id folder;

  ownerLogin = [self ownerInContext: context];

  if ([_uids count] == 0) return nil;
  folders = [NSMutableArray arrayWithCapacity:16];
  e = [_uids objectEnumerator];
  while ((uid = [e nextObject]))
    {
      if ([uid isEqualToString: ownerLogin])
	folder = self;
      else
	{
	  folder = [self lookupCalendarFolderForUID: uid];
	  if (![folder isNotNull])
	    [self logWithFormat:@"Note: did not find folder for uid: '%@'", uid];
	}

      if (folder)
	[folders addObject: folder];
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
  while ((uid = [e nextObject]))
    {
      id obj;
    
      obj = [self lookupHomeFolderForUID:uid inContext:nil];
      if ([obj isNotNull])
	{
	  obj = [obj lookupName: @"freebusy.ifb" inContext: nil acquire: NO];
	  if ([obj isKindOfClass: [NSException class]])
	    obj = nil;
	}
      if (![obj isNotNull])
	[self logWithFormat: @"Note: did not find freebusy.ifb for uid: '%@'",
	      uid];
    
      /* Note: intentionally add 'null' folders to allow a mapping */
      if (!obj)
	obj = [NSNull null];
      [objs addObject: obj];
    }

  return objs;
}

- (NSArray *) uidsFromICalPersons: (NSArray *) _persons
{
  /* Note: can return NSNull objects in the array! */
  NSMutableArray    *uids;
  LDAPUserManager *um;
  unsigned          i, count;
  iCalPerson *person;
  NSString   *email;
  NSString   *uid;
  
  if (_persons)
    {
      count = [_persons count];
      uids  = [NSMutableArray arrayWithCapacity:count + 1];
      um    = [LDAPUserManager sharedUserManager];
  
      for (i = 0; i < count; i++)
	{
	  person = [_persons objectAtIndex:i];
	  email  = [person rfc822Email];
	  if ([email isNotNull])
	    uid = [um getUIDForEmail:email];
	  else
	    uid = nil;
	  
	  if (!uid)
	    uid = (NSString *) [NSNull null];
	  [uids addObject: uid];
	}
    }
  else
    uids = nil;

  return uids;
}

- (NSArray *) lookupCalendarFoldersForICalPerson: (NSArray *) _persons
				       inContext: (id) _ctx
{
  /* Note: can return NSNull objects in the array! */
  NSArray *uids, *folders;

  uids = [self uidsFromICalPersons: _persons];
  if (uids)
    folders = [self lookupCalendarFoldersForUIDs: uids
		    inContext: _ctx];
  else
    folders = nil;
  
  return folders;
}

// - (id) lookupGroupFolderForUIDs: (NSArray *) _uids
//                       inContext: (id)_ctx
// {
//   SOGoCustomGroupFolder *folder;
  
//   if (_uids == nil)
//     return nil;

//   folder = [[SOGoCustomGroupFolder alloc] initWithUIDs:_uids inContainer:self];
//   return [folder autorelease];
// }

// - (id) lookupGroupCalendarFolderForUIDs: (NSArray *) _uids
//                               inContext: (id) _ctx
// {
//   SOGoCustomGroupFolder *folder;
  
//   if ((folder = [self lookupGroupFolderForUIDs:_uids inContext:_ctx]) == nil)
//     return nil;
  
//   folder = [folder lookupName:@"Calendar" inContext:_ctx acquire:NO];
//   if (![folder isNotNull])
//     return nil;
//   if ([folder isKindOfClass:[NSException class]]) {
//     [self debugWithFormat:@"Note: could not lookup 'Calendar' in folder: %@",
// 	    folder];
//     return nil;
//   }
  
//   return folder;
// }

/* bulk fetches */

// #warning We only support ONE calendar per user at this time
// - (BOOL) _appendSubscribedFolders: (NSDictionary *) subscribedFolders
// 		     toFolderList: (NSMutableArray *) calendarFolders
// {
//   NSEnumerator *keys;
//   NSString *currentKey;
//   NSMutableDictionary *currentCalendar;
//   BOOL firstShouldBeActive;
//   unsigned int count;

//   firstShouldBeActive = YES;

//   keys = [[subscribedFolders allKeys] objectEnumerator];
//   currentKey = [keys nextObject];
//   count = 1;
//   while (currentKey)
//     {
//       currentCalendar = [NSMutableDictionary new];
//       [currentCalendar autorelease];
//       [currentCalendar
// 	setDictionary: [subscribedFolders objectForKey: currentKey]];
//       [currentCalendar setObject: currentKey forKey: @"folder"];
//       [calendarFolders addObject: currentCalendar];
//       if ([[currentCalendar objectForKey: @"active"] boolValue])
// 	firstShouldBeActive = NO;
//       count++;
//       currentKey = [keys nextObject];
//     }

//   return firstShouldBeActive;
// }

// - (NSArray *) calendarFolders
// {
//   NSMutableDictionary *userCalendar, *calendarDict;
//   NSMutableArray *calendarFolders;
//   SOGoUser *calendarUser;
//   BOOL firstActive;

//   calendarFolders = [NSMutableArray new];
//   [calendarFolders autorelease];

//   calendarUser = [SOGoUser userWithLogin: [self ownerInContext: context]
// 			   roles: nil];
//   userCalendar = [NSMutableDictionary new];
//   [userCalendar autorelease];
//   [userCalendar setObject: @"/" forKey: @"folder"];
//   [userCalendar setObject: @"Calendar" forKey: @"displayName"];
//   [calendarFolders addObject: userCalendar];

//   calendarDict = [[calendarUser userSettings] objectForKey: @"Calendar"];
//   firstActive = [[calendarDict objectForKey: @"activateUserFolder"] boolValue];
//   firstActive = ([self _appendSubscribedFolders:
// 			 [calendarDict objectForKey: @"SubscribedFolders"]
// 		       toFolderList: calendarFolders]
// 		 || firstActive);
//   [userCalendar setObject: [NSNumber numberWithBool: firstActive]
// 		forKey: @"active"];

//   return calendarFolders;
// }

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

- (BOOL) isActive
{
  NSUserDefaults *settings;
  NSArray *inactiveFolders;

  settings = [[context activeUser] userSettings];
  inactiveFolders
    = [[settings objectForKey: @"Calendar"] objectForKey: @"InactiveFolders"];

  return (![inactiveFolders containsObject: nameInContainer]);
}

@end /* SOGoAppointmentFolder */
