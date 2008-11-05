/*
  Copyright (C) 2005 SKYRIX Software AG

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
#import <Foundation/NSDistributedNotificationCenter.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/NSURL+GCS.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLAccess/EOAdaptorContext.h>
#import <GDLAccess/EOAttribute.h>

#import "NSObject+Utilities.h"

#import "SOGoUserDefaults.h"

@implementation SOGoUserDefaults

static NSString *uidColumnName = @"c_uid";

- (id) initWithTableURL: (NSURL *) tableURL
		    uid: (NSString *) userID
	      fieldName: (NSString *) defaultsFieldName
{
  if ((self = [super init]))
    {
      if (tableURL && [userID length] > 0
	  && [defaultsFieldName length] > 0)
	{
	  fieldName = [defaultsFieldName copy];
	  url = [tableURL copy];
	  uid = [userID copy];
	}
      else
	{
	  [self errorWithFormat: @"missing arguments"];
	  [self release];
	  self = nil;
	}
    }

  return self;
}

- (id) init
{
  [self release];

  return nil;
}

- (void) dealloc
{
  [values release];
  [lastFetch release];
  [url release];
  [uid release];
  [fieldName release];
  [super dealloc];
}

/* accessors */

- (NSURL *) tableURL
{
  return url;
}

- (NSString *) uid
{
  return uid;
}

- (NSString *) fieldName
{
  return fieldName;
}

/* operation */

- (BOOL) primaryFetchProfile
{
  GCSChannelManager *cm;
  EOAdaptorChannel *channel;
  NSDictionary *row;
  NSException *ex;
  NSString *sql, *value, *error;
  NSArray *attrs;
  BOOL rc;
  NSData *plistData;

  rc = NO;
  
  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: [self tableURL]];
  if (channel)
    {
      /* generate SQL */
      sql = [NSString stringWithFormat: (@"SELECT %@"
					 @"  FROM %@"
					 @" WHERE %@ = '%@'"),
		      fieldName, [[self tableURL] gcsTableName],
		      uidColumnName, [self uid]];
      
      [values release];

      /* run SQL */

      ex = [channel evaluateExpressionX: sql];
      if (ex)
	[self errorWithFormat:@"could not run SQL '%@': %@", sql, ex];
      else
	{
	  /* fetch schema */
	  attrs = [channel describeResults: NO /* don't beautify */];
  
	  /* fetch values */
	  row = [channel fetchAttributes: attrs withZone: NULL];
	  defFlags.isNew = (row == nil);
	  [channel cancelFetch];
  
	  /* remember values */
	  value = [row objectForKey: fieldName];
	  if ([value isNotNull])
	    {
	      value = [value stringByReplacingString: @"''"
			     withString: @"'"];
	      value = [value stringByReplacingString: @"\\\\"
			     withString: @"\\"];
	      plistData = [value dataUsingEncoding: NSUTF8StringEncoding];
	      values
		= [NSPropertyListSerialization propertyListFromData: plistData
					       mutabilityOption: NSPropertyListMutableContainers
					       format: NULL
					       errorDescription: &error];
	      if ([values isKindOfClass: [NSMutableDictionary class]])
		[values retain];
	      else
		values = [NSMutableDictionary new];
	    }
	  else
	    values = [NSMutableDictionary new];

	  ASSIGN (lastFetch, [NSCalendarDate date]);
	  defFlags.modified = NO;
	  rc = YES;
	}

      [cm releaseChannel:channel];
    }
  else
    [self errorWithFormat:@"failed to acquire channel for URL: %@", 
	  [self tableURL]];

  return rc;
}

- (NSString *) _serializedDefaults
{
  NSMutableString *serializedDefaults;
  NSData *serializedDefaultsData;
  NSString *error;

  error = nil;
  serializedDefaultsData
    = [NSPropertyListSerialization dataFromPropertyList: values
				   format: NSPropertyListOpenStepFormat
				   errorDescription: &error];
  if (error)
    {
      [self errorWithFormat: @"serializing the defaults: %@", error];
      serializedDefaults = nil;
      [error release];
    }
  else
    {
      serializedDefaults
	= [[NSMutableString alloc] initWithData: serializedDefaultsData
				   encoding: NSUTF8StringEncoding];
      [serializedDefaults autorelease];
      [serializedDefaults replaceString: @"\\" withString: @"\\\\"];
      [serializedDefaults replaceString: @"'" withString: @"''"];
    }

  return serializedDefaults;
}

- (NSString *) generateSQLForInsert
{
  NSString *sql, *serializedDefaults;

  serializedDefaults = [self _serializedDefaults];
  if (serializedDefaults)
    sql = [NSString stringWithFormat: (@"INSERT INTO %@"
				       @"            (%@, %@)"
				       @"     VALUES ('%@', '%@')"),
		    [[self tableURL] gcsTableName], uidColumnName, fieldName,
		    [self uid], serializedDefaults];
  else
    sql = nil;

  return sql;
}

- (NSString *) generateSQLForUpdate
{
  NSString *sql, *serializedDefaults;

  serializedDefaults = [self _serializedDefaults];
  if (serializedDefaults)
    sql = [NSString stringWithFormat: (@"UPDATE %@"
				       @"     SET %@ = '%@'"
				       @"   WHERE %@ = '%@'"),
		    [[self tableURL] gcsTableName],
		    fieldName,
		    serializedDefaults,
		    uidColumnName, [self uid]];
  else
    sql = nil;

  return sql;
}

