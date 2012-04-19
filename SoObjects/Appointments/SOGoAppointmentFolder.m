/*
  Copyright (C) 2007-2012 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
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
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOMessage.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSString+misc.h>
#import <GDLContentStore/GCSFolder.h>
#import <DOM/DOMElement.h>
#import <DOM/DOMProtocols.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalFreeBusy.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalRecurrenceCalculator.h>
#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalTimeZonePeriod.h>
#import <NGCards/NSString+NGCards.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SOGo/DOMNode+SOGo.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoWebDAVAclManager.h>
#import <SOGo/SOGoWebDAVValue.h>
#import <SOGo/WORequest+SOGo.h>
#import <SOGo/WOResponse+SOGo.h>

#import "iCalRepeatableEntityObject+SOGo.h"
#import "iCalEvent+SOGo.h"
#import "iCalPerson+SOGo.h"
#import "SOGoAppointmentObject.h"
#import "SOGoAppointmentFolders.h"
#import "SOGoFreeBusyObject.h"
#import "SOGoTaskObject.h"

#import "SOGoAppointmentFolder.h"

#define defaultColor @"#AAAAAA"

@interface SOGoGCSFolder (SOGoPrivate)

- (void) appendObject: (NSDictionary *) object
	   properties: (NSString **) properties
                count: (unsigned int) propertiesCount
          withBaseURL: (NSString *) baseURL
	     toBuffer: (NSMutableString *) r;

@end

@implementation SOGoAppointmentFolder

static NSNumber *sharedYes = nil;

+ (void) initialize
{
  static BOOL didInit = NO;

  if (!didInit)
    {
      didInit = YES;
      sharedYes = [[NSNumber numberWithBool: YES] retain];
      [iCalEntityObject initializeSOGoExtensions];
    }
}

+ (SOGoWebDAVAclManager *) webdavAclManager
{
  static SOGoWebDAVAclManager *aclManager = nil;
  NSString *nsI;

  if (!aclManager)
    {
      nsI = @"urn:inverse:params:xml:ns:inverse-dav";

      aclManager = [SOGoWebDAVAclManager new];
      [aclManager registerDAVPermission: davElement (@"read", XMLNS_WEBDAV)
                               abstract: YES
                         withEquivalent: SoPerm_WebDAVAccess
                              asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager
        registerDAVPermission: davElement (@"read-current-user-privilege-set", XMLNS_WEBDAV)
                     abstract: YES
               withEquivalent: SoPerm_WebDAVAccess
                    asChildOf: davElement (@"read", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"read-free-busy", XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: SOGoCalendarPerm_ReadFreeBusy
                              asChildOf: davElement (@"all", XMLNS_WEBDAV)];
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
                     abstract: NO
               withEquivalent: SoPerm_ChangePermissions /* hackish */
                    asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager
	registerDAVPermission: davElement (@"write-content", XMLNS_WEBDAV)
                     abstract: NO
               withEquivalent: SoPerm_AddDocumentsImagesAndFiles
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
  SOGoUser *user;
  if ((self = [super initWithName: name inContainer: newContainer]))
    {
      user = [context activeUser];
      timeZone = [[user userDefaults] timeZone];
      aclMatrix = [NSMutableDictionary new];
      stripFields = nil;
      uidToFilename = nil;
      memset (userCanAccessObjectsClassifiedAs, NO,
              iCalAccessClassCount * sizeof (BOOL));

      davCalendarStartTimeLimit
        = [[user domainDefaults] davCalendarStartTimeLimit];
      davTimeLimitSeconds = davCalendarStartTimeLimit * 86400;
      /* 86400 / 2 = 43200. We hardcode that value in order to avoid
         integer and float confusion. */
      davTimeHalfLimitSeconds = davCalendarStartTimeLimit * 43200;
      componentSet = nil;
    }

  return self;
}

- (void) dealloc
{
  [aclMatrix release];
  [stripFields release];
  [uidToFilename release];
  [componentSet release];
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
  NSString *color;

  color = [self folderPropertyValueInCategory: @"FolderColors"];
  if (!color)
    color = defaultColor;

  return color;
}

- (void) setCalendarColor: (NSString *) newColor
{
  if (![newColor length])
    newColor = nil;

  [self setFolderPropertyValue: newColor
                    inCategory: @"FolderColors"];
}

- (BOOL) showCalendarAlarms
{
  NSNumber *showAlarms;

  showAlarms = [self folderPropertyValueInCategory: @"FolderShowAlarms"];

  return (showAlarms ? [showAlarms boolValue] : YES);
}

- (void) setShowCalendarAlarms: (BOOL) new
{
  NSNumber *showAlarms;

  if (new)
    showAlarms = nil;
  else
    showAlarms = [NSNumber numberWithBool: NO];

  [self setFolderPropertyValue: showAlarms
                    inCategory: @"FolderShowAlarms"];    
}

- (BOOL) showCalendarTasks
{
  NSNumber *showTasks;

  showTasks = [self folderPropertyValueInCategory: @"FolderShowTasks"];

  return (showTasks ? [showTasks boolValue] : YES);
}

- (void) setShowCalendarTasks: (BOOL) new
{
  NSNumber *showTasks;

  /* the default value is "YES", so we keep only those with a value of "NO"... */
  if (new)
    showTasks = nil;
  else
    showTasks = [NSNumber numberWithBool: NO];

  [self setFolderPropertyValue: showTasks
                    inCategory: @"FolderShowTasks"];    
}

- (NSString *) syncTag
{
  NSString *syncTag;

  syncTag = [self folderPropertyValueInCategory: @"FolderSyncTags"];
  if (!syncTag)
    syncTag = @"";

  return syncTag;
}

- (void) setSyncTag: (NSString *) newSyncTag
{
  // Check for duplicated tags
  SOGoUserSettings *settings;
  NSDictionary *syncTags;
  NSArray *values;

  if ([newSyncTag length])
    {
      settings = [[context activeUser] userSettings];
      syncTags = [[settings objectForKey: @"Calendar"]
                           objectForKey: @"FolderSyncTags"];
      values = [syncTags allValues];
      if (![values containsObject: newSyncTag])
        [self setFolderPropertyValue: newSyncTag
                          inCategory: @"FolderSyncTags"];
    }
  else
    [self setFolderPropertyValue: nil
                      inCategory: @"FolderSyncTags"];
}

- (BOOL) synchronizeCalendar
{
  NSNumber *synchronize;

  synchronize = [self folderPropertyValueInCategory: @"FolderSynchronize"];

  return [synchronize boolValue];
}

- (void) setSynchronizeCalendar: (BOOL) new
{
  NSNumber *synchronize;

  if (new)
    synchronize = [NSNumber numberWithBool: YES];
  else
    synchronize = nil;

  [self setFolderPropertyValue: synchronize
                    inCategory: @"FolderSynchronize"];
}

- (BOOL) includeInFreeBusy
{
  NSNumber *excludeFromFreeBusy;

  // Check if the owner (not the active user) has excluded the calendar from her/his free busy data.
  excludeFromFreeBusy
    = [self folderPropertyValueInCategory: @"FreeBusyExclusions"
				  forUser: [SOGoUser userWithLogin: [self ownerInContext: context]]];

  return ![excludeFromFreeBusy boolValue];
}

