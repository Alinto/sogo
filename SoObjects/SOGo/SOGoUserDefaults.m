/*
  Copyright (C) 2008-2009 Inverse inc.
  Copyright (C) 2005 SKYRIX Software AG

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
#import "NSString+Utilities.h"

#import "NSDictionary+BSJSONAdditions.h"
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
	  ASSIGN (fieldName, theFieldName);
	  ASSIGN (url, theURL);
	  ASSIGN (uid, theUID);
	  defFlags.ready = NO;
	  defFlags.isNew = NO;
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

- (NSString *) fetchJSONProfileFromDB
{
  GCSChannelManager *cm;
  EOAdaptorChannel *channel;
  NSDictionary *row;
  NSException *ex;
  NSString *sql, *value;
  NSArray *attrs;

  value = nil;

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: [self tableURL]];
  if (channel)
    {
      /* generate SQL */
      defFlags.ready = YES;
      sql = [NSString stringWithFormat: @"SELECT %@ FROM %@ WHERE %@ = '%@'",
                      fieldName, [[self tableURL] gcsTableName],
                      uidColumnName, [self uid]];
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
          [channel cancelFetch];

          value = [row objectForKey: fieldName];
          if ([value isNotNull])
            {
              defFlags.isNew = NO;
              /* The following enables the restitution of coded unicode (\U1234)
                 characters with the Oracle adaptor. */
              value = [value stringByReplacingString: @"\\\\" withString: @"\\"];
            }
          else
            {
              defFlags.isNew = YES;
              value = nil; /* we discard any NSNull instance */
            }
        }

      [cm releaseChannel: channel];
    }
  else
    {
      defFlags.ready = NO;
      [self errorWithFormat:@"failed to acquire channel for URL: %@", 
            [self tableURL]];
    }

  return value;
}

- (NSString *) _convertPListToJSON: (NSString *) plistValue
{
  NSData *plistData;
  NSDictionary *plist;
  NSString *jsonValue, *error;

  plistData = [plistValue dataUsingEncoding: NSUTF8StringEncoding];
  plist = [NSPropertyListSerialization propertyListFromData: plistData
                                           mutabilityOption: NSPropertyListMutableContainers
                                                     format: NULL
                                           errorDescription: &error];
  if (plist)
    {
      [self logWithFormat: @"database value for '%@'"
                  @" (uid: '%@') is a plist", fieldName, uid];
      jsonValue = [plist jsonStringValue];
    }
  else
    {
      [self errorWithFormat: @"failed to parse property list value"
                  @" (error: %@): %@", error, plistValue];
      jsonValue = nil;
    }

  if (!jsonValue)
    jsonValue = @"{}";

  return jsonValue;
}

- (NSString *) jsonRepresentation
{
  SOGoCache *cache;
  NSString *jsonValue;

  cache = [SOGoCache sharedCache];
  if ([fieldName isEqualToString: @"c_defaults"])
    jsonValue = [cache userDefaultsForLogin: uid];
  else
    jsonValue = [cache userSettingsForLogin: uid];
  if ([jsonValue length])
    {
      defFlags.ready = YES;
      defFlags.isNew = NO;
    }
  else
    {
      jsonValue = [self fetchJSONProfileFromDB];
      if ([jsonValue length])
        {
          if (![jsonValue isJSONString])
            jsonValue = [self _convertPListToJSON: jsonValue];
          defFlags.isNew = NO;
          if ([fieldName isEqualToString: @"c_defaults"])
            [cache setUserDefaults: jsonValue forLogin: uid];
          else
            [cache setUserSettings: jsonValue forLogin: uid];
        }
      else
        {
          defFlags.isNew = YES;
          jsonValue = @"{}";
        }
    }

  return jsonValue;
}

- (void) primaryFetchProfile
{
  NSString *jsonValue;

  defFlags.modified = NO;
  [values release];
  jsonValue = [self jsonRepresentation];
  values = [NSMutableDictionary dictionaryWithJSONString: jsonValue];
  if (values)
    [values retain];
  else
    [self errorWithFormat: @"failure parsing json string: '%@'", jsonValue];
}

- (BOOL) _isReadyOrRetry
{
  BOOL rc;

  if (defFlags.ready)
    rc = YES;
  else
    {
      [self primaryFetchProfile];
      rc = defFlags.ready;
    }

  return rc;
}

- (NSString *) _sqlJsonRepresentation: (NSString *) jsonRepresentation
{
  NSMutableString *sql;

  sql = [jsonRepresentation mutableCopy];
  [sql autorelease];
  [sql replaceString: @"\\" withString: @"\\\\"];
  [sql replaceString: @"'" withString: @"''"];

  return sql;
}

- (NSString *) generateSQLForInsert: (NSString *) jsonRepresentation
{
  NSString *sql;

  if ([jsonRepresentation length])
    sql = [NSString stringWithFormat: (@"INSERT INTO %@"
                                       @"            (%@, %@)"
                                       @"     VALUES ('%@', '%@')"),
                    [[self tableURL] gcsTableName], uidColumnName, fieldName,
                    [self uid],
                    [self _sqlJsonRepresentation: jsonRepresentation]];
  else
    sql = nil;

  return sql;
}

