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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSProcessInfo.h>

#import <NGObjWeb/SoProductRegistry.h>
#import <NGExtensions/NSObject+Logs.h>

#import "SOGoProductLoader.h"

@implementation SOGoProductLoader

+ (int) sogoMajorVersion
{
  return SOGO_MAJOR_VERSION;
}

+ (int) sogoMinorVersion
{
  return SOGO_MINOR_VERSION;
}

+ (id) productLoader
{
  return [[self new] autorelease];
}

- (id) init
{
  if ((self = [super init]))
    {
      productDirectoryName =
	[[NSString alloc] initWithFormat: @"SOGo-%i.%i",
			  [[self class] sogoMajorVersion],
			  [[self class] sogoMinorVersion]];
    }
  return self;
}

- (void) dealloc
{
  [productDirectoryName release];
  [searchPathes release];
  [super dealloc];
}

/* loading */

- (void) _addCocoaSearchPathesToArray: (NSMutableArray *) ma
{
  id tmp;
  NSEnumerator *e;

  tmp = NSSearchPathForDirectoriesInDomains (NSAllLibrariesDirectory,
					     NSAllDomainsMask,
					     YES);
  if ([tmp count] > 0)
    {
      e = [tmp objectEnumerator];
      while ((tmp = [e nextObject]))
	{
	  tmp = [tmp stringByAppendingPathComponent: productDirectoryName];
	  if (![ma containsObject: tmp])
	    [ma addObject: tmp];
	}
    }
}

- (void) _addGNUstepSearchPathesToArray: (NSMutableArray *) ma
{
  NSEnumerator *libraryPaths;
  NSString *directory;

  libraryPaths = [NSStandardLibraryPaths() objectEnumerator];
  while ((directory = [libraryPaths nextObject]))
    [ma addObject:
	  [directory stringByAppendingPathComponent: productDirectoryName]];
}

- (void) _addFHSPathesToArray: (NSMutableArray *) ma
{
  NSString *s;

  s = @"sogod-0.9";
  [ma addObject: [NSString stringWithFormat: @"/usr/local/lib/%@", s]];
  [ma addObject: [NSString stringWithFormat: @"/usr/lib/%@", s]];
}

- (NSArray *) productSearchPathes
{
  NSMutableArray *ma;

  if (!searchPathes)
    {
      ma = [NSMutableArray arrayWithCapacity: 6];

      [self _addGNUstepSearchPathesToArray: ma];
#if COCOA_Foundation_LIBRARY
      else
	[self _addCocoaSearchPathesToArray: ma];
#endif

      [self _addFHSPathesToArray: ma];

      searchPathes = [ma copy];

      if ([searchPathes count] == 0)
	[self logWithFormat: @"%s: no search pathes were found !",
	      __PRETTY_FUNCTION__];
    }

  return searchPathes;
}

- (void) loadProducts
{
  SoProductRegistry *registry = nil;
  NSFileManager *fm;
  NSEnumerator *pathes;
  NSString *lpath, *bpath, *extension;
  NSEnumerator *productNames;
  NSString *productName;

  registry = [SoProductRegistry sharedProductRegistry];
  fm = [NSFileManager defaultManager];

  pathes = [[self productSearchPathes] objectEnumerator];
  while ((lpath = [pathes nextObject]))
    {
      [self logWithFormat: @"scanning SOGo products in: %@", lpath];

      productNames = [[fm directoryContentsAtPath: lpath] objectEnumerator];
      while ((productName = [productNames nextObject]))
	{
	  extension = [productName pathExtension];
	  if ([extension length] > 0
	      && [extension isEqualToString: @"SOGo"])
	    {
	      bpath = [lpath stringByAppendingPathComponent: productName];
	      [self logWithFormat: @" register SOGo product: %@",
		    productName];
	      [registry registerProductAtPath: bpath];
	    }
	}
    }

  if (![registry loadAllProducts])
    [self warnWithFormat: @"could not load all products !"];
}

@end /* SOGoProductLoader */