- (void) setIncludeInFreeBusy: (BOOL) newInclude
{
  NSNumber *excludeFromFreeBusy;

  excludeFromFreeBusy = [NSNumber numberWithBool: !newInclude];

  [self setFolderPropertyValue: excludeFromFreeBusy
                    inCategory: @"FreeBusyExclusions"];
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

- (NSString *) _sqlStringRangeFrom: (NSCalendarDate *) _startDate
                                to: (NSCalendarDate *) _endDate
                             cycle: (BOOL) _isCycle
{
  NSString *format;
  unsigned int start, end;

  start = (unsigned int) [_startDate timeIntervalSince1970];
  end = (unsigned int) [_endDate timeIntervalSince1970];

  // vTODOs don't necessarily have start/end dates
  if (_isCycle)
    format = (@"(c_startdate = NULL OR c_startdate <= %u)"
              @" AND (c_cycleenddate = NULL OR c_cycleenddate >= %u)");
  else
    format = (@"(c_startdate = NULL OR c_startdate <= %u)"
              @" AND (c_enddate = NULL OR c_enddate >= %u)");

  return [NSString stringWithFormat: format, end, start];
}

- (NSString *) aclSQLListingFilter
{
  NSString *filter;
  NSMutableArray *grantedClasses, *deniedClasses;
  NSNumber *classNumber;
  unsigned int grantedCount;
  iCalAccessClass currentClass;

  [self initializeQuickTablesAclsInContext: context];
  grantedClasses = [NSMutableArray arrayWithCapacity: 3];
  deniedClasses = [NSMutableArray arrayWithCapacity: 3];
  for (currentClass = 0;
       currentClass < iCalAccessClassCount; currentClass++)
    {
      classNumber = [NSNumber numberWithInt: currentClass];
      if (userCanAccessObjectsClassifiedAs[currentClass])
        [grantedClasses addObject: classNumber];
      else
        [deniedClasses addObject: classNumber];
    }
  grantedCount = [grantedClasses count];
  if (grantedCount == 3)
    filter = @"";
  else if (grantedCount == 2)
    filter
      = [NSString stringWithFormat: @"c_classification != %@",
                  [deniedClasses objectAtIndex: 0]];
  else if (grantedCount == 1)
    filter
      = [NSString stringWithFormat: @"c_classification = %@",
                  [grantedClasses objectAtIndex: 0]];
  else
    filter = nil;

  return filter;
}

- (NSString *) componentSQLFilter
{
  NSString *filter;

  if ([self showCalendarTasks])
    filter = nil;
  else
    filter = @"c_component != 'vtodo'";

  return filter;
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

#warning filters should make use of EOQualifier
- (NSArray *) bareFetchFields: (NSArray *) fields
                         from: (NSCalendarDate *) startDate
                           to: (NSCalendarDate *) endDate 
                        title: (NSString *) title
                    component: (NSString *) component
            additionalFilters: (NSString *) filters
{
  EOQualifier *qualifier;
  GCSFolder *folder;
  NSMutableArray *baseWhere;
  NSString *where, *privacySQLString;
  NSArray *records;

  folder = [self ocsFolder];

  baseWhere = [NSMutableArray arrayWithCapacity: 32];
  if (startDate && endDate)
    [baseWhere addObject: [self _sqlStringRangeFrom: startDate to: endDate
                                              cycle: NO]];

  if ([title length])
    [baseWhere
      addObject: [NSString stringWithFormat: @"c_title isCaseInsensitiveLike: '%%%@%%'",
                           [title stringByReplacingString: @"'"  withString: @"\\'\\'"]]];

  if (component)
    {
      if ([component isEqualToString: @"vtodo"] && ![self showCalendarTasks])
        return [NSArray array];
      else
        [baseWhere addObject: [NSString stringWithFormat: @"c_component = '%@'",
                                        component]];
    }
  else if (![self showCalendarTasks])
      [baseWhere addObject: @"c_component != 'vtodo'"];

  if ([filters length])
    [baseWhere addObject: filters];

  privacySQLString = [self aclSQLListingFilter];
  if (privacySQLString)
    {
      if ([privacySQLString length])
        [baseWhere addObject: privacySQLString];

      /* sql is empty when we fetch everything (all parameters are nil) */
      if ([baseWhere count] > 0)
        {
          where = [baseWhere componentsJoinedByString: @" AND "];
          qualifier = [EOQualifier qualifierWithQualifierFormat: where];
        }
      else
        qualifier = nil;

      /* fetch non-recurrent apts first */

      records = [folder fetchFields: fields matchingQualifier: qualifier];
    }
  else
    records = [NSArray array];
  
  if ([self _checkIfWeCanRememberRecords: fields])
    [self _rememberRecords: records];

  return records;
}

/**
 * Set the timezone of the event start and end dates to the user's timezone.
 * @param theRecord a dictionnary with the attributes of the event.
 * @return a copy of theRecord with adjusted dates.
 */
- (NSMutableDictionary *) fixupRecord: (NSDictionary *) theRecord
{
  NSMutableDictionary *record;
  static NSString *fields[] = { @"c_startdate", @"startDate",
				@"c_enddate", @"endDate" };
  unsigned int count;
  NSCalendarDate *date;
  NSNumber *dateValue;
  unsigned int offset;

  record = [[theRecord mutableCopy] autorelease];
  for (count = 0; count < 2; count++)
    {
      dateValue = [theRecord objectForKey: fields[count * 2]];
      if (dateValue)
	{
	  date = [NSCalendarDate dateWithTimeIntervalSince1970: [dateValue unsignedIntValue]];
	  if (date)
	    {
	      [date setTimeZone: timeZone];
	      if ([[theRecord objectForKey: @"c_isallday"] boolValue])
		{
		  // Since there's no timezone associated to all-day events,
		  // their time must be adjusted for the user's timezone.
		  offset = [timeZone secondsFromGMTForDate: date];
		  date = (NSCalendarDate*)[date dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
							  seconds:-offset];
		  [record setObject: [NSNumber numberWithInt: [dateValue intValue] - offset] forKey: fields[count * 2]];
		}
	      [record setObject: date forKey: fields[count * 2 + 1]];
	    }
	}
      else
	[self logWithFormat: @"missing '%@' in record?", fields[count * 2]];
    }

  return record;
}

//
//
//
- (NSArray *) fixupRecords: (NSArray *) theRecords
{
  // TODO: is the result supposed to be sorted by date?
  NSMutableArray *ma;
  unsigned count, max;
  id row; // TODO: what is the type of the record?

  if (theRecords)
    {
      max = [theRecords count];
      ma = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
	{
	  row = [self fixupRecord: [theRecords objectAtIndex: count]];
	  if (row)
	    [ma addObject: row];
	}
    }
  else
    ma = nil;

  return ma;
}

/**
 * Adjust the timezone of the start and end dates to the user's timezone.
 * The event is recurrent and the dates must first be adjusted with respect to
 * the event's timezone.
 * @param theRecord
 * @param theCycle
 * @param theFirstCycle
 * @param theEventTimeZone
 * @see fixupRecord:
 * @return a copy of theRecord with adjusted dates.
 */
- (NSMutableDictionary *) fixupCycleRecord: (NSDictionary *) theRecord
                                cycleRange: (NGCalendarDateRange *) theCycle
	    firstInstanceCalendarDateRange: (NGCalendarDateRange *) theFirstCycle
			 withEventTimeZone: (iCalTimeZone *) theEventTimeZone
{
  NSMutableDictionary *record;
  NSNumber *dateSecs;
  id date;
  int secondsOffsetFromGMT;

  record = [[theRecord mutableCopy] autorelease];

  date = [theCycle startDate];
  if (theEventTimeZone)
    {
      secondsOffsetFromGMT = (int) [[theEventTimeZone periodForDate: date] secondsOffsetFromGMT];
      date = [date dateByAddingYears: 0 months: 0 days: 0 hours: 0 minutes: 0 seconds: -secondsOffsetFromGMT];
    }
  [date setTimeZone: timeZone];
  [record setObject: date forKey: @"startDate"];
  dateSecs = [NSNumber numberWithInt: [date timeIntervalSince1970]];
  [record setObject: dateSecs forKey: @"c_startdate"];
  [record setObject: dateSecs forKey: @"c_recurrence_id"];

  date = [theCycle endDate];
  if (theEventTimeZone)
    {
      secondsOffsetFromGMT = (int) [[theEventTimeZone periodForDate: date] secondsOffsetFromGMT];
      date = [date dateByAddingYears: 0 months: 0 days: 0 hours: 0 minutes: 0 seconds: -secondsOffsetFromGMT];
    }
  [date setTimeZone: timeZone];
  [record setObject: date forKey: @"endDate"];
  dateSecs = [NSNumber numberWithInt: [date timeIntervalSince1970]];
  [record setObject: dateSecs forKey: @"c_enddate"];
  
  // The first instance date is added to the dictionary so it can
  // be used by UIxCalListingActions to compute the DST offset.
  date = [theFirstCycle startDate];
  [record setObject: date forKey: @"cycleStartDate"];
  
  return record;
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
firstInstanceCalendarDateRange: (NGCalendarDateRange *) fir
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
	      
	      // The first instance date is added to the dictionary so it can
	      // be used by UIxCalListingActions to compute the DST offset.
	      [newRecord setObject: [fir startDate] forKey: @"cycleStartDate"];
	      
	      // We identified the record as an exception.
	      [newRecord setObject: [NSNumber numberWithInt: 1]
			    forKey: @"isException"];
	      
	      [ma replaceObjectAtIndex: recordIndex withObject: newRecord];
	    }
	  else
	    [ma removeObjectAtIndex: recordIndex];
	}
      else
	[self errorWithFormat:
		@"missing exception record for recurrence-id %@ (uid %@)",
	      recurrenceId, [component uid]];
    }
  else
    {
      newRecord = [self fixupRecord: [component quickRecord]];
      newRecordRange = [NGCalendarDateRange 
			 calendarDateRangeWithStartDate: [newRecord objectForKey: @"startDate"]
			 endDate: [newRecord objectForKey: @"endDate"]];
      if ([dateRange doesIntersectWithDateRange: newRecordRange])
	[ma addObject: newRecord];
    }

  if (newRecord)
    [self _fixExceptionRecord: newRecord fromRow: row];
}

