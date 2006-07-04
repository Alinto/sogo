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

#include <SOGoUI/UIxComponent.h>

@interface UIxMailTree : UIxComponent
{
  NSString *rootClassName;
  NSString *treeFolderAction;
  id rootNodes;
  id item;
}
@end

#include "UIxMailTreeBlock.h"
#include <SoObjects/Mailer/SOGoMailBaseObject.h>
#include <SoObjects/Mailer/SOGoMailAccount.h>
#include "common.h"
#include <NGObjWeb/SoComponent.h>
#include <NGObjWeb/SoObject+SoDAV.h>

/*
  Support special icons:
    tbtv_leaf_corner_17x17.gif
    tbtv_inbox_17x17.gif
    tbtv_drafts_17x17.gif
    tbtv_sent_17x17.gif
    tbtv_trash_17x17.gif
*/

@interface NSString(DotCutting)

- (NSString *)stringByCuttingOffAtDotsWhenExceedingLength:(int)_maxLength;

- (NSString *)titleForSOGoIMAP4String;

@end

@implementation UIxMailTree

static BOOL debugBlocks = NO;

+ (void)initialize {
  [UIxMailTreeBlock class]; // ensure that globals are initialized
}

- (void)dealloc {
  [self->treeFolderAction release];
  [self->rootClassName    release];
  [self->rootNodes release];
  [self->item      release];
  [super dealloc];
}

/* icons */

- (NSString *)defaultIconName {
  return @"tbtv_leaf_corner_17x17.gif";
}

- (NSString *)iconNameForType:(NSString *)_type {
  if (![_type isNotNull])
    return [self defaultIconName];
  
  //return @"tbtv_drafts_17x17.gif";
  
  return [self defaultIconName];
}

/* accessors */

- (void)setRootClassName:(id)_rootClassName {
  ASSIGNCOPY(self->rootClassName, _rootClassName);
}
- (id)rootClassName {
  return self->rootClassName;
}

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (void)setTreeFolderAction:(NSString *)_action {
  ASSIGNCOPY(self->treeFolderAction, _action);
}
- (NSString *)treeFolderAction {
  return self->treeFolderAction;
}

- (NSString *)itemIconName {
  // TODO: only called once!
  NSString *ftype;
  
  ftype = [[self item] valueForKey:@"outlookFolderClass"];
  return [self iconNameForType:ftype];
}

/* fetching subfolders */

- (NSArray *)fetchSubfoldersOfObject:(id)_object {
  /* Walk over toManyRelationshipKeys and lookup the controllers for them. */
  NSMutableArray *ma;
  NSArray  *names;
  unsigned i, count;
  
  if ((names = [_object toManyRelationshipKeys]) == nil) {
    if (debugBlocks) [self logWithFormat:@"no to-many: %@", _object];
    return nil;
  }
  
  if (debugBlocks) {
    [self logWithFormat:@"to-many: %@ %@", _object,
	  [names componentsJoinedByString:@","]];
  }
  
  count = [names count];
  ma    = [NSMutableArray arrayWithCapacity:(count + 1)];
  for (i = 0; i < count; i++) {
    id folder;
    
    // TODO: use some context or reuse the main context?
    folder = [_object lookupName:[names objectAtIndex:i] inContext:nil 
		      acquire:NO];
    if (folder == nil) {
      if (debugBlocks) {
	[self logWithFormat:@"  DID NOT FIND FOLDER %@: %@",
	        _object,
	        [names objectAtIndex:i]];
      }
      continue;
    }
    if ([folder isKindOfClass:[NSException class]]) {
      if (debugBlocks) {
	[self logWithFormat:@"  FOLDER LOOKUP EXCEPTION %@: %@",
	        [names objectAtIndex:i], folder];
      }
      continue;
    }
    
    [ma addObject:folder];
  }
  if (debugBlocks)
    [self logWithFormat:@"  returning: %@ %@", _object, ma];
  return ma;
}

/* navigation nodes */

- (BOOL)isRootObject:(id)_object {
  if (![_object isNotNull]) {
    [self warnWithFormat:@"(%s): got to root by nil lookup ...",
            __PRETTY_FUNCTION__];
    return YES;
  }

  if ([_object isKindOfClass:NSClassFromString(@"SOGoUserFolder")])
    return YES;
  
  return [_object isKindOfClass:NSClassFromString([self rootClassName])];
}

