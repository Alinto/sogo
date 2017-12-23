/*
  Copyright (C) 2007-2017 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

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
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSDictionary.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGExtensions/NSString+misc.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeMultipartBody.h>

#import <NGObjWeb/WOResponse.h>

#import <SOGo/NSString+Utilities.h>
#import <Mailer/NSData+Mail.h>
#import <Mailer/NSDictionary+Mail.h>
#import <Mailer/SOGoMailBodyPart.h>

#import "MailerUI/WOContext+UIxMailer.h"
#import "UIxMailRenderingContext.h"
#import "UIxMailSizeFormatter.h"

#import "UIxMailPartViewer.h"

@implementation UIxMailPartViewer

- (id) init
{
  if ((self = [super init]))
    {
      attachmentIds = nil;
      flatContent = nil;
      decodedContent = nil;
    }

  return self;
}

- (void) dealloc
{
  [flatContent release];
  [decodedContent release];
  [bodyInfo release];
  [partPath release];
  [super dealloc];
}

/* caches */

//
// This is called when -setPartPath: is called
//
- (void) resetPathCaches
{
  DESTROY(flatContent);
  DESTROY(decodedContent);
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
    return [flatContent isNotNull] ? (id)flatContent : nil;
  
  flatContent = [[[context mailRenderingContext] flatContentForPartPath: partPath] retain];

  return flatContent;
}

- (void) setFlatContent: (NSData *) theData
{
  ASSIGN(flatContent, theData);
}

//
// This methods decodes quoted-printable or
// based64 encoded data coming straight
// from the IMAP server.
//
- (id) decodedFlatContent
{
  NSString *enc;

  if (decodedContent != nil)
    return [decodedContent isNotNull] ? (id)decodedContent : nil;
  
  enc = [[bodyInfo objectForKey:@"encoding"] lowercaseString];

  decodedContent = [[[self flatContent] bodyDataFromEncoding: enc] retain];

  return decodedContent;
}

- (void) setDecodedContent: (id) theData
{
  ASSIGN(decodedContent, theData);
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

- (id) renderedPart
{
  NSString *type;

  type = [NSString stringWithFormat: @"%@/%@",
                            [bodyInfo objectForKey: @"type"],
                            [bodyInfo objectForKey: @"subtype"]];

  return [NSDictionary dictionaryWithObjectsAndKeys:
                         [self className], @"type",
                       type, @"contentType",
                       [[self generateResponse] contentAsString], @"content",
                       nil];
}

//
// Attachment IDs are used to replace CID from HTML content
// with their MIME parts when viewing an HTML mail with
// embedded images, defined as CID.
//
- (void) setAttachmentIds: (NSDictionary *) newAttachmentIds
{
  attachmentIds = newAttachmentIds;
}

- (NSString *) flatContentAsString
{
  NSString *charset, *s;
  NSData *content;

  content = [self decodedFlatContent];
  if (content)
    {
      // We handle special cases for S/MIME encrypted message
      // as we won't deal with IMAP body structure objects here
      // but rather directly with NGMime objects.
      if ([content isKindOfClass: [NSData class]])
        {
          charset = [[bodyInfo objectForKey:@"parameterList"]
                      objectForKey: @"charset"];
          s = [content bodyStringFromCharset: charset];
        }
      else if ([content isKindOfClass: [NGMimeBodyPart class]] ||
               [content isKindOfClass: [NGMimeMultipartBody class]])
        s = [content body];
      else
        s = (id)content;
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
    if ([_st isEqualToString:@"rfc822"]) return @"eml";
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
  return [bodyInfo filename];
}

- (NSString *) filenameForDisplay
{
  NSString *s;
  
  if ((s = [self filename]) != nil)
    return s;
  
  s = [partPath componentsJoinedByString:@"-"];
  return ([s length] > 0)
    ? (id)[@"untitled-" stringByAppendingString:s]
    : (id)@"untitled";
}

- (NSFormatter *) sizeFormatter
{
  return [UIxMailSizeFormatter sharedMailSizeFormatter];
}

/* URL generation */

- (NSString *) _filenameForAttachment: (SOGoMailBodyPart *) bodyPart
{
  NSMutableString *filename;
  NSString *extension;

  filename = [NSMutableString stringWithString: [self filename]];
  if ([filename length])
    // We replace any slash by a dash since Apache won't allow encoded slashes by default.
    // See http://httpd.apache.org/docs/2.2/mod/core.html#allowencodedslashes
    filename = [NSMutableString stringWithString: [filename stringByReplacingString: @"/" withString: @"-"]];
  else
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

- (NSString *) _pathForAttachmentOrDownload: (BOOL) forDownload
{
  SOGoMailBodyPart *bodyPart;
  NSString *s, *attachment;
  NSMutableString *url;

  bodyPart = [self clientPart];
  s = [[self clientObject] baseURLInContext: [self context]];

  url = [NSMutableString stringWithString: s];
  if (![url hasSuffix: @"/"])
    [url appendString: @"/"];

  [url appendString: [[self partPath] componentsJoinedByString: @"/"]];
  [url appendString: @"/"];

  if ([bodyPart isKindOfClass: [SOGoMailBodyPart class]])
    attachment = [self _filenameForAttachment: bodyPart];
  else if ([[self decodedFlatContent] isKindOfClass: [NGMimeBodyPart class]])
    attachment = [[[self decodedFlatContent] headerForKey: @"content-disposition"] filename];
  else
    attachment = @"0";

  if (forDownload)
    [url appendString: @"asAttachment/"];

  [url appendString: attachment];

  return url;
}

//
// Used by UI/Templates/MailPartViewers/UIxMailPartICalViewer.wox
//
- (NSString *) pathToAttachmentFromMessage
{
  NSMutableArray *parts;
  SOGoMailBodyPart *bodyPart;

  bodyPart = [self clientPart];
  if ([bodyPart isKindOfClass: [SOGoMailBodyPart class]])
    {
      parts = [NSMutableArray arrayWithObject: [self _filenameForAttachment: bodyPart]];
      do
        {
          [parts insertObject: [bodyPart nameInContainer] atIndex: 0];
          bodyPart = [bodyPart container];
        }
      while ([bodyPart isKindOfClass: [SOGoMailBodyPart class]]);
      return [parts componentsJoinedByString: @"/"];
    }

  return @"0";
}

- (NSString *) pathToAttachment
{
  return [self _pathForAttachmentOrDownload: NO];
}

- (NSString *) pathForDownload
{
  return [self _pathForAttachmentOrDownload: YES];
}

@end /* UIxMailPartViewer */
