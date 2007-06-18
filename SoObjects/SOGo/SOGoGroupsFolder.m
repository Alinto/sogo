/*
  Copyright (C) 2004 SKYRIX Software AG

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

#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSObject+Logs.h>

#import "SOGoGroupsFolder.h"

@implementation SOGoGroupsFolder

// - (void)dealloc {
//   [super dealloc];
// }

/* accessors */

/* SOPE */

- (BOOL) isFolderish
{
  return YES;
}

/* looking up shared objects */

- (SOGoGroupsFolder *) lookupGroupsFolder
{
  return self;
}

/* pathes */

/* name lookup */

- (id) customGroup: (NSString *) _key
	 inContext: (id) _ctx
{
  static Class groupClass = Nil;
  id group;

  if (!groupClass)
    groupClass = NSClassFromString(@"SOGoCustomGroupFolder");
  if (!groupClass)
    {
      [self logWithFormat:@"ERROR: missing SOGoCustomGroupFolder class!"];
      group = nil;
    }
  else
    group = [groupClass objectWithName: _key inContainer: self];

  return group;
}

- (id) lookupName: (NSString *) _key
	inContext: (id) _ctx
	  acquire: (BOOL) _flag
{
  id obj;
  
  /* first check attributes directly bound to the application */
  obj = [super lookupName: _key inContext: _ctx acquire: NO];
  if (!obj)
    {
      if ([_key hasPrefix: @"_custom_"])
	obj = [self customGroup: _key inContext: _ctx];
      else
	obj = [NSException exceptionWithHTTPStatus:404 /* Not Found */];
    }

  return obj;
}

@end /* SOGoGroupsFolder */
