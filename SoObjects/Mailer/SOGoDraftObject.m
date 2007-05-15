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

#include "SOGoDraftObject.h"
#include <SoObjects/SOGo/WOContext+Agenor.h>
#include <SoObjects/SOGo/NSCalendarDate+SOGo.h>
#include <NGMail/NGMimeMessage.h>
#include <NGMail/NGMimeMessageGenerator.h>
#include <NGMail/NGSendMail.h>
#include <NGMime/NGMimeBodyPart.h>
#include <NGMime/NGMimeFileData.h>
#include <NGMime/NGMimeMultipartBody.h>
#include <NGMime/NGMimeType.h>
#include <NGMime/NGMimeHeaderFieldGenerator.h>
#include <NGImap4/NGImap4Envelope.h>
#include <NGImap4/NGImap4EnvelopeAddress.h>
#include <NGExtensions/NSFileManager+Extensions.h>
#include "common.h"

static NSString *contentTypeValue = @"text/plain; charset=utf-8";

@interface NSString (NGMimeHelpers)

- (NSString *) asQPSubjectString: (NSString *) encoding;

@end

@implementation NSString (NGMimeHelpers)

- (NSString *) asQPSubjectString: (NSString *) encoding;
{
  NSString *qpString;
  NSData *subjectData, *destSubjectData;

  subjectData = [self dataUsingEncoding: NSUTF8StringEncoding];
  destSubjectData = [subjectData dataByEncodingQuotedPrintable];

  qpString = [[NSString alloc] initWithData: destSubjectData
			       encoding: NSASCIIStringEncoding];
  [qpString autorelease];

  return [NSString stringWithFormat: @"=?%@?Q?%@?=", encoding, qpString];
}

@end

@implementation SOGoDraftObject

static NGMimeType  *TextPlainType  = nil;
static NGMimeType  *MultiMixedType = nil;
static NSString    *userAgent      = @"SOGoMail 1.0";
static BOOL        draftDeleteDisabled = NO; // for debugging
static BOOL        debugOn = NO;
static BOOL        showTextAttachmentsInline  = NO;
static NSString    *fromInternetSuffixPattern = nil;

+ (int)version {
  return [super version] + 0 /* v1 */;
}

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  NSAssert2([super version] == 1,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  /* Note: be aware of the charset issues before enabling this! */
  showTextAttachmentsInline = [ud boolForKey:@"SOGoShowTextAttachmentsInline"];
  
  if ((draftDeleteDisabled = [ud boolForKey:@"SOGoNoDraftDeleteAfterSend"]))
    NSLog(@"WARNING: draft delete is disabled! (SOGoNoDraftDeleteAfterSend)");
  
  fromInternetSuffixPattern = [ud stringForKey:@"SOGoInternetMailSuffix"];
  if ([fromInternetSuffixPattern length] == 0)
    NSLog(@"Note: no 'SOGoInternetMailSuffix' is configured.");
  else {
    fromInternetSuffixPattern =
      [@"\n" stringByAppendingString:fromInternetSuffixPattern];
  }
  
  TextPlainType  = [[NGMimeType mimeType:@"text"      subType:@"plain"]  copy];
  MultiMixedType = [[NGMimeType mimeType:@"multipart" subType:@"mixed"]  copy];
}

- (void)dealloc {
  [envelope release];
  [info release];
  [path release];
  [super dealloc];
}

/* draft folder functionality */

- (NSFileManager *)spoolFileManager {
  return [[self container] spoolFileManager];
}
- (NSString *)userSpoolFolderPath {
  return [[self container] userSpoolFolderPath];
}
- (BOOL)_ensureUserSpoolFolderPath {
  return [[self container] _ensureUserSpoolFolderPath];
}

/* draft object functionality */

