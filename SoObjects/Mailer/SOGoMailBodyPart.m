/*
  Copyright (C) 2005-2017 Inverse inc.
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
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimeType.h>

#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/SOGo/NSObject+Utilities.h>

#import "NSData+SMIME.h"
#import "NSDictionary+Mail.h"
#import "SOGoMailObject.h"
#import "SOGoMailAccount.h"
#import "SOGoMailBodyPart.h"

@implementation SOGoMailBodyPart

static NSString *mailETag = nil;
static BOOL debugOn = NO;

+ (void) initialize
{
  if (!mailETag)
    {
      /* The following disabled code should not be needed, except if we use
         annotations (see davEntityTag below) */
      // if (![[ud objectForKey: @"SOGoMailDisableETag"] boolValue]) {
      
      mailETag = [[NSString alloc] initWithFormat:@"\"imap4url_%@_%@_%@\"",
                                   UIX_MAILER_MAJOR_VERSION,
                                   UIX_MAILER_MINOR_VERSION,
                                   UIX_MAILER_SUBMINOR_VERSION];
    }
}

- (id) init
{
  if ((self = [super init]))
    asAttachment = NO;

  return self;
}

- (void) dealloc
{
  [partInfo   release];
  [identifier release];
  [pathToPart release];
  [super dealloc];
}

- (void) setAsAttachment
{
  asAttachment = YES;
}


/* hierarchy */

- (SOGoMailObject *) mailObject
{
  return [[self container] mailObject];
}

/* IMAP4 */

- (NSString *) bodyPartName
{
  NSString *s;
  NSRange  r;

  s = [self nameInContainer];
  r = [s rangeOfString:@"."]; /* strip extensions */
  if (r.length == 0)
    return s;
  return [s substringToIndex:r.location];
}

- (NSArray *) bodyPartPath
{
  NSMutableArray *p;
  id obj;
  
  if (pathToPart != nil)
    return ([pathToPart isNotNull] ? (id)pathToPart : nil);
  
#warning partToPart should be populated directly
  p = [[NSMutableArray alloc] initWithCapacity:8];
  for (obj = self; [obj isKindOfClass:[SOGoMailBodyPart class]]; 
       obj = [obj container]) {
    [p insertObject:[obj bodyPartName] atIndex:0];
  }
  
  pathToPart = [p copy];
  [p release];
  return pathToPart;
}

- (NSString *) bodyPartIdentifier
{
  if (identifier != nil)
    return ([identifier isNotNull] ? (id)identifier : nil);
  
  identifier =
    [[[self bodyPartPath] componentsJoinedByString:@"."] copy];
  return identifier;
}

- (NSURL *) imap4URL
{
  /* reuse URL of message */
  if (!imap4URL)
    {
      imap4URL = [[self mailObject] imap4URL];
      [imap4URL retain];
    }

  return imap4URL;
}

/* part info */

- (id) partInfo
{
  if (!partInfo)
    {
      partInfo
	= [[self mailObject] lookupInfoForBodyPart: [self bodyPartPath]];
      [partInfo retain];
    }

  return partInfo;
}

/* name lookup */

- (id) lookupImap4BodyPartKey: (NSString *) key
		    inContext: (WOContext *) localContext
{
  // TODO: we might want to check for existence prior controller creation
  NSDictionary *subPart, *infos;
  NSString *mimeType;
  NSArray *subParts;
  Class clazz;
  id o, obj;

  unsigned int nbr;

  nbr = [key intValue];
  o = [self container];

  while (![o isKindOfClass: [SOGoMailObject class]])
    o = [o container];

  if ([o isEncrypted])
    {
      NSData *certificate;
      NGMimeMessage *m;
      id part;

      int i;

      certificate = [[self mailAccountFolder] certificate];
      m = [[o content] messageFromEncryptedDataAndCertificate: certificate];
      part = [m body];

      for (i = 0; i < [[self bodyPartPath] count]; i++)
        {
          nbr = [[[self bodyPartPath] objectAtIndex: i] intValue]-1;
          part = [[part parts] objectAtIndex: nbr];;
        }

      //part = [[[m body] parts] objectAtIndex: ([key intValue]-1)];
      part = [[part parts] objectAtIndex: ([key intValue]-1)];
      mimeType = [[part contentType] stringValue];
      clazz = [SOGoMailBodyPart bodyPartClassForMimeType: mimeType
                                               inContext: localContext];
      obj = [clazz objectWithName:key inContainer: self];
    }
  else
    {
      infos = [self partInfo];
      subParts = [infos objectForKey: @"parts"];
      if (!subParts)
        subParts = [[infos objectForKey: @"body"] objectForKey: @"parts"];

      if (nbr > 0 && nbr < ([subParts count] + 1))
        {
          subPart = [subParts objectAtIndex: nbr - 1];
          mimeType = [subPart keysWithFormat: @"%{type}/%{subtype}"];
          clazz = [[self class] bodyPartClassForMimeType: mimeType
                                               inContext: localContext];
          obj = [clazz objectWithName: key inContainer: self];
        }
      else
        obj = self;
    }

  return obj;
}

