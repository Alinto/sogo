/*
  Copyright (C) 2004-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess
  Copyright (c) 2008 Inverse inc.

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

#import "GCSFieldInfo.h"
#import "GCSFolder.h"
#import "GCSFolderManager.h"
#import "GCSFolderType.h"
#import "GCSChannelManager.h"
#import "GCSFieldExtractor.h"
#import "NSURL+GCS.h"
#import "EOAdaptorChannel+GCS.h"
#import "EOQualifier+GCS.h"
#import "GCSStringFormatter.h"
#import "common.h"

#import <GDLAccess/EOEntity.h>
#import <GDLAccess/EOAttribute.h>
#import <GDLAccess/EOSQLQualifier.h>
#import <GDLAccess/EOAdaptorContext.h>

typedef enum {
  noTableRequired = 0,
  quickTableRequired = 1,
  contentTableRequired = 2,
  bothTableRequired = 3
} GCSTableRequirement;

#define CHECKERROR() \
 if (error) { \
   [[storeChannel adaptorContext] rollbackTransaction]; \
   [[quickChannel adaptorContext] rollbackTransaction]; \
   [self logWithFormat:@"ERROR(%s): cannot %s content : %@", \
	 __PRETTY_FUNCTION__, isNewRecord ? "insert" : "update", error]; \
   return error; \
 } \

@implementation GCSFolder

static BOOL debugOn    = NO;
static BOOL doLogStore = NO;

static Class NSStringClass       = Nil;
static Class NSNumberClass       = Nil;
static Class NSCalendarDateClass = Nil;

static GCSStringFormatter *stringFormatter = nil;
static NSArray *contentFieldNames = nil;

+ (void) initialize
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn         = [ud boolForKey:@"GCSFolderDebugEnabled"];
  doLogStore      = [ud boolForKey:@"GCSFolderStoreDebugEnabled"];

  NSStringClass       = [NSString class];
  NSNumberClass       = [NSNumber class];
  NSCalendarDateClass = [NSCalendarDate class];
  if (!contentFieldNames)
    {
      contentFieldNames = [NSArray arrayWithObjects: @"c_content",
				    @"c_creationdate", @"c_lastmodified",
				    @"c_version", @"c_deleted", nil];
      [contentFieldNames retain];
    }

  stringFormatter = [GCSStringFormatter sharedFormatter];
}

- (id) initWithPath: (NSString *)_path
	 primaryKey: (id)_folderId
     folderTypeName: (NSString *)_ftname
	 folderType: (GCSFolderType *)_ftype
	   location: (NSURL *)_loc
      quickLocation: (NSURL *)_qloc
	aclLocation: (NSURL *)_aloc
      folderManager: (GCSFolderManager *)_fm
{
  NSEnumerator *fields;
  GCSFieldInfo *field;
  NSString *fieldName;

  if (![_loc isNotNull])
    {
      [self errorWithFormat:@"missing quicktable parameter!"];
      [self release];
      return nil;
    }
  
  if ((self = [super init])) {
    folderManager  = [_fm    retain];
    folderInfo     = [_ftype retain];
    fields = [[_ftype fields] objectEnumerator];
    quickFieldNames = [NSMutableArray new];
    while ((field = [fields nextObject]))
      {
	fieldName = [field columnName];
	if (![fieldName isEqualToString: @"c_name"])
	  [quickFieldNames addObject: fieldName];
      }
    
    folderId       = [_folderId copy];
    folderName     = [[_path lastPathComponent] copy];
    path           = [_path   copy];
    location       = [_loc    retain];
    quickLocation  = _qloc ? [_qloc   retain] : [_loc retain];
    aclLocation    = [_aloc   retain];
    folderTypeName = [_ftname copy];

    ofFlags.requiresFolderSelect = 0;
    ofFlags.sameTableForQuick = 
      [location isEqualTo:quickLocation] ? 1 : 0;
  }
  return self;
}

- (id) init
{
  return [self initWithPath:nil primaryKey:nil
	       folderTypeName:nil folderType:nil 
	       location:nil quickLocation:nil
               aclLocation:nil
	       folderManager:nil];
}

- (id)initWithPath:(NSString *)_path primaryKey:(id)_folderId
  folderTypeName:(NSString *)_ftname folderType:(GCSFolderType *)_ftype
  location:(NSURL *)_loc quickLocation:(NSURL *)_qloc
  folderManager:(GCSFolderManager *)_fm
{
  return [self initWithPath:_path primaryKey:_folderId folderTypeName:_ftname
	       folderType:_ftype location:_loc quickLocation:_qloc
	       aclLocation:nil
	       folderManager:_fm];
}

- (void) dealloc
{
  [folderManager  release];
  [folderInfo     release];
  [folderId       release];
  [folderName     release];
  [path           release];
  [location       release];
  [quickLocation  release];
  [quickFieldNames release];
  [aclLocation    release];
  [folderTypeName release];
  [super dealloc];
}

/* accessors */

- (NSNumber *)folderId {
  return folderId;
}

- (NSString *)folderName {
  return folderName;
}
- (NSString *)path {
  return path;
}