- (NSString *)draftFolderPath {
  if (path != nil)
    return path;
  
  path = [[[self userSpoolFolderPath] stringByAppendingPathComponent:
					      [self nameInContainer]] copy];
  return path;
}
- (BOOL)_ensureDraftFolderPath {
  NSFileManager *fm;
  
  if (![self _ensureUserSpoolFolderPath])
    return NO;
  
  if ((fm = [self spoolFileManager]) == nil) {
    [self errorWithFormat:@"missing spool file manager!"];
    return NO;
  }
  return [fm createDirectoriesAtPath:[self draftFolderPath] attributes:nil];
}

- (NSString *)infoPath {
  return [[self draftFolderPath] 
	        stringByAppendingPathComponent:@".info.plist"];
}

/* contents */

- (NSException *)storeInfo:(NSDictionary *)_info {
  if (_info == nil) {
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason:@"got no info to write for draft!"];
  }
  if (![self _ensureDraftFolderPath]) {
    [self errorWithFormat:@"could not create folder for draft: '%@'",
            [self draftFolderPath]];
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason:@"could not create folder for draft!"];
  }
  if (![_info writeToFile:[self infoPath] atomically:YES]) {
    [self errorWithFormat:@"could not write info: '%@'", [self infoPath]];
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason:@"could not write draft info!"];
  }
  
  /* reset info cache */
  [info release]; info = nil;
  
  return nil /* everything is excellent */;
}
- (NSDictionary *)fetchInfo {
  NSString *p;

  if (info != nil)
    return info;
  
  p = [self infoPath];
  if (![[self spoolFileManager] fileExistsAtPath:p]) {
    [self debugWithFormat:@"Note: info object does not yet exist: %@", p];
    return nil;
  }
  
  info = [[NSDictionary alloc] initWithContentsOfFile:p];
  if (info == nil)
    [self errorWithFormat:@"draft info dictionary broken at path: %@", p];
  
  return info;
}

/* accessors */

- (NSString *)sender {
  id tmp;
  
  if ((tmp = [[self fetchInfo] objectForKey:@"from"]) == nil)
    return nil;
  if ([tmp isKindOfClass:[NSArray class]])
    return [tmp count] > 0 ? [tmp objectAtIndex:0] : nil;
  return tmp;
}

/* attachments */

- (NSArray *)fetchAttachmentNames {
  NSMutableArray *ma;
  NSFileManager  *fm;
  NSArray        *files;
  unsigned i, count;
  
  fm = [self spoolFileManager];
  if ((files = [fm directoryContentsAtPath:[self draftFolderPath]]) == nil)
    return nil;
  
  count = [files count];
  ma    = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSString *filename;
    
    filename = [files objectAtIndex:i];
    if ([filename hasPrefix:@"."])
      continue;
    
    [ma addObject:filename];
  }
  return ma;
}

- (BOOL)isValidAttachmentName:(NSString *)_name {
  static NSString *sescape[] = { @"/", @"..", @"~", @"\"", @"'", @" ", nil };
  unsigned i;
  NSRange  r;

  if (![_name isNotNull])     return NO;
  if ([_name length] == 0)    return NO;
  if ([_name hasPrefix:@"."]) return NO;
  
  for (i = 0; sescape[i] != nil; i++) {
    r = [_name rangeOfString:sescape[i]];
    if (r.length > 0) return NO;
  }
  return YES;
}

- (NSString *)pathToAttachmentWithName:(NSString *)_name {
  if ([_name length] == 0)
    return nil;
  
  return [[self draftFolderPath] stringByAppendingPathComponent:_name];
}

- (NSException *)invalidAttachmentNameError:(NSString *)_name {
  return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
		      reason:@"Invalid attachment name!"];
}

- (NSException *)saveAttachment:(NSData *)_attach withName:(NSString *)_name {
  NSString *p;
  
  if (![_attach isNotNull]) {
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			reason:@"Missing attachment content!"];
  }
  
  if (![self _ensureDraftFolderPath]) {
    return [NSException exceptionWithHTTPStatus:500 /* Server Error */
			reason:@"Could not create folder for draft!"];
  }
  if (![self isValidAttachmentName:_name])
    return [self invalidAttachmentNameError:_name];
  
  p = [self pathToAttachmentWithName:_name];
  if (![_attach writeToFile:p atomically:YES]) {
    return [NSException exceptionWithHTTPStatus:500 /* Server Error */
			reason:@"Could not write attachment to draft!"];
  }
  
  return nil; /* everything OK */
}

