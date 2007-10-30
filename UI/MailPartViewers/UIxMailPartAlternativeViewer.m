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
  id           childInfo;
  unsigned int childIndex;
}

@end

@implementation UIxMailPartAlternativeViewer

- (void)dealloc {
  [childInfo release];
  [super dealloc];
}

/* caches */

- (void)resetBodyInfoCaches {
  [childInfo release]; childInfo = nil;
  childIndex = 0;
  [super resetBodyInfoCaches];
}

/* part selection */

- (NSArray *)childPartTypes {
  NSMutableArray *types;
  unsigned i, count;
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
    [types addObject:mt ? mt : (id)[NSNull null]];
  }
  return types;
}

- (int)selectPartIndexFromTypes:(NSArray *)_types {
  /* returns the index of the selected part or NSNotFound */
  unsigned i, count;

  if ((count = [_types count]) == 0)
    return NSNotFound;
  
  if ((i = [_types indexOfObject:@"text/html"]) != NSNotFound)
    return i;
  if ((i = [_types indexOfObject:@"text/plain"]) != NSNotFound)
    return i;

  /* then we scan for other text types and choose the first one found */
  for (i = 0; i < count; i++) {
    if ([(NSString *)[_types objectAtIndex:i] hasPrefix:@"text/"])
      return i;
  }
  
  /* as a fallback, we select the first available part */
  return 0;
}

- (void)selectChildInfo {
  unsigned idx;
  
  [childInfo release]; childInfo = nil;
  childIndex = 0;
  
  idx = [self selectPartIndexFromTypes:[self childPartTypes]];
  if (idx == NSNotFound) {
    [self errorWithFormat:@"could not select a part of types: %@",
            [self childPartTypes]];
    return;
  }
  
  childIndex = idx + 1;
  childInfo  = 
    [[[[self bodyInfo] valueForKey:@"parts"] objectAtIndex:idx] retain];
}

/* accessors */

- (id)childInfo {
  if (childInfo == nil)
    [self selectChildInfo];
  
  return childInfo;
}

- (unsigned int) childIndex {
  if (childIndex == 0)
    [self selectChildInfo];
  
  return childIndex - 1;
}

- (NSString *)childPartName {
  char buf[8];
  sprintf(buf, "%d", [self childIndex] + 1);
  return [NSString stringWithCString:buf];
}

- (id)childPartPath {
  NSArray *pp;

  pp = [self partPath];
  return [pp count] > 0
    ? [pp arrayByAddingObject:[self childPartName]]
    : [NSArray arrayWithObject:[self childPartName]];
}

/* nested viewers */

- (id)contentViewerComponent {
  id info;
  
  info = [self childInfo];
  return [[[self context] mailRenderingContext] viewerForBodyInfo:info];
}

@end /* UIxMailPartAlternativeViewer */
