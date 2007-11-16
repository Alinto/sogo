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

#import <Foundation/NSString.h>

#import <NGObjWeb/WOComponent.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>

#import <SoObjects/Mailer/SOGoMailObject.h>

#import "UIxMailRenderingContext.h"

@interface UIxMailRenderingContext (Private)

- (BOOL) _shouldDisplayAsAttachment: (NSDictionary *) info;

@end

@implementation UIxMailRenderingContext (Private)

- (BOOL) _shouldDisplayAsAttachment: (NSDictionary *) info
{
  NSString *s;

  s = [[info objectForKey:@"disposition"] objectForKey: @"type"];
	
  return (s && [s caseInsensitiveCompare: @"ATTACHMENT"] == NSOrderedSame);
}

@end

@implementation UIxMailRenderingContext

static BOOL showNamedTextAttachmentsInline = NO;

- (id) initWithViewer: (WOComponent *) _viewer
	      context: (WOContext *) _ctx
{
  if ((self = [super init]))
    {
      viewer  = _viewer;
      context = _ctx;
    }

  return self;
}

- (id) init
{
  return [self initWithViewer: nil context: nil];
}

- (void) dealloc
{
  [flatContents release];
  [iCalViewer release];
  [htmlViewer release];
  [textViewer release];
  [imageViewer release];
  [linkViewer release];
  [messageViewer release];
  [super dealloc];
}

- (void) reset
{
  [flatContents release];
  [iCalViewer release];
  [htmlViewer release];
  [textViewer release];
  [imageViewer release];
  [linkViewer release];
  [messageViewer release];

  flatContents = nil;
  iCalViewer = nil;
  textViewer = nil;
  imageViewer = nil;
  htmlViewer = nil;
  linkViewer = nil;
  messageViewer = nil;
}

/* fetching */

- (NSDictionary *) flatContents
{
  if (!flatContents)
    {
      flatContents = [[viewer clientObject] fetchPlainTextParts];
      [flatContents retain];
//       [self debugWithFormat:@"CON: %@", flatContents];
    }

  return flatContents;
}

- (NSData *) flatContentForPartPath: (NSArray *) _partPath
{
  NSString *pid;
  
  pid = _partPath ? [_partPath componentsJoinedByString:@"."] : @"";

  return [[self flatContents] objectForKey:pid];
}

/* viewer components */

- (WOComponent *) mixedViewer
{
  /* Note: we cannot cache the multipart viewers, because it can be nested */
  return [viewer pageWithName: @"UIxMailPartMixedViewer"];
}

- (WOComponent *) signedViewer
{
  /* Note: we cannot cache the multipart viewers, because it can be nested */
  // TODO: temporary workaround (treat it like a plain mixed part)

  return [self mixedViewer];
}

- (WOComponent *) alternativeViewer
{
  /* Note: we cannot cache the multipart viewers, because it can be nested */
  return [viewer pageWithName: @"UIxMailPartAlternativeViewer"];
}

- (WOComponent *) textViewer
{
  if (!textViewer)
    {
      textViewer = [viewer pageWithName: @"UIxMailPartTextViewer"];
      [textViewer retain];
    }

  return textViewer;
}

- (WOComponent *) imageViewer
{
  if (!imageViewer)
    {
      imageViewer = [viewer pageWithName: @"UIxMailPartImageViewer"];
      [imageViewer retain];
    }

  return imageViewer;
}

- (WOComponent *) linkViewer
{
  if (!linkViewer)
    {
      linkViewer = [viewer pageWithName: @"UIxMailPartLinkViewer"];
      [linkViewer retain];
    }

  return linkViewer;
}

- (WOComponent *) htmlViewer
{
  if (!htmlViewer)
    {
      htmlViewer = [viewer pageWithName: @"UIxMailPartHTMLViewer"];
      [htmlViewer retain];
    }

  return htmlViewer;
}

- (WOComponent *) messageViewer
{
  if (!messageViewer)
    {
      messageViewer = [viewer pageWithName: @"UIxMailPartMessageViewer"];
      [messageViewer retain];
    }

  return messageViewer;
}

- (WOComponent *) iCalViewer
{
  if (!iCalViewer)
    {
      iCalViewer = [viewer pageWithName: @"UIxMailPartICalViewer"];
      [iCalViewer retain];
    }

  return iCalViewer;
}

/* Kolab viewers */

- (WOComponent *) kolabContactViewer
{
  return [viewer pageWithName: @"UIxKolabPartContactViewer"];
}

- (WOComponent *) kolabEventViewer
{
  return [viewer pageWithName: @"UIxKolabPartEventViewer"];
}

- (WOComponent *) kolabTodoViewer
{
  return [viewer pageWithName: @"UIxKolabPartTodoViewer"];
}