- (NSException *)deleteAttachmentWithName:(NSString *)_name {
  NSFileManager *fm;
  NSString *p;
  
  if (![self isValidAttachmentName:_name])
    return [self invalidAttachmentNameError:_name];
  
  fm = [self spoolFileManager];
  p  = [self pathToAttachmentWithName:_name];
  if (![fm fileExistsAtPath:p])
    return nil; /* well, doesn't exist, so its deleted ;-) */
  
  if (![fm removeFileAtPath:p handler:nil]) {
    [self logWithFormat:@"ERROR: failed to delete file: %@", p];
    return [NSException exceptionWithHTTPStatus:500 /* Server Error */
			reason:@"Could not delete attachment from draft!"];
  }
  return nil; /* everything OK */
}

/* NGMime representations */

- (NGMimeBodyPart *)bodyPartForText
{
  /*
    This add the text typed by the user (the primary plain/text part).
  */
  NGMutableHashMap *map;
  NGMimeBodyPart   *bodyPart;
  NSDictionary     *lInfo;
  id body;
  
  if ((lInfo = [self fetchInfo]) == nil)
    return nil;
  
  /* prepare header of body part */

  map = [[[NGMutableHashMap alloc] initWithCapacity:2] autorelease];

  // TODO: set charset in header!
  [map setObject:@"text/plain" forKey:@"content-type"];
  if ((body = [lInfo objectForKey:@"text"]) != nil) {
    if ([body isKindOfClass: [NSString class]]) {
      [map setObject: contentTypeValue
	   forKey: @"content-type"];
//       body = [body dataUsingEncoding:NSUTF8StringEncoding];
    }
  }
  
  /* prepare body content */
  
  bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];
  [bodyPart setBody:body];
  return bodyPart;
}

- (NGMimeMessage *)mimeMessageForContentWithHeaderMap:(NGMutableHashMap *)map
{
  NSDictionary  *lInfo;
  NGMimeMessage *message;  
  NSString *fromInternetSuffix;
  BOOL     addSuffix;
  id       body;

  if ((lInfo = [self fetchInfo]) == nil)
    return nil;
  
  addSuffix = [context isAccessFromIntranet] ? NO : YES;
  if (addSuffix) {
    fromInternetSuffix = 
      [fromInternetSuffixPattern stringByReplacingVariablesWithBindings:
				   [context request]
				 stringForUnknownBindings:@""];
    
    addSuffix = [fromInternetSuffix length] > 0 ? YES : NO;
  }
  
  [map setObject:@"text/plain" forKey:@"content-type"];
  if ((body = [lInfo objectForKey:@"text"]) != nil) {
    if ([body isKindOfClass:[NSString class]]) {
      if (addSuffix)
	body = [body stringByAppendingString:fromInternetSuffix];
      
      /* Note: just 'utf8' is displayed wrong in Mail.app */
      [map setObject: contentTypeValue
	   forKey: @"content-type"];
//       body = [body dataUsingEncoding:NSUTF8StringEncoding];
    }
    else if ([body isKindOfClass:[NSData class]] && addSuffix) {
      body = [[body mutableCopy] autorelease];
      [(NSMutableData *)body
                        appendData: [fromInternetSuffix dataUsingEncoding:NSUTF8StringEncoding]];
    }
    else if (addSuffix) {
      [self warnWithFormat:@"Note: cannot add Internet marker to body: %@",
	      NSStringFromClass([body class])];
    }
  }
  else if (addSuffix)
    body = fromInternetSuffix;
  
  message = [[[NGMimeMessage alloc] initWithHeader:map] autorelease];
  [message setBody:body];
  return message;
}

