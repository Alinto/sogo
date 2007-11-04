/*
  Copyright (C) 2004-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#include "GCSFolder.h"
#include "GCSFolderManager.h"
#include "GCSFolderType.h"
#include "GCSChannelManager.h"
#include "GCSFieldExtractor.h"
#include "NSURL+GCS.h"
#include "EOAdaptorChannel+GCS.h"
#include "EOQualifier+GCS.h"
#include "GCSStringFormatter.h"
#include "common.h"

#include <GDLAccess/EOEntity.h>
#include <GDLAccess/EOAttribute.h>
#include <GDLAccess/EOSQLQualifier.h>
#include <GDLAccess/EOAdaptorContext.h>

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

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn         = [ud boolForKey:@"GCSFolderDebugEnabled"];
  doLogStore      = [ud boolForKey:@"GCSFolderStoreDebugEnabled"];

  NSStringClass       = [NSString class];
  NSNumberClass       = [NSNumber class];
  NSCalendarDateClass = [NSCalendarDate class];
  
  stringFormatter = [GCSStringFormatter sharedFormatter];
}

- (id)initWithPath:(NSString *)_path primaryKey:(id)_folderId
  folderTypeName:(NSString *)_ftname folderType:(GCSFolderType *)_ftype
  location:(NSURL *)_loc quickLocation:(NSURL *)_qloc
  aclLocation:(NSURL *)_aloc
  folderManager:(GCSFolderManager *)_fm
{
  if (![_loc isNotNull]) {
    [self errorWithFormat:@"missing quicktable parameter!"];
    [self release];
    return nil;
  }
  
  if ((self = [super init])) {
    self->folderManager  = [_fm    retain];
    self->folderInfo     = [_ftype retain];
    
    self->folderId       = [_folderId copy];
    self->folderName     = [[_path lastPathComponent] copy];
    self->path           = [_path   copy];
    self->location       = [_loc    retain];
    self->quickLocation  = _qloc ? [_qloc   retain] : [_loc retain];
    self->aclLocation    = [_aloc   retain];
    self->folderTypeName = [_ftname copy];

    self->ofFlags.requiresFolderSelect = 0;
    self->ofFlags.sameTableForQuick = 
      [self->location isEqualTo:self->quickLocation] ? 1 : 0;
  }
  return self;
}
- (id)init {
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

- (void)dealloc {
  [self->folderManager  release];
  [self->folderInfo     release];
  [self->folderId       release];
  [self->folderName     release];
  [self->path           release];
  [self->location       release];
  [self->quickLocation  release];
  [self->aclLocation    release];
  [self->folderTypeName release];
  [super dealloc];
}

/* accessors */

- (NSNumber *)folderId {
  return self->folderId;
}

- (NSString *)folderName {
  return self->folderName;
}
- (NSString *)path {
  return self->path;
}

- (NSURL *)location {
  return self->location;
}
- (NSURL *)quickLocation {
  return self->quickLocation;
}
- (NSURL *)aclLocation {
  return self->aclLocation;
}

- (NSString *)folderTypeName {
  return self->folderTypeName;
}

