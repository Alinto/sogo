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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGExtensions/NSString+misc.h>

#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/Mailer/SOGoMailBodyPart.h>

#import "UI/MailerUI/WOContext+UIxMailer.h"
#import "UIxMailRenderingContext.h"
#import "UIxMailSizeFormatter.h"

#import "UIxMailPartViewer.h"

@implementation UIxMailPartViewer

- (void) dealloc
{
  [flatContent release];
  [bodyInfo release];
  [partPath release];
  [super dealloc];
}

/* caches */

- (void) resetPathCaches
{
  /* this is called when -setPartPath: is called */
  [flatContent release]; flatContent = nil;
}

- (void) resetBodyInfoCaches
{
}

/* notifications */

- (void) sleep
{
  [self resetPathCaches];
  [self resetBodyInfoCaches];
  [partPath release];
  [bodyInfo release];
  partPath = nil;
  bodyInfo = nil;
  [super sleep];
}

/* accessors */

- (void) setPartPath: (NSArray *) _path
{
  if ([_path isEqual: partPath])
    return;

  ASSIGN(partPath, _path);

  [self resetPathCaches];
}

- (NSArray *) partPath
{
  return partPath;
}

- (void) setBodyInfo: (id) _info
{
  ASSIGN(bodyInfo, _info);
}

- (id) bodyInfo
{
  return bodyInfo;
}

- (NSData *) flatContent
{
  if (flatContent != nil)
    return [flatContent isNotNull] ? flatContent : nil;
  
  flatContent = 
    [[[context mailRenderingContext] flatContentForPartPath:
					      partPath] retain];
  return flatContent;
}

- (NSData *) decodedFlatContent
{
  NSString *enc;
  
  enc = [[bodyInfo objectForKey:@"encoding"] lowercaseString];

  if ([enc isEqualToString:@"7bit"])
    return [self flatContent];
  
  if ([enc isEqualToString:@"8bit"]) // TODO: correct?
    return [self flatContent];
  
  if ([enc isEqualToString:@"base64"])
    return [[self flatContent] dataByDecodingBase64];

  if ([enc isEqualToString:@"quoted-printable"])
    return [[self flatContent] dataByDecodingQuotedPrintable];
  
  [self errorWithFormat:@"unsupported MIME encoding: %@", enc];

  return [self flatContent];
}

- (NSData *) content
{
  NSData *content;
  NSEnumerator *parts;
  id currentObject;
  NSString *currentPart;

  content = nil;

  currentObject = [self clientObject];
  parts = [partPath objectEnumerator];
  currentPart = [parts nextObject];
  while (currentPart)
    {
      currentObject = [currentObject lookupName: currentPart
				     inContext: context
				     acquire: NO];
      currentPart = [parts nextObject];
    }

  content = [currentObject fetchBLOB];

  return content;
}

- (NSStringEncoding) fallbackStringEncoding
{
  return 0;
}

- (NSString *) flatContentAsString
{
  /* Note: we even have the line count in the body-info! */
  NSString *charset;
  NSString *s;
  NSData   *content;

  content = [self decodedFlatContent];
  if (content)
    {
      charset = [[bodyInfo objectForKey:@"parameterList"]
		  objectForKey: @"charset"];
      charset = [charset lowercaseString];
      if (![charset length]
	  || [charset isEqualToString: @"us-ascii"])
	{
	  s = [[NSString alloc] initWithData: content
				encoding: NSISOLatin1StringEncoding];
	  [s autorelease];
	}
      else
	{
	  s = [NSString stringWithData: content
			usingEncodingNamed: charset];
	  if (![s length])
	    {
	      /* latin 1 is used as a 8bit fallback charset... but does this
		 encoding accept any byte from 0 to 255? */
	      s = [[NSString alloc] initWithData: content
				    encoding: NSISOLatin1StringEncoding];
	      [s autorelease];
	    }
	}

      if (!s)
	{
	  /* 
	     Note: this can happend with iCalendar invitations sent by Outlook 2002.
	     It will mark the content as UTF-8 but actually deliver it as
	     Latin-1 (or Windows encoding?).
	  */
	  [self errorWithFormat:@"could not convert content to text, charset: '%@'",
		charset];
	  if ([self fallbackStringEncoding] > 0)
	    {
	      s = [[NSString alloc] initWithData:content 
				    encoding: [self fallbackStringEncoding]];
	      if (s)
		[s autorelease];
	      else
		[self errorWithFormat:
			@"an attempt to use fallback encoding failed to."];
	    }
	}
    }
  else
    {
      [self errorWithFormat:@"got no text content: %@", 
	    [partPath componentsJoinedByString:@"."]];
      s = nil;
    }

  return s;
}

