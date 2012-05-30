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
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING. If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <NGImap4/NGImap4Envelope.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>

#import <NGExtensions/NSString+Encoding.h>

#import <SoObjects/Mailer/NSData+Mail.h>
#import <SoObjects/Mailer/NSString+Mail.h>

#import <UI/MailerUI/WOContext+UIxMailer.h>
#import "UIxMailRenderingContext.h"

#import "UIxMailPartViewer.h"

/*
  UIxMailPartMessageViewer

 Show message/rfc822 mail parts. Note that the IMAP4 server already returns a
 proper body structure of the message.

 Relevant body-info keys:
 to/sender/from/cc/bcc/in-reply-to/reply-to - array of addr-dicts
 type/subtype - message/RFC822
 size
 subject
 parameterList - dict (eg 'name')
 messageId 
 date
 encoding - 7BIT
 bodyLines - 83
 bodyId - (empty string?)
 description - (empty string?, content-description?)
 
 body - a body structure?
 
 Addr-Dict:
 hostName / mailboxName / personalName / sourceRoute
*/

@class NGImap4Envelope;

@interface UIxMailPartMessageViewer : UIxMailPartViewer
{
  NGImap4Envelope *envelope;
}

@end

@implementation UIxMailPartMessageViewer

- (void) dealloc
{
  [envelope release];
  [super dealloc];
}

/* cache maintenance */

- (void) resetBodyInfoCaches
{
  [super resetBodyInfoCaches];
  [envelope release]; envelope = nil;
}

/* nested body structure */

- (id) contentInfo
{
  return [[self bodyInfo] valueForKey:@"body"];
}

- (id) contentPartPath
{
  /*
    Path processing is a bit weird in the context of message/rfc822. If we have
    a multipart, the multipart itself has no own identifier! Instead the
    children of the multipart are directly mapped into the message namespace.
 
    If the message has just a plain content, ids seems to be as expected (that
    is, its just a "1").
  */
  NSArray *pp;
  NSString *mt;
 
  mt = [[[self contentInfo] valueForKey:@"type"] lowercaseString];
  if ([mt isEqualToString:@"multipart"])
    return [self partPath];
 
  pp = [self partPath];
  return (([pp count] > 0)
	  ? (id)[pp arrayByAddingObject: @"1"]
	  : (id)[NSArray arrayWithObject: @"1"]);
}

- (id) contentViewerComponent
{
  UIxMailRenderingContext *mailContext;

  mailContext = [[self context] mailRenderingContext];

  return [mailContext viewerForBodyInfo: [self contentInfo]];
}

/* generating envelope */

- (NGImap4Envelope *) envelope
{
  if (!envelope)
    envelope = [[NGImap4Envelope alloc] initWithBodyStructureInfo:
					  [self bodyInfo]];

  return envelope;
}

- (NSString *) formattedComponents: (NSArray *) components
{
  NSMutableArray *formattedComponents;
  unsigned int count, max;
  NSString *component;

  max = [components count];
  formattedComponents = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      component = [[components objectAtIndex: count] email];
      if (component)
	[formattedComponents addObject: [component decodedHeader]];
    }

  return [formattedComponents componentsJoinedByString: @", "];
}

- (NSString *) messageSubject
{
  id baseSubject;
  NSString *subject;

  baseSubject = [[self envelope] subject];

  // We avoid uber-lamenesses in SOPE - see sope-core/NGExtensions/NGQuotedPrintableCoding.m
  // -stringByDecodingQuotedPrintable for all details
  if ([baseSubject isKindOfClass: [NSString class]])
    baseSubject = [baseSubject dataUsingEncoding: NSASCIIStringEncoding];
  subject = [baseSubject decodedHeader];

  if (![subject length])
    subject = @"";

  return subject;
}

- (NSString *) fromAddresses
{
  NSArray *from;

  from = [[self envelope] from];

  return [self formattedComponents: from];
}

- (NSString *) toAddresses
{
  NSArray *to;

  to = [[self envelope] to];

  return [self formattedComponents: to];
}

- (NSString *) ccAddresses
{
  NSArray *cc;

  cc = [[self envelope] cc];

  return [self formattedComponents: cc];
}

/* links to recipients */

- (NSString *) linkToEnvelopeAddress: (NGImap4EnvelopeAddress *) _address
{
  // TODO: make some web-link, eg open a new compose panel?
  return [@"mailto:" stringByAppendingString:[_address baseEMail]];
}

@end /* UIxMailPartMessageViewer */
