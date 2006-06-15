/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include "UIxMailPartViewer.h"

/*
  UIxMailPartMessageViewer

  Show message/rfc822 mail parts. Note that the IMAP4 server already returns a
  proper body structure of the message.

  Relevant body-info keys:
    to/sender/from/cc/bcc/in-reply-to/reply-to - array of addr-dicts
    type/subtype          - message/RFC822
    size
    subject
    parameterList         - dict (eg 'name')
    messageId     
    date
    encoding              - 7BIT
    bodyLines             - 83
    bodyId                - (empty string?)
    description           - (empty string?, content-description?)
    
    body                  - a body structure?
  
  Addr-Dict:
    hostName / mailboxName / personalName / sourceRoute
*/

@class NGImap4Envelope;

@interface UIxMailPartMessageViewer : UIxMailPartViewer
{
  NGImap4Envelope *envelope;
  id currentAddress;
}

@end

#include <UI/MailerUI/WOContext+UIxMailer.h>
#include "UIxMailRenderingContext.h"
#include <NGImap4/NGImap4Envelope.h>
#include <NGImap4/NGImap4EnvelopeAddress.h>
#include "common.h"

@implementation UIxMailPartMessageViewer

- (void)dealloc {
  [self->currentAddress release];
  [self->envelope       release];
  [super dealloc];
}

/* cache maintenance */

- (void)resetBodyInfoCaches {
  [super resetBodyInfoCaches];
  [self->envelope       release]; self->envelope       = nil;
  [self->currentAddress release]; self->currentAddress = nil;
}

/* notifications */

- (void)sleep {
  [self->currentAddress release]; self->currentAddress = nil;
  [super sleep];
}

/* accessors */

- (void)setCurrentAddress:(id)_addr {
  ASSIGN(self->currentAddress, _addr);
}
- (id)currentAddress {
  return self->currentAddress;
}

/* nested body structure */

- (id)contentInfo {
  return [[self bodyInfo] valueForKey:@"body"];
}

- (id)contentPartPath {
  /*
    Path processing is a bit weird in the context of message/rfc822. If we have
    a multipart, the multipart itself has no own identifier! Instead the
    children of the multipart are directly mapped into the message namespace.
    
    If the message has just a plain content, ids seems to be as expected (that
    is, its just a "1").
  */
  NSArray  *pp;
  NSString *mt;
  
  mt = [[[self contentInfo] valueForKey:@"type"] lowercaseString];
  if ([mt isEqualToString:@"multipart"])
    return [self partPath];
  
  pp = [self partPath];
  return [pp count] > 0
    ? [pp arrayByAddingObject:@"1"]
    : [NSArray arrayWithObject:@"1"];
}

- (id)contentViewerComponent {
  id info;
  
  info = [self contentInfo];
  return [[[self context] mailRenderingContext] viewerForBodyInfo:info];
}

/* generating envelope */

- (NGImap4Envelope *)envelope {
  if (self->envelope == nil) {
    self->envelope = [[NGImap4Envelope alloc] initWithBodyStructureInfo:
						[self bodyInfo]];
  }
  return self->envelope;
}

/* links to recipients */

- (NSString *)linkToEnvelopeAddress:(NGImap4EnvelopeAddress *)_address {
  // TODO: make some web-link, eg open a new compose panel?
  return [@"mailto:" stringByAppendingString:[_address baseEMail]];
}

- (NSString *)currentAddressLink {
  return [self linkToEnvelopeAddress:[self currentAddress]];
}

@end /* UIxMailPartMessageViewer */