- (NSString *)treeNavigationLinkForObject:(id)_object atDepth:(int)_depth {
  NSString *link;
  unsigned i;
  
  link = [[_object nameInContainer] stringByAppendingString:@"/"];
  link = [link stringByAppendingString:[self treeFolderAction]];
  
  switch (_depth) {
  case 0: return link;
  case 1: return [@"../"       stringByAppendingString:link];
  case 2: return [@"../../"    stringByAppendingString:link];
  case 3: return [@"../../../" stringByAppendingString:link];
  }
  
  for (i = 0; i < _depth; i++)
    link = [@"../" stringByAppendingString:link];
  return link;
}

- (void)getTitle:(NSString **)_t andIcon:(NSString **)_icon
  forObject:(id)_object
{
  // TODO: need to refactor for reuse!
  NSString *ftype;
  unsigned len;
  
  ftype = [_object valueForKey:@"outlookFolderClass"];
  len   = [ftype length];
  
  switch (len) {
  case 8:
    if ([ftype isEqualToString:@"IPF.Sent"]) {
      *_t = [self labelForKey:@"SentFolderName"];
      *_icon = @"tbtv_sent_17x17.gif";
      return;
    }
    break;
  case 9:
    if ([ftype isEqualToString:@"IPF.Inbox"]) {
      *_t = [self labelForKey:@"InboxFolderName"];
      *_icon = @"tbtv_inbox_17x17.gif";
      return;
    }
    if ([ftype isEqualToString:@"IPF.Trash"]) {
      *_t = [self labelForKey:@"TrashFolderName"];
      *_icon = @"tbtv_trash_17x17.gif";
      return;
    }
    break;
  case 10:
    if ([ftype isEqualToString:@"IPF.Drafts"]) {
      *_t = [self labelForKey:@"DraftsFolderName"];
      *_icon = @"tbtv_drafts_17x17.gif";
      return;
    }
    if ([ftype isEqualToString:@"IPF.Filter"]) {
      *_t = [self labelForKey:@"SieveFolderName"];
      *_icon = nil;
      return;
    }
    break;
  }

  *_t    = [_object davDisplayName];
  *_icon = nil;
  
  if ([_object isKindOfClass:NSClassFromString(@"SOGoMailFolder")])
    *_icon = nil;
  else if ([_object isKindOfClass:NSClassFromString(@"SOGoMailAccount")]) {
    *_icon = @"tbtv_inbox_17x17.gif";
    
    /* title processing is somehow Agenor specific and should be done in UI */
    *_t = [[_object nameInContainer] titleForSOGoIMAP4String];
  }
  else if ([_object isKindOfClass:NSClassFromString(@"SOGoMailAccounts")])
    *_icon = @"tbtv_inbox_17x17.gif";
  else if ([_object isKindOfClass:NSClassFromString(@"SOGoUserFolder")])
    *_icon = @"tbtv_inbox_17x17.gif";
  else {
    // TODO: use drafts icon for other SOGo folders
    *_icon = @"tbtv_drafts_17x17.gif";
  }

  NSLog (@"title: '%@', ftype: '%@', class: '%@', icon: '%@'",
	 *_t,
	 ftype, NSStringFromClass([_object class]), *_icon);
  
  return;
}

- (UIxMailTreeBlock *)treeNavigationBlockForLeafNode:(id)_o atDepth:(int)_d {
  UIxMailTreeBlock *md;
  NSString *n, *i;
  id blocks;
  
  /* 
     Trigger plus in treeview if it has subfolders. It is an optimization that
     we do not generate blocks for folders which are not displayed anyway.
  */
  blocks = [[_o toManyRelationshipKeys] count] > 0
    ? UIxMailTreeHasChildrenMarker
    : nil;
  
  [self getTitle:&n andIcon:&i forObject:_o];

  md = [UIxMailTreeBlock blockWithName:nil
			 title:n iconName:i
			 link:[self treeNavigationLinkForObject:_o atDepth:_d]
			 isPathNode:NO isActiveNode:NO
			 childBlocks:blocks];
  return md;
}

