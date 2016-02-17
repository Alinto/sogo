/* teststrings.m - this file is part of SOGO
 *
 * Copyright (C) 2010 Inverse inc.
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

#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>

#include <SOGo/NSDictionary+Utilities.h>

static int
performTest (char *filename)
{
  NSDictionary *testDict;
  NSString *nsFilename;
  int rc;

  nsFilename = [NSString stringWithFormat: @"%s", filename];
  NS_DURING
    {
      testDict = [NSDictionary dictionaryFromStringsFile: nsFilename];
      if ([testDict count] == 0)
        {
          NSLog (@"Bad or empty strings file");
          rc = 2;
          testDict = nil;
        }
      else
        rc = 0;
    }
  NS_HANDLER
    {
      NSLog (@"An exception was caught: %@", localException);
      rc = 1;
      testDict = nil;
    }
  NS_ENDHANDLER;

  return rc;
}

int
main (int argc, char *argv[])
{
  NSAutoreleasePool *pool;
  int rc;

  pool = [NSAutoreleasePool new];

  if (argc == 2)
    {
      rc = performTest (argv[1]);
    }
  else
    {
      NSLog (@"Usage: %s file.strings", argv[0]);
      rc = 1;
    }

  [pool release];

  return rc;
}