- (NSURL *)location {
  return location;
}
- (NSURL *)quickLocation {
  return quickLocation;
}
- (NSURL *)aclLocation {
  return aclLocation;
}

- (NSString *)folderTypeName {
  return folderTypeName;
}

- (GCSFolderManager *)folderManager {
  return folderManager;
}
- (GCSChannelManager *)channelManager {
  return [[self folderManager] channelManager];
}

- (NSString *)storeTableName {
  return [[self location] gcsTableName];
}
- (NSString *)quickTableName {
  return [[self quickLocation] gcsTableName];
}
- (NSString *)aclTableName {
  return [[self aclLocation] gcsTableName];
}

- (BOOL)isQuickInfoStoredInContentTable {
  return ofFlags.sameTableForQuick ? YES : NO;
}

/* channels */

- (EOAdaptorChannel *)acquireStoreChannel {
  return [[self channelManager] acquireOpenChannelForURL:[self location]];
}
- (EOAdaptorChannel *)acquireQuickChannel {
  return [[self channelManager] acquireOpenChannelForURL:[self quickLocation]];
}
- (EOAdaptorChannel *)acquireAclChannel {
  return [[self channelManager] acquireOpenChannelForURL:[self aclLocation]];
}

- (void)releaseChannel:(EOAdaptorChannel *)_channel {
  [[self channelManager] releaseChannel:_channel];
  if (debugOn) [self debugWithFormat:@"released channel: %@", _channel];
}

- (BOOL)canConnectStore {
  return [[self channelManager] canConnect:[self location]];
}
- (BOOL)canConnectQuick {
  return [[self channelManager] canConnect:[self quickLocation]];
}
- (BOOL)canConnectAcl {
  return [[self channelManager] canConnect:[self quickLocation]];
}

/* errors */

- (NSException *)errorVersionMismatchBetweenStoredVersion:(unsigned int)_store
  andExpectedVersion:(unsigned int)_base
{
  NSDictionary *ui;

  ui = [NSDictionary dictionaryWithObjectsAndKeys:
		       [NSNumber numberWithUnsignedInt:_base],  
		       @"GCSExpectedVersion",
		       [NSNumber numberWithUnsignedInt:_store],
		       @"GCSStoredVersion",
  		       self, @"GCSFolder",
		       nil];
  
  return [NSException exceptionWithName:@"GCSVersionMismatch"
		      reason:@"Transaction conflict during a GCS modification."
		      userInfo:ui];
}

- (NSException *)errorExtractorReturnedNoQuickRow:(id)_extractor
  forContent:(NSString *)_content
{
  NSDictionary *ui;

  ui = [NSDictionary dictionaryWithObjectsAndKeys:
  		       self,       @"GCSFolder",
		       _extractor, @"GCSExtractor",
		       _content,   @"GCSContent",
		       nil];
  return [NSException exceptionWithName:@"GCSExtractFailed"
		      reason:@"Quickfield extractor did not return a result!"
		      userInfo:ui];
}

/* operations */

- (NSArray *)subFolderNames {
  return [[self folderManager] listSubFoldersAtPath:[self path]
			       recursive:NO];
}
- (NSArray *)allSubFolderNames {
  return [[self folderManager] listSubFoldersAtPath:[self path]
			       recursive:YES];
}

- (GCSTableRequirement) _tableRequirementForFields: (NSArray *) fields
				    andOrQualifier: (EOQualifier *) qualifier
{
  GCSTableRequirement requirement;
  NSMutableArray *allFields;
  NSArray *quFields;
  unsigned int fieldCount;

  requirement = noTableRequired;
  allFields = [NSMutableArray new];
  if ([fields count])
    [allFields addObjectsFromArray: fields];
  quFields = [[qualifier allQualifierKeys] allObjects];
  if ([quFields count])
    [allFields addObjectsFromArray: quFields];

  fieldCount = [allFields count];
  if (fieldCount)
    {
      if ([allFields firstObjectCommonWithArray: quickFieldNames])
	requirement |= quickTableRequired;
      if ([allFields firstObjectCommonWithArray: contentFieldNames])
	requirement |= contentTableRequired;
      if (requirement == noTableRequired
	  && [allFields containsObject: @"c_name"])
	requirement |= quickTableRequired;
    }
  else
    {
      [allFields release];
      [NSException raise: @"GCSFolderMissingFieldNames"
		   format: @"No field specified for query"];
    }

  [allFields release];

  return requirement;
}

- (NSString *) _dottedFields: (NSArray *) fields
{
  NSMutableString *dottedFields;
  NSEnumerator *fieldsEnum;
  NSString *currentField, *prefix;

  dottedFields = [NSMutableString string];
  fieldsEnum = [fields objectEnumerator];
  while ((currentField = [fieldsEnum nextObject]))
    {
      if ([quickFieldNames containsObject: currentField])
	prefix = @"a";
      else
	prefix = @"b";
      [dottedFields appendFormat: @"%@.%@,", prefix, currentField];
    }
  [dottedFields deleteCharactersInRange: NSMakeRange ([dottedFields length] -
						      1, 1)];

  return dottedFields;
}