- (UIxMailTreeBlock *)treeNavigationBlockForRootNode:(id)_object {
  /*
     This generates the block for the root object (root of the tree, we get
     there by walking up the chain starting with the client object).
  */
  UIxMailTreeBlock *md;
  NSMutableArray   *blocks;
  NSArray          *folders;
  NSString         *title, *icon;
  unsigned         i, count;

  if (debugBlocks) {
    [self logWithFormat:@"block for root node 0x%08X<%@>", 
	    _object, NSStringFromClass([_object class])];
  }
  
  /* process child folders */
  
  folders = [self fetchSubfoldersOfObject:_object];
  count   = [folders count];
  blocks  = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    id block;
    
    block = [self treeNavigationBlockForLeafNode:[folders objectAtIndex:i]
		  atDepth:0];
    if ([block isNotNull]) [blocks addObject:block];
  }
  if ([blocks count] == 0)
    blocks = nil;
  
  /* build block */
  
  [self getTitle:&title andIcon:&icon forObject:_object];

  md = [UIxMailTreeBlock blockWithName:[_object nameInContainer]
			 title:title iconName:icon
			 link:[@"../" stringByAppendingString:
				  [_object nameInContainer]]
			 isPathNode:YES isActiveNode:YES
			 childBlocks:blocks];
  return md;
}

- (UIxMailTreeBlock *)treeNavigationBlockForActiveNode:(id)_object {
  /* 
     This generates the block for the clientObject (the object which has the 
     focus)
  */
  UIxMailTreeBlock *md;
  NSMutableArray   *blocks;
  NSArray  *folders;
  NSString *title, *icon;
  unsigned i, count;

  // TODO: maybe we can join the two implementations, this might not be
  //       necessary
  if ([self isRootObject:_object]) /* we are at the top */
    return [self treeNavigationBlockForRootNode:_object];
  
  if (debugBlocks) {
    [self logWithFormat:@"block for active node 0x%08X<%@> - %@", 
	    _object, NSStringFromClass([_object class]),
	    [_object davDisplayName]];
  }
  
  /* process child folders */
  
  folders = [self fetchSubfoldersOfObject:_object];
  count   = [folders count];
  blocks  = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    UIxMailTreeBlock *block;
    
    block = [self treeNavigationBlockForLeafNode:[folders objectAtIndex:i]
		  atDepth:0];
    if ([block isNotNull]) [blocks addObject:block];
  }
  if ([blocks count] == 0) blocks = nil;
  
  /* build block */
  
  [self getTitle:&title andIcon:&icon forObject:_object];
  md = [UIxMailTreeBlock blockWithName:[_object nameInContainer]
			 title:title iconName:icon
			 link:@"."
			 isPathNode:YES isActiveNode:YES
			 childBlocks:blocks];
  return md;
}

- (UIxMailTreeBlock *)treeNavigationBlockForObject:(id)_object
  withActiveChildBlock:(UIxMailTreeBlock *)_activeChildBlock 
  depth:(int)_depth
{
  /*
    Note: 'activeChildBlock' here doesn't mean that the block is the selected
          folder in the tree. Its just the element which is active in the
	  list of subfolders.
  */
  UIxMailTreeBlock *resultBlock;
  NSMutableArray   *blocks;
  NSString         *activeName;
  NSArray          *folders;
  NSString         *title, *icon;
  unsigned         i, count;
  
  activeName = [_activeChildBlock valueForKey:@"name"];
  
  /* process child folders */
  
  folders = [self fetchSubfoldersOfObject:_object];
  count   = [folders count];
  blocks  = [NSMutableArray arrayWithCapacity:count == 0 ? 1 : count];
  for (i = 0; i < count; i++) {
    UIxMailTreeBlock *block;
    id folder;
    
    NSLog(@"activeName: %@", activeName);
    folder = [folders objectAtIndex:i];
    block = [activeName isEqualToString:[folder nameInContainer]]
      ? _activeChildBlock
      : [self treeNavigationBlockForLeafNode:folder atDepth:_depth];
    
    if ([block isNotNull]) [blocks addObject:block];
  }
  if ([blocks count] == 0) {
    if (_activeChildBlock != nil) // if the parent has no proper fetchmethod!
      [blocks addObject:_activeChildBlock];
    else
      blocks = nil;
  }
  
  /* build block */
  
  [self getTitle:&title andIcon:&icon forObject:_object];
  resultBlock = [UIxMailTreeBlock blockWithName:[_object nameInContainer]
				  title:title iconName:icon
				  link:
				    [self treeNavigationLinkForObject:_object 
					  atDepth:(_depth + 1)] 
				  isPathNode:YES isActiveNode:NO
				  childBlocks:blocks];
  
  /* recurse up unless we are at the root */

  if ([self isRootObject:_object]) /* we are at the top */
    return resultBlock;
  
  return [self treeNavigationBlockForObject:[_object container] 
	       withActiveChildBlock:resultBlock
	       depth:(_depth + 1)];
}