//
//
//
- (void) _appendCycleExceptionsFromRow: (NSDictionary *) row
        firstInstanceCalendarDateRange: (NGCalendarDateRange *) fir
			      forRange: (NGCalendarDateRange *) dateRange
			       toArray: (NSMutableArray *) ma
{
  NSArray *elements, *components;
  unsigned int count, max;
  NSString *content;

  content = [row objectForKey: @"c_content"];
  if ([content length])
    {
      // TODO : c_content could have already been parsed.
      // @see _flattenCycleRecord:forRange:intoArray:
      elements = [iCalCalendar parseFromSource: content];
      if ([elements count])
	{
	  components = [[elements objectAtIndex: 0] allObjects];
	  max = [components count];
	  for (count = 1; count < max; count++)
	    [self _appendCycleException: [components objectAtIndex: count]
		  firstInstanceCalendarDateRange: fir
				fromRow: row
			       forRange: dateRange
				toArray: ma];
	}
    }
}

/**
 * Calculate and return the occurrences of the recurrent event for the given
 * period.
 * @param theRecord the event definition.
 * @param theRange the period to look in.
 * @param theRecords the array into which are copied the resulting occurrences.
 * @see [iCalRepeatableEntityObject+SOGo doesOccurOnDate:]
 */
- (void) _flattenCycleRecord: (NSDictionary *) theRecord
                    forRange: (NGCalendarDateRange *) theRange
                   intoArray: (NSMutableArray *) theRecords
{
  NSMutableDictionary *row, *fixedRow;
  NSMutableArray *records, *newExDates;
  NSDictionary *cycleinfo;
  NSEnumerator *exDatesList;
  NGCalendarDateRange *firstRange, *recurrenceRange, *oneRange;
  NSArray *rules, *exRules, *exDates, *ranges;
  NSArray *elements, *components;
  NSString *content;
  NSCalendarDate *checkStartDate, *checkEndDate, *firstStartDate,
                    *firstEndDate;
  iCalDateTime *dtstart;
  iCalEvent *component;
  iCalTimeZone *eventTimeZone;
  unsigned count, max, offset;
  id exDate;

  content = [theRecord objectForKey: @"c_cycleinfo"];
  if (![content isNotNull])
    {
      [self errorWithFormat:@"cyclic record doesn't have cycleinfo -> %@",
	    theRecord];
      return;
    }

  cycleinfo = [content propertyList];
  if (!cycleinfo)
    {
      [self errorWithFormat:@"cyclic record doesn't have cycleinfo -> %@",
	    theRecord];
      return;
    }
  rules = [cycleinfo objectForKey: @"rules"];
  exRules = [cycleinfo objectForKey: @"exRules"];
  exDates = [cycleinfo objectForKey: @"exDates"];
  
  row = [self fixupRecord: theRecord];
  [row removeObjectForKey: @"c_cycleinfo"];
  [row setObject: sharedYes forKey: @"isRecurrentEvent"];

  content = [theRecord objectForKey: @"c_content"];
  if ([content isNotNull])
    {
      elements = [iCalCalendar parseFromSource: content];
      if ([elements count])
	{
	  components = [[elements objectAtIndex: 0] events];
	  if ([components count])
	    {
	      // Retrieve the range of the first/master event
	      component = [components objectAtIndex: 0];
              dtstart = (iCalDateTime *) [component uniqueChildWithTag: @"dtstart"];
              firstStartDate = [[[[dtstart valuesForKey: @""]
                                   lastObject]
                                  lastObject]
                                 asCalendarDate];
              firstEndDate = [firstStartDate addTimeInterval: [component occurenceInterval]];
              
              firstRange = [NGCalendarDateRange calendarDateRangeWithStartDate: firstStartDate
                                                                       endDate: firstEndDate];

              eventTimeZone = [dtstart timeZone];
              if (eventTimeZone)
                {
                  // Adjust the range to check with respect to the event timezone (extracted from the start date)
                  checkStartDate = [eventTimeZone computedDateForDate: [theRange startDate]];
                  checkEndDate = [eventTimeZone computedDateForDate: [theRange endDate]];
                  recurrenceRange = [NGCalendarDateRange calendarDateRangeWithStartDate: checkStartDate
                                                                                endDate: checkEndDate];
                  
                  // Adjust the exception dates
                  exDates = [eventTimeZone computedDatesForStrings: exDates];
                  
                  // Adjust the recurrence rules "until" dates
                  rules = [component recurrenceRulesWithTimeZone: eventTimeZone];
                  exRules = [component exceptionRulesWithTimeZone: eventTimeZone];
                }
              else 
                {
                  recurrenceRange = theRange;
                  if ([[theRecord objectForKey: @"c_isallday"] boolValue])
                    {
                      // The event lasts all-day and has no timezone (floating); we convert the range of the first event
                      // to the user's timezone
                      offset = [timeZone secondsFromGMTForDate: [firstRange startDate]];
                      firstStartDate = [[firstRange startDate] dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                                                         seconds:-offset];
                      firstEndDate = [[firstRange endDate] dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                                                     seconds:-offset];
                      [firstStartDate setTimeZone: timeZone];
                      [firstEndDate setTimeZone: timeZone];
                      firstRange = [NGCalendarDateRange calendarDateRangeWithStartDate: firstStartDate
                                                                               endDate: firstEndDate];
        
                      // Adjust the exception dates
                      exDatesList = [exDates objectEnumerator];
                      newExDates = [NSMutableArray arrayWithCapacity: [exDates count]];
                      while ((exDate = [exDatesList nextObject]))
                        {
                          exDate = [[exDate asCalendarDate] dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                                                      seconds:-offset];
                          [newExDates addObject: exDate];
                        }
                      exDates = newExDates;
                    }
                }
              
              // Calculate the occurrences for the given range
              records = [NSMutableArray array];
              ranges = [iCalRecurrenceCalculator recurrenceRangesWithinCalendarDateRange: recurrenceRange
                                                          firstInstanceCalendarDateRange: firstRange
									 recurrenceRules: rules
                                                                          exceptionRules: exRules
                                                                          exceptionDates: exDates];
              max = [ranges count];
              for (count = 0; count < max; count++)
                {
                  oneRange = [ranges objectAtIndex: count];
                  fixedRow = [self fixupCycleRecord: row
                                         cycleRange: oneRange
                                   firstInstanceCalendarDateRange: firstRange
                                  withEventTimeZone: eventTimeZone];
                  if (fixedRow)
                    [records addObject: fixedRow];
                }
              
              [self _appendCycleExceptionsFromRow: row
                   firstInstanceCalendarDateRange: firstRange
                                         forRange: theRange
                                          toArray: records];
              
              [theRecords addObjectsFromArray: records];
            }
        }
    }
  else
    [self errorWithFormat:@"cyclic record doesn't have content -> %@", theRecord];
}

