/* SOGoToolCleanOpenIdSessions.m - this file is part of SOGo
 *
 * Copyright (C) 2012-2021 Inverse inc.
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSUserDefaults.h>

#import <GDLAccess/EOAdaptorChannel.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/NSURL+GCS.h>

#import <NGExtensions/NSNull+misc.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoSession.h>
#import <SOGo/SOGoOpenIdSession.h>

#import "SOGoTool.h"

@interface SOGoToolCleanOpenIdSessions : SOGoTool
@end

@implementation SOGoToolCleanOpenIdSessions

+ (NSString *) command
{
  return @"clean-openid-sessions";
}

+ (NSString *) description
{
  return @"clean user openid sessions that are expired";
}

- (void) usage
{
  fprintf (stderr, "clean-openid-sessions\n\n"
	   "\n"
     "The clean-openid-sessions action should be configured as a cronjob.\n");
}

- (BOOL) cleanExpiredOpenIdSession
{
  BOOL rc;
  EOAdaptorChannel *channel;
  GCSChannelManager *cm;
  NSArray *attrs;
  NSDictionary *qresult;
  NSException *ex;
  NSString *sql, *sessionsFolderURL, *sessionID;
  NSURL *tableURL;
  NSUserDefaults *ud;

  unsigned int now;

  rc = YES;
  ud = [NSUserDefaults standardUserDefaults];
  now = [[NSCalendarDate calendarDate] timeIntervalSince1970];
  sessionID = nil;

  sessionsFolderURL = [ud stringForKey: @"OCSOpenIdURL"];
  if (!sessionsFolderURL)
  {
    if (verbose)
      NSLog(@"Couldn't read OCSOpenIdURL");
    return rc = NO;
  }

  tableURL = [[NSURL alloc] initWithString: sessionsFolderURL];
  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: tableURL];
  if (!channel)
  {
    /* FIXME: nice error msg */
    NSLog(@"Can't acquire channel");
    return rc = NO;
  }

  sql = [NSString stringWithFormat: @"SELECT c_user_session FROM %@ WHERE c_access_token_expires_in <= %d AND c_refresh_token_expires_in <= %d",
                  [tableURL gcsTableName], now, now];
  ex = [channel evaluateExpressionX: sql]; 
  if (ex)
  {
    NSLog(@"%@", [ex reason]);
    [ex raise];
    return rc = NO;
  }

  attrs = [channel describeResults: NO];
  while ((qresult = [channel fetchAttributes: attrs withZone: NULL]))
    {
      sessionID = [qresult objectForKey: @"c_user_session"];
      if (sessionID)
        {
          if (verbose)
            NSLog(@"Removing session %@", sessionID);
          [SOGoOpenIdSession deleteValueForSessionKey: sessionID];
        }
    }
  [cm releaseChannel: channel  immediately: YES];

  if (verbose && sessionID == nil)
    NSLog(@"No session to remove on openId table");

  return rc;
}

- (BOOL) run
{
  BOOL rc;

  rc = [self cleanExpiredOpenIdSession];

  return rc;
}

@end
