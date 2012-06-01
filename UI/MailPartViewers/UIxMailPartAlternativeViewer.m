/*
  Copyright (C) 2007-2009 Inverse inc.
  Copyright (C) 2004 SKYRIX Software AG

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
  id           childInfo;
  NSUInteger   childIndex;
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
  [childInfo release]; childInfo = nil;
  childIndex = 0;
  [super resetBodyInfoCaches];
}

/* part selection */

- (NSArray *) childPartTypes
{
  NSMutableArray *types;
  NSUInteger i, count;
  NSArray  *childParts;

  childParts = [[self bodyInfo] valueForKey:@"parts"];
  count      = [childParts count];
  types      = [NSMutableArray arrayWithCapacity:count];
  
  for (i = 0; i < count; i++) {
    NSString *mt, *st;

    mt = [[[childParts objectAtIndex:i] valueForKey:@"type"] lowercaseString];
    st = [[[childParts objectAtIndex:i] valueForKey:@"subtype"]
	               lowercaseString];
    mt = [[mt stringByAppendingString:@"/"] stringByAppendingString:st];
    [types addObject:mt ? (id)mt : (id)[NSNull null]];
  }
  return types;
}

- (NSUInteger) _preferredTypesPart: (NSArray *) types
{
  NSUInteger count, max;
  NSUInteger part;
  const NSString *priorities[] = { @"multipart/related", @"multipart/mixed",
				   @"text/calendar", @"text/html",
				   @"text/plain" };

  part = NSNotFound;

  max = sizeof (priorities) / sizeof (NSString *);
  for (count = 0; count < max; count++)
    {
      part = [types indexOfObject: priorities[count]];
      if (part != NSNotFound)
	break;
    }

  return part;
}

- (int) _selectPartIndexFromTypes: (NSArray *) _types
{
  /* returns the index of the selected part or NSNotFound */
  NSUInteger count, max, part;

  part = [self _preferredTypesPart: _types];
  if (part == NSNotFound)
    {
      max = [_types count];
      /* then we scan for other text types and choose the first one found */
      for (count = 0; count < max; count++)
	if ([[_types objectAtIndex: count] hasPrefix:@"text/"])
	  {
	    part = count;
	    break;
	  }
    }

  if (part == NSNotFound)
    part = 0; /* as a fallback, we select the first available part */

  return part;
}

- (void) selectChildInfo
{
  NSUInteger idx;

  [childInfo release]; childInfo = nil;
  childIndex = 0;
  
  idx = [self _selectPartIndexFromTypes: [self childPartTypes]];
  if (idx == NSNotFound)
    {
      [self errorWithFormat:@"could not select a part of types: %@",
            [self childPartTypes]];
      return;
    }

  childIndex = idx + 1;
  childInfo  = 
    [[[[self bodyInfo] valueForKey:@"parts"] objectAtIndex:idx] retain];
}

/* accessors */

- (id) childInfo
{
  if (!childInfo)
    [self selectChildInfo];
  
  return childInfo;
}

- (NSUInteger) childIndex
{
  if (!childIndex)
    [self selectChildInfo];
  
  return childIndex - 1;
}

- (NSString *) childPartName
{
  return [NSString stringWithFormat: @"%u",
                   (unsigned int) ([self childIndex] + 1)];
}

- (id) childPartPath
{
  NSArray *pp;

  pp = [self partPath];
  return [pp count] > 0
    ? (id)[pp arrayByAddingObject:[self childPartName]]
    : (id)[NSArray arrayWithObject:[self childPartName]];
}

/* nested viewers */

- (id) contentViewerComponent
{
  id info;
  
  info = [self childInfo];
  return [[[self context] mailRenderingContext] viewerForBodyInfo:info];
}

@end /* UIxMailPartAlternativeViewer */