- (BOOL) primaryStoreProfile
{
  GCSChannelManager *cm;
  EOAdaptorChannel *channel;
  NSException *ex;
  NSString *sql;
  BOOL rc;

  rc = NO;
  
  cm = [GCSChannelManager defaultChannelManager];
  sql = ((defFlags.isNew)
	 ? [self generateSQLForInsert] 
	 : [self generateSQLForUpdate]);
  if (sql)
    {
      channel = [cm acquireOpenChannelForURL: [self tableURL]];
      if (channel)
	{
	  ex = [channel evaluateExpressionX:sql];
	  if (ex)
	    [self errorWithFormat: @"could not run SQL '%@': %@", sql, ex];
	  else
	    {
	      NSMutableDictionary *d;

	      d = [[NSMutableDictionary alloc] init];
	      [d addEntriesFromDictionary: values];
	      [d setObject: uid  forKey: @"uid"];

	      [[NSDistributedNotificationCenter defaultCenter]
		postNotificationName: ([fieldName isEqualToString: @"c_defaults"] ? @"SOGoUserDefaultsHaveChanged" : @"SOGoUserSettingsHaveChanged")
		object: nil
		userInfo: d];
	      [d release];
	      
	      if ([[channel adaptorContext] hasOpenTransaction])
		{
		  ex = [channel evaluateExpressionX: @"COMMIT TRANSACTION"];
		  if (ex)
		    [self errorWithFormat:@"could not commit transaction for update: %@", ex];
		  else
		    rc = YES;
		}
	      else
		rc = YES;
	      
	      defFlags.modified = NO;
	      defFlags.isNew = NO;
	    }
	  
	  [cm releaseChannel: channel];
	}
      else
	[self errorWithFormat: @"failed to acquire channel for URL: %@", 
	      [self tableURL]];
    }
  else
    [self errorWithFormat: @"failed to generate SQL for storing defaults"];

  return rc;
}

- (BOOL) fetchProfile
{
  return (values || [self primaryFetchProfile]);
}

- (NSString *) jsonRepresentation
{
  [self fetchProfile];

  return [values jsonRepresentation];
}

/* value access */
- (void) setValues: (NSDictionary *) theValues
{
  [values removeAllObjects];
  [values addEntriesFromDictionary: theValues];
}

- (void) setObject: (id) value
	    forKey: (NSString *) key
{ 
  id old;
  
  if (![self fetchProfile])
    return;

  /* check whether the value is actually modified */
  if (!defFlags.modified)
    {
      old = [values objectForKey: key];
      if (old == value || [old isEqual: value]) /* value didn't change */
	return;
  
      /* we need to this because our typed accessors convert to strings */
      // TODO: especially problematic with bools
      if ([value isKindOfClass: [NSString class]]) {
	if (![old isKindOfClass: [NSString class]])
	  if ([[old description] isEqualToString: value])
	    return;
      }
    }

  /* set in hash and mark as modified */
  [values setObject: value forKey: key];

  defFlags.modified = YES;
}

- (id) objectForKey: (NSString *) key
{
  id value;
  
  if (![self fetchProfile])
    value = nil;
  else
    value = [values objectForKey: key];

  return value;
}

- (void) removeObjectForKey: (NSString *) key
{
  [self setObject: nil forKey: key];
}

/* saving changes */

- (BOOL) synchronize
{
//   if (!defFlags.modified) /* was not modified */
//     return YES;
  
  /* ensure fetched data (more or less guaranteed by modified!=0) */
  if (![self fetchProfile])
    return NO;

  /* store */
  if (![self primaryStoreProfile])
    {
      [self primaryFetchProfile];
      return NO;
    }

  /* refetch */
  return [self primaryFetchProfile];
}

- (void) flush
{
  [values release];
  [lastFetch release];
  values = nil;
  lastFetch = nil;
  defFlags.modified = NO;
  defFlags.isNew = NO;
}

/* typed accessors */

- (NSArray *) arrayForKey: (NSString *) key
{
  return [self objectForKey: key];
}

- (NSDictionary *) dictionaryForKey: (NSString *) key
{
  return [self objectForKey: key];
}

- (NSData *) dataForKey: (NSString *) key
{
  return [self objectForKey: key];
}

- (NSString *) stringForKey: (NSString *) key
{
  return [self objectForKey: key];
}

- (BOOL) boolForKey: (NSString *) key
{
  return [[self objectForKey: key] boolValue];
}

- (float) floatForKey: (NSString *) key
{
  return [[self objectForKey: key] floatValue];
}

- (int) integerForKey: (NSString *) key
{
  return [[self objectForKey: key] intValue];
}

- (void) setBool: (BOOL) value
	  forKey: (NSString *) key
{
  // TODO: need special support here for int-DB fields
  [self setObject: [NSNumber numberWithBool: value]
	forKey: key];
}

- (void) setFloat: (float) value
	   forKey: (NSString *) key
{
  [self setObject: [NSNumber numberWithFloat: value]
	forKey: key];
}

- (void) setInteger: (int) value
	     forKey: (NSString *) key
{
  [self setObject: [NSNumber numberWithInt: value]
	forKey: key];
}

@end /* SOGoUserDefaults */
