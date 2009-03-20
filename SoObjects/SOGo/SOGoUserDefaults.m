/*
  Copyright (C) 2005 SKYRIX Software AG
  Copyright (C) 2008-2009 Inverse inc.

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
#import "SOGoCache.h"

@implementation SOGoUserDefaults

static NSString *uidColumnName = @"c_uid";

- (id) initWithTableURL: (NSURL *) theURL
		    uid: (NSString *) theUID
	      fieldName: (NSString *) theFieldName
{
  if ((self = [self init]))
    {
      if (theURL && [theUID length] > 0
	  && [theFieldName length] > 0)
	{
	  fieldName = [theFieldName copy];
	  url = [theURL copy];
	  uid = [theUID copy];
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
      defFlags.ready = YES;
      sql = [NSString stringWithFormat: (@"SELECT %@"
					 @"  FROM %@"
					 @" WHERE %@ = '%@'"),
		      fieldName, [[self tableURL] gcsTableName],
		      uidColumnName, [self uid]];
      
      values = [[NSMutableDictionary alloc] init];

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
	      id v;
	      
	      value = [value stringByReplacingString: @"''"
			     withString: @"'"];
	      value = [value stringByReplacingString: @"\\\\"
			     withString: @"\\"];
	      plistData = [value dataUsingEncoding: NSUTF8StringEncoding];
	      v = [NSPropertyListSerialization propertyListFromData: plistData
					       mutabilityOption: NSPropertyListMutableContainers
					       format: NULL
					       errorDescription: &error];
	      if ([v isKindOfClass: [NSMutableDictionary class]])
		[values addEntriesFromDictionary: v];
	    }
	  
	  ASSIGN(lastFetch, [NSCalendarDate date]);
	  defFlags.modified = NO;
	  rc = YES;
	}

      [cm releaseChannel:channel];
    }
  else
    {
      defFlags.ready = NO;
      [self errorWithFormat:@"failed to acquire channel for URL: %@", 
	    [self tableURL]];
    }

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
	  defFlags.ready = YES;
	  [[channel adaptorContext] beginTransaction];
	  ex = [channel evaluateExpressionX:sql];
	  if (ex)
	    {
	      [self errorWithFormat: @"could not run SQL '%@': %@", sql, ex];
	      [[channel adaptorContext] rollbackTransaction];
	    }
	  else
	    {
	      if ([[channel adaptorContext] commitTransaction])
		{
		  rc = YES;
		}
	      
	      defFlags.modified = NO;
	      defFlags.isNew = NO;
	    }
	  
	  [cm releaseChannel: channel];
	}
      else
	{
	  defFlags.ready = NO;
	  [self errorWithFormat: @"failed to acquire channel for URL: %@", 
		[self tableURL]];
	}
    }
  else
    [self errorWithFormat: @"failed to generate SQL for storing defaults"];

  if (rc)
    {
      NSMutableDictionary *d;
      
      d = [NSMutableDictionary dictionary];
      [d setObject: values forKey: @"values"];
      [d setObject: uid  forKey: @"uid"];
      [d setObject: [url absoluteString]  forKey: @"url"];

      [[SOGoCache sharedCache] setDefaults: self
			       forLogin: uid
			       key: ([fieldName isEqualToString: @"c_defaults"] ? @"defaults" : @"settings")];

      [[NSDistributedNotificationCenter defaultCenter]
	postNotificationName: ([fieldName isEqualToString: @"c_defaults"]
			       ? @"SOGoUserDefaultsHaveChanged"
			       : @"SOGoUserSettingsHaveChanged")
	object: nil
	userInfo: d
	deliverImmediately: YES];
    }

  return rc;
}

- (BOOL) fetchProfile
{
  return (values  || [self primaryFetchProfile]);
}

- (NSString *) jsonRepresentation
{
  NSString *jsonRep;

  [self fetchProfile];
  if (values)
    jsonRep = [values jsonRepresentation];
  else
    jsonRep = @"{}";

  return jsonRep;
}

/* value access */
- (void) setValues: (NSDictionary *) theValues
{
  [values release];
  
  values = [[NSMutableDictionary alloc] init];
  [values addEntriesFromDictionary: theValues];
  ASSIGN(lastFetch, [NSCalendarDate date]);
  defFlags.modified = NO;
  defFlags.isNew = NO;
}

- (NSDictionary *) values
{
  return values;
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
  
  if (!defFlags.ready || ![self fetchProfile])
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
  [values removeAllObjects];
  [lastFetch release];
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

- (NSString *) description
{
  return [values description];
}

@end /* SOGoUserDefaults */
