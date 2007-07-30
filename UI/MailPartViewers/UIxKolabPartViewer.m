/*
  Copyright (C) 2005 SKYRIX Software AG

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

#import <NGExtensions/NSNull+misc.h>
#import <DOM/DOMBuilderFactory.h>
#import <DOM/DOMProtocols.h>

#import "UIxKolabPartViewer.h"

@implementation UIxKolabPartViewer

static id<DOMBuilder> domBuilder = nil;

+ (void)initialize {
  DOMBuilderFactory *factory
    = [DOMBuilderFactory standardDOMBuilderFactory];
  
  domBuilder = [[factory createDOMBuilderForMimeType:@"text/xml"] retain];
  NSLog(@"Note(%@): using DOM builder: %@", 
	NSStringFromClass(self), domBuilder);
}

- (void)dealloc {
  [(id)self->domDocument release];
  [self->item release];
  [super dealloc];
}

/* maintain caches */

- (void)resetPathCaches {
  [super resetPathCaches];
  [(id)self->domDocument release]; self->domDocument = nil;
  [self->item            release]; self->item        = nil;
}

/* getting a DOM representation */

- (id<DOMDocument>)domDocument {
  /* 
     Note: this ignores the charset MIME header and will rely on proper
           encoding header in the XML.
  */

  if (self->domDocument != nil)
    return [(id)self->domDocument isNotNull] ? self->domDocument : nil;
  
  self->domDocument =
    [[domBuilder buildFromSource:[self decodedFlatContent]
		 systemId:@"Kolab Mail Object"] retain];
  return self->domDocument;
}

/* accessors */

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

@end /* UIxKolabPartViewer */
