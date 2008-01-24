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

- (SOGoMailBodyPart *) clientPart
{
  id currentObject;
  NSString *currentPart;
  NSEnumerator *parts;

  currentObject = [self clientObject];
  parts = [partPath objectEnumerator];
  while ((currentPart = [parts nextObject]))
    currentObject = [currentObject lookupName: currentPart
				   inContext: context
				   acquire: NO];

  return currentObject;
}

- (NSData *) content
{
  return [[self clientPart] fetchBLOB];
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
      if ([charset length])
	charset = [charset lowercaseString];
      else
	charset = @"us-ascii";
      s = [NSString stringWithData: content usingEncodingNamed: charset];
      if (![s length])
	{
	  /* UTF-8 is used as a 8bit fallback charset... */
	  s = [[NSString alloc] initWithData: content
				encoding: NSUTF8StringEncoding];
	  [s autorelease];
	}

      if (!s)
	{
	  /*
	    iCalendar invitations sent by Outlook 2002 have the annoying bug that the
	    mail states an UTF-8 content encoding but the actual iCalendar content is
	    encoding in Latin-1 (or Windows Western?).
		
	    As a result the content decoding will fail (TODO: always?). In this case we
	    try to decode with Latin-1.
 
	    Note: we could check for the Outlook x-mailer, but it was considered better
	    to try Latin-1 as a fallback in any case (be tolerant).
	  */

	  s = [[NSString alloc] initWithData:content 
				encoding: NSISOLatin1StringEncoding];
	  if (!s)
	    [self errorWithFormat: @"an attempt to use"
		  @" NSISOLatin1StringEncoding as callback failed"];
	  [s autorelease];
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
  
  /* if we get a message with an image-* or application-*
     Content-Type, we must generate a 'fake' part since our
     decoded mail won't have any. Also see SOGoMailBodyPart: -fetchBLOB
     and SOGoMailObject: -lookupImap4BodyPartKey: inContext for
     other workarounds */
  if (!partPath || [partPath count] == 0)
    partPath = [NSArray arrayWithObject: @"0"];

  /* mail relative path to body-part
     eg this was nil for a draft containing an HTML message */
  if ([(n = [partPath componentsJoinedByString:@"/"]) isNotNull])
    url = [url stringByAppendingString:n];
  
  return url;
}

- (NSString *) _filenameForAttachment: (SOGoMailBodyPart *) bodyPart
{
  NSMutableString *filename;
  NSString *extension;

  filename = [NSMutableString stringWithString: [bodyPart filename]];
  if (![filename length])
    [filename appendFormat: @"%@-%@",
	      [self labelForKey: @"Untitled"],
	      [bodyPart nameInContainer]];

  if (![[filename pathExtension] length])
    {
      extension = [self preferredPathExtension];
      if (extension)
	[filename appendFormat: @".%@", extension];
    }

  return [filename stringByEscapingURL];
}

- (NSString *) pathToAttachment
{
  NSMutableString *url;
  NSString *s, *attachment;
  SOGoMailBodyPart *bodyPart;

  bodyPart = [self clientPart];
  s = [bodyPart baseURLInContext: [self context]];
  url = [NSMutableString stringWithString: s];
  if (![url hasSuffix: @"/"])
    [url appendString: @"/"];

//   s = [[self partPath] componentsJoinedByString: @"/"];
  if ([bodyPart isKindOfClass: [SOGoMailBodyPart class]])
    attachment = [self _filenameForAttachment: bodyPart];
  else
    attachment = @"0";
  [url appendString: attachment];

  return url;
}

@end /* UIxMailPartViewer */
