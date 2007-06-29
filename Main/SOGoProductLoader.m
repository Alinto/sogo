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

+ (int)sogoMajorVersion {
  return SOGO_MAJOR_VERSION;
}
+ (int)sogoMinorVersion {
  return SOGO_MINOR_VERSION;
}

+ (id)productLoader {
  return [[[self alloc] init] autorelease];
}

- (id)init {
  if ((self = [super init])) {
    self->productDirectoryName =
      [[NSString alloc] initWithFormat:@"SOGo-%i.%i", 
	[[self class] sogoMajorVersion],
	[[self class] sogoMinorVersion]];
  }
  return self;
}

- (void)dealloc {
  [self->productDirectoryName release];
  [self->searchPathes release];
  [super dealloc];
}

/* loading */

- (void)_addCocoaSearchPathesToArray:(NSMutableArray *)ma {
  id tmp;

  tmp = NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory,
                                            NSAllDomainsMask,
                                            YES);
  if ([tmp count] > 0) {
    NSEnumerator *e;
      
    e = [tmp objectEnumerator];
    while ((tmp = [e nextObject])) {
      tmp = [tmp stringByAppendingPathComponent:self->productDirectoryName];
      if (![ma containsObject:tmp])
        [ma addObject:tmp];
    }
  }
}

- (void)_addGNUstepSearchPathesToArray:(NSMutableArray *)ma {
  NSDictionary *env;
  id tmp;
  
  env = [[NSProcessInfo processInfo] environment];
  if ((tmp = [env objectForKey:@"GNUSTEP_PATHPREFIX_LIST"]) == nil)
    tmp = [env objectForKey:@"GNUSTEP_PATHLIST"];
  
  tmp = [tmp componentsSeparatedByString:@":"];
  if ([tmp count] > 0) {
    NSEnumerator *e;
      
    e = [tmp objectEnumerator];
    while ((tmp = [e nextObject])) {
      tmp = [tmp stringByAppendingPathComponent:@"Library"];
      tmp = [tmp stringByAppendingPathComponent:self->productDirectoryName];
      if (![ma containsObject:tmp])
        [ma addObject:tmp];
    }
  }
  else {
    NSLog(@"%s: empty library search path !", __PRETTY_FUNCTION__);
  }
}

- (void)_addFHSPathesToArray:(NSMutableArray *)ma {
  NSString *s;

  s = @"sogod-0.9";
  [ma addObject:[@"/usr/local/lib/" stringByAppendingString:s]];
  [ma addObject:[@"/usr/lib/"       stringByAppendingString:s]];
}

- (NSArray *)productSearchPathes {
  NSMutableArray *ma;
  BOOL hasGNUstepEnv;
  
  if (self->searchPathes != nil)
    return self->searchPathes;

  hasGNUstepEnv = [[[[NSProcessInfo processInfo] environment]
		     objectForKey:@"GNUSTEP_USER_ROOT"] length] > 0 ? YES : NO;
  
  ma  = [NSMutableArray arrayWithCapacity:6];
  
  if (hasGNUstepEnv)
    [self _addGNUstepSearchPathesToArray:ma];
#if COCOA_Foundation_LIBRARY
  else
    [self _addCocoaSearchPathesToArray:ma];
#endif

  [self _addFHSPathesToArray:ma];
  
  self->searchPathes = [ma copy];
  
  if ([self->searchPathes count] == 0) {
    [self logWithFormat:@"%s: no search pathes were found !", 
	  __PRETTY_FUNCTION__];
  }
  
  return self->searchPathes;
}

- (void)loadProducts {
  SoProductRegistry *registry = nil;
  NSFileManager *fm;
  NSEnumerator  *pathes;
  NSString      *lpath;
  
  registry = [SoProductRegistry sharedProductRegistry];
  fm       = [NSFileManager defaultManager];
 
  pathes = [[self productSearchPathes] objectEnumerator];
  while ((lpath = [pathes nextObject]) != nil) {
    NSEnumerator *productNames;
    NSString *productName;

    [self logWithFormat:@"scanning SOGo products in: %@", lpath];

    productNames = [[fm directoryContentsAtPath:lpath] objectEnumerator];
    
    while ((productName = [productNames nextObject]) != nil) {
      NSString *bpath;

      if ([[productName pathExtension] length] == 0)
	/* filter out directories without extensions */
	continue;
      
      bpath = [lpath stringByAppendingPathComponent:productName];
      [self logWithFormat:@"  register SOGo product: %@", 
              [bpath lastPathComponent]];
      [registry registerProductAtPath:bpath];
    }
  }
  
  if (![registry loadAllProducts])
    [self warnWithFormat:@"could not load all products !"];
}

@end /* SOGoProductLoader */
