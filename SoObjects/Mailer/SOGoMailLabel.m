/*
  Copyright (C) 2007-2015 Inverse inc.

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

#import "SOGoMailLabel.h"

#import <Foundation/NSDictionary.h>

@implementation SOGoMailLabel

- (id) initWithName: (NSString *) theName
              label: (NSString *) theLabel
              color: (NSString *) theColor
{
  self = [super init];

  if (self)
    {
      ASSIGN(_name, theName);
      ASSIGN(_label, theLabel);
      ASSIGN(_color, theColor);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_name);
  RELEASE(_label);
  RELEASE(_color);
  [super dealloc];
}

- (NSString *) name
{
  return _name;
}

- (NSString *) label
{
  return _label;
}

- (NSString *) color
{
  return _color;
}


+ (NSArray *) labelsFromDefaults: (NSDictionary *) theDefaults
                       component: (id) theComponent
{
  NSMutableArray *allLabels, *allKeys;
  NSString *key, *name;
  SOGoMailLabel *label;
  NSArray *values;
  int i;

  allLabels = [NSMutableArray array];
  allKeys = (NSMutableArray *)[[theDefaults allKeys] sortedArrayUsingSelector: @selector (caseInsensitiveCompare:)];
  
  for (i = 0; i < [allKeys count]; i++)
    {
      key = [allKeys objectAtIndex: i];
      values = [theDefaults objectForKey: key];
      name = [theComponent commonLabelForKey: [values objectAtIndex: 0]];
      label = [[self alloc] initWithName: key
                                   label: name
                                   color: [values objectAtIndex: 1]];
      [allLabels addObject: label];
      RELEASE(label);
    }
  
  return allLabels;
}

@end
