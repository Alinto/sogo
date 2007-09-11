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

#import <Foundation/NSException.h>
#import <Foundation/NSUserDefaults.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSException+misc.h>
#import <NGExtensions/NSString+misc.h>
#import <NGImap4/NGImap4Envelope.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>
#import <SoObjects/Mailer/SOGoMailObject.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/Mailer/SOGoMailFolder.h>
#import <SOGoUI/UIxComponent.h>
#import <MailPartViewers/UIxMailRenderingContext.h> // cyclic

#import "WOContext+UIxMailer.h"

@interface UIxMailView : UIxComponent
{
  id currentAddress;
}

- (BOOL)isDeletableClientObject;

@end

@implementation UIxMailView

static NSString *mailETag = nil;

+ (int)version {
  return [super version] + 0 /* v2 */;
}

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  if ([ud boolForKey:@"SOGoDontUseETagsForMailViewer"]) {
    NSLog(@"Note: usage of constant etag for mailer viewer is disabled.");
  }
  else {
    mailETag = [[NSString alloc] initWithFormat:@"\"imap4url_%d_%d_%03d\"",
				 UIX_MAILER_MAJOR_VERSION,
				 UIX_MAILER_MINOR_VERSION,
				 UIX_MAILER_SUBMINOR_VERSION];
    NSLog(@"Note: using constant etag for mail viewer: '%@'", mailETag);
  }
}

- (void)dealloc {
  [super dealloc];
}

/* accessors */

- (void) setCurrentAddress: (id) _addr
{
  currentAddress = _addr;
}

- (id) currentAddress
{
  return currentAddress;
}

- (NSString *) objectTitle
{
  return [[self clientObject] subject];
}

- (NSString *) panelTitle
{
  return [NSString stringWithFormat: @"%@: %@",
                   [self labelForKey: @"View Mail"],
                   [self objectTitle]];
}

/* links (DUP to UIxMailPartViewer!) */

- (NSString *) linkToEnvelopeAddress: (NGImap4EnvelopeAddress *) _address
{
  // TODO: make some web-link, eg open a new compose panel?
  return [NSString stringWithFormat: @"mailto: %@", [_address baseEMail]];
}

- (NSString *) currentAddressLink
{
  return [self linkToEnvelopeAddress:[self currentAddress]];
}

/* fetching */

- (id) message
{
  return [[self clientObject] fetchCoreInfos];
}

- (BOOL) hasCC
{
  return [[[self clientObject] ccEnvelopeAddresses] count] > 0 ? YES : NO;
}

/* viewers */

- (id) contentViewerComponent
{
  // TODO: I would prefer to flatten the body structure prior rendering,
  //       using some delegate to decide which parts to select for alternative.
  id info;
  
  info = [[self clientObject] bodyStructure];

  return [[context mailRenderingContext] viewerForBodyInfo:info];
}

/* actions */

- (id) defaultAction
{
  WOResponse *response;
  NSString *s;

  /* check etag to see whether we really must rerender */
  if (mailETag)
    {
      /*
	Note: There is one thing which *can* change for an existing message,
	those are the IMAP4 flags (and annotations, which we do not use).
	Since we don't render the flags, it should be OK, if this changes
	we must embed the flagging into the etag.
      */
      s = [[context request] headerForKey: @"if-none-match"];
      if (s)
	{
	  if ([s rangeOfString:mailETag].length > 0) /* not perfectly correct */
	    { 
	      /* client already has the proper entity */
	      // [self logWithFormat:@"MATCH: %@ (tag %@)", s, mailETag];
	      
	      if (![[self clientObject] doesMailExist]) {
		return [NSException exceptionWithHTTPStatus:404 /* Not Found */
				    reason:@"message got deleted"];
	      }

	      response = [context response];
	      [response setStatus: 304 /* Not Modified */];

	      return response;
	    }
	}
    }
  
  if (![self message]) // TODO: redirect to proper error
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			reason:@"did not find specified message!"];
  
  return self;
}

- (BOOL) isDeletableClientObject
{
  return [[self clientObject] respondsToSelector: @selector (delete)];
}

- (BOOL) isInlineViewer
{
  return NO;
}

- (BOOL) mailIsDraft
{
  return [[self clientObject] isInDraftsFolder];
}

- (id) redirectToParentFolder
{
  id url;
  
  url = [[[self clientObject] container] baseURLInContext: context];

  return [self redirectToLocation: url];
}

/* generating response */

- (void) appendToResponse: (WOResponse *) _response
		inContext: (WOContext *) _ctx
{
  UIxMailRenderingContext *mctx;

  if (mailETag != nil)
    [[_ctx response] setHeader:mailETag forKey:@"etag"];

  mctx = [[UIxMailRenderingContext alloc] initWithViewer: self
					  context: _ctx];

  [_ctx pushMailRenderingContext: mctx];
  [mctx release];

  [super appendToResponse: _response inContext: _ctx];
  
  [[_ctx popMailRenderingContext] reset];
}

@end /* UIxMailView */