- (NSString *)mimeTypeForExtension:(NSString *)_ext {
  // TODO: make configurable
  // TODO: use /etc/mime-types
  if ([_ext isEqualToString:@"txt"])  return @"text/plain";
  if ([_ext isEqualToString:@"html"]) return @"text/html";
  if ([_ext isEqualToString:@"htm"])  return @"text/html";
  if ([_ext isEqualToString:@"gif"])  return @"image/gif";
  if ([_ext isEqualToString:@"jpg"])  return @"image/jpeg";
  if ([_ext isEqualToString:@"jpeg"]) return @"image/jpeg";
  if ([_ext isEqualToString:@"mail"]) return @"message/rfc822";
  return @"application/octet-stream";
}

- (NSString *)contentTypeForAttachmentWithName:(NSString *)_name {
  NSString *s;
  
  s = [self mimeTypeForExtension:[_name pathExtension]];
  if ([_name length] > 0)
    s = [s stringByAppendingFormat:@"; name=\"%@\"", _name];

  return s;
}
- (NSString *)contentDispositionForAttachmentWithName:(NSString *)_name {
  NSString *type;
  NSString *cdtype;
  NSString *cd;
  
  type = [self contentTypeForAttachmentWithName:_name];
  
  if ([type hasPrefix:@"text/"])
    cdtype = showTextAttachmentsInline ? @"inline" : @"attachment";
  else if ([type hasPrefix:@"image/"] || [type hasPrefix:@"message"])
    cdtype = @"inline";
  else
    cdtype = @"attachment";
  
  cd = [cdtype stringByAppendingString:@"; filename=\""];
  cd = [cd stringByAppendingString:_name];
  cd = [cd stringByAppendingString:@"\""];
  
  // TODO: add size parameter (useful addition, RFC 2183)
  return cd;
}

- (NGMimeBodyPart *)bodyPartForAttachmentWithName:(NSString *)_name {
  NSFileManager    *fm;
  NGMutableHashMap *map;
  NGMimeBodyPart   *bodyPart;
  NSString         *s;
  NSData           *content;
  BOOL             attachAsString, is7bit;
  NSString         *p;
  id body;

  if (_name == nil) return nil;

  /* check attachment */
  
  fm = [self spoolFileManager];
  p  = [self pathToAttachmentWithName:_name];
  if (![fm isReadableFileAtPath:p]) {
    [self errorWithFormat:@"did not find attachment: '%@'", _name];
    return nil;
  }
  attachAsString = NO;
  is7bit         = NO;
  
  /* prepare header of body part */

  map = [[[NGMutableHashMap alloc] initWithCapacity:4] autorelease];

  if ((s = [self contentTypeForAttachmentWithName:_name]) != nil) {
    [map setObject:s forKey:@"content-type"];
    if ([s hasPrefix:@"text/"])
      attachAsString = YES;
    else if ([s hasPrefix:@"message/rfc822"])
      is7bit = YES;
  }
  if ((s = [self contentDispositionForAttachmentWithName:_name]))
    [map setObject:s forKey:@"content-disposition"];
  
  /* prepare body content */
  
  if (attachAsString) { // TODO: is this really necessary?
    NSString *s;
    
    content = [[NSData alloc] initWithContentsOfMappedFile:p];
    
    s = [[NSString alloc] initWithData:content
			  encoding:[NSString defaultCStringEncoding]];
    if (s != nil) {
      body = s;
      [content release]; content = nil;
    }
    else {
      [self warnWithFormat:
              @"could not get text attachment as string: '%@'", _name];
      body = content;
      content = nil;
    }
  }
  else if (is7bit) {
    /* 
       Note: Apparently NGMimeFileData objects are not processed by the MIME
             generator!
    */
    body = [[NGMimeFileData alloc] initWithPath:p removeFile:NO];
    [map setObject:@"7bit" forKey:@"content-transfer-encoding"];
    [map setObject:[NSNumber numberWithInt:[body length]] 
	 forKey:@"content-length"];
  }
  else {
    /* 
       Note: in OGo this is done in LSWImapMailEditor.m:2477. Apparently
             NGMimeFileData objects are not processed by the MIME generator!
    */
    NSData *encoded;
    
    content = [[NSData alloc] initWithContentsOfMappedFile:p];
    encoded = [content dataByEncodingBase64];
    [content release]; content = nil;
    
    [map setObject:@"base64" forKey:@"content-transfer-encoding"];
    [map setObject:[NSNumber numberWithInt:[encoded length]] 
	 forKey:@"content-length"];
    
    /* Note: the -init method will create a temporary file! */
    body = [[NGMimeFileData alloc] initWithBytes:[encoded bytes]
				   length:[encoded length]];
  }
  
  bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];
  [bodyPart setBody:body];
  
  [body release]; body = nil;
  return bodyPart;
}