- (NSString *) _selectedFields: (NSArray *) fields
		   requirement: (GCSTableRequirement) requirement
{
  NSMutableString *selectedFields;

  selectedFields = [NSMutableString string];
  
  if (requirement == bothTableRequired
      && [fields containsObject: @"c_name"])
    [selectedFields appendString: [self _dottedFields: fields]];
  else
    [selectedFields appendString: [fields componentsJoinedByString: @", "]];

  return selectedFields;
}

- (NSString *) _sqlForQualifier: (EOQualifier *) qualifier
{
  NSMutableString *ms;
  
  if (qualifier)
    {
      ms = [NSMutableString stringWithCapacity:32];
      [qualifier _gcsAppendToString: ms];
    }
  else
    ms = nil;

  return ms;
}

- (NSString *)_sqlForSortOrderings:(NSArray *)_so {
  NSMutableString *sql;
  unsigned i, count;

  if ((count = [_so count]) == 0)
    return nil;
  
  sql = [NSMutableString stringWithCapacity:(count * 16)];
  for (i = 0; i < count; i++) {
    EOSortOrdering *so;
    NSString *column;
    SEL      sel;

    so     = [_so objectAtIndex:i];
    sel    = [so selector];
    column = [so key];
    
    if (i > 0) [sql appendString:@", "];
    
    if (sel_eq(sel, EOCompareAscending)) {
      [sql appendString:column];
      [sql appendString:@" ASC"];
    }
    else if (sel_eq(sel, EOCompareDescending)) {
      [sql appendString:column];
      [sql appendString:@" DESC"];
    }
    else if (sel_eq(sel, EOCompareCaseInsensitiveAscending)) {
      [sql appendString:@"UPPER("];
      [sql appendString:column];
      [sql appendString:@") ASC"];
    }
    else if (sel_eq(sel, EOCompareCaseInsensitiveDescending)) {
      [sql appendString:@"UPPER("];
      [sql appendString:column];
      [sql appendString:@") DESC"];
    }
    else {
      [self logWithFormat:@"cannot handle sort selector in store: %@",
	      NSStringFromSelector(sel)];
    }
  }
  return sql;
}

- (NSString *) _queryForFields: (NSArray *) fields
                          spec: (EOFetchSpecification *) spec
		 ignoreDeleted: (BOOL) ignoreDeleted
{
  EOQualifier      *qualifier;
  NSArray          *sortOrderings;
  NSMutableString  *sql;
  NSMutableArray   *whereSql;
  GCSTableRequirement requirement;
  NSString *whereString;

//   NSLog(@"queryForFields...");
  qualifier = [spec qualifier];
  requirement = [self _tableRequirementForFields: fields
		      andOrQualifier: qualifier];
  sql = [NSMutableString stringWithCapacity: 256];
  [sql appendString: @"SELECT "];
  if (fields)
    [sql appendString: [self _selectedFields: fields requirement: requirement]];
  else
    [sql appendString: @"*"];
  [sql appendString:@" FROM "];
  if (requirement == bothTableRequired)
    [sql appendFormat: @"%@ a, %@ b",
	 [self quickTableName], [self storeTableName]];
  else
    {
      if ((requirement & quickTableRequired))
	[sql appendString: [self quickTableName]];
      else if ((requirement & contentTableRequired))
	[sql appendString: [self storeTableName]];
    }

  whereSql = [NSMutableArray new];
  if (qualifier)
    {
      whereString = [NSString stringWithFormat: @"(%@)",
			      [self _sqlForQualifier: qualifier]];
      #warning this may be dangerous...
      if (requirement == bothTableRequired)
	[whereSql addObject: [whereString stringByReplacingString: @"c_name"
					  withString: @"a.c_name"]];
      else
	[whereSql addObject: whereString];
    }
  if (requirement == bothTableRequired)
    [whereSql addObject: @"a.c_name = b.c_name"];
  if ((requirement & contentTableRequired)
      && ignoreDeleted)
    [whereSql addObject: @"(c_deleted != 1 OR c_deleted IS NULL)"];
  if ([whereSql count])
    [sql appendFormat: @" WHERE %@",
	 [whereSql componentsJoinedByString: @" AND "]];
  [whereSql release];

  sortOrderings = [spec sortOrderings];
  if ([sortOrderings count] > 0)
    {
      [sql appendString:@" ORDER BY "];
      [sql appendString:[self _sqlForSortOrderings:sortOrderings]];
    }

#if 0
  /* limit */
  [sql appendString:@" LIMIT "]; // count
  [sql appendString:@" OFFSET "]; // index from 0
#endif

//   NSLog(@"/queryForFields...");

//   NSLog (@"query:\n/%@/", sql);

  return sql;
}