- (GCSFolderManager *)folderManager {
  return self->folderManager;
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
  return self->ofFlags.sameTableForQuick ? YES : NO;
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

- (id)_fetchValueOfColumn:(NSString *)_col inContentWithName:(NSString *)_name{
  EOAdaptorChannel *channel;
  NSException  *error;
  NSDictionary *row;
  NSArray      *attrs;
  NSString     *result;
  NSString     *sql;
  
  if ((channel = [self acquireStoreChannel]) == nil) {
    [self errorWithFormat:@"could not open storage channel!"];
    return nil;
  }
  
  /* generate SQL */
  
  sql = @"SELECT ";
  sql = [sql stringByAppendingString:_col];
  sql = [sql stringByAppendingString:@" FROM "];
  sql = [sql stringByAppendingString:[self storeTableName]];
  sql = [sql stringByAppendingString:@" WHERE c_name = '"];
  sql = [sql stringByAppendingString:_name];
  sql = [sql stringByAppendingString:@"'"];
  
  /* run SQL */
  
  if ((error = [channel evaluateExpressionX:sql]) != nil) {
    [self errorWithFormat:@"%s: cannot execute SQL '%@': %@", 
	    __PRETTY_FUNCTION__, sql, error];
    [self releaseChannel:channel];
    return nil;
  }
  
  /* fetch results */
  
  result = nil;
  attrs  = [channel describeResults:NO /* do not beautify names */];
  if ((row = [channel fetchAttributes:attrs withZone:NULL]) != nil) {
    result = [[[row objectForKey:_col] copy] autorelease];
    if (![result isNotNull]) result = nil;
    [channel cancelFetch];
  }
  
  /* release and return result */
  
  [self releaseChannel:channel];
  return result;
}

- (NSNumber *)versionOfContentWithName:(NSString *)_name {
  return [self _fetchValueOfColumn:@"c_version" inContentWithName:_name];
}

- (NSNumber *)deletionOfContentWithName:(NSString *)_name {
  return [self _fetchValueOfColumn:@"c_deleted" inContentWithName:_name];
}

- (NSString *)fetchContentWithName:(NSString *)_name {
  return [self _fetchValueOfColumn:@"c_content" inContentWithName:_name];
}

- (NSDictionary *)fetchContentsOfAllFiles {
  /*
    Note: try to avoid the use of this method! The key of the dictionary
          will be filename, the value the content.
  */
  NSMutableDictionary *result;
  EOAdaptorChannel *channel;
  NSException  *error;
  NSDictionary *row;
  NSArray      *attrs;
  NSString     *sql;
  
  if ((channel = [self acquireStoreChannel]) == nil) {
    [self errorWithFormat:@"%s: could not open storage channel!",
            __PRETTY_FUNCTION__];
    return nil;
  }
  
  /* generate SQL */
  
  sql = @"SELECT c_name, c_content FROM ";
  sql = [sql stringByAppendingString:[self storeTableName]];
  
  /* run SQL */
  
  if ((error = [channel evaluateExpressionX:sql]) != nil) {
    [self logWithFormat:@"ERROR(%s): cannot execute SQL '%@': %@", 
	    __PRETTY_FUNCTION__, sql, error];
    [self releaseChannel:channel];
    return nil;
  }
  
  /* fetch results */
  
  result = [NSMutableDictionary dictionaryWithCapacity:128];
  attrs  = [channel describeResults:NO /* do not beautify names */];
  while ((row = [channel fetchAttributes:attrs withZone:NULL]) != nil) {
    NSString *cName, *cContent;
    
    cName    = [row objectForKey:@"c_name"];
    cContent = [row objectForKey:@"c_content"];
    
    if (![cName isNotNull]) {
      [self errorWithFormat:@"missing c_name in row: %@", row];
      continue;
    }
    if (![cContent isNotNull]) {
      [self errorWithFormat:@"missing c_content in row: %@", row];
      continue;
    }
    
    [result setObject:cContent forKey:cName];
  }
  
  /* release and return result */
  
  [self releaseChannel:channel];
  return result;
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

  table = [self storeTableName];
  delSql = [NSString stringWithFormat: @"DELETE FROM %@"
		     @" WHERE c_name = %@", table,
		     [self _formatRowValue: recordName]];
  [channel evaluateExpressionX: delSql];
  [self releaseChannel: channel];
}

- (NSException *)writeContent:(NSString *)_content toName:(NSString *)_name
  baseVersion:(unsigned int)_baseVersion
{
  EOAdaptorChannel    *storeChannel, *quickChannel;
  NSMutableDictionary *quickRow, *contentRow;
  GCSFieldExtractor   *extractor;
  NSException         *error;
  NSNumber            *storedVersion;
  BOOL                isNewRecord, hasInsertDelegate, hasUpdateDelegate;
  NSCalendarDate      *nowDate;
  NSNumber            *now;

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
  
  storedVersion = [self versionOfContentWithName:_name];
  if (doLogStore)
    [self logWithFormat:@"  version: %@", storedVersion];
  isNewRecord = [storedVersion isNotNull] ? NO : YES;
  if (!isNewRecord)
    {
      if ([[self deletionOfContentWithName:_name] intValue] > 0)
	{
	  [self _purgeRecordWithName: _name];
	  isNewRecord = YES;
	}
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
  extractor = [self->folderInfo quickExtractor];
  if ((quickRow = [extractor extractQuickFieldsFromContent:_content]) == nil) {
    return [self errorExtractorReturnedNoQuickRow:extractor
		 forContent:_content];
  }
  
  [quickRow setObject:_name forKey:@"c_name"];
  
  if (doLogStore)
    [self logWithFormat:@"  store quick: %@", quickRow];
  
  /* make content row */
  contentRow = [NSMutableDictionary dictionaryWithCapacity:16];
  
  if (self->ofFlags.sameTableForQuick)
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
  if (!self->ofFlags.sameTableForQuick) {
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

  [[storeChannel adaptorContext] beginTransaction];
  [[quickChannel adaptorContext] beginTransaction];
  
  if (isNewRecord) {
    if (!self->ofFlags.sameTableForQuick) {
	error = (hasInsertDelegate ? [quickChannel insertRowX: quickRow
						   forEntity: [self _entityWithName: [self quickTableName]]]
		 : [quickChannel evaluateExpressionX: [self _generateInsertStatementForRow: quickRow 
							    tableName: [self quickTableName]]]);
      CHECKERROR();
    }

    error = (hasInsertDelegate ? [storeChannel insertRowX: contentRow
					       forEntity: [self _entityWithName: [self storeTableName]]]
	     : [storeChannel evaluateExpressionX: [self _generateInsertStatementForRow: contentRow
							tableName: [self storeTableName]]]);

    CHECKERROR();
  }
  else {
    if (!self->ofFlags.sameTableForQuick) {
      error = (hasUpdateDelegate ? [quickChannel updateRowX: quickRow
						 describedByQualifier: [self _qualifierUsingWhereColumn: @"c_name"
									     isEqualTo: _name  andColumn: nil  isEqualTo: nil
									     entity: [self _entityWithName: [self quickTableName]]]]
	       : [quickChannel evaluateExpressionX: [self _generateUpdateStatementForRow: quickRow
							  tableName: [self quickTableName]
							  whereColumn: @"c_name" isEqualTo: _name
							  andColumn: nil isEqualTo: nil]]);
      CHECKERROR();
    }
    
    error = (hasUpdateDelegate ? [storeChannel updateRowX: contentRow
					       describedByQualifier: [self _qualifierUsingWhereColumn: @"c_name"  isEqualTo: _name
									   andColumn: (_baseVersion != 0 ? (id)@"c_version" : (id)nil)
									   isEqualTo: (_baseVersion != 0 ? [NSNumber numberWithUnsignedInt:_baseVersion] : (NSNumber *)nil)
									   entity: [self _entityWithName: [self storeTableName]]]]
	     : [storeChannel evaluateExpressionX: [self _generateUpdateStatementForRow: contentRow  tableName:[self storeTableName]
							whereColumn: @"c_name"  isEqualTo: _name
							andColumn: (_baseVersion != 0 ? (id)@"c_version" : (id)nil)
							isEqualTo: (_baseVersion != 0 ? [NSNumber numberWithUnsignedInt: _baseVersion] : (NSNumber *)nil)]]);
    CHECKERROR();
  }
  
  [[storeChannel adaptorContext] commitTransaction];
  [[quickChannel adaptorContext] commitTransaction];
  
  [self releaseChannel: storeChannel];
  if (!self->ofFlags.sameTableForQuick) [self releaseChannel: quickChannel];

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
  if (!self->ofFlags.sameTableForQuick) {
    if ((quickChannel = [self acquireQuickChannel]) == nil) {
      [self errorWithFormat:@"could not open quick channel!"];
      [self releaseChannel:storeChannel];
      return nil;
    }
  }
  
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
  else if (!self->ofFlags.sameTableForQuick) {
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
  
  [self releaseChannel:storeChannel];
  if (!self->ofFlags.sameTableForQuick)
    [self releaseChannel:quickChannel];
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
  
  [self releaseChannel:channel];

  return nil;
}

- (NSString *)columnNameForFieldName:(NSString *)_fieldName {
  return _fieldName;
}

/* SQL generation */

- (NSString *)generateSQLForSortOrderings:(NSArray *)_so {
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
    column = [self columnNameForFieldName:[so key]];
    
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

- (NSString *)generateSQLForQualifier:(EOQualifier *)_q {
  NSMutableString *ms;
  
  if (_q == nil) return nil;
  ms = [NSMutableString stringWithCapacity:32];
  [_q _gcsAppendToString:ms];
  return ms;
}

/* fetching */

- (NSArray *)fetchFields:(NSArray *)_flds 
  fetchSpecification:(EOFetchSpecification *)_fs
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
  [sql appendString:@"SELECT "];
  if (_flds == nil)
    [sql appendString:@"*"];
  else {
    unsigned i, count;
    
    count = [_flds count];
    for (i = 0; i < count; i++) {
      if (i > 0) [sql appendString:@", "];
      [sql appendString:[self columnNameForFieldName:[_flds objectAtIndex:i]]];
    }
  }
  [sql appendString:@" FROM "];
  [sql appendString:[self quickTableName]];
  
  if (qualifier != nil) {
    [sql appendString:@" WHERE "];
    [sql appendString:[self generateSQLForQualifier:qualifier]];
  }
  if ([sortOrderings count] > 0) {
    [sql appendString:@" ORDER BY "];
    [sql appendString:[self generateSQLForSortOrderings:sortOrderings]];
  }
#if 0
  /* limit */
  [sql appendString:@" LIMIT "]; // count
  [sql appendString:@" OFFSET "]; // index from 0
#endif
  
  /* open channel */

  if ((channel = [self acquireStoreChannel]) == nil) {
    [self errorWithFormat:@" could not open storage channel!"];
    return nil;
  }
  
  /* run SQL */

  if ((error = [channel evaluateExpressionX:sql]) != nil) {
    [self errorWithFormat:@"%s: cannot execute quick-fetch SQL '%@': %@", 
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
  
  [self releaseChannel:channel];
  
  return results;
}
- (NSArray *)fetchFields:(NSArray *)_flds matchingQualifier:(EOQualifier *)_q {
  EOFetchSpecification *fs;

  if (_q == nil)
    fs = nil;
  else {
    fs = [EOFetchSpecification fetchSpecificationWithEntityName:
				 [self folderName]
			       qualifier:_q
			       sortOrderings:nil];
  }
  return [self fetchFields:_flds fetchSpecification:fs];
}

- (NSArray *)fetchAclWithSpecification:(EOFetchSpecification *)_fs {
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
    [sql appendString:[self generateSQLForQualifier:qualifier]];
  }
  if ([sortOrderings count] > 0) {
    [sql appendString:@" ORDER BY "];
    [sql appendString:[self generateSQLForSortOrderings:sortOrderings]];
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
  
  [self releaseChannel:channel];
  
  return results;
}
- (NSArray *) fetchAclMatchingQualifier:(EOQualifier *)_q {
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

- (void) deleteAclMatchingQualifier:(EOQualifier *)_q {
  EOFetchSpecification *fs;

  if (_q != nil) {
    fs = [EOFetchSpecification fetchSpecificationWithEntityName:
				 [self folderName]
			       qualifier:_q
			       sortOrderings:nil];
    [self deleteAclWithSpecification:fs];
  }
}

- (void)deleteAclWithSpecification:(EOFetchSpecification *)_fs
{
  EOQualifier      *qualifier;
  EOAdaptorChannel *channel;
  NSException      *error;
  NSMutableString  *sql;
  
  qualifier     = [_fs qualifier];
  if (qualifier != nil) {
    sql = [NSMutableString stringWithCapacity:256];
    [sql appendString:@"DELETE FROM "];
    [sql appendString:[self aclTableName]];
    [sql appendString:@" WHERE "];
    [sql appendString:[self generateSQLForQualifier:qualifier]];
  }
  
  /* open channel */

  if ((channel = [self acquireAclChannel]) == nil) {
    [self errorWithFormat:@"could not open acl channel!"];
    return;
  }
  
  /* run SQL */

  if ((error = [channel evaluateExpressionX:sql]) != nil) {
    [self errorWithFormat:@"%s: cannot execute acl-fetch SQL '%@': %@", 
	    __PRETTY_FUNCTION__, sql, error];
    [self releaseChannel:channel];
    return;
  }
  
  [self releaseChannel:channel];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  id tmp;
  
  ms = [NSMutableString stringWithCapacity:256];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if (self->folderId)
    [ms appendFormat:@" id=%@", self->folderId];
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