- (NSArray *)bodyPartsForAllAttachments {
  /* returns nil on error */
  NSMutableArray *bodyParts;
  NSArray  *names;
  unsigned i, count;
  
  names = [self fetchAttachmentNames];
  if ((count = [names count]) == 0)
    return [NSArray array];
  
  bodyParts = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    NGMimeBodyPart *bodyPart;
    
    bodyPart = [self bodyPartForAttachmentWithName:[names objectAtIndex:i]];
    if (bodyPart == nil)
      return nil;
    
    [bodyParts addObject:bodyPart];
  }
  return bodyParts;
}

- (NGMimeMessage *)mimeMultiPartMessageWithHeaderMap:(NGMutableHashMap *)map
  andBodyParts:(NSArray *)_bodyParts
{
  NGMimeMessage       *message;  
  NGMimeMultipartBody *mBody;
  NGMimeBodyPart      *part;
  NSEnumerator        *e;
  
  [map addObject:MultiMixedType forKey:@"content-type"];
    
  message = [[[NGMimeMessage alloc] initWithHeader:map] autorelease];
  mBody   = [[NGMimeMultipartBody alloc] initWithPart:message];
  
  part = [self bodyPartForText];
  [mBody addBodyPart:part];
  
  e = [_bodyParts objectEnumerator];
  while ((part = [e nextObject]) != nil)
    [mBody addBodyPart:part];
  
  [message setBody:mBody];
  [mBody release]; mBody = nil;
  return message;
}

- (void)_addHeaders:(NSDictionary *)_h toHeaderMap:(NGMutableHashMap *)_map {
  NSEnumerator *names;
  NSString *name;

  if ([_h count] == 0)
    return;
    
  names = [_h keyEnumerator];
  while ((name = [names nextObject]) != nil) {
    id value;
      
    value = [_h objectForKey:name];
    [_map addObject:value forKey:name];
  }
}

- (BOOL)isEmptyValue:(id)_value {
  if (![_value isNotNull])
    return YES;
  
  if ([_value isKindOfClass:[NSArray class]])
    return [_value count] == 0 ? YES : NO;
  
  if ([_value isKindOfClass:[NSString class]])
    return [_value length] == 0 ? YES : NO;
  
  return NO;
}

