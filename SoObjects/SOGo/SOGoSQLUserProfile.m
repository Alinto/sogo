/* SOGoSQLUserProfile.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/NSURL+GCS.h>
#import <GDLAccess/EOAdaptor.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLAccess/EOAdaptorContext.h>
#import <GDLAccess/EOAttribute.h>

#import "SOGoSystemDefaults.h"

#import "SOGoSQLUserProfile.h"

static NSURL *tableURL = nil;
static NSString *uidColumnName = @"c_uid";
static EOAttribute *textColumn = nil;

@implementation SOGoSQLUserProfile

+ (void) initialize
{
  NSDictionary *description;
  NSString *profileURL;
  SOGoSystemDefaults *sd;

  if (!tableURL)
    {
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      profileURL = [sd profileURL];
      if (profileURL)
        tableURL = [[NSURL alloc] initWithString: profileURL];
    }

  if (!textColumn)
    {
      #warning This is a hack for providing an EOAttribute definition \
        that is compatible with all the backends that we support
      /* TODO: ... We should make use of EOModel for the profile tables */
      description = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"c_textfield", @"columnName",
                                    @"VARCHAR", @"externalType",
                                  nil];
      textColumn = [EOAttribute attributeFromPropertyList: description];
      [textColumn retain];
    }
}

- (id) init
{
  if ((self = [super init]))
    {
      fieldName = nil;
    }

  return self;
}

- (void) dealloc
{
  [fieldName release];
  [super dealloc];
}

- (void) setProfileType: (SOGoUserProfileType) newProfileType
{
  if (newProfileType == SOGoUserProfileTypeDefaults)
    ASSIGN (fieldName, @"c_defaults");
  else if (newProfileType == SOGoUserProfileTypeSettings)
    ASSIGN (fieldName, @"c_settings");
  else
    [self errorWithFormat: @"unknown profile value: %d", newProfileType];

  [super setProfileType: newProfileType];
}

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
  channel = [cm acquireOpenChannelForURL: tableURL];
  if (channel)
    {
      /* generate SQL */
      defFlags.ready = YES;
      sql = [NSString stringWithFormat: @"SELECT %@ FROM %@ WHERE %@ = '%@'",
                      fieldName, [tableURL gcsTableName],
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

          /* the isNew flag depends on the presence of the row in the
             database rather than on the existence of the value. */
          defFlags.isNew = (row == nil);

          value = [row objectForKey: fieldName];
          if (![value isNotNull])
            value = nil; /* we discard any NSNull instance */
        }

      [cm releaseChannel: channel];
    }
  else
    {
      defFlags.ready = NO;
      [self errorWithFormat:@"failed to acquire channel for URL: %@", 
            tableURL];
    }

  return value;
}

- (NSString *) generateSQLForInsert: (NSString *) jsonRepresentation
{
  NSString *sql;

  if ([jsonRepresentation length])
    sql = [NSString stringWithFormat: (@"INSERT INTO %@"
                                       @"            (%@, %@)"
                                       @"     VALUES ('%@', %@)"),
                    [tableURL gcsTableName], uidColumnName, fieldName,
                    [self uid],
                    jsonRepresentation];
  else
    sql = nil;

  return sql;
}

- (NSString *) generateSQLForUpdate: (NSString *) jsonRepresentation
{
  NSString *sql;

  if ([jsonRepresentation length])
    sql = [NSString stringWithFormat: (@"UPDATE %@"
                                       @"     SET %@ = %@"
                                       @"   WHERE %@ = '%@'"),
                    [tableURL gcsTableName],
                    fieldName,
                    jsonRepresentation,
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
  NSString *sql, *formattedValue;
  BOOL rc;

  rc = NO;

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: tableURL];
  if (channel)
    {
      context = [channel adaptorContext];
      if ([context beginTransaction])
        {
          formattedValue = [[context adaptor] formatValue: jsonRepresentation
                                             forAttribute: textColumn];
          sql = ((defFlags.isNew)
                 ? [self generateSQLForInsert: formattedValue]
                 : [self generateSQLForUpdate: formattedValue]);

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
            tableURL];
    }

  return rc;
}

@end