- (NSString *) filename
{
  [self partInfo];
  
  return [partInfo filename];
}

/* We overwrite the super's class method in order to make sure
   we aren't dealing with our actual filename as the _key. That
   could lead to problems if we weren't doing this as our filename
   could start with a digit, leading to a wrong assumption in
   the super class
*/
// - (BOOL)isBodyPartKey:(NSString *)_key inContext:(id)_ctx
// {
//   NSString *s;

//   s = [self filename];
//   if (s && [s isEqualToString: _key]) return NO;

//   return [super isBodyPartKey: _key  inContext: _ctx];
// }

- (id) lookupName: (NSString *) _key
	inContext: (id) _ctx
	  acquire: (BOOL) _flag
{
  id obj;
 
  /* first check attributes directly bound to the application */
  obj = [super lookupName:_key inContext:_ctx acquire:NO];
  if (!obj)
    {
      /* lookup body part */
      if ([self isBodyPartKey: _key]) {
        obj = [self lookupImap4BodyPartKey: _key inContext: _ctx];
      }
      else if ([_key isEqualToString: @"asAttachment"])
        {
          // Don't try to render the part; rewrite object to a simple body part.
          obj = [SOGoMailBodyPart objectWithName: [self nameInContainer] inContainer: [self container]];
          [obj setAsAttachment];
        }
      /* should check whether such a filename exist in the attached names */
      if (!obj)
	obj = self;
    }

  return obj;      
}

/* fetch */

- (NSData *) fetchBLOBWithPeek: (BOOL) withPeek
{
  // HEADER, HEADER.FIELDS, HEADER.FIELDS.NOT, MIME, TEXT
  NSString *enc;
  NSData *data;
  
  data = [[self imap4Connection] fetchContentOfBodyPart: [self bodyPartIdentifier]
                                                  atURL: [self imap4URL]
                                               withPeek: withPeek];
  if (data == nil) return nil;

  /* check for content encodings */
  enc = [[self partInfo] valueForKey: @"encoding"];
 
  /* if we haven't found one, check out the main message's encoding
     as we could be trying to fetch the message's content as a part */
  if (!enc)
    enc = [[[[self mailObject] fetchCoreInfos] valueForKey: @"body"]
	    valueForKey: @"encoding"];

  if (enc)
    {
      enc = [enc lowercaseString];
      
      if ([enc isEqualToString: @"base64"])
	data = [data dataByDecodingBase64];
      else if ([enc isEqualToString: @"quoted-printable"])
	data = [data dataByDecodingQuotedPrintableTransferEncoding];
      else if ([enc isEqualToString: @"7bit"]
	       || [enc isEqualToString: @"8bit"]
	       || [enc isEqualToString: @"binary"])
	; /* keep data as is */ // TODO: do we need to change encodings?
      else
	{
	  data = nil;
	  [self errorWithFormat: @"unsupported encoding: %@", enc];
	}
    }

  return data;
}

- (NSData *) fetchBLOB
{
  id o;

  // We check if the associated SOGoMailObject is encrypted, we must navigate
  // in the container list until we find the proper container.
  o = [self container];

  while (![o isKindOfClass: [SOGoMailObject class]])
    o = [o container];

  if ([o isEncrypted])
    {
      NSData *certificate;
      NGMimeMessage *m;
      id part;

      unsigned int i, nbr;

      // No need to check if the cert is valid as we already do so
      // in SOGoMailObject.
      certificate = [[self mailAccountFolder] certificate];

      m = [[o content] messageFromEncryptedDataAndCertificate: certificate];
      part = [m body];

      for (i = 0; i < [[self bodyPartPath] count]; i++)
        {
          nbr = [[[self bodyPartPath] objectAtIndex: i] intValue]-1;
          part = [[part parts] objectAtIndex: nbr];;
        }

      return [part body];
    }

  // The mail is not encrypted, lets fetch the body party normally
  // straight from the IMAP server
  return [self fetchBLOBWithPeek: NO];
}

/* WebDAV */

- (NSString *)contentTypeForBodyPartInfo:(id)_info {
  NSMutableString *type;
  NSString     *mt, *st;
  NSDictionary *parameters;
  NSEnumerator *ke;
  NSString     *pn;
    
  if (![_info isNotNull])
    return nil;
  
  mt = [_info valueForKey:@"type"];    if (![mt isNotNull]) return nil;
  st = [_info valueForKey:@"subtype"]; if (![st isNotNull]) return nil;
  
  type = [NSMutableString stringWithCapacity:16];
  [type appendString:[mt lowercaseString]];
  [type appendString:@"/"];
  [type appendString:[st lowercaseString]];
  
  parameters = [_info valueForKey:@"parameterList"];
  ke = [parameters keyEnumerator];
  while ((pn = [ke nextObject]) != nil) {
    [type appendString:@"; "];
    [type appendString:pn];
    [type appendString:@"=\""];
    [type appendString:[[parameters objectForKey:pn] stringValue]];
    [type appendString:@"\""];
  }
  return type;
}