- (NSString *) generateSQLForUpdate: (NSString *) jsonRepresentation
{
  NSString *sql;

  if ([jsonRepresentation length])
    sql = [NSString stringWithFormat: (@"UPDATE %@"
                                       @"     SET %@ = '%@'"
                                       @"   WHERE %@ = '%@'"),
                    [[self tableURL] gcsTableName],
                    fieldName,
                    [self _sqlJsonRepresentation: jsonRepresentation],
                    uidColumnName, [self uid]];
  else
    sql = nil;

  return sql;
}

- (BOOL) storeJSONProfileInDB: (NSString *) jsonRepresentation
{
  GCSChannelManager *cm;
  EOAdaptorChannel *channel;
  EOAdaptorContext *context;
  NSException *ex;
  NSString *sql;
  BOOL rc;

  rc = NO;

  sql = ((defFlags.isNew)
         ? [self generateSQLForInsert: jsonRepresentation]
         : [self generateSQLForUpdate: jsonRepresentation]);
  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: [self tableURL]];
  if (channel)
    {
      context = [channel adaptorContext];
      if ([context beginTransaction])
        {
          defFlags.ready = YES;
          ex = [channel evaluateExpressionX:sql];
          if (ex)
            {
              [self errorWithFormat: @"could not run SQL '%@': %@", sql, ex];
              [context rollbackTransaction];
            }
          else
            {
              rc = YES;
              defFlags.modified = NO;
              defFlags.isNew = NO;
              [context commitTransaction];
            }
          [cm releaseChannel: channel];
        }
      else
        {
          defFlags.ready = NO;
          [cm releaseChannel: channel immediately: YES];
        }
    }
  else
    {
      defFlags.ready = NO;
      [self errorWithFormat: @"failed to acquire channel for URL: %@", 
            [self tableURL]];
    }

  return rc;
}

- (BOOL) primaryStoreProfile
{
  NSString *jsonRepresentation;
  SOGoCache *cache;
  BOOL rc;

  jsonRepresentation = [values jsonStringValue];
  if (jsonRepresentation)
    {
      rc = [self storeJSONProfileInDB: jsonRepresentation];
      if (rc)
        {
          cache = [SOGoCache sharedCache];
          if ([fieldName isEqualToString: @"c_defaults"])
            [cache setUserDefaults: jsonRepresentation
                          forLogin: uid];
          else
            [cache setUserSettings: jsonRepresentation
                          forLogin: uid];
        }
    }
 else
   {
     [self errorWithFormat: @"Unable to convert (%@) to a JSON string for"
                   @" type: %@ and login: %@", values, fieldName, uid];
     rc = NO;
   }

  return rc;
}

- (void) fetchProfile
{
  if (!values)
    [self primaryFetchProfile];
}

/* value access */
- (void) setValues: (NSDictionary *) theValues
{
  if ([self _isReadyOrRetry])
    {
      [values release];
      values = [[NSMutableDictionary alloc] init];
      [values addEntriesFromDictionary: theValues];
      defFlags.modified = YES;
    }
}

- (NSDictionary *) values
{
  NSDictionary *returnValues;

  if ([self _isReadyOrRetry])
    returnValues = values;
  else
    returnValues = nil;

  return returnValues;
}

- (void) setObject: (id) value
	    forKey: (NSString *) key
{ 
  id old;

  if ([self _isReadyOrRetry])
    {  
      /* check whether the value is actually modified */
      if (!defFlags.modified)
        {
          old = [values objectForKey: key];
          if (old == value || [old isEqual: value]) /* value didn't change */
            return;

#warning Note that this work-around only works for first-level objects.
          /* we need to this because our typed accessors convert to strings */
          // TODO: especially problematic with bools
          if ([value isKindOfClass: [NSString class]]) {
            if (![old isKindOfClass: [NSString class]])
              if ([[old description] isEqualToString: value])
                return;
          }
        }

      /* set in hash and mark as modified */
      if (value)
        [values setObject: value forKey: key];
      else
        [values removeObjectForKey: key];
      
      defFlags.modified = YES;
    }
}

- (id) objectForKey: (NSString *) key
{
  return [[self values] objectForKey: key];
}

- (void) removeObjectForKey: (NSString *) key
{
  [self setObject: nil forKey: key];
}

/* saving changes */

- (BOOL) synchronize
{
  BOOL rc;
//   if (!defFlags.modified) /* was not modified */
//     return YES;

  rc = NO;

  /* ensure fetched data (more or less guaranteed by modified!=0) */
  [self fetchProfile];
  if (values)
    {
      /* store */
      if ([self primaryStoreProfile])
        {
          rc = YES;
          // /* refetch */
          // [self primaryFetchProfile];
        }
      else
        {
          [self primaryFetchProfile];
          return NO;
        }
    }

  return rc;
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
