/*
 Copyright (C) 2007-2009 Inverse inc.
 Copyright (C) 2000-2005 SKYRIX Software AG
 
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

#import <Foundation/NSDictionary.h>

#import <NGObjWeb/WOComponent.h>

@class NSString, NSMutableArray, NSDictionary;

@interface UIxMailMoveToPopUp : WOComponent
{
  NSString *identifier;
  NSString *callback;
  id       rootNodes;
  id       item;
}

- (NSString *)itemDisplayString;
- (NSString *)itemURL;
  
- (void)_appendEntriesFromNodeDict:(NSDictionary *)_dict
  toList:(NSMutableArray *)_list
  withPrefix:(NSString *)_pathPrefix;

@end

@implementation UIxMailMoveToPopUp

- (void)dealloc {
  [self->identifier release];
  [self->callback   release];
  [self->rootNodes  release];
  [self->item       release];
  [super dealloc];
}

/* accessors */

- (void)setIdentifier:(NSString *)_identifier {
  ASSIGN(self->identifier, _identifier);
}
- (NSString *)identifier {
  return self->identifier;
}

- (void)setCallback:(NSString *)_callback {
  ASSIGN(self->callback, _callback);
}
- (NSString *)callback {
  return self->callback;
}

- (void)setRootNodes:(id)_rootNodes {
  ASSIGN(self->rootNodes, _rootNodes);
}
- (id)rootNodes {
  return self->rootNodes;
}

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (NSArray *)sortedNodes {
  NSMutableArray *r;
  NSDictionary *dict;

  r = [NSMutableArray arrayWithCapacity:10];
  
  /* INBOX node */
  dict = [[self->rootNodes objectForKey:@"children"] objectAtIndex:0];
  [self _appendEntriesFromNodeDict:dict toList:r withPrefix:nil];
  return r;
}

- (void)_appendEntriesFromNodeDict:(NSDictionary *)_dict
  toList:(NSMutableArray *)_list
  withPrefix:(NSString *)_pathPrefix
{
  NSMutableDictionary *e;
  NSString *title, *link;
  NSArray  *children;
  unsigned count, i;

  title = [_dict objectForKey:@"title"];
  link  = [_dict objectForKey:@"link"];
  
  e = [[NSMutableDictionary alloc] initWithCapacity:2];
  _pathPrefix = (_pathPrefix == nil)
    ? (id)title
    : (id)[NSString stringWithFormat:@"%@.%@", _pathPrefix, title];
  [e setObject:_pathPrefix forKey:@"title"];
  [e setObject:link        forKey:@"link"];
  [_list addObject:e];
  [e release]; e = nil;
  
  children = [_dict objectForKey:@"children"];
  count = [children count];
  for (i = 0; i < count; i++) {
    NSDictionary *dict;
    
    dict = [children objectAtIndex:i];
    [self _appendEntriesFromNodeDict:dict
                              toList:_list
                          withPrefix:_pathPrefix];
  }
}

- (NSString *)itemDisplayString {
  return [self->item objectForKey:@"title"];
}

- (NSString *)itemURL {
  return [self->item objectForKey:@"link"];
}

- (NSString *)itemDisabledValue {
  return [[self itemURL] isEqualToString:@"."] ? @" disabled" : @"";
}

/* JavaScript */

- (NSString *)selectItemJS {
  static NSString *selectJS = \
    @"javascript:if(!this.hasAttribute('disabled')) %@('%@');";
  return [NSString stringWithFormat:selectJS, self->callback, [self itemURL]];
}

@end /* UIxMailMoveToPopUp */
