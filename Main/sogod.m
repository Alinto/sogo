/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSTimeZone.h>

#import <NGObjWeb/NGObjWeb.h>
#import "common.h"

int main(int argc, char **argv, char **env)
{
  NSString *tzName;
  NSUserDefaults *ud;
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  [NGBundleManager defaultBundleManager];

  ud = [NSUserDefaults standardUserDefaults];
  tzName = [ud stringForKey: @"SOGoServerTimeZone"];
  if (!tzName)
    tzName = @"Canada/Eastern";
  [NSTimeZone setDefaultTimeZone: [NSTimeZone timeZoneWithName: tzName]];

  WOWatchDogApplicationMain(@"SOGo", argc, (void*)argv);

  [pool release];
  return 0;
}