- (NGMutableHashMap *)mimeHeaderMapWithHeaders:(NSDictionary *)_headers {
  NGMutableHashMap *map;
  NSDictionary *lInfo; // TODO: this should be some kind of object?
  NSArray      *emails;
  NSString     *s, *dateString;
  id           from, replyTo;
  
  if ((lInfo = [self fetchInfo]) == nil)
    return nil;
  
  map = [[[NGMutableHashMap alloc] initWithCapacity:16] autorelease];
  
  /* add recipients */
  
  if ((emails = [lInfo objectForKey:@"to"]) != nil) {
    if ([emails count] == 0) {
      [self errorWithFormat:@"missing 'to' recipient in email!"];
      return nil;
    }
    [map setObjects:emails forKey:@"to"];
  }
  if ((emails = [lInfo objectForKey:@"cc"]) != nil)
    [map setObjects:emails forKey:@"cc"];
  if ((emails = [lInfo objectForKey:@"bcc"]) != nil)
    [map setObjects:emails forKey:@"bcc"];
  
  /* add senders */
  
  from    = [lInfo objectForKey:@"from"];
  replyTo = [lInfo objectForKey:@"replyTo"];
  
  if (![self isEmptyValue:from]) {
    if ([from isKindOfClass:[NSArray class]])
      [map setObjects:from forKey:@"from"];
    else
      [map setObject:from forKey:@"from"];
  }
  
  if (![self isEmptyValue:replyTo]) {
    if ([from isKindOfClass:[NSArray class]])
      [map setObjects:from forKey:@"reply-to"];
    else
      [map setObject:from forKey:@"reply-to"];
  }
  else if (![self isEmptyValue:from])
    [map setObjects:[map objectsForKey:@"from"] forKey:@"reply-to"];
  
  /* add subject */
  
  if ([(s = [lInfo objectForKey:@"subject"]) length] > 0)
    [map setObject: [s asQPSubjectString: @"utf-8"]
	 forKey:@"subject"];
//     [map setObject: [s asQPSubjectString: @"utf-8"] forKey:@"subject"];
  
  /* add standard headers */

  dateString = [[NSCalendarDate date] rfc822DateString];
  [map addObject: dateString forKey:@"date"];
  [map addObject: @"1.0"                forKey:@"MIME-Version"];
  [map addObject: userAgent             forKey:@"X-Mailer"];

  /* add custom headers */
  
  [self _addHeaders:[lInfo objectForKey:@"headers"] toHeaderMap:map];
  [self _addHeaders:_headers                        toHeaderMap:map];
  
  return map;
}

- (NGMimeMessage *)mimeMessageWithHeaders:(NSDictionary *)_headers {
  NSAutoreleasePool *pool;
  NGMutableHashMap  *map;
  NSArray           *bodyParts;
  NGMimeMessage     *message;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  if ([self fetchInfo] == nil) {
    [self errorWithFormat:@"could not locate draft fetch info!"];
    return nil;
  }
  
  if ((map = [self mimeHeaderMapWithHeaders:_headers]) == nil)
    return nil;
  [self debugWithFormat:@"MIME Envelope: %@", map];
  
  if ((bodyParts = [self bodyPartsForAllAttachments]) == nil) {
    [self errorWithFormat:
            @"could not create body parts for attachments!"];
    return nil; // TODO: improve error handling, return exception
  }
  [self debugWithFormat:@"attachments: %@", bodyParts];
  
  if ([bodyParts count] == 0) {
    /* no attachments */
    message = [self mimeMessageForContentWithHeaderMap:map];
  }
  else {
    /* attachments, create multipart/mixed */
    message = [self mimeMultiPartMessageWithHeaderMap:map 
		    andBodyParts:bodyParts];
  }
  [self debugWithFormat:@"message: %@", message];

  message = [message retain];
  [pool release];
  return [message autorelease];
}
- (NGMimeMessage *)mimeMessage {
  return [self mimeMessageWithHeaders:nil];
}

- (NSString *)saveMimeMessageToTemporaryFileWithHeaders:(NSDictionary *)_h {
  NGMimeMessageGenerator *gen;
  NSAutoreleasePool *pool;
  NGMimeMessage *message;
  NSString      *tmpPath;

  pool = [[NSAutoreleasePool alloc] init];
  
  message = [self mimeMessageWithHeaders:_h];
  if (![message isNotNull])
    return nil;
  if ([message isKindOfClass:[NSException class]]) {
    [self errorWithFormat:@"error: %@", message];
    return nil;
  }
  
  gen     = [[NGMimeMessageGenerator alloc] init];
  tmpPath = [[gen generateMimeFromPartToFile:message] copy];
  [gen release]; gen = nil;
  
  [pool release];
  return [tmpPath autorelease];
}
- (NSString *)saveMimeMessageToTemporaryFile {
  return [self saveMimeMessageToTemporaryFileWithHeaders:nil];
}

