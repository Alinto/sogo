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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGImap4/NGImap4Connection.h>

#import <SoObjects/SOGo/NSDictionary+Utilities.h>

#import "SOGoMailObject.h"
#import "SOGoMailManager.h"

#import "SOGoMailBodyPart.h"

@implementation SOGoMailBodyPart

static NSString *mailETag = nil;
static BOOL debugOn = NO;

+ (void) initialize
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  if (![[ud objectForKey:@"SOGoMailDisableETag"] boolValue]) {
    mailETag = [[NSString alloc] initWithFormat:@"\"imap4url_%d_%d_%03d\"",
				 UIX_MAILER_MAJOR_VERSION,
				 UIX_MAILER_MINOR_VERSION,
				 UIX_MAILER_SUBMINOR_VERSION];
    NSLog(@"Note(SOGoMailBodyPart): using constant etag for mail parts: '%@'", 
	  mailETag);
  }
  else
    NSLog(@"Note(SOGoMailBodyPart): etag caching disabled!");
}

- (void)dealloc {
  [self->partInfo   release];
  [self->identifier release];
  [self->pathToPart release];
  [super dealloc];
}

/* hierarchy */

- (SOGoMailObject *)mailObject {
  return [[self container] mailObject];
}

/* IMAP4 */

- (NSString *)bodyPartName {
  NSString *s;
  NSRange  r;

  s = [self nameInContainer];
  r = [s rangeOfString:@"."]; /* strip extensions */
  if (r.length == 0)
    return s;
  return [s substringToIndex:r.location];
}

- (NSArray *)bodyPartPath {
  NSMutableArray *p;
  id obj;
  
  if (self->pathToPart != nil)
    return [self->pathToPart isNotNull] ? self->pathToPart : nil;
  
  p = [[NSMutableArray alloc] initWithCapacity:8];
  for (obj = self; [obj isKindOfClass:[SOGoMailBodyPart class]]; 
       obj = [obj container]) {
    [p insertObject:[obj bodyPartName] atIndex:0];
  }
  
  self->pathToPart = [p copy];
  [p release];
  return self->pathToPart;
}

- (NSString *)bodyPartIdentifier {
  if (self->identifier != nil)
    return [self->identifier isNotNull] ? self->identifier : nil;
  
  self->identifier =
    [[[self bodyPartPath] componentsJoinedByString:@"."] copy];
  return self->identifier;
}

- (NSURL *)imap4URL {
  /* reuse URL of message */
  return [[self mailObject] imap4URL];
}

/* part info */

- (id)partInfo {
  if (self->partInfo != nil)
    return [self->partInfo isNotNull] ? self->partInfo : nil;

  self->partInfo =
    [[[self mailObject] lookupInfoForBodyPart:[self bodyPartPath]] retain];
  return self->partInfo;
}

/* name lookup */

- (id) lookupImap4BodyPartKey: (NSString *) _key
		    inContext: (id) _ctx
{
  // TODO: we might want to check for existence prior controller creation
  Class clazz;
  
  clazz = [SOGoMailBodyPart bodyPartClassForKey:_key inContext:_ctx];

  return [clazz objectWithName: _key inContainer: self];
}

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
      if ([self isBodyPartKey:_key inContext:_ctx])
	obj = [self lookupImap4BodyPartKey:_key inContext:_ctx];
      /* should check whether such a filename exist in the attached names */
      if (!obj)
	obj = self;
    }

  return obj;      
}

/* fetch */

- (NSData *) fetchBLOB
{
  // HEADER, HEADER.FIELDS, HEADER.FIELDS.NOT, MIME, TEXT
  NSString *enc;
  NSData *data;
  
  data = [[self imap4Connection] fetchContentOfBodyPart:
				   [self bodyPartIdentifier]
				 atURL:[self imap4URL]];
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
      enc = [enc uppercaseString];
      
      if ([enc isEqualToString:@"BASE64"])
	data = [data dataByDecodingBase64];
      else if ([enc isEqualToString:@"7BIT"])
	; /* keep data as is */ // TODO: do we need to change encodings?
      else
	[self errorWithFormat:@"unsupported encoding: %@", enc];
    }
  
  return data;
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
  
  parts = [self contentTypeForBodyPartInfo: [self partInfo]];
  contentType = [[parts componentsSeparatedByString: @";"] objectAtIndex: 0];

  if (![contentType length])
    {
      extension = [[self nameInContainer] pathExtension];
      contentType = [self contentTypeForPathExtension: extension];
    }

  return contentType;
}

/* actions */

- (id)GETAction:(id)_ctx {
  NSException *error;
  WOResponse *r;
  NSData     *data;
  NSString   *etag, *mimeType;
  
  if ((error = [self matchesRequestConditionInContext:_ctx]) != nil) {
    // TODO: currently we fetch the body structure to get here - check this!
    /* check whether the mail still exists */
    if (![[self mailObject] doesMailExist]) {
      return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			  reason:@"mail was deleted"];
    }
    return error; /* return 304 or 416 */
  }

  [self debugWithFormat:@"should fetch body part: %@", 
	  [self bodyPartIdentifier]];
  
  if ((data = [self fetchBLOB]) == nil) {
    return [NSException exceptionWithHTTPStatus:404 /* not found */
			reason:@"did not find body part"];
  }
  
  [self debugWithFormat:@"  fetched %d bytes: %@", [data length],
	[self partInfo]];
  
  // TODO: wrong, could be encoded
  r = [(WOContext *)_ctx response];
  mimeType = [self davContentType];
  if ([mimeType isEqualToString: @"application/x-xpinstall"])
    mimeType = @"application/octet-stream";

  [r setHeader: mimeType forKey:@"content-type"];
  [r setHeader: [NSString stringWithFormat:@"%d", [data length]]
     forKey: @"content-length"];

  if ((etag = [self davEntityTag]) != nil)
    [r setHeader:etag forKey:@"etag"];

  [r setContent:data];

  return r;
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
    if ([pe isEqualToString:@"mail"])
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
  else if ([mimeType isEqualToString: @"text/calendar"])
    classString = @"SOGoCalendarMailBodyPart";
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

/* etag support */

- (id)davEntityTag {
  return mailETag;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* SOGoMailBodyPart */
