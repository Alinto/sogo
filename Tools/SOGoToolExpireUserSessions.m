/* SOGoToolExpireUserSessions.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc.
 *
 * Author: Jean Raby <jraby@inverse.ca>
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

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <GDLAccess/EOAdaptorChannel.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/NSURL+GCS.h>

#import <NGExtensions/NSNull+misc.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUserDefaults.h>

#import "SOGoTool.h"

@interface SOGoToolExpireUserSessions : SOGoTool
@end

@implementation SOGoToolExpireUserSessions

+ (void) initialize
{
}

+ (NSString *) command
{
  return @"expire-sessions";
}

+ (NSString *) description
{
  return @"Expires user sessions without activity for specified number of minutes";
}

- (void) usage
{
  fprintf (stderr, "expire-sessions [nbMinutes]\n\n"
	   "       nbMinutes       Number of minutes of inactivity after which a user session will be expired\n"
	   "\n"
     "The expire-sessions action should be configured as a cronjob.\n");
}

- (BOOL) expireUserSessionOlderThan: (int) nbMinutes
{
  BOOL rc;
  EOAdaptorChannel *channel;
  GCSChannelManager *cm;
  NSArray *attrs, *qValues;
  NSDictionary *qresult;
  NSException *ex;
  NSString *sql, *sessionsFolderURL;
  NSURL *tableURL;
  NSUserDefaults *ud;

  unsigned int now, oldest;
  int sessionsToDelete;

  rc=YES;
  ud = [NSUserDefaults standardUserDefaults];
  now = [[NSCalendarDate calendarDate] timeIntervalSince1970];
  oldest = now - (nbMinutes * 60);

  sessionsFolderURL = [ud stringForKey: @"OCSSessionsFolderURL"];
  if (!sessionsFolderURL)
  {
    if (verbose)
      NSLog(@"Couldn't read OCSSessionsFolderURL");
    return rc = NO;
  }

  tableURL = [[NSURL alloc] initWithString: sessionsFolderURL];
  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: tableURL];
  if (!channel)
  {
    /* FIXME: nice error msg */
    NSLog(@"Can't aquire channel");
    return rc=NO;
  }

  sql = [NSString stringWithFormat: @"SELECT count(*) FROM %@ WHERE c_lastseen <= %d",
                        [tableURL gcsTableName], oldest];
  ex = [channel evaluateExpressionX: sql]; 
  if (ex)
  {
    NSLog(@"%@", [ex reason]);
    [ex raise];
    return rc=NO;
  }

  attrs = [channel describeResults: NO];
  /* only one row */
  qresult = [channel fetchAttributes: attrs withZone: NULL];
  qValues = [qresult allValues];
  sessionsToDelete = [[qValues objectAtIndex: 0] intValue];
  if (sessionsToDelete)
  {
    if (verbose)
      NSLog(@"Will be removing %d sessions", sessionsToDelete);
    [channel cancelFetch];
    sql = [NSString stringWithFormat: @"DELETE FROM %@ WHERE c_lastseen <= %d",
                        [tableURL gcsTableName], oldest];
    if (verbose)
      NSLog(@"Removing sessions older than %d minute(s)", nbMinutes);
    ex = [channel evaluateExpressionX: sql]; 
    if (ex)
    {
      NSLog(@"An exception occured while deleting old sessions: %@", [ex reason]);
      [ex raise];
      return rc=NO;
    }
  }
  else
  {
    if (verbose)
      NSLog(@"No session to remove", sessionsToDelete);
  }

  [cm releaseChannel: channel];
  return rc;
}

- (BOOL) run
{
  BOOL rc;
  int sessionExpireMinutes=0;
  
  rc = NO;

  if ([arguments count])
  {
    sessionExpireMinutes = [[arguments objectAtIndex: 0] intValue];
  }

  if (sessionExpireMinutes > 0)
  {
    rc = [self expireUserSessionOlderThan: sessionExpireMinutes];
  }
  else
  {
    [self usage];
  }
  
  return rc;
}

@end
