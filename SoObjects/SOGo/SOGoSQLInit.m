/* SOGoSQLInit.m - this file is part of SOGo
 *
 * Copyright (C) 2013 Wolfgang Sourdeau
 *
 * Author: Wolfgang Sourdeau <Wolfgang@Contre.COM>
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

#import <Foundation/NSBundle.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSAlarmsFolder.h>
#import <GDLContentStore/GCSSessionsFolder.h>

#import "SOGoSystemDefaults.h"

#import "SOGoSQLInit.h"

static BOOL hasCheckedTables = NO;

#warning the following methods should be replaced with helpers in GCSSpecialQueries
static NSString *
SQLScriptForTable (NSString *tableName, NSString *tableType,
                   NSString *fileSuffix)
{
  NSString *tableFile, *descFile;
  NSBundle *bundle;
  unsigned int length;

  bundle = [NSBundle bundleForClass: [SOGoSystemDefaults class]];
  if (!bundle)
    [NSException raise: @"IOException"
                format: @"did not find SOGo framework!"];

  length = [tableType length] - 3;
  tableFile = [tableType substringToIndex: length];
  descFile
    = [bundle pathForResource: [NSString stringWithFormat: @"%@-%@",
					 tableFile, fileSuffix]
	      ofType: @"sql"];
  if (!descFile)
    descFile = [bundle pathForResource: tableFile ofType: @"sql"];

  if (!descFile)
    [NSException raise: @"IOException"
                format: @"did not find sql file for '%@'", tableName];

  return [[NSString stringWithContentsOfFile: descFile]
	   stringByReplacingString: @"@{tableName}"
	   withString: tableName];
}

static void
EnsureTable (GCSChannelManager *cm, NSString *url, NSString *tableType)
{
  NSString *tableName, *fileSuffix, *tableScript;
  EOAdaptorChannel *tc;
  NSURL *channelURL;

  channelURL = [NSURL URLWithString: url];
  fileSuffix = [channelURL scheme];
  tc = [cm acquireOpenChannelForURL: channelURL];

  /* FIXME: make use of [EOChannelAdaptor describeTableNames] instead */
  tableName = [url lastPathComponent];
  if ([tc evaluateExpressionX:
	    [NSString stringWithFormat: @"SELECT count(*) FROM %@",
		      tableName]])
    {
      tableScript = SQLScriptForTable (tableName, tableType, fileSuffix);
      [tc evaluateExpressionX: tableScript];
    }
  else
    [tc cancelFetch];

  [cm releaseChannel: tc];
}

static void
CheckMandatoryTables ()
{
  GCSChannelManager *cm;
  GCSFolderManager *fm;
  NSString *urlStrings[] = {@"SOGoProfileURL", @"OCSFolderInfoURL", nil};
  NSString **urlString;
  NSString *value;
  SOGoSystemDefaults *defaults;
  BOOL ok;

  defaults = [SOGoSystemDefaults sharedSystemDefaults];
  ok = YES;
  cm = [GCSChannelManager defaultChannelManager];

  urlString = urlStrings;
  while (*urlString)
    {
      value = [defaults stringForKey: *urlString];
      if (value)
        EnsureTable (cm, value, *urlString);
      else
	{
	  NSLog (@"No value specified for '%@'", *urlString);
	  ok = NO;
	}
      urlString++;
    }

  if (ok)
    {
      fm = [GCSFolderManager defaultFolderManager];

      // Create the sessions table
      [[fm sessionsFolder] createFolderIfNotExists];
      
      // Create the email alarms table, if required
      if ([defaults enableEMailAlarms])
        [[fm alarmsFolder] createFolderIfNotExists];
    }
  else
      [NSException raise: @"IOException"
                  format: @"a problem occurred during db initialization"];
}

void
SOGoEnsureMandatoryTables()
{
  if (!hasCheckedTables)
    {
      hasCheckedTables = YES;
      CheckMandatoryTables();
    }
}
