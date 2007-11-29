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

#import <SaxObjC/XMLNamespaces.h>

#import "NSString+Utilities.h"

#import "SOGoPermissions.h"
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

/* sorting */
- (NSComparisonResult) _compareByOrigin: (SOGoFolder *) otherFolder
{
  NSArray *thisElements, *otherElements;
  unsigned thisCount, otherCount;
  NSComparisonResult comparison;

  thisElements = [nameInContainer componentsSeparatedByString: @"_"];
  otherElements = [[otherFolder nameInContainer]
		    componentsSeparatedByString: @"_"];
  thisCount = [thisElements count];
  otherCount = [otherElements count];
  if (thisCount == otherCount)
    {
      if (thisCount == 1)
	comparison = NSOrderedSame;
      else
	comparison = [[thisElements objectAtIndex: 0]
		       compare: [otherElements objectAtIndex: 0]];
    }
  else
    {
      if (thisCount > otherCount)
	comparison = NSOrderedDescending;
      else
	comparison = NSOrderedAscending;
    }

  return comparison;
}

- (NSComparisonResult) _compareByNameInContainer: (SOGoFolder *) otherFolder
{
  NSString *otherName;
  NSComparisonResult comparison;

  otherName = [otherFolder nameInContainer];
  if ([nameInContainer hasSuffix: @"personal"])
    {
      if ([otherName hasSuffix: @"personal"])
	comparison = [nameInContainer compare: otherName];
      else
	comparison = NSOrderedAscending;
    }
  else
    {
      if ([otherName hasSuffix: @"personal"])
	comparison = NSOrderedDescending;
      else
	comparison = NSOrderedSame;
    }

  return comparison;
}

- (NSComparisonResult) compare: (id) otherFolder
{
  NSComparisonResult comparison;

  comparison = [self _compareByOrigin: otherFolder];
  if (comparison == NSOrderedSame)
    {
      comparison = [self _compareByNameInContainer: otherFolder];
      if (comparison == NSOrderedSame)
	comparison
	  = [[self displayName]
	      localizedCaseInsensitiveCompare: [otherFolder displayName]];
    }

  return comparison;
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

- (NSArray *) davResourceType
{
  NSArray *rType, *groupDavCollection;

  if ([self respondsToSelector: @selector (groupDavResourceType)])
    {
      groupDavCollection
	= [NSArray arrayWithObjects: [self groupDavResourceType],
		   XMLNS_GROUPDAV, nil];
      rType = [NSArray arrayWithObjects: @"collection", groupDavCollection,
		       nil];
    }
  else
    rType = [NSArray arrayWithObject: @"collection"];

  return rType;
}

/* folder type */

- (BOOL) isEqual: (id) otherFolder
{
  return ([otherFolder class] == [self class]
	  && [container isEqual: [otherFolder container]]
	  && [nameInContainer
	       isEqualToString: [otherFolder nameInContainer]]);
}

- (NSString *) outlookFolderClass
{
  [self subclassResponsibility: _cmd];

  return nil;
}

/* acls */

- (NSArray *) subscriptionRoles
{
  return [NSArray arrayWithObjects: SoRole_Owner, SOGoRole_ObjectViewer,
		  SOGoRole_ObjectEditor, SOGoRole_ObjectCreator,
 SOGoRole_ObjectEraser, nil];
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  return nil;
}

@end