- (NSArray *) fetchFields: (NSArray *) fields
       fetchSpecification: (EOFetchSpecification *) spec
	    ignoreDeleted: (BOOL) ignoreDeleted
{
  EOAdaptorChannel *channel;
  NSException      *error;
  NSString  *sql;
  NSArray          *attrs;
  NSMutableArray   *results;
  NSDictionary     *row;

  sql = [self _queryForFields: fields spec: spec ignoreDeleted: ignoreDeleted];
  channel = [self acquireStoreChannel];
  if (channel)
    {
      /* run SQL */
//       NSLog(@"running query...");

      error = [channel evaluateExpressionX:sql];
      if (error)
	{
	  [self errorWithFormat:@"%s: cannot execute quick-fetch SQL '%@': %@", 
		__PRETTY_FUNCTION__, sql, error];
	  [self releaseChannel: channel];
	  results = nil;
	}
      else
	{
	  /* fetch results */
  
	  results = [NSMutableArray arrayWithCapacity: 64];
	  attrs = [channel describeResults: NO /* do not beautify names */];
	  while ((row = [channel fetchAttributes: attrs withZone: NULL]))
	    [results addObject: row];

	  /* release channels */
  
	  [self releaseChannel: channel];
	}
//         NSLog(@"/running query");
    }
  else
    {
      [self errorWithFormat:@" could not open storage channel!"];
      results = nil;
    }
  
  return results;
}

- (EOFetchSpecification *) _simpleFetchSpecificationWith: (NSString *) field
						andValue: (NSString *) value
{
  EOQualifier *qualifier;

  qualifier
    = [EOQualifier qualifierWithQualifierFormat:
                     [NSString stringWithFormat: @"%@='%@'", field, value]];

  return [EOFetchSpecification
	   fetchSpecificationWithEntityName: [self folderName]
	   qualifier: qualifier
	   sortOrderings: nil];
}

- (NSDictionary *) recordOfEntryWithName: (NSString *) name
{
  NSDictionary *row;
  NSMutableDictionary *record;
  NSArray *rows, *columns;
  NSString *strValue;
  int intValue;

  columns = [NSArray arrayWithObjects: @"c_content", @"c_version",
		     @"c_creationdate", @"c_lastmodified", nil];
  rows
    = [self fetchFields: columns
	    fetchSpecification: [self _simpleFetchSpecificationWith: @"c_name"
				      andValue: name]
	    ignoreDeleted: YES];
  if ([rows count])
    {
      row = [rows objectAtIndex: 0];
      record = [NSMutableDictionary dictionaryWithCapacity: 5];
      strValue = [row objectForKey: @"c_content"];
      if (![strValue isNotNull])
	strValue = @"";
      [record setObject: strValue forKey: @"c_content"];
      [record setObject: [row objectForKey: @"c_version"]
	      forKey: @"c_version"];
      intValue = [[row objectForKey: @"c_creationdate"] intValue];
      [record
	setObject: [NSCalendarDate dateWithTimeIntervalSince1970: intValue]
	forKey: @"c_creationdate"];
      intValue = [[row objectForKey: @"c_lastmodified"] intValue];
      [record
	setObject: [NSCalendarDate dateWithTimeIntervalSince1970: intValue]
	forKey: @"c_lastmodified"];
    }
  else
    record = nil;

  return record;
}

/* writing content */

- (NSString *)_formatRowValue:(id)_value {

  if (![_value isNotNull])
    return @"NULL";

  if ([_value isKindOfClass:NSStringClass])
    return [stringFormatter stringByFormattingString:_value];

  if ([_value isKindOfClass:NSNumberClass]) {
#if GNUSTEP_BASE_LIBRARY
    _value = [_value stringValue];
    return ([(NSString *)_value hasPrefix:@"Y"] || 
	    [(NSString *)_value hasPrefix:@"N"])
      ? (id)([_value boolValue] ? @"1" : @"0")
      : _value;
#endif
    return [_value stringValue];
  }
  
  if ([_value isKindOfClass:NSCalendarDateClass]) {
    /* be smart ... convert to timestamp. Note: we loose precision. */
    char buf[256];
    snprintf(buf, sizeof(buf), "%i", (int)[_value timeIntervalSince1970]);
    return [NSString stringWithCString:buf];
  }
  
  [self errorWithFormat:@"cannot handle value class: %@", [_value class]];
  return nil;
}

- (NSString *)_generateInsertStatementForRow:(NSDictionary *)_row
  tableName:(NSString *)_table
{
  // TODO: move to NSDictionary category?
  NSMutableString *sql;
  NSArray  *keys;
  unsigned i, count;

  if (_row == nil || _table == nil)
    return nil;

  keys = [_row allKeys];

  sql = [NSMutableString stringWithCapacity:512];
  [sql appendString:@"INSERT INTO "];
  [sql appendString:_table];
  [sql appendString:@" ("];

  for (i = 0, count = [keys count]; i < count; i++) {
    if (i != 0) [sql appendString:@", "];
    [sql appendString:[keys objectAtIndex:i]];
  }

  [sql appendString:@") VALUES ("];

  for (i = 0, count = [keys count]; i < count; i++) {
    id value;

    if (i != 0) [sql appendString:@", "];
    value = [_row objectForKey:[keys objectAtIndex:i]];
    value = [self _formatRowValue:value];
    [sql appendString:value];
  }

  [sql appendString:@")"];
  return sql;
}