- (NSString *) contentTypeForPathExtension: (NSString *) pe
{
  if ([pe length] == 0)
    return @"application/octet-stream";
  
  /* TODO: add some map */
  if ([pe isEqualToString:@"gif"]) return @"image/gif";
  if ([pe isEqualToString:@"png"]) return @"image/png";
  if ([pe isEqualToString:@"jpg"]) return @"image/jpeg";
  if ([pe isEqualToString:@"txt"]) return @"text/plain";
  
  return @"application/octet-stream";
}

- (NSString *) davContentType
{
  // TODO: what about the content-type and other headers?
  //       => we could pass them in as the extension? (eg generate 1.gif!)
  NSString *parts, *contentType, *extension;
  
  /* try type from body structure info */
  
  if (asAttachment)
    contentType = @"application/octet-stream";
  else {
    parts = [self contentTypeForBodyPartInfo: [self partInfo]];
    contentType = [[parts componentsSeparatedByString: @";"] objectAtIndex: 0];
  
    if (![contentType length])
      {
	extension = [[self nameInContainer] pathExtension];
	contentType = [self contentTypeForPathExtension: extension];
      }
  }

  return contentType;
}

/* actions */

- (id) GETAction: (WOContext *) localContext
{
  NSException *error;
  NSData     *data;
  NSString   *etag, *mimeType, *fileName;
  id response;
  
  error = [self matchesRequestConditionInContext: localContext];
  if (error)
    {
      response = error; /* return 304 or 416 */
    }
  else
    {
//   [self debugWithFormat: @"should fetch body part: %@", 
// 	[self bodyPartIdentifier]];
      data = [self fetchBLOB];
      if (data)
	{
//   [self debugWithFormat:@"  fetched %d bytes: %@", [data length],
// 	[self partInfo]];
  
  // TODO: wrong, could be encoded
	  response = [localContext response];
	  mimeType = [self davContentType];
	  if ([mimeType isEqualToString: @"application/x-xpinstall"])
	    mimeType = @"application/octet-stream";
	  
	  [response setHeader: mimeType forKey: @"content-type"];
	  [response setHeader: [NSString stringWithFormat:@"%d", (int)[data length]]
		    forKey: @"content-length"];
  
	  if (asAttachment)
	    {
	      fileName = [self filename];
	      if ([fileName length])
		[response setHeader: [NSString stringWithFormat: @"attachment; filename*=\"utf-8''%@\"",
					       [fileName stringByEscapingURL]]
			     forKey: @"content-disposition"];
	    }

	  etag = [self davEntityTag];
	  if (etag)
	    [response setHeader: etag forKey: @"etag"];
	  
	  [response setContent: data];
	}
      else
	response = [NSException exceptionWithHTTPStatus: 404 /* not found */
				reason: @"did not find body part"];
    }

  return response;
}

/* factory */

+ (Class) bodyPartClassForKey: (NSString *) _key
		    inContext: (id) _ctx
{
  NSString *pe;
  
  pe = [_key pathExtension];
  if (![pe isNotNull] || [pe length] == 0)
    return self;
  
  /* hard coded for now */
  
  switch ([pe length]) {
  case 3:
    if ([pe isEqualToString:@"gif"] ||
	[pe isEqualToString:@"png"] ||
	[pe isEqualToString:@"jpg"])
      return NSClassFromString(@"SOGoImageMailBodyPart");
    if ([pe isEqualToString:@"ics"])
      return NSClassFromString(@"SOGoCalendarMailBodyPart");
    if ([pe isEqualToString:@"vcf"])
      return NSClassFromString(@"SOGoVCardMailBodyPart");
    break;
  case 4:
    if ([pe isEqualToString:@"eml"])
      return NSClassFromString(@"SOGoMessageMailBodyPart");
    break;
  default:
    return self;
  }
  return self;
}

+ (Class) bodyPartClassForMimeType: (NSString *) mimeType
			 inContext: (id) _ctx
{
  NSString *classString;
  Class klazz;

  if ([mimeType isEqualToString: @"image/gif"]
      || [mimeType isEqualToString: @"image/png"]
      || [mimeType isEqualToString: @"image/jpg"]
      || [mimeType isEqualToString: @"image/jpeg"])
    classString = @"SOGoImageMailBodyPart";
  else if ([mimeType isEqualToString: @"text/calendar"]
	   || [mimeType isEqualToString: @"application/ics"])
    classString = @"SOGoCalendarMailBodyPart";
  else if ([mimeType isEqualToString: @"text/html"])
    classString = @"SOGoHTMLMailBodyPart";
  else if ([mimeType isEqualToString: @"text/x-vcard"])
    classString = @"SOGoVCardMailBodyPart";
  else if ([mimeType isEqualToString: @"message/rfc822"])
    classString = @"SOGoMessageMailBodyPart";
  else
    {
      classString = @"SOGoMailBodyPart";
//       NSLog (@"unhandled mime type: '%@'", mimeType);
    }

  klazz = NSClassFromString (classString);

  return klazz;
}

- (BOOL) isFolderish
{
  return NO;
}

/* etag support */

- (id)davEntityTag {
  return mailETag;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* SOGoMailBodyPart */