- (void)deleteTemporaryMessageFile:(NSString *)_path {
  NSFileManager *fm;
  
  if (![_path isNotNull])
    return;

  fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:_path])
    return;
  
  [fm removeFileAtPath:_path handler:nil];
}

- (NSArray *)allRecipients {
  NSDictionary   *lInfo;
  NSMutableArray *ma;
  NSArray        *tmp;
  
  if ((lInfo = [self fetchInfo]) == nil)
    return nil;
  
  ma = [NSMutableArray arrayWithCapacity:16];
  if ((tmp = [lInfo objectForKey:@"to"]) != nil)
    [ma addObjectsFromArray:tmp];
  if ((tmp = [lInfo objectForKey:@"cc"]) != nil)
    [ma addObjectsFromArray:tmp];
  if ((tmp = [lInfo objectForKey:@"bcc"]) != nil)
    [ma addObjectsFromArray:tmp];
  return ma;
}

- (NSString *) _rawSender
{
  NSString *startEmail, *rawSender;
  NSRange delimiter;

  startEmail = [self sender];
  delimiter = [startEmail rangeOfString: @"<"];
  if (delimiter.location == NSNotFound)
    rawSender = startEmail;
  else
    {
      rawSender = [startEmail substringFromIndex: NSMaxRange (delimiter)];
      delimiter = [rawSender rangeOfString: @">"];
      if (delimiter.location != NSNotFound)
	rawSender = [rawSender substringToIndex: delimiter.location];
    }

  return rawSender;
}

- (NSException *)sendMimeMessageAtPath:(NSString *)_path {
  static NGSendMail *mailer = nil;
  NSArray  *recipients;
  NSString *from;
  
  /* validate */
  
  recipients = [self allRecipients];
  from       = [self _rawSender];
  if ([recipients count] == 0) {
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason:@"draft has no recipients set!"];
  }
  if ([from length] == 0) {
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason:@"draft has no sender (from) set!"];
  }
  
  /* setup mailer object */
  
  if (mailer == nil)
    mailer = [[NGSendMail sharedSendMail] retain];
  if (![mailer isSendMailAvailable]) {
    [self errorWithFormat:@"missing sendmail binary!"];
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason:@"did not find sendmail binary!"];
  }
  
  /* send mail */
  
  return [mailer sendMailAtPath:_path toRecipients:recipients sender:from];
}

- (NSException *)sendMail {
  NSException *error;
  NSString    *tmpPath;
  
  /* save MIME mail to file */
  
  tmpPath = [self saveMimeMessageToTemporaryFile];
  if (![tmpPath isNotNull]) {
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason:@"could not save MIME message for draft!"];
  }
  
  /* send mail */
  error = [self sendMimeMessageAtPath:tmpPath];
  
  /* delete temporary file */
  [self deleteTemporaryMessageFile:tmpPath];

  return error;
}

/* operations */

- (NSException *)delete {
  NSFileManager *fm;
  NSString      *p, *sp;
  NSEnumerator  *e;
  
  if ((fm = [self spoolFileManager]) == nil) {
    [self errorWithFormat:@"missing spool file manager!"];
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason:@"missing spool file manager!"];
  }
  
  p = [self draftFolderPath];
  if (![fm fileExistsAtPath:p]) {
    return [NSException exceptionWithHTTPStatus:404 /* not found */
			reason:@"did not find draft!"];
  }
  
  e = [[fm directoryContentsAtPath:p] objectEnumerator];
  while ((sp = [e nextObject])) {
    sp = [p stringByAppendingPathComponent:sp];
    if (draftDeleteDisabled) {
      [self logWithFormat:@"should delete draft file %@ ...", sp];
      continue;
    }
    
    if (![fm removeFileAtPath:sp handler:nil]) {
      return [NSException exceptionWithHTTPStatus:500 /* server error */
			  reason:@"failed to delete draft!"];
    }
  }

  if (draftDeleteDisabled) {
    [self logWithFormat:@"should delete draft directory: %@", p];
  }
  else {
    if (![fm removeFileAtPath:p handler:nil]) {
      return [NSException exceptionWithHTTPStatus:500 /* server error */
			  reason:@"failed to delete draft directory!"];
    }
  }
  return nil;
}