- (UIxMailTreeBlock *)buildNavigationNodesForObject:(id)_object {
  /*
    This is the top-level 'flattening' method. The _object is the active
    object in the tree, that is, usually a "current folder".
    
    The tree will show:
    all subfolders of the current folder,
    all parent folders of the current folder up to some root,
    all siblings along the parent chain.
  */
  UIxMailTreeBlock *block;
  
  /* 
     This is the cursor, we create nodes below that for direct subfolders
  */
  if (debugBlocks) [self logWithFormat:@"ACTIVE block ..."];
  block = [self treeNavigationBlockForActiveNode:_object];
  if (debugBlocks) [self logWithFormat:@"  ACTIVE block: %@", block];
  
  if ([self isRootObject:_object]) {
    if (debugBlocks) [self logWithFormat:@"  active block is root."];
    return block;
  }
  
  /* 
     The following returns the root block. It calculates the chain up to the
     root folder starting with the parent of the current object.
  */
  if (debugBlocks) [self logWithFormat:@"ACTIVE parent block ..."];
  block = [self treeNavigationBlockForObject:[_object container] 
		withActiveChildBlock:block
		depth:1];
  if (debugBlocks) [self logWithFormat:@"done: %@", block];
  return block;
}

/* tree */

- (NSArray *)rootNodes {
  UIxMailTreeBlock *navNode;
  
  if (self->rootNodes != nil)
    return self->rootNodes;
  
  navNode = [self buildNavigationNodesForObject:[self clientObject]];
  
  if ([navNode hasChildren] && [navNode areChildrenLoaded])
    self->rootNodes = [[navNode children] retain];
  else if (navNode)
    self->rootNodes = [[NSArray alloc] initWithObjects:&navNode count:1];
  
  return self->rootNodes;
}

/* notifications */

- (void)sleep {
  [self->item      release]; self->item      = nil;
  [self->rootNodes release]; self->rootNodes = nil;
  [super sleep];
}

@end /* UIxMailTree */


@implementation NSString(DotCutting)

- (NSString *)stringByCuttingOffAtDotsWhenExceedingLength:(int)_maxLength {
  NSRange  r, r2;
  NSString *s;
  int      i;
  
  if ([self length] <= _maxLength) /* if length is small, return as is */
    return self;
  
  if ((r = [self rangeOfString:@"."]).length == 0)
    /* no dots in share, return even if longer than boundary */
    return self;
  
  s = self;
  i  = r.location + r.length;
  r2 = [s rangeOfString:@"." options:NSLiteralSearch 
	  range:NSMakeRange(i, [s length] - i)];
    
  if (r2.length > 0) {
    s = [s substringToIndex:r2.location];
    if ([s length] <= _maxLength) /* if length is small, return as is */
      return s;
  }
  
  /* no second dot, and the whole was too long => cut off after first */
  return [s substringToIndex:r.location];
}

- (NSString *)titleForSOGoIMAP4String {
  /* 
     eg:
       guizmo.g.-.baluh.hommes.tests-montee-en-charge-ogo@\
       amelie-01.ac.melanie2.i2
  */
  static int CutOffLength = 16;
  NSString *s;
  NSRange  r;
  
  s = self;
  
  /* check for connect strings without hostnames */
  
  r = [s rangeOfString:@"@"];
  if (r.length == 0) {
    /* no login provide, just use the hostname (without domain) */
    r = [s rangeOfString:@"."];
    return r.length > 0 ? [s substringToIndex:r.location] : s;
  }
  
  s = [s substringToIndex:r.location];
  
  /* check for shares */
  
  r = [s rangeOfString:@".-."];
  if (r.length > 0) {
    /* eg: 'baluh.hommes.tests-montee-en-charge-ogo' */
    s = [s substringFromIndex:(r.location + r.length)];
    
    return [s stringByCuttingOffAtDotsWhenExceedingLength:CutOffLength];
  }
  
  /* just the login name, possibly long (test.et.di.cete-lyon) */
  return [s stringByCuttingOffAtDotsWhenExceedingLength:CutOffLength];
}

@end /* NSString(DotCutting) */