- (NSString *)_generateUpdateStatementForRow:(NSDictionary *)_row
  tableName:(NSString *)_table
  whereColumn:(NSString *)_colname isEqualTo:(id)_value
  andColumn:(NSString *)_colname2  isEqualTo:(id)_value2
{
  // TODO: move to NSDictionary category?
  NSMutableString *sql;
  NSArray  *keys;
  unsigned i, count;

  if (_row == nil || _table == nil)
    return nil;

  keys = [_row allKeys];

  sql = [NSMutableString stringWithCapacity:512];
  [sql appendString:@"UPDATE "];
  [sql appendString:_table];

  [sql appendString:@" SET "];
  for (i = 0, count = [keys count]; i < count; i++) {
    id value;

    value = [_row objectForKey:[keys objectAtIndex:i]];
    value = [self _formatRowValue:value];

    if (i != 0) [sql appendString:@", "];
    [sql appendString:[keys objectAtIndex:i]];
    [sql appendString:@" = "];
    [sql appendString:value];
  }

  [sql appendString:@" WHERE "];
  [sql appendString:_colname];
  [sql appendString:@" = "];
  [sql appendString:[self _formatRowValue:_value]];

  if (_colname2 != nil) {
    [sql appendString:@" AND "];
    [sql appendString:_colname2];
    [sql appendString:@" = "];
    [sql appendString:[self _formatRowValue:_value2]];
  }

  return sql;
}

- (EOEntity *) _entityWithName: (NSString *) _name
{
  EOAttribute *attribute;
  EOEntity *entity;
  
  entity = AUTORELEASE([[EOEntity alloc] init]);
  [entity setName: _name];
  [entity setExternalName: _name];

  attribute = AUTORELEASE([[EOAttribute alloc] init]);
  [attribute setName: @"c_name"];
  [attribute setColumnName: @"c_name"];
  [entity addAttribute: attribute];

  return entity;
}

- (EOEntity *) _storeTableEntity
{
  EOAttribute *attribute;
  EOEntity *entity;

  entity = [self _entityWithName: [self storeTableName]];  

  attribute = AUTORELEASE([[EOAttribute alloc] init]);
  [attribute setName: @"c_version"];
  [attribute setColumnName: @"c_version"];
  [entity addAttribute: attribute];

  return entity;
}

- (EOEntity *) _quickTableEntity
{
  return [self _entityWithName: [self quickTableName]];
}

- (EOSQLQualifier *) _qualifierUsingWhereColumn:(NSString *)_colname
				      isEqualTo:(id)_value
				      andColumn:(NSString *)_colname2 
				      isEqualTo:(id)_value2
					 entity: (EOEntity *)_entity
{
  EOSQLQualifier *qualifier;

  if (_colname2 == nil)
    {
      qualifier = [[EOSQLQualifier alloc] initWithEntity: _entity
					  qualifierFormat: @"%A = %@", _colname, [self _formatRowValue:_value]];
    }
  else
    {
      qualifier = [[EOSQLQualifier alloc] initWithEntity: _entity
					  qualifierFormat: @"%A = %@ AND %A = %@", _colname, [self _formatRowValue:_value],
					  _colname2, [self _formatRowValue:_value2]];
    }

  return AUTORELEASE(qualifier);
}

- (void) _purgeRecordWithName: (NSString *) recordName
{
  NSString *delSql, *table;
  EOAdaptorChannel *channel;

  channel = [self acquireStoreChannel];
  [[channel adaptorContext] beginTransaction];

  table = [self storeTableName];
  delSql = [NSString stringWithFormat: @"DELETE FROM %@"
		     @" WHERE c_name = %@", table,
		     [self _formatRowValue: recordName]];
  [channel evaluateExpressionX: delSql];

  [[channel adaptorContext] commitTransaction];
  [self releaseChannel: channel];
}