- (NSData *)content {
  /* Note: does not cache, expensive operation */
  NSData   *data;
  NSString *p;
  
  if ((p = [self saveMimeMessageToTemporaryFile]) == nil)
    return nil;
  
  data = [NSData dataWithContentsOfMappedFile:p];
  
  /* delete temporary file */
  [self deleteTemporaryMessageFile:p];

  return data;
}
- (NSString *)contentAsString {
  NSString *str;
  NSData   *data;
  
  if ((data = [self content]) == nil)
    return nil;
  
  str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
  if (str == nil) {
    [self errorWithFormat:@"could not load draft as ASCII (data size=%d)",
	  [data length]];
    return nil;
  }

  return [str autorelease];
}

/* actions */

- (id)DELETEAction:(id)_ctx {
  NSException *error;

  if ((error = [self delete]) != nil)
    return error;
  
  return [NSNumber numberWithBool:YES]; /* delete worked out ... */
}

- (id)GETAction:(id)_ctx {
  /* 
     Override, because SOGoObject's GETAction uses the less efficient
     -contentAsString method.
  */
  WORequest *rq;

  rq = [_ctx request];
  if ([rq isSoWebDAVRequest]) {
    WOResponse *r;
    NSData     *content;
    
    if ((content = [self content]) == nil) {
      return [NSException exceptionWithHTTPStatus:500
			  reason:@"Could not generate MIME content!"];
    }
    r = [_ctx response];
    [r setHeader:@"message/rfc822" forKey:@"content-type"];
    [r setContent:content];
    return r;
  }
  
  return [super GETAction:_ctx];
}

/* fake being a SOGoMailObject */

- (id)fetchParts:(NSArray *)_parts {
  return [NSDictionary dictionaryWithObject:self forKey:@"fetch"];
}

- (NSString *)uid {
  return [self nameInContainer];
}
- (NSArray *)flags {
  static NSArray *seenFlags = nil;
  seenFlags = [[NSArray alloc] initWithObjects:@"seen", nil];
  return seenFlags;
}
- (unsigned)size {
  // TODO: size, hard to support, we would need to generate MIME?
  return 0;
}

- (NSArray *)imap4EnvelopeAddressesForStrings:(NSArray *)_emails {
  NSMutableArray *ma;
  unsigned i, count;
  
  if (_emails == nil)
    return nil;
  if ((count = [_emails count]) == 0)
    return [NSArray array];

  ma = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    NGImap4EnvelopeAddress *envaddr;

    envaddr = [[NGImap4EnvelopeAddress alloc] 
		initWithString:[_emails objectAtIndex:i]];
    if ([envaddr isNotNull])
      [ma addObject:envaddr];
    [envaddr release];
  }
  return ma;
}

- (NGImap4Envelope *)envelope {
  NSDictionary *lInfo;
  id from, replyTo;
  
  if (envelope != nil)
    return envelope;
  if ((lInfo = [self fetchInfo]) == nil)
    return nil;
  
  if ((from = [self sender]) != nil)
    from = [NSArray arrayWithObjects:&from count:1];

  if ((replyTo = [lInfo objectForKey:@"replyTo"]) != nil) {
    if (![replyTo isKindOfClass:[NSArray class]])
      replyTo = [NSArray arrayWithObjects:&replyTo count:1];
  }
  
  envelope = 
    [[NGImap4Envelope alloc] initWithMessageID:[self nameInContainer]
			     subject:[lInfo objectForKey:@"subject"]
			     from:from replyTo:replyTo
			     to:[lInfo objectForKey:@"to"]
			     cc:[lInfo objectForKey:@"cc"]
			     bcc:[lInfo objectForKey:@"bcc"]];
  return envelope;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* SOGoDraftObject */
