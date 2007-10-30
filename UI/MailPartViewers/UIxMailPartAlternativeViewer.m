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

#import <Foundation/NSNull.h>

#import <NGExtensions/NSObject+Logs.h>

#import <UI/MailerUI/WOContext+UIxMailer.h>

#import "UIxMailPartViewer.h"
#import "UIxMailRenderingContext.h"

/*
  UIxMailPartAlternativeViewer
  
  Display multipart/alternative parts. Most common application is for messages
  which contain text/html and text/plain, but it is also used in other
  contexts, eg in OGo appointment mails.
  
  TODO: We might want to give the user the possibility to access all parts
        of the alternative set.
*/

@interface UIxMailPartAlternativeViewer : UIxMailPartViewer
{
  id childInfo;
  unsigned int childIndex;
}

@end

@implementation UIxMailPartAlternativeViewer

- (void) dealloc
{
  [childInfo release];
  [super dealloc];
}

/* caches */

- (void) resetBodyInfoCaches
{
  [childInfo release];
  childInfo = nil;
  childIndex = 0;

  [super resetBodyInfoCaches];
}

/* part selection */

- (NSArray *) childPartTypes
{
  NSMutableArray *types;
  NSArray *childParts;
  NSEnumerator *allParts;
  NSString *mt, *st;
  NSDictionary *currentPart;

  types = [NSMutableArray array];

  childParts = [[self bodyInfo] valueForKey: @"parts"];
  allParts = [childParts objectEnumerator];

  while ((currentPart = [allParts nextObject]))
    {
      mt = [[currentPart valueForKey:@"type"] lowercaseString];
      st = [[currentPart valueForKey:@"subtype"] lowercaseString];
      [types addObject: [NSString stringWithFormat: @"%@/%@", mt, st]];
    }

  return types;
}

- (int) selectPartIndexFromTypes: (NSArray *) types
{
  /* returns the index of the selected part or NSNotFound */
  unsigned int count, max;
  int index;

  index = -1;

  max = [types count];
  if (max > 0)
    {
      index = [types indexOfObject: @"text/html"];
      if (index == NSNotFound)
	{
	  index = [types indexOfObject: @"text/plain"];
	  if (index == NSNotFound)
	    {
	      count = 0;
	      while (index == -1
		     && count < max)
		if ([[types objectAtIndex: count] hasPrefix: @"text/"])
		  index = count;
		else
		  count++;
	      if (index == -1)
		index = 0;
	    }
	}
      else
	index = count;
    }
  else
    index = NSNotFound;

  return index;
}

- (void) selectChildInfo
{
  int idx;
  
  [childInfo release];
  childInfo = nil;
  childIndex = 0;
  
  idx = [self selectPartIndexFromTypes: [self childPartTypes]];
  if (idx == NSNotFound)
    [self errorWithFormat: @"could not select a part of types: %@",
	  [self childPartTypes]];
  else
    {
      childIndex = idx + 1;
      childInfo = [[[self bodyInfo] valueForKey:@"parts"] objectAtIndex: idx];
      [childInfos retain];
    }
}

/* accessors */

- (id) childInfo
{
  if (!childInfo)
    [self selectChildInfo];
  
  return childInfo;
}

- (unsigned int) childIndex
{
  if (!childIndex)
    [self selectChildInfo];

  return childIndex - 1;
}

- (NSString *) childPartName
{
  return [NSString stringWithFormat: @"%d", ([self childIndex] + 1)];
}

- (id) childPartPath
{
  NSArray *pp;

  pp = [self partPath];

  return [pp count] > 0
    ? [pp arrayByAddingObject: [self childPartName]]
    : [NSArray arrayWithObject: [self childPartName]];
}

/* nested viewers */

- (id) contentViewerComponent
{
  id info;
  
  info = [self childInfo];

  return [[context mailRenderingContext] viewerForBodyInfo:info];
}

@end /* UIxMailPartAlternativeViewer */