- (NSException *) writeContent: (NSString *) _content
			toName: (NSString *) _name
		   baseVersion: (unsigned int) _baseVersion
{
  EOAdaptorChannel    *storeChannel, *quickChannel;
  NSMutableDictionary *quickRow, *contentRow;
  NSDictionary	      *currentRow;
  GCSFieldExtractor   *extractor;
  NSException         *error;
  NSNumber            *storedVersion;
  BOOL                isNewRecord, hasInsertDelegate, hasUpdateDelegate;
  NSCalendarDate      *nowDate;
  NSNumber            *now;
  EOEntity *quickTableEntity, *storeTableEntity;
  NSArray *rows;

  /* check preconditions */  
  if (_name == nil) {
    return [NSException exceptionWithName:@"GCSStoreException"
			reason:@"no content filename was provided"
			userInfo:nil];
  }
  if (_content == nil) {
    return [NSException exceptionWithName:@"GCSStoreException"
			reason:@"no content was provided"
			userInfo:nil];
  }
  
  /* run */
  error   = nil;
  nowDate = [NSCalendarDate date];
  now     = [NSNumber numberWithUnsignedInt:[nowDate timeIntervalSince1970]];
  
  if (doLogStore)
    [self logWithFormat:@"should store content: '%@'\n%@", _name, _content];
  
  rows = [self fetchFields: [NSArray arrayWithObjects:
				       @"c_version",
				     @"c_deleted",
				     nil]
	       fetchSpecification: [self _simpleFetchSpecificationWith:
					   @"c_name"
					 andValue: _name]
	       ignoreDeleted: NO];
  if ([rows count])
    {
      currentRow = [rows objectAtIndex: 0];
      storedVersion = [currentRow objectForKey: @"c_version"];
      if (doLogStore)
	[self logWithFormat:@"  version: %@", storedVersion];
      if ([[currentRow objectForKey: @"c_deleted"] intValue] > 0)
	{
	  [self _purgeRecordWithName: _name];
	  isNewRecord = YES;
	}
      else
	isNewRecord = NO;
    }
  else
    {
      storedVersion = nil;
      isNewRecord = YES;
    }

  /* check whether sequence matches */  
  if (_baseVersion != 0 /* use 0 to override check */) {
    if (_baseVersion != [storedVersion unsignedIntValue]) {
      /* version mismatch (concurrent update) */
      return [self errorVersionMismatchBetweenStoredVersion:
		     [storedVersion unsignedIntValue]
		   andExpectedVersion:_baseVersion];
    }
  }
  
  /* extract quick info */
  extractor = [folderInfo quickExtractor];
  if ((quickRow = [extractor extractQuickFieldsFromContent:_content]) == nil) {
    return [self errorExtractorReturnedNoQuickRow:extractor
		 forContent:_content];
  }
  
  [quickRow setObject:_name forKey:@"c_name"];
  
  if (doLogStore)
    [self logWithFormat:@"  store quick: %@", quickRow];
  
  /* make content row */
  contentRow = [NSMutableDictionary dictionaryWithCapacity:16];
  
  if (ofFlags.sameTableForQuick)
    [contentRow addEntriesFromDictionary:quickRow];
  
  [contentRow setObject:_name forKey:@"c_name"];
  if (isNewRecord) [contentRow setObject:now forKey:@"c_creationdate"];
  [contentRow setObject:now forKey:@"c_lastmodified"];
  if (isNewRecord)
    [contentRow setObject:[NSNumber numberWithInt:0] forKey:@"c_version"];
  else {
    // TODO: increase version?
    [contentRow setObject:
		  [NSNumber numberWithInt:([storedVersion intValue] + 1)]
		forKey:@"c_version"];
  }
  [contentRow setObject:_content forKey:@"c_content"];
  
  /* open channels */
  if ((storeChannel = [self acquireStoreChannel]) == nil) {
    [self errorWithFormat:@"%s: could not open storage channel!",
	    __PRETTY_FUNCTION__];
    return nil;
  }
  if (!ofFlags.sameTableForQuick) {
    if ((quickChannel = [self acquireQuickChannel]) == nil) {
      [self errorWithFormat:@"%s: could not open quick channel!",
	      __PRETTY_FUNCTION__];
      [self releaseChannel:storeChannel];
      return nil;
    }
  }

  /* we check if we can call directly methods on our adaptor
     channel delegate. If not, we generate SQL ourself since it'll
     be a little bit faster and less complex than using GDL to do so */
  hasInsertDelegate = [[storeChannel delegate] 
			respondsToSelector: @selector(adaptorChannel:willInsertRow:forEntity:)];
  hasUpdateDelegate = [[storeChannel delegate]
			respondsToSelector: @selector(adaptorChannel:willUpdateRow:describedByQualifier:)];

  [[quickChannel adaptorContext] beginTransaction];
  [[storeChannel adaptorContext] beginTransaction];
  
  quickTableEntity = [self _quickTableEntity];
  storeTableEntity = [self _storeTableEntity];

  if (isNewRecord) {
    if (!ofFlags.sameTableForQuick) {
      error = (hasInsertDelegate
	       ? [quickChannel insertRowX: quickRow forEntity: quickTableEntity]
	       : [quickChannel
		   evaluateExpressionX: [self _generateInsertStatementForRow: quickRow 
					      tableName: [self quickTableName]]]);
      CHECKERROR();
    }

    error = (hasInsertDelegate
	     ? [storeChannel insertRowX: contentRow forEntity: storeTableEntity]
	     : [storeChannel
		 evaluateExpressionX: [self _generateInsertStatementForRow: contentRow
					    tableName: [self storeTableName]]]);
    
    CHECKERROR();
  }
  else {
    if (!ofFlags.sameTableForQuick) {
      error = (hasUpdateDelegate
	       ? [quickChannel updateRowX: quickRow
			       describedByQualifier: [self _qualifierUsingWhereColumn: @"c_name"
							   isEqualTo: _name  andColumn: nil  isEqualTo: nil
							   entity: quickTableEntity]]
	       : [quickChannel evaluateExpressionX: [self _generateUpdateStatementForRow: quickRow
							  tableName: [self quickTableName]
							  whereColumn: @"c_name" isEqualTo: _name
							  andColumn: nil isEqualTo: nil]]);
      CHECKERROR();
    }
    
    error = (hasUpdateDelegate
	     ? [storeChannel updateRowX: contentRow
			     describedByQualifier: [self _qualifierUsingWhereColumn: @"c_name"  isEqualTo: _name
							 andColumn: (_baseVersion != 0 ? (id)@"c_version" : (id)nil)
							 isEqualTo: (_baseVersion != 0 ? [NSNumber numberWithUnsignedInt:_baseVersion] : (NSNumber *)nil)
							 entity: storeTableEntity]]
	     : [storeChannel evaluateExpressionX: [self _generateUpdateStatementForRow: contentRow  tableName:[self storeTableName]
							whereColumn: @"c_name"  isEqualTo: _name
							andColumn: (_baseVersion != 0 ? (id)@"c_version" : (id)nil)
							isEqualTo: (_baseVersion != 0 ? [NSNumber numberWithUnsignedInt: _baseVersion] : (NSNumber *)nil)]]);
    CHECKERROR();
  }
  
  [[storeChannel adaptorContext] commitTransaction];
  [[quickChannel adaptorContext] commitTransaction];
  
  [self releaseChannel: storeChannel];
  if (!ofFlags.sameTableForQuick) [self releaseChannel: quickChannel];

  return error;
}


