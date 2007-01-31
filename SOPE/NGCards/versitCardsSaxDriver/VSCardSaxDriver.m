/*
  Copyright (C) 2003-2004 Max Berger
  Copyright (C) 2004-2005 OpenGroupware.org
  
  This file is part of versitCardsSaxDriver, written for the OpenGroupware.org
  project (OGo).
  
  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.
  
  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.
  
  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "VSCardSaxDriver.h"
#include "common.h"

#define XMLNS_VSvCard \
  @"http://www.ietf.org/internet-drafts/draft-dawson-vcard-xml-dtd-03.txt"

@implementation VSCardSaxDriver

static NSSet *defElementNames = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  
  if(didInit)
    return;
  didInit = YES;
  
  defElementNames = [[NSSet alloc] initWithObjects:
    @"class", @"prodid", @"rev", @"uid", @"version", nil];
}

- (id)init {
  if ((self = [super init]) != nil) {
    [self setPrefixURI:XMLNS_VSvCard];
//     [self setElementMapping:[[self class] xcardMapping]];
//     [self setAttributeElements:defElementNames];
  }
  return self;
}

/* top level parsing method */

- (void)reportDocStart {
  [super reportDocStart];
  
  [self->contentHandler startElement:@"vCardSet" namespace:self->prefixURI
                        rawName:@"vCardSet" attributes:nil];
}
- (void)reportDocEnd {
  [self->contentHandler endElement:@"vCardSet" namespace:self->prefixURI
                        rawName:@"vCardSet"];
  
  [super reportDocEnd];
}

@end /* VCardSaxDriver */