/* path extension */

- (NSString *) pathExtensionForType: (NSString *) _mt
			    subtype: (NSString *) _st
{
  // TODO: support /etc/mime.types
  
  if (![_mt isNotNull] || ![_st isNotNull])
    return nil;
  if ([_mt length] == 0) return nil;
  if ([_st length] == 0) return nil;
  _mt = [_mt lowercaseString];
  _st = [_st lowercaseString];
  
  if ([_mt isEqualToString:@"image"]) {
    if ([_st isEqualToString:@"gif"])  return @"gif";
    if ([_st isEqualToString:@"jpeg"]) return @"jpg";
    if ([_st isEqualToString:@"png"])  return @"png";
  }
  else if ([_mt isEqualToString:@"text"]) {
    if ([_st isEqualToString:@"plain"])    return @"txt";
    if ([_st isEqualToString:@"xml"])      return @"xml";
    if ([_st isEqualToString:@"calendar"]) return @"ics";
    if ([_st isEqualToString:@"x-vcard"])  return @"vcf";
  }
  else if ([_mt isEqualToString:@"message"]) {
    if ([_st isEqualToString:@"rfc822"]) return @"mail";
  }
  else if ([_mt isEqualToString:@"application"]) {
    if ([_st isEqualToString:@"pdf"]) return @"pdf";
  }
  return nil;
}

- (NSString *) preferredPathExtension
{
  return [self pathExtensionForType: [bodyInfo valueForKey:@"type"]
	       subtype: [bodyInfo valueForKey:@"subtype"]];
}

- (NSString *) filename
{
  NSDictionary *parameters;
  NSString *filename;

  filename = nil;
  parameters = [bodyInfo valueForKey: @"parameterList"];
  if (parameters)
    filename = [parameters valueForKey: @"name"];

  if (!filename)
    {
      parameters = [[bodyInfo valueForKey: @"disposition"]
		     valueForKey: @"parameterList"];
      filename = [parameters valueForKey: @"filename"];
    }

  return filename;
}

- (NSString *) filenameForDisplay
{
  NSString *s;
  
  if ((s = [self filename]) != nil)
    return s;
  
  s = [partPath componentsJoinedByString:@"-"];
  return ([s length] > 0)
    ? [@"untitled-" stringByAppendingString:s]
    : @"untitled";
}

- (NSFormatter *) sizeFormatter
{
  return [UIxMailSizeFormatter sharedMailSizeFormatter];
}

/* URL generation */

- (NSString *) pathToAttachmentObject
{
  /* this points to the SoObject representing the part, no modifications */
  NSString *url, *n;

  /* path to mail controller object */
  
  url = [[self clientObject] baseURLInContext:context];
  if (![url hasSuffix: @"/"])
    url = [url stringByAppendingString: @"/"];
  
  /* mail relative path to body-part */
  
  /* eg this was nil for a draft containing an HTML message */
  if ([(n = [partPath componentsJoinedByString:@"/"]) isNotNull])
    url = [url stringByAppendingString:n];
  
  return url;
}

- (NSString *) pathToAttachment
{
  /* this generates a more beautiful 'download' URL for a part */
  NSString *fn;
  NSMutableString *url;

  fn = [self filename];
  if ([fn length] > 0)
    {
      /* get basic URL */
      url = [NSMutableString stringWithString: [self pathToAttachmentObject]];
  
      /* 
	 If we have an attachment name, we attach it, this is properly handled by
	 SOGoMailBodyPart.
      */
  
      if (![url hasSuffix: @"/"])
	[url appendString: @"/"];
      if (isdigit([url characterAtIndex: 0]))
	[url appendString: @"fn-"];
      [url appendString: [fn stringByEscapingURL]];
      // TODO: should we check for a proper extension?
    }
  else
    url = nil;

  return url;
}

@end /* UIxMailPartViewer */