- (NSException *)writeContent:(NSString *)_content toName:(NSString *)_name {
  /* this method does not check for concurrent writes */
  return [self writeContent:_content toName:_name baseVersion:0];
}

- (NSException *)deleteContentWithName:(NSString *)_name {
  EOAdaptorChannel *storeChannel, *quickChannel;
  NSException *error;
  NSString *delsql;
  NSCalendarDate *nowDate;
  
  /* check preconditions */
  
  if (_name == nil) {
    return [NSException exceptionWithName:@"GCSDeleteException"
			reason:@"no content filename was provided"
			userInfo:nil];
  }
  
  if (doLogStore)
    [self logWithFormat:@"should delete content: '%@'", _name];
  
  /* open channels */
  
  if ((storeChannel = [self acquireStoreChannel]) == nil) {
    [self errorWithFormat:@"could not open storage channel!"];
    return nil;
  }
  if (ofFlags.sameTableForQuick)
    quickChannel = nil;
  else
    {
      quickChannel = [self acquireQuickChannel];
      if (!quickChannel)
	{
	  [self errorWithFormat:@"could not open quick channel!"];
	  [self releaseChannel:storeChannel];
	  return nil;
	}
    }

  if (!ofFlags.sameTableForQuick) [[quickChannel adaptorContext] beginTransaction];
  [[storeChannel adaptorContext] beginTransaction];

  /* delete rows */
  nowDate = [NSCalendarDate calendarDate];

  delsql = [@"UPDATE " stringByAppendingString:[self storeTableName]];
  delsql = [delsql stringByAppendingString:@" SET c_deleted = 1"];
  delsql = [delsql stringByAppendingFormat:@", c_lastmodified = %u",
		   (unsigned int) [nowDate timeIntervalSince1970]];
  delsql = [delsql stringByAppendingString:@" WHERE c_name="];
  delsql = [delsql stringByAppendingString:[self _formatRowValue:_name]];
  if ((error = [storeChannel evaluateExpressionX:delsql]) != nil) {
    [self errorWithFormat:
	    @"%s: cannot delete content '%@': %@", 
	  __PRETTY_FUNCTION__, delsql, error];
  }
  else if (!ofFlags.sameTableForQuick) {
    /* content row deleted, now delete the quick row */
    delsql = [@"DELETE FROM " stringByAppendingString:[self quickTableName]];
    delsql = [delsql stringByAppendingString:@" WHERE c_name="];
    delsql = [delsql stringByAppendingString:[self _formatRowValue:_name]];
    if ((error = [quickChannel evaluateExpressionX:delsql]) != nil) {
      [self errorWithFormat:
	      @"%s: cannot delete quick row '%@': %@", 
	    __PRETTY_FUNCTION__, delsql, error];
      /* 
	 Note: we now have a "broken" record, needs to be periodically GCed by
	       a script!
      */
    }
  }
  
  /* release channels and return */
  [[storeChannel adaptorContext] commitTransaction];
  [self releaseChannel:storeChannel];
  
  if (!ofFlags.sameTableForQuick) {
    [[quickChannel adaptorContext] commitTransaction];
    [self releaseChannel:quickChannel];
  }
  return error;
}

- (NSException *)deleteFolder {
  EOAdaptorChannel *channel;
  NSString *delsql;
  NSString *table;
  
  /* open channels */
  
  if ((channel = [self acquireStoreChannel]) == nil) {
    [self errorWithFormat:@"could not open channel!"];
    return nil;
  }
  
  /* delete rows */
  [[channel adaptorContext] beginTransaction];
  table = [self storeTableName];
  if ([table length] > 0) {
    delsql = [@"DROP TABLE " stringByAppendingString: table];
    [channel evaluateExpressionX:delsql];
  }
  table = [self quickTableName];
  if ([table length] > 0) {
    delsql = [@"DROP TABLE " stringByAppendingString: table];
    [channel evaluateExpressionX:delsql];
  }
  table = [self aclTableName];
  if ([table length] > 0) {
    delsql = [@"DROP TABLE  " stringByAppendingString: table];
    [channel evaluateExpressionX:delsql];
  }
  
  [[channel adaptorContext] commitTransaction];
  [self releaseChannel:channel];

  return nil;
}

/* SQL generation */

/* fetching */
- (NSArray *) fetchFields: (NSArray *) fields
       fetchSpecification: (EOFetchSpecification *) spec
{
  return [self fetchFields: fields
	       fetchSpecification: spec
	       ignoreDeleted: YES];
}

