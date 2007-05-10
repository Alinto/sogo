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

#import <Foundation/NSValue.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/NSURL+GCS.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLAccess/EOAdaptorContext.h>
#import <GDLAccess/EOAttribute.h>

#import "common.h"
#import "AgenorUserDefaults.h"

@implementation AgenorUserDefaults

static NSString *uidColumnName = @"uid";

- (id) initWithTableURL: (NSURL *) tableURL
		    uid: (NSString *) userID
	      fieldName: (NSString *) defaultsFieldName
{
  if ((self = [super init]))
    {
      if (tableURL && [userID length] > 0
	  && [defaultsFieldName length] > 0)
	{
	  parent = [[NSUserDefaults standardUserDefaults] retain];
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
  [parent release];
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

- (NSUserDefaults *) parentDefaults
{
  return parent;
}

/* operation */

- (BOOL) primaryFetchProfile
{
  GCSChannelManager *cm;
  EOAdaptorChannel *channel;
  NSDictionary *row;
  NSException *ex;
  NSString *sql, *value;
  NSArray *attrs;
  BOOL rc;

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
      values = [NSMutableDictionary new];

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
	    [values setDictionary: [value propertyList]];

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

- (NSString *) generateSQLForInsert
{
  NSMutableString *sql;
  NSString *serializedDefaults;

#if LIB_FOUNDATION_LIBRARY
  serializedDefaults = [values stringRepresentation];

  sql = [NSString stringWithFormat: (@"INSERT INTO %@"
				     @"            (%@, %@)"
				     @"     VALUES ('%@', '%@')"),
		  [[self tableURL] gcsTableName], uidColumnName, fieldName,
		  [self uid],
		  [serializedDefaults stringByReplacingString:@"'" withString:@"''"]];
#else
  NSData *serializedDefaultsData;
  NSString *error;

  serializedDefaultsData
    = [NSPropertyListSerialization dataFromPropertyList: values
				   format: NSPropertyListOpenStepFormat
				   errorDescription: &error];

  if (error)
    sql = nil;
  else
    {
      serializedDefaults = [[NSString alloc] initWithData: serializedDefaultsData
					     encoding: NSUTF8StringEncoding];

      sql = [NSString stringWithFormat: (@"INSERT INTO %@"
					 @"            (%@, %@)"
					 @"     VALUES ('%@', '%@')"),
		      [[self tableURL] gcsTableName], uidColumnName, fieldName,
		      [self uid],
		      [serializedDefaults stringByReplacingString:@"'" withString:@"''"]];
      [serializedDefaults release];
    }
#endif

  return sql;
}

- (NSString *) generateSQLForUpdate
{
  NSMutableString *sql;
  NSString *serializedDefaults;

#if LIB_FOUNDATION_LIBRARY
  serializedDefaults = [values stringRepresentation];

  sql = [NSString stringWithFormat: (@"UPDATE %@"
				     @"     SET %@ = '%@'"
				     @"   WHERE %@ = '%@'"),
		  [[self tableURL] gcsTableName],
		  fieldName,
		  [serializedDefaults stringByReplacingString:@"'" withString:@"''"],
		  uidColumnName, [self uid]];
#else
  NSData *serializedDefaultsData;
  NSString *error;

  serializedDefaultsData
    = [NSPropertyListSerialization dataFromPropertyList: values
				   format: NSPropertyListOpenStepFormat
				   errorDescription: &error];
  error = nil;
  if (error)
    {
      sql = nil;
      [error release];
    }
  else
    {
      serializedDefaults = [[NSString alloc] initWithData: serializedDefaultsData
					     encoding: NSUTF8StringEncoding];

      sql = [NSString stringWithFormat: (@"UPDATE %@"
					 @"     SET %@ = '%@'"
					 @"   WHERE %@ = '%@'"),
		      [[self tableURL] gcsTableName],
		      fieldName,
		      [serializedDefaults stringByReplacingString:@"'" withString:@"''"],
		      uidColumnName, [self uid]];
      [serializedDefaults release];
    }
#endif

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

/* value access */

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

@end /* AgenorUserDefaults */
