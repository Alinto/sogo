/*
  Copyright (C) 2007-2009 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#import <Foundation/NSKeyValueCoding.h>
#import <NGExtensions/NGExtensions.h>
#import <NGObjWeb/NGObjWeb.h>
#import <NGObjWeb/SoObjects.h>

#import <SOGoUI/UIxComponent.h>

#import <NGObjWeb/SoComponent.h>

@class NSArray, NSDictionary;

@interface UIxToolbar : UIxComponent
{
  NSArray      *toolbarConfig;
  NSArray      *toolbarGroup;
  NSString *toolbar;
  NSDictionary *buttonInfo;
}

- (void) setToolbar: (NSString *) newToolbar;
- (NSString *) toolbar;

@end

@implementation UIxToolbar

- (id) init
{
  if ((self = [super init]))
    {
      toolbar = nil;
    }

  return self;
}

- (void)dealloc {
  [toolbarGroup  release];
  [toolbarConfig release];
  [buttonInfo    release];
  [toolbar release];
  [super dealloc];
}

/* accessors */

- (void)setToolbarGroup:(id)_group {
  ASSIGN(toolbarGroup, _group);
}

- (id)toolbarGroup {
  return toolbarGroup;
}

- (void)setButtonInfo:(id)_info {
  ASSIGN(buttonInfo, _info);
}

- (id)buttonInfo {
  return buttonInfo;
}

/* toolbar */

- (WOResourceManager *)pageResourceManager {
  WOResourceManager *rm;
  
  if ((rm = [[[self context] page] resourceManager]) != nil)
    return rm;
  
  return [[self application] resourceManager];
}

- (id) pathToResourceNamed: (NSString *) name
{
  WOResourceManager *rm;
  NSRange  r;
  NSString *fw, *rn;

  r = [name rangeOfString: @"/"];
  if (r.length > 0)
    {
      fw = [name substringToIndex: r.location];
      rn = [name substringFromIndex: (r.location + r.length)];
    }
  else
    {
      rn = name;
      fw = nil;
    }
  
  rm = [self pageResourceManager];

  return [rm pathForResourceNamed: rn inFramework: fw 
	     languages: [[self context] resourceLookupLanguages]];
}

- (id)loadToolbarConfigFromResourceNamed:(NSString *)_name {
  /*
    Note: we cannot cache by name because we don't know how the resource
          manager will look up the name.
	  Both, the clientObject and the page might be different.
	  
	  Of course the resourcemanager will cache the resource path and we
	  cache the parsed content for a given path;
  */
  static NSMutableDictionary *pathToConfig = nil;
  NSDictionary *tb;
  NSString *path;

  path = [self pathToResourceNamed: _name];
  if (path == nil) {
    [self errorWithFormat:@"Did not find toolbar resource: %@", _name];
    return nil;
  }

  if ((tb = [pathToConfig objectForKey:path]) != nil)
    return [tb isNotNull] ? (id)tb : nil;
  
  if ((tb = [NSArray arrayWithContentsOfFile:path]) == nil)
    [self errorWithFormat:@"Could not load toolbar resource: %@", _name];

  if (pathToConfig == nil)
    pathToConfig = [[NSMutableDictionary alloc] initWithCapacity:32];
  [pathToConfig setObject:(tb ? (id)tb : (id)[NSNull null]) forKey:path];

  return tb;
}

- (id) toolbarConfig
{
  id tb;
  
  if (toolbarConfig != nil)
    return [toolbarConfig isNotNull] ? (id)toolbarConfig : nil;
  
  if (toolbar)
    tb = toolbar;
  else
    tb = [[self clientObject] lookupName: @"toolbar" inContext:[self context]
                              acquire:NO];

  if ([tb isKindOfClass:[NSException class]]) {
    [self errorWithFormat:
            @"not toolbar configuration found on SoObject: %@ (%@)",
            [self clientObject], [[self clientObject] soClass]];
    toolbarConfig = [[NSNull null] retain];
    return nil;
  }

  if ([tb isKindOfClass: [NSString class]])
    {
      if ([tb isEqualToString: @"none"])
        tb = [NSNull null];
      else
        tb = [self loadToolbarConfigFromResourceNamed:tb];
    }

  toolbarConfig = [tb retain];

  return toolbarConfig;
}

/* labels */

- (NSString *) buttonLabel
{
  NSString          *key;
  
  key = [[self buttonInfo] valueForKey: @"label"];

  return [self labelForKey: key];
}

- (id) buttonImage
{
  NSString *image;

  image = [buttonInfo objectForKey: @"image"];
  if (image && [image length] > 0)
    image = [self urlForResourceFilename: image];

  return image;
}

- (NSString *) buttonTooltip
{
  NSString          *key;
  
  key = [[self buttonInfo] valueForKey: @"tooltip"];

  return [self labelForKey: key];
}

/* enable/disable buttons */

- (BOOL)isButtonEnabled {
  // TODO: replace 'enabled' with WOAssociation when this gets a dynamic
  //       element
  NSString *onOffKey;
  
  if ((onOffKey = [[self buttonInfo] valueForKey:@"enabled"]) == nil)
    return YES;

  return [[[[self context] page] valueForKeyPath:onOffKey] boolValue];
}

- (NSString *) cssClasses
{
  NSMutableArray *cssClasses;
  NSString *infoClasses;

  cssClasses = [NSMutableArray arrayWithCapacity: 16];
  if ([self isButtonEnabled])
    [cssClasses addObject: @"toolbarButton"];
  else
    [cssClasses addObject: @"disabledToolbarButton"];

  infoClasses = [[self buttonInfo] objectForKey: @"cssClass"];
  if ([infoClasses length] > 0)
    [cssClasses addObject: infoClasses];

  return [cssClasses componentsJoinedByString: @" "];
}

- (BOOL) isLastGroup {
  return ([toolbarConfig indexOfObject: toolbarGroup]
	  == ([toolbarConfig count] - 1));
}

- (BOOL) hasButtons
{
  id tbConfig;
  unsigned int count, max, amount;

  tbConfig = [self toolbarConfig];

  amount = 0;
  max = [tbConfig count];
  for (count = 0; count < max; count++)
    amount += [[tbConfig objectAtIndex: count] count];

  return (amount > 0);
}

- (BOOL) hasMenu
{
  return [[[self buttonInfo] valueForKey:@"hasMenu"] boolValue];
}

- (void) setToolbar: (NSString *) newToolbar
{
  ASSIGN(toolbar, newToolbar);
}

- (NSString *) toolbar
{
  return toolbar;
}

@end /* UIxToolbar */