- (NSArray *) fetchFields: (NSArray *) _flds
	matchingQualifier: (EOQualifier *)_q
{
  EOFetchSpecification *fs;

  if (_q == nil)
    fs = nil;
  else
    fs = [EOFetchSpecification fetchSpecificationWithEntityName:
				 [self folderName]
			       qualifier:_q
			       sortOrderings:nil];

  return [self fetchFields:_flds fetchSpecification:fs];
}

- (NSArray *) fetchAclWithSpecification: (EOFetchSpecification *)_fs
{
  EOQualifier      *qualifier;
  NSArray          *sortOrderings;
  EOAdaptorChannel *channel;
  NSException      *error;
  NSMutableString  *sql;
  NSArray          *attrs;
  NSMutableArray   *results;
  NSDictionary     *row;
  
  qualifier     = [_fs qualifier];
  sortOrderings = [_fs sortOrderings];
  
#if 0
  [self logWithFormat:@"FETCH: %@", _flds];
  [self logWithFormat:@"  MATCH: %@", _q];
#endif
  
  /* generate SQL */

  sql = [NSMutableString stringWithCapacity:256];
  [sql appendString:@"SELECT c_uid, c_object, c_role"];
  [sql appendString:@" FROM "];
  [sql appendString:[self aclTableName]];
  
  if (qualifier != nil) {
    [sql appendString:@" WHERE "];
    [sql appendString:[self _sqlForQualifier:qualifier]];
  }
  if ([sortOrderings count] > 0) {
    [sql appendString:@" ORDER BY "];
    [sql appendString:[self _sqlForSortOrderings:sortOrderings]];
  }
#if 0
  /* limit */
  [sql appendString:@" LIMIT "]; // count
  [sql appendString:@" OFFSET "]; // index from 0
#endif
  
  /* open channel */

  if ((channel = [self acquireAclChannel]) == nil) {
    [self errorWithFormat:@"could not open acl channel!"];
    return nil;
  }
  
  /* run SQL */

  if ((error = [channel evaluateExpressionX:sql]) != nil) {
    [self errorWithFormat:@"%s: cannot execute acl-fetch SQL '%@': %@", 
	    __PRETTY_FUNCTION__, sql, error];
    [self releaseChannel:channel];
    return nil;
  }
  
  /* fetch results */
  
  results = [NSMutableArray arrayWithCapacity:64];
  attrs   = [channel describeResults:NO /* do not beautify names */];
  while ((row = [channel fetchAttributes:attrs withZone:NULL]) != nil)
    [results addObject:row];
  
  /* release channels */
  
  [self releaseChannel: channel];
  
  return results;
}

- (NSArray *) fetchAclMatchingQualifier: (EOQualifier *) _q
{
  EOFetchSpecification *fs;

  if (_q == nil)
    fs = nil;
  else {
    fs = [EOFetchSpecification fetchSpecificationWithEntityName:
				 [self folderName]
			       qualifier:_q
			       sortOrderings:nil];
  }
  return [self fetchAclWithSpecification:fs];
}

- (void) deleteAclMatchingQualifier: (EOQualifier *)_q
{
  EOFetchSpecification *fs;

  if (_q)
    {
      fs = [EOFetchSpecification fetchSpecificationWithEntityName:
				   [self folderName]
				 qualifier:_q
				 sortOrderings:nil];
      [self deleteAclWithSpecification: fs];
    }
}

- (void) deleteAclWithSpecification: (EOFetchSpecification *) _fs
{
  EOQualifier      *qualifier;
  EOAdaptorChannel *channel;
  NSException      *error;
  NSMutableString  *sql;
  
  qualifier     = [_fs qualifier];
  if (qualifier)
    {
      sql = [NSMutableString stringWithCapacity:256];
      [sql appendString:@"DELETE FROM "];
      [sql appendString:[self aclTableName]];
      [sql appendString:@" WHERE "];
      [sql appendString:[self _sqlForQualifier:qualifier]];
  
      /* open channel */

      if ((channel = [self acquireAclChannel]) == nil) {
	[self errorWithFormat:@"could not open acl channel!"];
	return;
      }
  
      /* run SQL */
      [[channel adaptorContext] beginTransaction];
      if ((error = [channel evaluateExpressionX:sql]) != nil) {
	[self errorWithFormat:@"%s: cannot execute acl-fetch SQL '%@': %@", 
	      __PRETTY_FUNCTION__, sql, error];
	[self releaseChannel:channel];
	return;
      }
      
      [[channel adaptorContext] commitTransaction];
      [self releaseChannel:channel];
    }
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  id tmp;
  
  ms = [NSMutableString stringWithCapacity:256];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if (folderId)
    [ms appendFormat:@" id=%@", folderId];
  else
    [ms appendString:@" no-id"];

  if ((tmp = [self path]))           [ms appendFormat:@" path=%@", tmp];
  if ((tmp = [self folderTypeName])) [ms appendFormat:@" type=%@", tmp];
  if ((tmp = [self location]))
    [ms appendFormat:@" loc=%@", [tmp absoluteString]];
  
  [ms appendString:@">"];
  return ms;
}

@end /* GCSFolder */
