/* sogo-ab-checkdoubles.m - this file is part of SOGo
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

/* TODO:
   - NSUserDefaults bootstrapping for using different backends
   - make sure we don't end up using 3000 different channels because of the
   amount of tables we need to wander */

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>

typedef void (*NSUserDefaultsInitFunction) ();

static unsigned int ContactsCountWarningLimit = 1000;

// static void
// NSLogInhibitor (NSString *message)
// {
// }

@interface SOGoDoublesChecker : NSObject

- (BOOL) run;

@end

@implementation SOGoDoublesChecker

+ (void) initialize
{
  NSUserDefaults *ud;
  NSNumber *warningLimit;

//   _NSLog_printf_handler = NSLogInhibitor;

  ud = [NSUserDefaults standardUserDefaults];
  [ud addSuiteNamed: @"sogod"];
  warningLimit = [ud objectForKey: @"SOGoContactsCountWarningLimit"];
  if (warningLimit)
    ContactsCountWarningLimit = [warningLimit unsignedIntValue];

  fprintf (stderr, "The warning limit for folder records is set at %u\n",
	   ContactsCountWarningLimit);
}

- (void) processIndexResults: (EOAdaptorChannel *) channel
		     withFoM: (GCSFolderManager *) fom
{
  NSArray *attrs;
  NSDictionary *folderRow;
  GCSFolder *currentFolder;
  NSString *folderPath;
  unsigned int recordsCount;

  attrs = [channel describeResults: NO];
  while ((folderRow = [channel fetchAttributes: attrs withZone: NULL]))
    {
      folderPath = [folderRow objectForKey: @"c_path"];
      currentFolder = [fom folderAtPath: folderPath];
      if (currentFolder)
	{
	  recordsCount = [currentFolder recordsCountByExcludingDeleted: YES];
	  if (recordsCount > ContactsCountWarningLimit)
	    {
	      fprintf (stderr, "'%s' (id: '%s'), of '%s': %u entries\n",
		       [[folderRow objectForKey: @"c_foldername"]
			 cStringUsingEncoding: NSUTF8StringEncoding],
		       [[currentFolder folderName]
			 cStringUsingEncoding: NSUTF8StringEncoding],
		       [[folderRow objectForKey: @"c_path2"]
			 cStringUsingEncoding: NSUTF8StringEncoding],
		       recordsCount);
	    }
	}
      else
	fprintf (stderr, "folder at path '%s' could not be opened\n",
		 [folderPath cStringUsingEncoding: NSUTF8StringEncoding]);
    }
}

- (BOOL) processWithFoM: (GCSFolderManager *) fom
{
  BOOL rc;
  NSString *sqlString;
  GCSChannelManager *cm;
  EOAdaptorChannel *channel;
  NSException *ex;

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: [fom folderInfoLocation]];
  if (channel)
    {
      sqlString
        = [NSString stringWithFormat: @"SELECT c_path, c_path2, c_foldername"
                    @" FROM %@"
                    @" WHERE c_folder_type = 'Contact'",
                    [fom folderInfoTableName]];
      ex = [channel evaluateExpressionX: sqlString];
      if (ex)
	{
	  fprintf (stderr, "an exception occured during the fetching of folder names");
	  [ex raise];
	  rc = NO;
	}
      else
	{
	  rc = YES;
	  [self processIndexResults: channel withFoM: fom];
	}

      [cm releaseChannel: channel];
    }
  else
    {
      fprintf (stderr, "could not open channel");
      rc = NO;
    }

  return rc;
}

- (BOOL) run
{
  GCSFolderManager *fom;
  BOOL rc;

  fom = [GCSFolderManager defaultFolderManager];
  if (fom)
    rc = [self processWithFoM: fom];
  else
    rc = NO;

  return rc;
}

@end

int
main (int argc, char **argv, char **env)
{
  NSAutoreleasePool *pool;
  SOGoDoublesChecker *checker;
  int rc;

  rc = 0;

  pool = [NSAutoreleasePool new];

  checker = [SOGoDoublesChecker new];
  if ([checker run])
    rc = 0;
  else
    rc = -1;
  [checker release];

  [pool release];

  return rc;
}