- (WOComponent *) kolabNoteViewer
{
  return [self textViewer]; // TODO
}

- (WOComponent *) kolabJournalViewer
{
  return [self textViewer]; // TODO
}

- (WOComponent *) kolabDistributionListViewer
{
  return [self textViewer]; // TODO
}

/* main viewer selection */

- (WOComponent *) viewerForBodyInfo: (id) _info
{
  NSString *mt, *st;

  mt = [[_info valueForKey:@"type"] lowercaseString];
  st = [[_info valueForKey:@"subtype"] lowercaseString];

  if ([mt isEqualToString:@"multipart"])
    {
      if ([st isEqualToString:@"mixed"] || [st isEqualToString:@"related"])
	return [self mixedViewer];
      else if ([st isEqualToString:@"signed"])
	return [self signedViewer];
      else if ([st isEqualToString:@"alternative"])
	return [self alternativeViewer];
    
    if ([st isEqualToString:@"report"])
      /* this is used by mail-delivery reports */
      return [self mixedViewer];
    }
  else if ([mt isEqualToString:@"text"])
    {
    if ([st isEqualToString:@"plain"] || [st isEqualToString:@"html"]) {
      if (!showNamedTextAttachmentsInline && [self _shouldDisplayAsAttachment: _info])
	return [self linkViewer];
      
      return [st isEqualToString:@"html"] 
	? [self htmlViewer] : [self textViewer];
    }
    
    if ([st isEqualToString:@"calendar"])
      return [self iCalViewer];
    }
  
  if ([mt isEqualToString:@"image"])
    {
      if ([self _shouldDisplayAsAttachment: _info])
	return [self linkViewer];
     
      return [self imageViewer];
    }
  
  if ([mt isEqualToString:@"message"] && [st isEqualToString:@"rfc822"])
    return [self messageViewer];
  
  if ([mt isEqualToString:@"message"] && 
      [st isEqualToString:@"delivery-status"]) {
    /*
      Content-Description: Delivery error report
      Content-Type: message/delivery-status
      
      Reporting-MTA: dns; mail.opengroupware.org
      Arrival-Date: Mon, 18 Jul 2005 12:08:43 +0200 (CEST)
      
      Final-Recipient: rfc822; ioioi@plop.com
      Action: failed
      Status: 5.0.0
      Diagnostic-Code: X-Postfix; host plop.com[64.39.31.55] said: 550 5.7.1
          <ioioi@plop.com>... Relaying denied
    */
    // Note: we cannot use the text viewer because the body is not pre-fetched
    return [self linkViewer];
  }

  if ([mt isEqualToString:@"application"])
    {
      // octet-stream (generate download link?, autodetect type?)
    
    if ([st hasPrefix:@"x-vnd.kolab."])
      {
	if ([st isEqualToString:@"x-vnd.kolab.contact"])
	  return [self kolabContactViewer];
	if ([st isEqualToString:@"x-vnd.kolab.event"])
	  return [self kolabEventViewer];
	if ([st isEqualToString:@"x-vnd.kolab.task"])
	  return [self kolabTodoViewer];
	if ([st isEqualToString:@"x-vnd.kolab.note"])
	  return [self kolabNoteViewer];
	if ([st isEqualToString:@"x-vnd.kolab.journal"])
	  return [self kolabJournalViewer];
	if ([st isEqualToString:@"x-vnd.kolab.contact.distlist"])
	  return [self kolabDistributionListViewer];
      
	[self errorWithFormat:@"found no viewer for Kolab type: %@/%@", mt, st];
	return [self linkViewer];
      }
    
#if 0 /* the link viewer looks better than plain text ;-) */
    if ([st isEqualToString:@"pgp-signature"]) // TODO: real PGP viewer
      return [self textViewer];
#endif
    }

  // TODO: always fallback to octet viewer?!
#if 1
  [self errorWithFormat:@"found no viewer for MIME type: %@/%@", mt, st];
#endif

  return [self linkViewer];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return NO;
}

@end /* UIxMailRenderingContext */


@implementation WOContext(UIxMailPart)

static NSString *MRK = @"UIxMailRenderingContext";

- (void)pushMailRenderingContext:(UIxMailRenderingContext *)_mctx {
  [self setObject:_mctx forKey:MRK];
}
- (UIxMailRenderingContext *)popMailRenderingContext {
  UIxMailRenderingContext *mctx;
  
  if ((mctx = [self objectForKey:MRK]) == nil)
    return nil;
  
  mctx = [[mctx retain] autorelease];
  [self removeObjectForKey:MRK];
  return mctx;
}
- (UIxMailRenderingContext *)mailRenderingContext {
  return [self objectForKey:MRK];
}

@end /* WOContext(UIxMailPart) */