- (NSArray *) _flattenCycleRecords: (NSArray *) _records
                        fetchRange: (NGCalendarDateRange *) _r
{
  // TODO: is the result supposed to be sorted by date?
  NSMutableArray *ma;
  NSDictionary *row;
  NSCalendarDate *rangeEndDate;
  unsigned int count, max;

  max = [_records count];
  ma = [NSMutableArray arrayWithCapacity: max];

  // Adjust the range so it ends at midnight. This is necessary when calculating
  // recurrences of all-day events.
  rangeEndDate = [[_r endDate] dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:1];
  _r = [NGCalendarDateRange calendarDateRangeWithStartDate: [_r startDate]
						   endDate: rangeEndDate];

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

  // What we keep....
  [stripFields removeObjectsInArray: [NSArray arrayWithObjects: @"c_name",
					      @"c_uid", @"c_startdate",
					      @"c_enddate", @"c_isallday",
					      @"c_iscycle", @"c_isopaque",
					      @"c_cycleinfo",
					      @"c_cycleenddate",
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

/* TODO: this method should make use of bareFetchFields instead and only keep
   its "intelligence" part for handling protected infos and recurrent
   events... */
- (NSArray *)    fetchFields: (NSArray *) _fields
                        from: (NSCalendarDate *) _startDate
                          to: (NSCalendarDate *) _endDate 
                       title: (NSString *) title
                   component: (id) _component
           additionalFilters: (NSString *) filters
 includeProtectedInformation: (BOOL) _includeProtectedInformation
{
  EOQualifier *qualifier;
  GCSFolder *folder;
  NSMutableArray *fields, *ma;
  NSArray *records;
  NSMutableArray *baseWhere;
  NSString *where, *dateSqlString, *privacySQLString, *currentLogin;
  NSCalendarDate *endDate;
  NGCalendarDateRange *r;
  BOOL rememberRecords, canCycle;

  rememberRecords = [self _checkIfWeCanRememberRecords: _fields];
  canCycle = [_component isEqualToString: @"vevent"];
//   if (rememberRecords)
//     NSLog (@"we will remember those records!");

  folder = [self ocsFolder];
  if (!folder)
    {
      [self errorWithFormat:@"(%s): missing folder for fetch!",
            __PRETTY_FUNCTION__];
      return nil;
    }

  baseWhere = [NSMutableArray arrayWithCapacity: 32];
  if (_component)
    {
      if ([_component isEqualToString: @"vtodo"] && ![self showCalendarTasks])
        return [NSArray array];
      else
        [baseWhere addObject: [NSString stringWithFormat: @"c_component = '%@'",
                                               _component]];
    }
  else if (![self showCalendarTasks])
      [baseWhere addObject: @"c_component != 'vtodo'"];

  if (_startDate)
    {
      if (_endDate)
        endDate = _endDate;
      else
        endDate = [NSCalendarDate distantFuture];
      r = [NGCalendarDateRange calendarDateRangeWithStartDate: _startDate
                                                      endDate: endDate];
      dateSqlString = [self _sqlStringRangeFrom: _startDate to: endDate
                                          cycle: NO];
    }
  else
    {
      r = nil;
      dateSqlString = nil;
    }

  privacySQLString = [self aclSQLListingFilter];
  if (privacySQLString)
    {
      if ([privacySQLString length])
        [baseWhere addObject: privacySQLString];

      if ([title length])
        [baseWhere
          addObject: [NSString stringWithFormat: @"c_title isCaseInsensitiveLike: '%%%@%%'",
                               [title stringByReplacingString: @"'"  withString: @"\\'\\'"]]];

      if ([filters length])
        [baseWhere addObject: [NSString stringWithFormat: @"(%@)", filters]];

      /* prepare mandatory fields */

      fields = [NSMutableArray arrayWithArray: _fields];
      [fields addObjectUniquely: @"c_name"];
      [fields addObjectUniquely: @"c_uid"];
      [fields addObjectUniquely: @"c_startdate"];
      [fields addObjectUniquely: @"c_enddate"];
      [fields addObjectUniquely: @"c_isallday"];

      if (canCycle)
        {
          if (dateSqlString)
            [baseWhere addObject: dateSqlString];
          [baseWhere addObject: @"c_iscycle = 0"];
        }

      where = [baseWhere componentsJoinedByString: @" AND "];

      /* fetch non-recurrent apts first */
      qualifier = [EOQualifier qualifierWithQualifierFormat: where];
      records = [folder fetchFields: fields matchingQualifier: qualifier];

      if (records)
        {
          if (r)
            records = [self fixupRecords: records];
          ma = [NSMutableArray arrayWithArray: records];
        }
      else
        ma = nil;

      // Fetch recurrent apts now, *excluding* events with no cycle end.
      if (canCycle && _endDate)
        {
          /* we know the last element of "baseWhere" is the c_iscycle
             condition */
          [baseWhere removeLastObject];

          /* replace the date range */
          if (r)
            {
              [baseWhere removeLastObject];
              dateSqlString = [self _sqlStringRangeFrom: _startDate
                                                     to: endDate
                                                  cycle: YES];
              [baseWhere addObject: dateSqlString];
            }
          [baseWhere addObject: @"c_iscycle = 1"];
          where = [baseWhere componentsJoinedByString: @" AND "];
          qualifier = [EOQualifier qualifierWithQualifierFormat: where];
          records = [folder fetchFields: fields matchingQualifier: qualifier];
          if (records)
            {
              if (r)
                records = [self _flattenCycleRecords: records fetchRange: r];
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

      currentLogin = [[context activeUser] login];
      if (![currentLogin isEqualToString: owner]
          && !_includeProtectedInformation)
        [self _fixupProtectedInformation: [ma objectEnumerator]
                                inFields: _fields
                                 forUser: currentLogin];

      if (rememberRecords)
        [self _rememberRecords: ma];
    }
  else
    ma = [NSMutableArray array];

  return ma;
}

#warning we should use the EOFetchSpecification for that!!! (see doPROPFIND:)

#warning components in calendar-data query are ignored

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

- (NSCalendarDate *) _getMaxStartDate
{
  NSCalendarDate *now, *rc;

  if (davCalendarStartTimeLimit > 0 && ![[context activeUser] isSuperUser])
    {
      now = [NSCalendarDate date];
      rc = [now addTimeInterval: -davTimeLimitSeconds];
    }
  else
    rc = nil;

  return rc;
}

- (void) _enforceTimeLimitOnFilter: (NSMutableDictionary *) filter
                     withStartDate: (NSCalendarDate *) startDate
                        andEndDate: (NSCalendarDate *) endDate
{
  NSCalendarDate *now;
  int interval, intervalStart, intervalEnd;

  if (davCalendarStartTimeLimit > 0 && ![[context activeUser] isSuperUser])
    {
      interval = ([endDate timeIntervalSinceDate: startDate] / 86400);
      if (interval > davCalendarStartTimeLimit)
        {
          now = [NSCalendarDate date];
          if ([now compare: startDate] == NSOrderedDescending
              && [now compare: endDate] == NSOrderedAscending)
            {
              intervalStart = [now timeIntervalSinceDate: startDate] / 86400;
              intervalEnd = [endDate timeIntervalSinceDate: now] / 86400;
              if (intervalStart > davCalendarStartTimeLimit / 2)
                {
                  startDate = [now addTimeInterval: -davTimeHalfLimitSeconds];
                  [filter setObject: startDate forKey: @"start"];
                }
              if (intervalEnd > davCalendarStartTimeLimit / 2)
                {
                  endDate = [now addTimeInterval: davTimeHalfLimitSeconds];
                  [filter setObject: endDate forKey: @"end"];
                }
            }
          else if ([now compare: endDate] == NSOrderedDescending)
            {
              startDate = [endDate addTimeInterval: -davTimeLimitSeconds];
              [filter setObject: startDate forKey: @"start"];
            }
          else if ([now compare: startDate] == NSOrderedAscending)
            {
              endDate = [startDate addTimeInterval: davTimeLimitSeconds];
              [filter setObject: endDate forKey: @"end"];
            }
        }
    }
}

- (void) _appendTimeRange: (id <DOMElement>) timeRangeElement
                 toFilter: (NSMutableDictionary *) filter
{
  NSCalendarDate *startDate, *endDate;

  startDate = [[timeRangeElement attribute: @"start"] asCalendarDate];
  if (!startDate)
    startDate = [NSCalendarDate distantPast];
  [filter setObject: startDate forKey: @"start"];

  endDate = [[timeRangeElement attribute: @"end"] asCalendarDate];
  if (!endDate)
    endDate = [NSCalendarDate distantFuture];
  [filter setObject: endDate forKey: @"end"];

  [self _enforceTimeLimitOnFilter: filter
                    withStartDate: startDate andEndDate: endDate];
}

- (void) _addDateRangeLimitToFilter: (NSMutableDictionary *) filter
{
  NSCalendarDate *now;

  now = [NSCalendarDate date];
  [filter setObject: [now addTimeInterval: davTimeHalfLimitSeconds]
             forKey: @"start"];
  [filter setObject: [now addTimeInterval: -davTimeHalfLimitSeconds]
             forKey: @"end"];
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

- (NSDictionary *) _parseCalendarFilter: (DOMElement *) filterElement
{
  NSMutableDictionary *filterData;
  id <DOMElement> parentNode;
  id <DOMNodeList> elements;
  NSString *componentName;
  NSCalendarDate *maxStart;

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

      if (![filterData objectForKey: @"start"])
        {
          maxStart = [self _getMaxStartDate];
          if (maxStart)
            [self _addDateRangeLimitToFilter: filterData];
        }
      [filterData setObject: [NSNumber numberWithBool: NO] forKey: @"iscycle"];
    }
  else
    filterData = nil;

  return filterData;
}

- (NSDictionary *) _makeCyclicFilterFrom: (NSDictionary *) filter
{
  NSMutableDictionary *rc;
  NSNumber *start;

  rc = [NSMutableDictionary dictionaryWithDictionary: filter];
  start = [rc objectForKey: @"start"];
  if (start)
    [rc setObject: start forKey: @"cycleenddate"];
  [rc removeObjectForKey: @"start"];
  [rc removeObjectForKey: @"end"];
  [rc setObject: sharedYes forKey: @"iscycle"];

  return rc;
}

- (NSArray *) _parseCalendarFilters: (DOMElement *) parentNode
{
  id <DOMNodeList> children;
  DOMElement *element;
  NSMutableArray *filters;
  NSDictionary *filter;
  unsigned int count, max;

//   NSLog (@"parseCalendarFilter: %@", [NSDate date]);

  filters = [NSMutableArray array];
  children = [parentNode getElementsByTagName: @"comp-filter"];
  max = [children length];
  for (count = 0; count < max; count++)
    {
      element = [children objectAtIndex: count];
      filter = [self _parseCalendarFilter: element];
      if (filter)
        {
          [filters addObject: filter];
          [filters addObject: [self _makeCyclicFilterFrom: filter]];
        }
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

/* This method enables the mapping between comp-filter attributes and SQL
   fields in the quick table. Probably unused most of the time but should be
   completed one day for full CalDAV compliance. */
- (NSString *) _composeAdditionalFilters: (NSDictionary *) filter
{
  NSString *additionalFilter;
  NSEnumerator *keys;
  NSString *currentKey, *keyField, *filterString;
  static NSArray *fields = nil;
  NSMutableArray *filters;
  NSCalendarDate *cEndDate;
  NSNumber *cycle;

#warning the list of fields should be taken from the .ocs description file
  if (!fields)
    {
      fields = [NSArray arrayWithObject: @"c_uid"];
      [fields retain];
    }

  filters = [NSMutableArray array];
  keys = [[filter allKeys] objectEnumerator];
  while ((currentKey = [keys nextObject]))
    {
      keyField = [NSString stringWithFormat: @"c_%@", currentKey];
      if ([fields containsObject: keyField])
        {
          filterString
            = [self _additionalFilterKey: keyField
                                   value: [filter objectForKey: currentKey]];
          [filters addObject: filterString];
        }
    }

  // Exception for iscycle
  cycle = [filter objectForKey: @"iscycle"];
  if (cycle)
    {
      filterString = [NSString stringWithFormat: @"(c_iscycle = '%d')", 
			       [cycle intValue]];
      [filters addObject: filterString];

      if ([cycle intValue])
        {
          cEndDate = [filter objectForKey: @"cycleenddate"];
          if (cEndDate)
            {
              filterString = [NSString stringWithFormat: 
                                         @"(c_cycleenddate = NULL OR c_cycleenddate >= %d)",
                                       (int) [cEndDate timeIntervalSince1970]];
              [filters addObject: filterString];
            }
        }
    }

  if ([filters count])
    additionalFilter = [filters componentsJoinedByString: @" AND "];
  else
    additionalFilter = nil;

  return additionalFilter;
}

- (NSString *) davCalendarColor
{
  NSString *color;

  color = [[self calendarColor] uppercaseString];

//   return color;
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

  return [NSString stringWithFormat: @"%d", order+1];
}

- (NSException *) setDavCalendarOrder: (NSString *) newColor
{
  /* we fail silently */
  return nil;
}

- (NSString *) davCalendarTimeZone
{
  SOGoUser *ownerUser;
  NSString *ownerTimeZone;
  iCalCalendar *tzCal;
  iCalTimeZone *tz;
  NSString *prodID;

  ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]];
  ownerTimeZone = [[ownerUser userDefaults] timeZoneName];
  tz = [iCalTimeZone timeZoneForName: ownerTimeZone];

  tzCal = [iCalCalendar groupWithTag: @"vcalendar"];
  [tzCal setVersion: @"2.0"];
  prodID = [NSString stringWithFormat:
                       @"-//Inverse inc./SOGo %@//EN", SOGoVersion];
  [tzCal setProdID: prodID];
  [tzCal addChild: tz];

  return [tzCal versitString];
}

- (NSException *) setDavCalendarTimeZone: (NSString *) newTimeZone
{
  /* we fail silently */
  return nil;
}

- (void) _appendComponentProperties: (NSDictionary *) properties
                    matchingFilters: (NSArray *) filters
                         toResponse: (WOResponse *) response
{
  NSArray *apts;
  NSMutableArray *fields;
  NSDictionary *currentFilter;
  NSEnumerator *filterList;
  NSString *additionalFilters, *baseURL, *currentField;
  NSMutableString *buffer;
  NSString **propertiesArray;
  NSEnumerator *addFields;
  unsigned int count, max, propertiesCount;

  fields = [NSMutableArray arrayWithObjects: @"c_name", @"c_component", nil];
  addFields = [[properties allValues] objectEnumerator];
  while ((currentField = [addFields nextObject]))
    if ([currentField length])
      [fields addObjectUniquely: currentField];
  baseURL = [self davURLAsString];

  propertiesArray = [[properties allKeys] asPointersOfObjects];
  propertiesCount = [properties count];

//   NSLog (@"start");
  filterList = [filters objectEnumerator];
  while ((currentFilter = [filterList nextObject]))
    {
      additionalFilters = [self _composeAdditionalFilters: currentFilter];
      /* TODO: we should invoke bareFetchField:... twice and compute the
         recurrent events properly instead of using _makeCyclicFilterFrom: */
      apts = [self bareFetchFields: fields
                              from: [currentFilter objectForKey: @"start"]
                                to: [currentFilter objectForKey: @"end"]
                             title: [currentFilter objectForKey: @"title"]
                         component: [currentFilter objectForKey: @"name"]
                 additionalFilters: additionalFilters];
//       NSLog(@"adding properties");
      max = [apts count];
      buffer = [NSMutableString stringWithCapacity: max * 512];
      for (count = 0; count < max; count++)
        [self appendObject: [apts objectAtIndex: count]
                properties: propertiesArray
                     count: propertiesCount
               withBaseURL: baseURL
                  toBuffer: buffer];
//       NSLog(@"done 1");
      [response appendContentString: buffer];
//       NSLog(@"done 2");
    }
//   NSLog (@"stop");

  NSZoneFree (NULL, propertiesArray);
}

/* This table is meant to match SQL fields to the properties that requires
   them. The fields may NOT be processed directly. This list is not complete
   but is at least sufficient for processing requests from Lightning. */
- (NSDictionary *) davSQLFieldsTable
{
  static NSMutableDictionary *davSQLFieldsTable = nil;

  if (!davSQLFieldsTable)
    {
      davSQLFieldsTable = [[super davSQLFieldsTable] mutableCopy];
      [davSQLFieldsTable setObject: @"c_content"
                            forKey: @"{" XMLNS_CALDAV  @"}calendar-data"];
    }

  return davSQLFieldsTable;
}

- (id) davCalendarQuery: (id) queryContext
{
  WOResponse *r;
  id <DOMDocument> document;
  DOMElement *documentElement, *propElement;

  r = [context response];
  [r prepareDAVResponse];
  [r appendContentString: @"<D:multistatus xmlns:D=\"DAV:\""
                @" xmlns:C=\"urn:ietf:params:xml:ns:caldav\">"];

  document = [[context request] contentAsDOMDocument];
  documentElement = (DOMElement *) [document documentElement];
  propElement = [documentElement firstElementWithTag: @"prop"
                                         inNamespace: XMLNS_WEBDAV];

  [self _appendComponentProperties: [self parseDAVRequestedProperties: propElement]
                   matchingFilters: [self _parseCalendarFilters: documentElement]
                        toResponse: r];
  [r appendContentString:@"</D:multistatus>"];

  return r;
}

- (WOResponse *) davCalendarMultiget: (WOContext *) queryContext
{
  return [self performMultigetInContext: queryContext
                            inNamespace: @"urn:ietf:params:xml:ns:caldav"];
}

- (NSString *) additionalWebdavSyncFilters
{
  NSCalendarDate *startDate;
  NSString *filter;
  NSMutableArray *filters;
  int startDateSecs;

  filters = [NSMutableArray arrayWithCapacity: 8];
  startDate = [self _getMaxStartDate];
  if (startDate)
    {
      startDateSecs = (int) [startDate timeIntervalSince1970];
      filter = [NSString stringWithFormat: @"(c_enddate = NULL"
                         @" OR (c_enddate >= %d AND c_iscycle = 0)"
                         @" OR (c_cycleenddate >= %d AND c_iscycle = 1))",
                         startDateSecs, startDateSecs];
      [filters addObject: filter];
    }

  if (![self showCalendarTasks])
    [filters addObject: @"c_component != 'vtodo'"];

  return [filters componentsJoinedByString: @" AND "];
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

/*
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
*/

- (id) lookupName: (NSString *)_key
        inContext: (id)_ctx
          acquire: (BOOL)_flag
{
  id obj;
  NSString *url;
  BOOL handledLater;
  WORequest *rq;

  /* first check attributes directly bound to the application */
  handledLater = [self requestNamedIsHandledLater: _key];
  if (handledLater)
    obj = nil;
  else
    {
      obj = [super lookupName:_key inContext:_ctx acquire:NO];
      if (!obj)
        {
          rq = [_ctx request];
	  if ([self isValidContentName:_key]
              && [rq handledByDefaultHandler])
            {
	      url = [[rq uri] urlWithoutParameters];
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

- (NSDictionary *) freebusyResponseForRecipient: (iCalPerson *) recipient
				       withUser: (SOGoUser *) user
				andCalendarData: (NSString *) calendarData
{
  NSDictionary *response;
  NSMutableArray *content;

  content = [NSMutableArray array];

  [content addObject: davElementWithContent (@"recipient",
                                             XMLNS_CALDAV, [recipient email])];
  if (user)
    {
      [content addObject: davElementWithContent (@"request-status", XMLNS_CALDAV,
						 @"2.0;Success")];
      [content addObject: davElementWithContent (@"calendar-data", XMLNS_CALDAV,
                                                 [calendarData stringByEscapingXMLString])];
    }
  else
      [content addObject:
		 davElementWithContent (@"request-status", XMLNS_CALDAV,
					@"3.7;Invalid Calendar User")];
  response = davElementWithContent (@"response", XMLNS_CALDAV, content);

  return response;
}

- (NSDictionary *) caldavFreeBusyRequestOnRecipient: (iCalPerson *) recipient
                                            withUID: (NSString *) uid
                                       andOrganizer: (iCalPerson *) organizer
					       from: (NSCalendarDate *) start
						 to: (NSCalendarDate *) to
{
  SOGoUser *user;
  NSString *login, *contactId, *calendarData;
  SOGoFreeBusyObject *freebusy;

  login = [recipient uid];
  if ([login length])
    {
      user = [SOGoUser userWithLogin: login];
      freebusy = [[user homeFolderInContext: context]
		       freeBusyObject: @"freebusy.ifb"
                            inContext: context];
      calendarData = [freebusy contentAsStringWithMethod: @"REPLY"
                                                  andUID: uid
                                            andOrganizer: organizer
                                              andContact: nil
                                                    from: start to: to];
    }
  else if ((contactId = [recipient contactIDInContext: context]))
    {
      user = [context activeUser];
      freebusy = [[user homeFolderInContext: context]
		       freeBusyObject: @"freebusy.ifb"
                            inContext: context];
      calendarData = [freebusy contentAsStringWithMethod: @"REPLY"
                                                  andUID: uid
                                            andOrganizer: organizer
                                              andContact: contactId
                                                    from: start to: to];      
    }
  else
    {
      user = nil;
      calendarData = nil;
    }

  return [self freebusyResponseForRecipient: recipient
                                   withUser: user
                            andCalendarData: calendarData];
}

- (NSDictionary *) caldavFreeBusyRequest: (iCalFreeBusy *) freebusy
{
  NSDictionary *responseElement;
  NSMutableArray *elements;
  NSString *uid;
  iCalPerson *recipient, *organizer;
  NSEnumerator *allRecipients;
  NSCalendarDate *startDate, *endDate;

  elements = [NSMutableArray array];
  [freebusy fillStartDate: &startDate andEndDate: &endDate];
  uid = [freebusy uid];
  organizer = [freebusy organizer];
  allRecipients = [[freebusy attendees] objectEnumerator];
  while ((recipient = [allRecipients nextObject]))
    [elements addObject: [self caldavFreeBusyRequestOnRecipient: recipient 
                                                        withUID: uid
                                                   andOrganizer: organizer
                                                           from: startDate
                                                             to: endDate]];
  responseElement = davElementWithContent (@"schedule-response",
					   XMLNS_CALDAV, elements);

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
      // WARNING
      // don't touch unless you're going to re-test caldav sync 
      // with an iPhone AND lightning
      [response setStatus: 200];
      [response appendContentString: @"<?xml version=\"1.0\""
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
    tags = [self caldavFreeBusyRequest: (iCalFreeBusy *) element];
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
		     componentsSeparatedByString: @","];
      obj = [self caldavScheduleRequest: [request contentAsString]
		  from: originator to: [recipients trimmedComponents]];
    }
  else
    obj = [super davPOSTRequest: request withContentType: cType
		 inContext: localContext];

  return obj;
}

- (NSArray *) groupDavResourceType
{
  return [NSArray arrayWithObjects: @"vevent-collection",
		  @"vtodo-collection", nil];
}

- (NSArray *) davResourceType
{
  NSMutableArray *colType;
  NSArray *gdRT, *gdVEventCol, *gdVTodoCol;
  WORequest *request;

  colType = [NSMutableArray arrayWithCapacity: 10];
  [colType addObject: @"collection"];
  [colType addObject: [NSArray arrayWithObjects: @"calendar", XMLNS_CALDAV, nil]];

  /* iPhone compatibility: we can only return a caldav "calendar"
     resourcetype. Anything else will prevent the iPhone from querying the
     collection. */
  request = [context request];
  if (!([request isIPhone] || [request isICal4]))
    {
      gdRT = [self groupDavResourceType];
      gdVEventCol = [NSArray arrayWithObjects: [gdRT objectAtIndex: 0],
                  XMLNS_GROUPDAV, nil];
      [colType addObject: gdVEventCol];
      if ([self showCalendarTasks])
        {
          gdVTodoCol = [NSArray arrayWithObjects: [gdRT objectAtIndex: 1],
                                XMLNS_GROUPDAV, nil];
          [colType addObject: gdVTodoCol];
        }
      if ([nameInContainer isEqualToString: @"personal"])
        [colType addObject: [NSArray arrayWithObjects: @"schedule-outbox",
                                     XMLNS_CALDAV, nil]];
    }

  return colType;
}

- (SOGoWebDAVValue *) davCalendarComponentSet
{
  NSMutableArray *components;

  if (!componentSet)
    {
      components = [[NSMutableArray alloc] initWithCapacity: 2];
      /* Totally hackish.... we use the "n1" prefix because we know our
         extensions will assign that one to ..:caldav but we really need to
         handle element attributes */
      [components addObject: [SOGoWebDAVValue
                               valueForObject: @"<n1:comp name=\"VEVENT\"/>"
                                   attributes: nil]];
      if ([self showCalendarTasks])
        [components addObject: [SOGoWebDAVValue
                                 valueForObject: @"<n1:comp name=\"VTODO\"/>"
                                     attributes: nil]];
      componentSet
        = [davElementWithContent (@"supported-calendar-component-set",
                                  XMLNS_CALDAV,
                                  components)
                                 asWebDAVValue];
      [componentSet retain];
      [components release];
    }

  return componentSet;
}

- (NSString *) davDescription
{
  return @"";
}

- (NSString *) davResourceId
{
  return [NSString stringWithFormat: @"urn:uuid:%@:calendars:%@",
                   [self ownerInContext: context], [self nameInContainer]];
}

- (NSArray *) davScheduleCalendarTransparency
{
  const NSString *opacity;

  opacity = ([self includeInFreeBusy] ? @"opaque" : @"transparent");

  return [NSArray arrayWithObject: [NSArray arrayWithObjects: opacity,
                                            XMLNS_CALDAV,
                                            nil]];
}

- (NSException *) setDavScheduleCalendarTransparency: (id) newName
{
  NSException *error;

  error = nil;

  if ([newName rangeOfString: @"opaque"].location != NSNotFound)
    [self setIncludeInFreeBusy: YES];
  else if ([newName rangeOfString: @"transparent"].location != NSNotFound)
    [self setIncludeInFreeBusy: NO];
  else
    error = [NSException exceptionWithHTTPStatus: 400
                                          reason: @"Bad transparency value."];

  return error;
}

- (NSString *) davCalendarShowAlarms
{
  NSString *boolean;

  if ([self showCalendarAlarms])
    boolean = @"true";
  else
    boolean = @"false";

  return boolean;
}

- (NSException *) setDavCalendarShowAlarms: (id) newBoolean
{
  NSException *error;

  error = nil;

  if ([newBoolean isEqualToString: @"true"]
      || [newBoolean isEqualToString: @"1"])
    [self setShowCalendarAlarms: YES];
  else if ([newBoolean isEqualToString: @"false"]
           || [newBoolean isEqualToString: @"0"])
    [self setShowCalendarAlarms: NO];
  else
    error = [NSException exceptionWithHTTPStatus: 400
                                          reason: @"Bad boolean value."];

  return error;
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
	  filename = [[records objectAtIndex:0] valueForKey: @"c_name"];
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
		  SOGoRole_ObjectCreator,
		  SOGoRole_ObjectEraser,
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
  NSString *accessRole, *ownerLogin, *prefix, *currentRole, *suffix;
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
      ownerLogin = [self ownerInContext: context];
      if ([ownerLogin isEqualToString: uid])
	accessRole = @"";
      else
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
	}
      [userRoles setObject: accessRole forKey: prefix];
    }

  return accessRole;
}

- (void) initializeQuickTablesAclsInContext: (WOContext *) localContext
{
  NSString *login, *role, *permission;
  iCalAccessClass currentClass;
  unsigned int permStrIndex;

  [super initializeQuickTablesAclsInContext: localContext];
  /* We assume "userIsOwner" will be set after calling the super method. */
  if (!userCanAccessAllObjects)
    {
      login = [[localContext activeUser] login];
      permStrIndex = [@"Component" length];
    }

  for (currentClass = 0; currentClass < iCalAccessClassCount; currentClass++)
    {
      if (userCanAccessAllObjects)
        userCanAccessObjectsClassifiedAs[currentClass] = YES;
      else
        {
          role = [self roleForComponentsWithAccessClass: currentClass
                                                forUser: login];
          if ([role length])
            {
              permission = [role substringFromIndex: permStrIndex];
              userCanAccessObjectsClassifiedAs[currentClass]
                = ([permission isEqualToString: @"Viewer"]
                   || [permission isEqualToString: @"DAndTViewer"]
                   || [permission isEqualToString: @"Modifier"]
                   || [permission isEqualToString: @"Responder"]);
            }
        }
    }
}

- (NSArray *) fetchFreeBusyInfosFrom: (NSCalendarDate *) _startDate
                                  to: (NSCalendarDate *) _endDate
{
  static NSArray *infos = nil; // TODO: move to a plist file
  
  if (!infos)
    infos = [[NSArray alloc] initWithObjects: @"c_content", @"c_partmails", @"c_partstates",
                             @"c_isopaque", @"c_status", @"c_cycleinfo", @"c_orgmail", nil];

  // We MUST include the protected information when checking for freebusy info as
  // we rely on the c_partmails/c_partstates fields for many operations.
  return [self fetchFields: infos
	       from: _startDate to: _endDate
	       title: nil
               component: @"vevent"
	       additionalFilters: nil
	       includeProtectedInformation: YES];
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
			     @"c_category", @"c_classification", @"c_isallday",
			     @"c_isopaque", @"c_participants", @"c_partmails",
			     @"c_partstates", @"c_sequence", @"c_priority",
			     @"c_cycleinfo", @"c_iscycle",  @"c_nextalarm", nil];

  return [self fetchFields: infos from: _startDate to: _endDate title: title
               component: _component
	       additionalFilters: filters
	       includeProtectedInformation: NO];
}

- (NSArray *) fetchAlarmInfosFrom: (NSNumber *) _startUTCDate
			       to: (NSNumber *) _endUTCDate
{
  static NSArray *nameFields = nil;
  EOQualifier *qualifier;
  GCSFolder *folder;
  NSArray *records;
  NSString *sql;

  if (!nameFields)
    nameFields = [[NSArray alloc] initWithObjects: @"c_name", @"c_nextalarm", @"c_iscycle", nil];
  
  folder = [self ocsFolder];
  if (!folder)
    {
      [self errorWithFormat:@"(%s): missing folder for fetch!",
            __PRETTY_FUNCTION__];
      return nil;
    }

  sql =  [NSString stringWithFormat: @"((c_nextalarm <= %u) AND (c_nextalarm >= %u)) OR ((c_nextalarm > 0) AND (c_enddate > %u))",
		   [_endUTCDate unsignedIntValue], [_startUTCDate unsignedIntValue], [_startUTCDate unsignedIntValue]];
  qualifier = [EOQualifier qualifierWithQualifierFormat: sql];
  records = [folder fetchFields: nameFields matchingQualifier: qualifier];
  
  return records;
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
  SOGoUserSettings *userSettings;
  NSMutableDictionary *calendarSettings;
  SOGoUser *ownerUser;

  rc = [super create];
  if (rc)
    {
      ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]];
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

- (void) removeFolderSettings: (NSMutableDictionary *) moduleSettings
                withReference: (NSString *) reference
{
  NSMutableArray *refArray;
  NSMutableDictionary *refDict;

  refDict = [moduleSettings objectForKey: @"FreeBusyExclusions"];
  [refDict removeObjectForKey: reference];

  refDict = [moduleSettings objectForKey: @"FolderColors"];
  [refDict removeObjectForKey: reference];

  refDict = [moduleSettings objectForKey: @"FolderShowAlarms"];
  [refDict removeObjectForKey: reference];

  refDict = [moduleSettings objectForKey: @"FolderShowTasks"];
  [refDict removeObjectForKey: reference];

  refArray = [moduleSettings objectForKey: @"InactiveFolders"];
  [refArray removeObject: nameInContainer];
            
  refDict = [moduleSettings objectForKey: @"FolderSyncTags"];
  [refDict removeObjectForKey: reference];

  refDict = [moduleSettings objectForKey: @"FolderSynchronize"];
  [refDict removeObjectForKey: reference];

  [super removeFolderSettings: moduleSettings
                withReference: reference];
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

//
// This method returns an array containing all the calendar folders
// of a specific user, excluding her/his subscriptions.
//
- (NSArray *) lookupCalendarFoldersForUID: (NSString *) theUID
{
  NSArray *aFolders;
  SOGoUser *theUser;
  NSEnumerator *e;
  NSMutableArray *aUserFolders;
  SOGoAppointmentFolders *aParent;
  SOGoFolder *aFolder;

  aUserFolders = [NSMutableArray arrayWithCapacity: 16];

  theUser = [SOGoUser userWithLogin: theUID];
  aParent = [theUser calendarsFolderInContext: context];
  
  aFolders = [aParent subFolders];
  e = [aFolders objectEnumerator];
  while ((aFolder = [e nextObject]))
    {
      if (![aFolder isSubscription])
	[aUserFolders addObject: aFolder];
    }

  return aUserFolders;
}

- (NSArray *) lookupCalendarFoldersForUIDs: (NSArray *) _uids
                                 inContext: (id)_ctx
{
  /* Note: can return NSNull objects in the array! */
  NSMutableArray *folders;
  NSEnumerator *e;
  NSString *uid, *ownerLogin;
  SOGoUser *user;
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
          user = [SOGoUser userWithLogin: uid];
	  folder = [user personalCalendarFolderInContext: context];
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
  SOGoUserManager *um;
  unsigned          i, count;
  iCalPerson *person;
  NSString   *email;
  NSString   *uid;
  
  if (_persons)
    {
      count = [_persons count];
      uids  = [NSMutableArray arrayWithCapacity:count + 1];
      um    = [SOGoUserManager sharedUserManager];
  
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

/* folder type */

- (NSString *) folderType
{
  return @"Appointment";
}

- (BOOL) isActive
{
  SOGoUserSettings *settings;
  NSArray *inactiveFolders;

  settings = [[context activeUser] userSettings];
  inactiveFolders
    = [[settings objectForKey: @"Calendar"] objectForKey: @"InactiveFolders"];

  return (![inactiveFolders containsObject: nameInContainer]);
}

- (NSString *) importComponent: (iCalEntityObject *) event
                      timezone: (iCalTimeZone *) timezone
{
  SOGoAppointmentObject *object;
  NSString *uid;
  NSMutableString *content;

  uid =  [self globallyUniqueObjectId];
  [event setUid: uid];
  object = [SOGoAppointmentObject objectWithName: uid
                                    inContainer: self];
  [object setIsNew: YES];
  content = [NSMutableString stringWithString: @"BEGIN:VCALENDAR\n"];
  if (timezone)
    [content appendFormat: @"%@\n",  [timezone versitString]];
  [content appendFormat: @"%@\nEND:VCALENDAR", [event versitString]];
  
  return ([object saveContentString: content] == nil) ? uid : nil;
}

/**
 * Import all components of a vCalendar.
 * @param calendar the calendar to import
 * @return the number of components imported
 */
- (int) importCalendar: (iCalCalendar *) calendar
{
  NSArray *vtimezones;
  NSMutableArray *components;
  NSMutableDictionary *timezones, *uids;
  NSString *tzId, *uid, *originalUid, *content;
  iCalEntityObject *element;
  iCalDateTime *startDate;
  iCalTimeZone *timezone;
  iCalCalendar *masterCalendar;
  iCalEvent *event;

  int imported, count, i;
  
  imported = 0;

  if (calendar)
    {
      // Build a hash with the timezones includes in the calendar
      vtimezones = [calendar timezones];
      count = [vtimezones count];
      timezones = [NSMutableDictionary dictionaryWithCapacity: count];
      for (i = 0; i < count; i++)
        {
          timezone = (iCalTimeZone *)[vtimezones objectAtIndex: i];
          [timezones setValue: timezone
                       forKey: [timezone tzId]];
        }

      // Parse events/todos/journals and import them
      uids = [NSMutableDictionary dictionary];
      components = [[calendar events] mutableCopy];
      [components autorelease];
      [components addObjectsFromArray: [calendar todos]];
      // [components addObjectsFromArray: [calendar journals]];
      // [components addObjectsFromArray: [calendar freeBusys]];
      count = [components count];
      for (i = 0; i < count; i++)
        {
          timezone = nil;
          element = [components objectAtIndex: i];
          // Use the timezone of the start date.
          startDate = (iCalDateTime *) [element uniqueChildWithTag: @"dtstart"];
          if (startDate)
            {
              tzId = [startDate value: 0 ofAttribute: @"tzid"];
              if ([tzId length])
                timezone = [timezones valueForKey: tzId];
              if ([element isKindOfClass: [iCalEvent class]])
                {
                  event = (iCalEvent *)element;
                  if (![event hasEndDate] && ![event hasDuration])
                    {
                      // No end date, no duration
                      if ([event isAllDay])
                        [event setDuration: @"P1D"];
                      else
                        [event setDuration: @"PT1H"];
                      
                      [self errorWithFormat: @"Importing event with no end date; setting duration to %@ for UID = %@", [event duration], [event uid]];
                    }
		  //
		  // We check for broken all-day events (like the ones coming from the "WebCalendar" tool) where
		  // the start date is equal to the end date. This clearly violates the RFC:
		  //
		  // 3.8.2.2. Date-Time End
		  // The value MUST be later in time than the value of the "DTSTART" property. 
		  //
		  if ([event isAllDay] && [[event startDate] isEqual: [event endDate]])
		    {
		      [event setEndDate: [[event startDate] dateByAddingYears: 0  months: 0  days: 1  hours: 0  minutes: 0  seconds: 0]];
		      [self errorWithFormat: @"Fixed broken all-day event; setting end date to %@ for UID = %@", [event endDate], [event uid]];
		    }
                  if ([event recurrenceId])
                    {
                      // Event is an occurrence of a repeating event
                      if ((uid = [uids valueForKey: [event uid]]))
                        {
                          SOGoAppointmentObject *master = [self lookupName: uid
                                                                 inContext: context
                                                                   acquire: NO];
                          if (master)
                            {
                              // Associate the occurrence to the master event
                              masterCalendar = [master calendar: NO secure: NO];
                              [masterCalendar addToEvents: event];
                              if (timezone)
                                [masterCalendar addTimeZone: timezone];
                              content = [masterCalendar versitString];
                              [master saveContentString: content];
                              continue;
                            }
                        }
                    }
                }
            }
          originalUid = [element uid];
          if ((uid = [self importComponent: element
                                  timezone: timezone]))
            {
              imported++;
              [uids setValue: uid
                      forKey: originalUid];
            }
        }
    }
  
  return imported;
}

/* acls */
- (NSArray *) aclsForUser: (NSString *) uid
          forObjectAtPath: (NSArray *) objectPathArray
{
  NSMutableArray *aclsForUser;
  NSArray *superAcls;

  superAcls = [super aclsForUser: uid forObjectAtPath: objectPathArray];
  if ([uid isEqualToString: [self defaultUserID]])
    {
      if (superAcls)
        {
          aclsForUser = [superAcls mutableCopy];
          [aclsForUser autorelease];
        }
      else
        aclsForUser = [NSMutableArray array];
      [aclsForUser addObject: SoRole_Authenticated];
    }
  else
    aclsForUser = (NSMutableArray *) superAcls;

  return aclsForUser;
}

/* caldav-proxy */
- (SOGoAppointmentProxyPermission)
     proxyPermissionForUserWithLogin: (NSString *) login
{
  SOGoAppointmentProxyPermission permission;
  NSArray *roles;
  static NSArray *readRoles = nil;
  static NSArray *writeRoles = nil;

  if (!readRoles)
    {
      readRoles = [NSArray arrayWithObjects:
                             SOGoCalendarRole_ConfidentialViewer,
                           SOGoCalendarRole_ConfidentialDAndTViewer,
                           SOGoCalendarRole_PrivateViewer,
                           SOGoCalendarRole_PrivateDAndTViewer,
                           SOGoCalendarRole_PublicViewer,
                           SOGoCalendarRole_PublicDAndTViewer,
                           nil];
      [readRoles retain];
    }
  if (!writeRoles)
    {
      writeRoles = [NSArray arrayWithObjects:
                              SOGoRole_ObjectCreator,
                            SOGoRole_ObjectEraser,
                            SOGoCalendarRole_ConfidentialModifier,
                            SOGoCalendarRole_ConfidentialResponder,
                            SOGoCalendarRole_PrivateModifier,
                            SOGoCalendarRole_PrivateResponder,
                            SOGoCalendarRole_PublicModifier,
                            SOGoCalendarRole_PublicResponder,
                            nil];
      [writeRoles retain];
    }

  permission = SOGoAppointmentProxyPermissionNone;
  roles = [self aclsForUser: login];
  if ([roles count])
    {
      if ([roles firstObjectCommonWithArray: readRoles])
        permission = SOGoAppointmentProxyPermissionRead;
      if ([roles firstObjectCommonWithArray: writeRoles])
        permission = SOGoAppointmentProxyPermissionWrite;
    }

  return permission;
}

- (NSArray *) aclUsersWithProxyWriteAccess: (BOOL) write
{
  NSMutableArray *users;
  NSArray *aclUsers;
  NSString *aclUser;
  SOGoAppointmentProxyPermission permission;
  int count, max;

  permission = (write
                ? SOGoAppointmentProxyPermissionWrite
                : SOGoAppointmentProxyPermissionRead);
  aclUsers = [self aclUsers];
  max = [aclUsers count];
  users = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      aclUser = [aclUsers objectAtIndex: count];
      if ([self proxyPermissionForUserWithLogin: aclUser]
          == permission)
        [users addObject: aclUser];
    }

  return users;
}

@end /* SOGoAppointmentFolder */
