/* SOGoFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/SoSelectorInvocation.h>

#import "NSString+Utilities.h"

#import "SOGoFolder.h"

@implementation SOGoFolder

- (id) init
{
  if ((self = [super init]))
    displayName = nil;

  return self;
}

- (void) dealloc
{
  [displayName release];
  [super dealloc];
}

- (void) setDisplayName: (NSString *) newDisplayName
{
  ASSIGN (displayName, newDisplayName);
}

- (NSString *) displayName
{
  return ((displayName) ? displayName : nameInContainer);
}

- (NSString *) folderType
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (id) lookupName: (NSString *) lookupName
        inContext: (id) localContext
          acquire: (BOOL) acquire
{
  id obj;
  NSArray *davNamespaces;
  NSDictionary *davInvocation;
  NSString *objcMethod;

  obj = [super lookupName: lookupName inContext: localContext
	       acquire: acquire];
  if (!obj)
    {
      davNamespaces = [self davNamespaces];
      if ([davNamespaces count] > 0)
	{
	  davInvocation = [lookupName asDavInvocation];
	  if (davInvocation
	      && [davNamespaces
		   containsObject: [davInvocation objectForKey: @"ns"]])
	    {
	      objcMethod = [[davInvocation objectForKey: @"method"]
			     davMethodToObjC];
	      obj = [[SoSelectorInvocation alloc]
		      initWithSelectorNamed:
			[NSString stringWithFormat: @"%@:", objcMethod]
		      addContextParameter: YES];
	      [obj autorelease];
	    }
	}
    }

  return obj;
}

- (BOOL) isFolderish
{
  return YES;
}

- (NSString *) httpURLForAdvisoryToUser: (NSString *) uid
{
  return [[self soURL] absoluteString];
}

- (NSString *) resourceURLForAdvisoryToUser: (NSString *) uid
{
  return [[self davURL] absoluteString];
}

/* WebDAV */

- (NSArray *) davNamespaces
{
  return nil;
}

- (BOOL) davIsCollection
{
  return [self isFolderish];
}

- (NSString *) davContentType
{
  return @"httpd/unix-directory";
}

/* folder type */

- (NSString *) outlookFolderClass
{
  [self subclassResponsibility: _cmd];

  return nil;
}

/* acls */

- (NSArray *) aclsForUser: (NSString *) uid
{
  return nil;
}

@end
