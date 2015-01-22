/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2006-2015 Inverse inc.

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

#include <unistd.h>
#include <sys/types.h>

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import <NGObjWeb/SoApplication.h>

#import <SOGo/SOGoSystemDefaults.h>

int
main (int argc, char **argv, char **env)
{
  NSAutoreleasePool *pool;
  SOGoSystemDefaults *sd;
  int rc;

  /* Here we work around a bug in GNUstep which decode XML user defaults using
     the system encoding, rather than honouring the encoding specified in the
     file. */
  putenv ("GNUSTEP_STRING_ENCODING=NSUTF8StringEncoding");

  pool = [NSAutoreleasePool new];

  if (getuid() > 0)
    {
      rc = 0;
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      [NSTimeZone setDefaultTimeZone: [sd timeZone]];
      WOWatchDogApplicationMain (@"SOGo", argc, (void *) argv);
    }
  else
    {
      rc = -1;
      NSLog (@"Don't run SOGo as root!");
    }

  [pool release];

  return rc;
}
