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

#include "UIxMailRenderingContext.h"
#include <SoObjects/Mailer/SOGoMailObject.h>
#include "common.h"

@implementation UIxMailRenderingContext

static BOOL showNamedTextAttachmentsInline = NO;

- (id)initWithViewer:(WOComponent *)_viewer context:(WOContext *)_ctx {
  if ((self = [super init])) {
    self->viewer  = _viewer;
    self->context = _ctx;
  }
  return self;
}
- (id)init {
  return [self initWithViewer:nil context:nil];
}

- (void)dealloc {
  [self->iCalViewer    release];
  [self->htmlViewer    release];
  [self->textViewer    release];
  [self->imageViewer   release];
  [self->linkViewer    release];
  [self->messageViewer release];
  [super dealloc];
}

/* resetting state */

- (void)reset {
  [self->flatContents  release]; self->flatContents  = nil;
  [self->textViewer    release]; self->textViewer    = nil;
  [self->htmlViewer    release]; self->htmlViewer    = nil;
  [self->imageViewer   release]; self->imageViewer   = nil;
  [self->linkViewer    release]; self->linkViewer    = nil;
  [self->messageViewer release]; self->messageViewer = nil;
  [self->iCalViewer    release]; self->iCalViewer    = nil;
}

/* fetching */

- (NSDictionary *)flatContents {
  if (self->flatContents != nil)
    return [self->flatContents isNotNull] ? self->flatContents : nil;
  
  self->flatContents =
    [[[self->viewer clientObject] fetchPlainTextParts] retain];
  [self debugWithFormat:@"CON: %@", self->flatContents];
  return self->flatContents;
}

- (NSData *)flatContentForPartPath:(NSArray *)_partPath {
  NSString *pid;
  
  pid = _partPath ? [_partPath componentsJoinedByString:@"."] : @"";
  return [[self flatContents] objectForKey:pid];
}

/* viewer components */

- (WOComponent *)mixedViewer {
  /* Note: we cannot cache the multipart viewers, because it can be nested */
  return [self->viewer pageWithName:@"UIxMailPartMixedViewer"];
}

- (WOComponent *)signedViewer {
  /* Note: we cannot cache the multipart viewers, because it can be nested */
  // TODO: temporary workaround (treat it like a plain mixed part)
  return [self mixedViewer];
}

- (WOComponent *)alternativeViewer {
  /* Note: we cannot cache the multipart viewers, because it can be nested */
  return [self->viewer pageWithName:@"UIxMailPartAlternativeViewer"];
}

- (WOComponent *)textViewer {
  if (self->textViewer == nil) {
    self->textViewer = 
      [[self->viewer pageWithName:@"UIxMailPartTextViewer"] retain];
  }
  return self->textViewer;
}

- (WOComponent *)imageViewer {
  if (self->imageViewer == nil) {
    self->imageViewer = 
      [[self->viewer pageWithName:@"UIxMailPartImageViewer"] retain];
  }
  return self->imageViewer;
}

- (WOComponent *)linkViewer {
  if (self->linkViewer == nil) {
    self->linkViewer = 
      [[self->viewer pageWithName:@"UIxMailPartLinkViewer"] retain];
  }
  return self->linkViewer;
}

- (WOComponent *)htmlViewer {
  if (self->htmlViewer == nil) {
    self->htmlViewer = 
      [[self->viewer pageWithName:@"UIxMailPartHTMLViewer"] retain];
  }
  return self->htmlViewer;
}

- (WOComponent *)messageViewer {
  if (self->messageViewer == nil) {
    self->messageViewer = 
      [[self->viewer pageWithName:@"UIxMailPartMessageViewer"] retain];
  }
  return self->messageViewer;
}

- (WOComponent *)iCalViewer {
  if (self->iCalViewer == nil) {
    self->iCalViewer = 
      [[self->viewer pageWithName:@"UIxMailPartICalViewer"] retain];
  }
  return self->iCalViewer;
}

/* Kolab viewers */

- (WOComponent *)kolabContactViewer {
  return [self->viewer pageWithName:@"UIxKolabPartContactViewer"];
}
- (WOComponent *)kolabEventViewer {
  return [self->viewer pageWithName:@"UIxKolabPartEventViewer"];
}
- (WOComponent *)kolabTodoViewer {
  return [self->viewer pageWithName:@"UIxKolabPartTodoViewer"];
}

- (WOComponent *)kolabNoteViewer {
  return [self textViewer]; // TODO
}
- (WOComponent *)kolabJournalViewer {
  return [self textViewer]; // TODO
}
- (WOComponent *)kolabDistributionListViewer {
  return [self textViewer]; // TODO
}

/* main viewer selection */

- (WOComponent *)viewerForBodyInfo:(id)_info {
  NSString *mt, *st;

  mt = [[_info valueForKey:@"type"]    lowercaseString];
  st = [[_info valueForKey:@"subtype"] lowercaseString];
  
  if ([mt isEqualToString:@"multipart"]) {
    if ([st isEqualToString:@"mixed"])
      return [self mixedViewer];
    if ([st isEqualToString:@"signed"])
      return [self signedViewer];
    if ([st isEqualToString:@"alternative"])
      return [self alternativeViewer];
    
    if ([st isEqualToString:@"report"])
      /* this is used by mail-delivery reports */
      return [self mixedViewer];
  }
  else if ([mt isEqualToString:@"text"]) {
    /* 
       Note: in the _info dictionary we do not get the content-disposition
             information (inline vs attachment). Our hack is to check for the
	     'name' parameter.
    */
    if ([st isEqualToString:@"plain"] || [st isEqualToString:@"html"]) {
      if (!showNamedTextAttachmentsInline) {
	NSString *n;
	
	n = [[_info objectForKey:@"parameterList"] objectForKey:@"name"];
	if ([n isNotNull] && [n length] > 0)
	  return [self linkViewer];
      }
      
      return [st isEqualToString:@"html"] 
	? [self htmlViewer] : [self textViewer];
    }
    
    if ([st isEqualToString:@"calendar"])
      return [self iCalViewer];
  }
  
  if ([mt isEqualToString:@"image"])
    return [self imageViewer];
  
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

  if ([mt isEqualToString:@"application"]) {
    // octet-stream (generate download link?, autodetect type?)
    
    if ([st hasPrefix:@"x-vnd.kolab."]) {
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

