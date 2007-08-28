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
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest+So.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSFileManager+Extensions.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGExtensions/NSString+misc.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Envelope.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeFileData.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimeType.h>
#import <NGMime/NGMimeHeaderFieldGenerator.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSCalendarDate+SOGo.h>
#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/SOGo/SOGoMailer.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import "SOGoMailAccount.h"
#import "SOGoMailFolder.h"
#import "SOGoMailObject.h"
#import "SOGoMailObject+Draft.h"

#import "SOGoDraftObject.h"

static NSString *contentTypeValue = @"text/plain; charset=utf-8";
static NSString *headerKeys[] = {@"subject", @"to", @"cc", @"bcc", 
				 @"from", @"replyTo",
				 nil};

@implementation SOGoDraftObject

static NGMimeType  *TextPlainType  = nil;
static NGMimeType  *MultiMixedType = nil;
static NSString    *userAgent      = @"SOGoMail 1.0";
static BOOL        draftDeleteDisabled = NO; // for debugging
static BOOL        debugOn = NO;
static BOOL        showTextAttachmentsInline  = NO;

+ (void) initialize
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  /* Note: be aware of the charset issues before enabling this! */
  showTextAttachmentsInline = [ud boolForKey: @"SOGoShowTextAttachmentsInline"];
  
  if ((draftDeleteDisabled = [ud boolForKey: @"SOGoNoDraftDeleteAfterSend"]))
    NSLog(@"WARNING: draft delete is disabled! (SOGoNoDraftDeleteAfterSend)");
  
  TextPlainType  = [[NGMimeType mimeType: @"text" subType: @"plain"]  copy];
  MultiMixedType = [[NGMimeType mimeType: @"multipart" subType: @"mixed"]  copy];
}

- (id) init
{
  if ((self = [super init]))
    {
      IMAP4ID = -1;
      headers = [NSMutableDictionary new];
      text = @"";
      sourceURL = nil;
      sourceFlag = nil;
      inReplyTo = nil;
    }

  return self;
}

- (void) dealloc
{
  [headers release];
  [text release];
  [envelope release];
  [path release];
  [sourceURL release];
  [sourceFlag release];
  [inReplyTo release];
  [super dealloc];
}

/* draft folder functionality */

- (NSString *) userSpoolFolderPath
{
  return [[self container] userSpoolFolderPath];
}

/* draft object functionality */

- (NSString *) draftFolderPath
{
  if (!path)
    {
      path = [[self userSpoolFolderPath] stringByAppendingPathComponent:
					   nameInContainer];
      [path retain];
    }

  return path;
}

- (BOOL) _ensureDraftFolderPath
{
  NSFileManager *fm;

  fm = [NSFileManager defaultManager];
  
  return ([fm createDirectoriesAtPath: [container userSpoolFolderPath]
	      attributes: nil]
	  && [fm createDirectoriesAtPath: [self draftFolderPath]
		 attributes:nil]);
}

- (NSString *) infoPath
{
  return [[self draftFolderPath]
	   stringByAppendingPathComponent: @".info.plist"];
}

/* contents */

- (void) setHeaders: (NSDictionary *) newHeaders
{
  id headerValue;
  unsigned int count;

  for (count = 0; count < 7; count++)
    {
      headerValue = [newHeaders objectForKey: headerKeys[count]];
      if (headerValue)
	[headers setObject: headerValue
		 forKey: headerKeys[count]];
      else
	[headers removeObjectForKey: headerKeys[count]];
    }
}

- (NSDictionary *) headers
{
  return headers;
}

- (void) setText: (NSString *) newText
{
  ASSIGN (text, newText);
}

- (NSString *) text
{
  return text;
}

- (void) setInReplyTo: (NSString *) newInReplyTo
{
  ASSIGN (inReplyTo, newInReplyTo);
}

- (void) setSourceURL: (NSString *) newSourceURL
{
  ASSIGN (sourceURL, newSourceURL);
}

- (void) setSourceFlag: (NSString *) newSourceFlag
{
  ASSIGN (sourceFlag, newSourceFlag);
}

- (NSException *) storeInfo
{
  NSMutableDictionary *infos;
  NSException *error;

  if ([self _ensureDraftFolderPath])
    {
      infos = [NSMutableDictionary new];
      [infos setObject: headers forKey: @"headers"];
      if (text)
	[infos setObject: text forKey: @"text"];
      if (inReplyTo)
	[infos setObject: inReplyTo forKey: @"inReplyTo"];
      if (IMAP4ID > -1)
	[infos setObject: [NSNumber numberWithInt: IMAP4ID]
	       forKey: @"IMAP4ID"];
      if (sourceURL && sourceFlag)
	{
	  [infos setObject: sourceURL forKey: @"sourceURL"];
	  [infos setObject: sourceFlag forKey: @"sourceFlag"];
	}

      if ([infos writeToFile: [self infoPath] atomically:YES])
	error = nil;
      else
	{
	  [self errorWithFormat: @"could not write info: '%@'",
		[self infoPath]];
	  error = [NSException exceptionWithHTTPStatus:500 /* server error */
			       reason: @"could not write draft info!"];
	}

      [infos release];
    }
  else
    {
      [self errorWithFormat: @"could not create folder for draft: '%@'",
            [self draftFolderPath]];
      error = [NSException exceptionWithHTTPStatus:500 /* server error */
			   reason: @"could not create folder for draft!"];
    }

  return error;
}

- (void) _loadInfosFromDictionary: (NSDictionary *) infoDict
{
  id value;

  value = [infoDict objectForKey: @"headers"];
  if (value)
    [self setHeaders: value];

  value = [infoDict objectForKey: @"text"];
  if ([value length] > 0)
    [self setText: value];

  value = [infoDict objectForKey: @"IMAP4ID"];
  if (value)
    [self setIMAP4ID: [value intValue]];

  value = [infoDict objectForKey: @"sourceURL"];
  if (value)
    [self setSourceURL: value];
  value = [infoDict objectForKey: @"sourceFlag"];
  if (value)
    [self setSourceFlag: value];

  value = [infoDict objectForKey: @"inReplyTo"];
  if (value)
    [self setInReplyTo: value];
}

- (NSString *) relativeImap4Name
{
  return [NSString stringWithFormat: @"%d", IMAP4ID];
}

- (void) fetchInfo
{
  NSString *p;
  NSDictionary *infos;
  NSFileManager *fm;

  p = [self infoPath];

  fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath: p])
    {
      infos = [NSDictionary dictionaryWithContentsOfFile: p];
      if (infos)
	[self _loadInfosFromDictionary: infos];
//       else
// 	[self errorWithFormat: @"draft info dictionary broken at path: %@", p];
    }
  else
    [self debugWithFormat: @"Note: info object does not yet exist: %@", p];
}

- (void) setIMAP4ID: (int) newIMAP4ID
{
  IMAP4ID = newIMAP4ID;
}

- (int) IMAP4ID
{
  return IMAP4ID;
}

- (int) _IMAP4IDFromAppendResult: (NSDictionary *) result
{
  NSDictionary *results;
  NSString *flag, *newIdString;

  results = [[result objectForKey: @"RawResponse"]
	      objectForKey: @"ResponseResult"];
  flag = [results objectForKey: @"flag"];
  newIdString = [[flag componentsSeparatedByString: @" "] objectAtIndex: 2];

  return [newIdString intValue];
}

- (NSException *) save
{
  NGImap4Client *client;
  NSException *error;
  NSData *message;
  NSString *folder;
  id result;

  error = nil;
  message = [self mimeMessageAsData];

  client = [[self imap4Connection] client];
  folder = [imap4 imap4FolderNameForURL: [container imap4URL]];
  result
    = [client append: message toFolder: folder
	      withFlags: [NSArray arrayWithObjects: @"seen", @"draft", nil]];
  if ([[result objectForKey: @"result"] boolValue])
    {
      if (IMAP4ID > -1)
	error = [imap4 markURLDeleted: [self imap4URL]];
      IMAP4ID = [self _IMAP4IDFromAppendResult: result];
      [self storeInfo];
    }
  else
    error = [NSException exceptionWithHTTPStatus:500 /* Server Error */
			 reason: @"Failed to store message"];

  return error;
}

- (void) _addEMailsOfAddresses: (NSArray *) _addrs
		       toArray: (NSMutableArray *) _ma
{
  unsigned i, count;

  for (i = 0, count = [_addrs count]; i < count; i++)
    [_ma addObject:
	   [(NGImap4EnvelopeAddress *) [_addrs objectAtIndex: i] email]];
}

- (void) _fillInReplyAddresses: (NSMutableDictionary *) _info
		    replyToAll: (BOOL) _replyToAll
		      envelope: (NGImap4Envelope *) _envelope
{
  /*
    The rules as implemented by Thunderbird:
    - if there is a 'reply-to' header, only include that (as TO)
    - if we reply to all, all non-from addresses are added as CC
    - the from is always the lone TO (except for reply-to)
    
    Note: we cannot check reply-to, because Cyrus even sets a reply-to in the
          envelope if none is contained in the message itself! (bug or
          feature?)
    
    TODO: what about sender (RFC 822 3.6.2)
  */
  NSMutableArray *to;
  NSArray *addrs;
  
  to = [NSMutableArray arrayWithCapacity:2];

  /* first check for "reply-to" */
  
  addrs = [_envelope replyTo];
  if ([addrs count] == 0)
    /* no "reply-to", try "from" */
    addrs = [_envelope from];

  [self _addEMailsOfAddresses: addrs toArray: to];
  [_info setObject: to forKey: @"to"];

  /* CC processing if we reply-to-all: add all 'to' and 'cc'  */
  
  if (_replyToAll)
    {
      to = [NSMutableArray arrayWithCapacity:8];

      [self _addEMailsOfAddresses: [_envelope to] toArray: to];
      [self _addEMailsOfAddresses: [_envelope cc] toArray: to];
    
      [_info setObject: to forKey: @"cc"];
    }
}

- (void) _fetchAttachments: (NSArray *) parts
                  fromMail: (SOGoMailObject *) sourceMail
{
  unsigned int count, max;
  NSDictionary *currentPart, *attachment, *body;
  NSArray *paths, *result;

  max = [parts count];
  if (max > 0)
    {
      paths = [parts keysWithFormat: @"BODY[%{path}]"];
      result = [[sourceMail fetchParts: paths] objectForKey: @"fetch"];
      for (count = 0; count < max; count++)
	{
	  currentPart = [parts objectAtIndex: count];
	  body = [[result objectAtIndex: count] objectForKey: @"body"];
	  attachment = [NSDictionary dictionaryWithObjectsAndKeys:
				       [currentPart objectForKey: @"filename"],
				     @"filename",
				     [currentPart objectForKey: @"mimetype"],
				     @"mime-type",
				     nil];
	  [self saveAttachment: [body objectForKey: @"data"]
		withMetadata: attachment];
	}
    }
}

- (void) fetchMailForEditing: (SOGoMailObject *) sourceMail
{
  NSString *subject;
  NSMutableDictionary *info;
  NSMutableArray *addresses;
  NGImap4Envelope *sourceEnvelope;

  [sourceMail fetchCoreInfos];

  [self _fetchAttachments: [sourceMail fetchFileAttachmentKeys]
	fromMail: sourceMail];
  info = [NSMutableDictionary dictionaryWithCapacity: 16];
  subject = [sourceMail subject];
  if ([subject length] > 0)
    [info setObject: subject forKey: @"subject"];

  sourceEnvelope = [sourceMail envelope];
  addresses = [NSMutableArray array];
  [self _addEMailsOfAddresses: [sourceEnvelope to] toArray: addresses];
  [info setObject: addresses forKey: @"to"];
  addresses = [NSMutableArray array];
  [self _addEMailsOfAddresses: [sourceEnvelope cc] toArray: addresses];
  if ([addresses count] > 0)
    [info setObject: addresses forKey: @"cc"];
  addresses = [NSMutableArray array];
  [self _addEMailsOfAddresses: [sourceEnvelope bcc] toArray: addresses];
  if ([addresses count] > 0)
    [info setObject: addresses forKey: @"bcc"];
  addresses = [NSMutableArray array];
  [self _addEMailsOfAddresses: [sourceEnvelope replyTo] toArray: addresses];
  if ([addresses count] > 0)
    [info setObject: addresses forKey: @"replyTo"];
  [self setHeaders: info];

  [self setText: [sourceMail contentForEditing]];
  [self setSourceURL: [sourceMail imap4URLString]];
  IMAP4ID = [[sourceMail nameInContainer] intValue];

  [self storeInfo];
}

- (void) fetchMailForReplying: (SOGoMailObject *) sourceMail
			toAll: (BOOL) toAll
{
  NSString *contentForReply, *msgID;
  NSMutableDictionary *info;
  NGImap4Envelope *sourceEnvelope;

  [sourceMail fetchCoreInfos];

  info = [NSMutableDictionary dictionaryWithCapacity: 16];
  [info setObject: [sourceMail subjectForReply] forKey: @"subject"];

  sourceEnvelope = [sourceMail envelope];
  [self _fillInReplyAddresses: info replyToAll: toAll
	envelope: sourceEnvelope];
  msgID = [sourceEnvelope messageID];
  if ([msgID length] > 0)
    [self setInReplyTo: msgID];
  contentForReply = [sourceMail contentForReply];
  [self setText: contentForReply];
  [self setHeaders: info];
  [self setSourceURL: [sourceMail imap4URLString]];
  [self setSourceFlag: @"Answered"];
  [self storeInfo];
}

- (void) fetchMailForForwarding: (SOGoMailObject *) sourceMail
{
  NSDictionary *info, *attachment;
  SOGoUser *currentUser;

  [sourceMail fetchCoreInfos];

  info = [NSDictionary dictionaryWithObject: [sourceMail subjectForForward]
		       forKey: @"subject"];
  [self setHeaders: info];
  [self setSourceURL: [sourceMail imap4URLString]];
  [self setSourceFlag: @"$Forwarded"];

  /* attach message */
  currentUser = [context activeUser];
  if ([[currentUser messageForwarding] isEqualToString: @"inline"])
    [self setText: [sourceMail contentForInlineForward]];
  else
    {
  // TODO: use subject for filename?
//   error = [newDraft saveAttachment:content withName:@"forward.mail"];
      attachment = [NSDictionary dictionaryWithObjectsAndKeys:
				   [sourceMail filenameForForward], @"filename",
				 @"message/rfc822", @"mime-type",
				 nil];
      [self saveAttachment: [sourceMail content]
	    withMetadata: attachment];
    }
  [self storeInfo];
}

/* accessors */

- (NSString *) sender
{
  id tmp;
  
  if ((tmp = [headers objectForKey: @"from"]) == nil)
    return nil;
  if ([tmp isKindOfClass:[NSArray class]])
    return [tmp count] > 0 ? [tmp objectAtIndex: 0] : nil;

  return tmp;
}

/* attachments */

- (NSArray *) fetchAttachmentNames
{
  NSMutableArray *ma;
  NSFileManager *fm;
  NSArray *files;
  unsigned count, max;
  NSString *filename;

  fm = [NSFileManager defaultManager];
  files = [fm directoryContentsAtPath: [self draftFolderPath]];

  max = [files count];
  ma = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      filename = [files objectAtIndex: count];
      if (![filename hasPrefix: @"."])
	[ma addObject: filename];
    }

  return ma;
}

- (BOOL) isValidAttachmentName: (NSString *) _name
{
  static NSString *sescape[] = { @"/", @"..", @"~", @"\"", @"'", @" ", nil };
  unsigned i;
  NSRange  r;

  if (![_name isNotNull])     return NO;
  if ([_name length] == 0)    return NO;
  if ([_name hasPrefix: @"."]) return NO;
  
  for (i = 0; sescape[i] != nil; i++) {
    r = [_name rangeOfString:sescape[i]];
    if (r.length > 0) return NO;
  }
  return YES;
}

- (NSString *) pathToAttachmentWithName: (NSString *) _name
{
  if ([_name length] == 0)
    return nil;
  
  return [[self draftFolderPath] stringByAppendingPathComponent:_name];
}

- (NSException *) invalidAttachmentNameError: (NSString *) _name
{
  return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
		      reason: @"Invalid attachment name!"];
}

- (NSException *) saveAttachment: (NSData *) _attach
		    withMetadata: (NSDictionary *) metadata
{
  NSString *p, *name, *mimeType;
  
  if (![_attach isNotNull]) {
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			reason: @"Missing attachment content!"];
  }
  
  if (![self _ensureDraftFolderPath]) {
    return [NSException exceptionWithHTTPStatus:500 /* Server Error */
			reason: @"Could not create folder for draft!"];
  }
  name = [metadata objectForKey: @"filename"];
  if (![self isValidAttachmentName: name])
    return [self invalidAttachmentNameError: name];
  
  p = [self pathToAttachmentWithName: name];
  if (![_attach writeToFile: p atomically: YES])
    {
      return [NSException exceptionWithHTTPStatus:500 /* Server Error */
			  reason: @"Could not write attachment to draft!"];
    }

  mimeType = [metadata objectForKey: @"mime-type"];
  if ([mimeType length] > 0)
    {
      p = [self pathToAttachmentWithName:
		  [NSString stringWithFormat: @".%@.mime", name]];
      if (![[mimeType dataUsingEncoding: NSUTF8StringEncoding]
	     writeToFile: p atomically: YES])
	{
	  return [NSException exceptionWithHTTPStatus:500 /* Server Error */
			      reason: @"Could not write attachment to draft!"];
	}
    }
  
  return nil; /* everything OK */
}

- (NSException *) deleteAttachmentWithName: (NSString *) _name
{
  NSFileManager *fm;
  NSString *p;
  NSException *error;

  error = nil;

  if ([self isValidAttachmentName:_name]) 
    {
      fm = [NSFileManager defaultManager];
      p = [self pathToAttachmentWithName:_name];
      if ([fm fileExistsAtPath: p])
	if (![fm removeFileAtPath: p handler: nil])
	  error
	    = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
			   reason: @"Could not delete attachment from draft!"];
    }
  else
    error = [self invalidAttachmentNameError:_name];

  return error;  
}

/* NGMime representations */

- (NGMimeBodyPart *) bodyPartForText
{
  /*
    This add the text typed by the user (the primary plain/text part).
  */
  NGMutableHashMap *map;
  NGMimeBodyPart   *bodyPart;
  
  /* prepare header of body part */

  map = [[[NGMutableHashMap alloc] initWithCapacity: 1] autorelease];

  // TODO: set charset in header!
  [map setObject: @"text/plain" forKey: @"content-type"];
  if (text)
    [map setObject: contentTypeValue forKey: @"content-type"];

//   if ((body = text) != nil) {
//     if ([body isKindOfClass: [NSString class]]) {
//       [map setObject: contentTypeValue
// 	   forKey: @"content-type"];
// //       body = [body dataUsingEncoding:NSUTF8StringEncoding];
//     }
//   }
  
  /* prepare body content */
  
  bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];
  [bodyPart setBody: text];

  return bodyPart;
}

- (NGMimeMessage *) mimeMessageForContentWithHeaderMap: (NGMutableHashMap *) map
{
  NGMimeMessage *message;  
//   BOOL     addSuffix;
  id       body;

  [map setObject: @"text/plain" forKey: @"content-type"];
  body = text;
  if (body)
    {
//       if ([body isKindOfClass:[NSString class]])
	/* Note: just 'utf8' is displayed wrong in Mail.app */
	[map setObject: contentTypeValue
	     forKey: @"content-type"];
//       body = [body dataUsingEncoding:NSUTF8StringEncoding];
//       else if ([body isKindOfClass:[NSData class]] && addSuffix) {
// 	body = [[body mutableCopy] autorelease];
//       }
//       else if (addSuffix) {
// 	[self warnWithFormat: @"Note: cannot add Internet marker to body: %@",
// 	      NSStringFromClass([body class])];
//       }

	message = [[[NGMimeMessage alloc] initWithHeader:map] autorelease];
	[message setBody: body];
    }
  else
    message = nil;


  return message;
}

- (NSString *) mimeTypeForExtension: (NSString *) _ext
{
  // TODO: make configurable
  // TODO: use /etc/mime-types
  if ([_ext isEqualToString: @"txt"])  return @"text/plain";
  if ([_ext isEqualToString: @"html"]) return @"text/html";
  if ([_ext isEqualToString: @"htm"])  return @"text/html";
  if ([_ext isEqualToString: @"gif"])  return @"image/gif";
  if ([_ext isEqualToString: @"jpg"])  return @"image/jpeg";
  if ([_ext isEqualToString: @"jpeg"]) return @"image/jpeg";
  if ([_ext isEqualToString: @"mail"]) return @"message/rfc822";
  return @"application/octet-stream";
}

- (NSString *) contentTypeForAttachmentWithName: (NSString *) _name
{
  NSString *s, *p;
  NSData *mimeData;
  
  p = [self pathToAttachmentWithName:
	      [NSString stringWithFormat: @".%@.mime", _name]];
  mimeData = [NSData dataWithContentsOfFile: p];
  if (mimeData)
    {
      s = [[NSString alloc] initWithData: mimeData
			    encoding: NSUTF8StringEncoding];
      [s autorelease];
    }
  else
    {
      s = [self mimeTypeForExtension:[_name pathExtension]];
      if ([_name length] > 0)
	s = [s stringByAppendingFormat: @"; name=\"%@\"", _name];
    }

  return s;
}

- (NSString *) contentDispositionForAttachmentWithName: (NSString *) _name
{
  NSString *type;
  NSString *cdtype;
  NSString *cd;
  
  type = [self contentTypeForAttachmentWithName:_name];
  
  if ([type hasPrefix: @"text/"])
    cdtype = showTextAttachmentsInline ? @"inline" : @"attachment";
  else if ([type hasPrefix: @"image/"] || [type hasPrefix: @"message"])
    cdtype = @"inline";
  else
    cdtype = @"attachment";
  
  cd = [cdtype stringByAppendingString: @"; filename=\""];
  cd = [cd stringByAppendingString: _name];
  cd = [cd stringByAppendingString: @"\""];

  // TODO: add size parameter (useful addition, RFC 2183)
  return cd;
}

- (NGMimeBodyPart *) bodyPartForAttachmentWithName: (NSString *) _name
{
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
  
  fm = [NSFileManager defaultManager];
  p  = [self pathToAttachmentWithName:_name];
  if (![fm isReadableFileAtPath:p]) {
    [self errorWithFormat: @"did not find attachment: '%@'", _name];
    return nil;
  }
  attachAsString = NO;
  is7bit         = NO;
  
  /* prepare header of body part */

  map = [[[NGMutableHashMap alloc] initWithCapacity:4] autorelease];

  if ((s = [self contentTypeForAttachmentWithName:_name]) != nil) {
    [map setObject:s forKey: @"content-type"];
    if ([s hasPrefix: @"text/"])
      attachAsString = YES;
    else if ([s hasPrefix: @"message/rfc822"])
      is7bit = YES;
  }
  if ((s = [self contentDispositionForAttachmentWithName:_name]))
    [map setObject:s forKey: @"content-disposition"];
  
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
    [map setObject: @"7bit" forKey: @"content-transfer-encoding"];
    [map setObject:[NSNumber numberWithInt:[body length]] 
	 forKey: @"content-length"];
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
    
    [map setObject: @"base64" forKey: @"content-transfer-encoding"];
    [map setObject:[NSNumber numberWithInt:[encoded length]] 
	 forKey: @"content-length"];
    
    /* Note: the -init method will create a temporary file! */
    body = [[NGMimeFileData alloc] initWithBytes:[encoded bytes]
				   length:[encoded length]];
  }
  
  bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];
  [bodyPart setBody:body];
  
  [body release]; body = nil;
  return bodyPart;
}

- (NSArray *) bodyPartsForAllAttachments
{
  /* returns nil on error */
  NSArray  *names;
  unsigned i, count;
  NGMimeBodyPart *bodyPart;
  NSMutableArray *bodyParts;

  names = [self fetchAttachmentNames];
  count = [names count];
  bodyParts = [NSMutableArray arrayWithCapacity: count];

  for (i = 0; i < count; i++)
    {
      bodyPart = [self bodyPartForAttachmentWithName: [names objectAtIndex: i]];
      [bodyParts addObject: bodyPart];
    }

  return bodyParts;
}

- (NGMimeMessage *) mimeMultiPartMessageWithHeaderMap: (NGMutableHashMap *) map
					 andBodyParts: (NSArray *) _bodyParts
{
  NGMimeMessage       *message;  
  NGMimeMultipartBody *mBody;
  NGMimeBodyPart      *part;
  NSEnumerator        *e;
  
  [map addObject: MultiMixedType forKey: @"content-type"];

  message = [[NGMimeMessage alloc] initWithHeader: map];
  [message autorelease];
  mBody = [[NGMimeMultipartBody alloc] initWithPart: message];

  part = [self bodyPartForText];
  [mBody addBodyPart: part];

  e = [_bodyParts objectEnumerator];
  part = [e nextObject];
  while (part)
    {
      [mBody addBodyPart: part];
      part = [e nextObject];
    }

  [message setBody: mBody];
  [mBody release];

  return message;
}

- (void) _addHeaders: (NSDictionary *) _h
         toHeaderMap: (NGMutableHashMap *) _map
{
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

- (BOOL) isEmptyValue: (id) _value
{
  if (![_value isNotNull])
    return YES;
  
  if ([_value isKindOfClass: [NSArray class]])
    return [_value count] == 0 ? YES : NO;
  
  if ([_value isKindOfClass: [NSString class]])
    return [_value length] == 0 ? YES : NO;

  return NO;
}

- (NGMutableHashMap *) mimeHeaderMapWithHeaders: (NSDictionary *) _headers
{
  NGMutableHashMap *map;
  NSArray      *emails;
  NSString     *s, *dateString;
  id           from, replyTo;
  
  map = [[[NGMutableHashMap alloc] initWithCapacity:16] autorelease];
  
  /* add recipients */
  
  if ((emails = [headers objectForKey: @"to"]) != nil)
    [map setObjects: emails forKey: @"to"];
  if ((emails = [headers objectForKey: @"cc"]) != nil)
    [map setObjects:emails forKey: @"cc"];
  if ((emails = [headers objectForKey: @"bcc"]) != nil)
    [map setObjects:emails forKey: @"bcc"];

  /* add senders */
  
  from = [headers objectForKey: @"from"];
  replyTo = [headers objectForKey: @"replyTo"];
  
  if (![self isEmptyValue:from]) {
    if ([from isKindOfClass:[NSArray class]])
      [map setObjects: from forKey: @"from"];
    else
      [map setObject: from forKey: @"from"];
  }
  
  if (![self isEmptyValue: replyTo]) {
    if ([from isKindOfClass:[NSArray class]])
      [map setObjects:from forKey: @"reply-to"];
    else
      [map setObject:from forKey: @"reply-to"];
  }
  else if (![self isEmptyValue:from])
    [map setObjects:[map objectsForKey: @"from"] forKey: @"reply-to"];
  
  /* add subject */
  if (inReplyTo)
    [map setObject: inReplyTo forKey: @"in-reply-to"];

  if ([(s = [headers objectForKey: @"subject"]) length] > 0)
    [map setObject: [s asQPSubjectString: @"utf-8"]
	 forKey: @"subject"];
//     [map setObject: [s asQPSubjectString: @"utf-8"] forKey: @"subject"];
  
  /* add standard headers */

  dateString = [[NSCalendarDate date] rfc822DateString];
  [map addObject: dateString forKey: @"date"];
  [map addObject: @"1.0" forKey: @"MIME-Version"];
  [map addObject: userAgent forKey: @"X-Mailer"];

  /* add custom headers */
  
//   [self _addHeaders: [lInfo objectForKey: @"headers"] toHeaderMap:map];
  [self _addHeaders: _headers toHeaderMap: map];
  
  return map;
}

- (NGMimeMessage *) mimeMessageWithHeaders: (NSDictionary *) _headers
{
  NGMutableHashMap  *map;
  NSArray           *bodyParts;
  NGMimeMessage     *message;

  message = nil;

  map = [self mimeHeaderMapWithHeaders: _headers];
  if (map)
    {
      [self debugWithFormat: @"MIME Envelope: %@", map];
  
      bodyParts = [self bodyPartsForAllAttachments];
      if (bodyParts)
	{
	  [self debugWithFormat: @"attachments: %@", bodyParts];
  
	  if ([bodyParts count] == 0)
	    /* no attachments */
	    message = [self mimeMessageForContentWithHeaderMap: map];
	  else
	    /* attachments, create multipart/mixed */
	    message = [self mimeMultiPartMessageWithHeaderMap: map 
			    andBodyParts: bodyParts];
	  [self debugWithFormat: @"message: %@", message];
	}
      else
	[self errorWithFormat:
		@"could not create body parts for attachments!"];
    }

  return message;
}

- (NGMimeMessage *) mimeMessage
{
  return [self mimeMessageWithHeaders: nil];
}

- (NSData *) mimeMessageAsData
{
  NGMimeMessageGenerator *generator;
  NSData *message;

  generator = [NGMimeMessageGenerator new];
  message = [generator generateMimeFromPart: [self mimeMessage]];
  [generator release];

  return message;
}

- (NSArray *) allRecipients
{
  NSMutableArray *allRecipients;
  NSArray *recipients;
  NSString *fieldNames[] = {@"to", @"cc", @"bcc"};
  unsigned int count;

  allRecipients = [NSMutableArray arrayWithCapacity: 16];

  for (count = 0; count < 3; count++)
    {
      recipients = [headers objectForKey: fieldNames[count]];
      if ([recipients count] > 0)
	[allRecipients addObjectsFromArray: recipients];
    }

  return allRecipients;
}

- (NSException *) sendMail
{
  NSException *error;
  SOGoMailFolder *sentFolder;
  NSData *message;
  NSURL *sourceIMAP4URL;
  
  /* send mail */
  sentFolder = [[self mailAccountFolder] sentFolderInContext: context];
  if ([sentFolder isKindOfClass: [NSException class]])
    error = (NSException *) sentFolder;
  else
    {
      message = [self mimeMessageAsData];
      error = [[SOGoMailer sharedMailer] sendMailData: message
					 toRecipients: [self allRecipients]
					 sender: [self sender]];
      if (!error)
	{
	  error = [sentFolder postData: message flags: @"seen"];
	  if (!error)
	    {
	      [self imap4Connection];
	      if (IMAP4ID > -1)
		[imap4 markURLDeleted: [self imap4URL]];
	      if (sourceURL && sourceFlag)
		{
		  sourceIMAP4URL = [NSURL URLWithString: sourceURL];
		  [imap4 addFlags: sourceFlag toURL: sourceIMAP4URL];
		}
	      if (!draftDeleteDisabled)
		error = [self delete];
	    }
	}
    }

  return error;
}

- (NSException *) delete
{
  NSException *error;

  if ([[NSFileManager defaultManager]
	removeFileAtPath: [self draftFolderPath]
	handler: nil])
    error = nil;
  else
    error = [NSException exceptionWithHTTPStatus: 500 /* server error */
			 reason: @"could not delete draft"];

  return error;
}

/* operations */

- (NSString *) contentAsString
{
  NSString *str;
  NSData *message;

  message = [self mimeMessageAsData];
  if (message)
    {
      str = [[NSString alloc] initWithData: message
			      encoding: NSUTF8StringEncoding];
      if (!str)
	[self errorWithFormat: @"could not load draft as UTF-8 (data size=%d)",
	      [message length]];
      else
	[str autorelease];
    }
  else
    {
      [self errorWithFormat: @"message data is empty"];
      str = nil;
    }

  return str;
}

/* debugging */

- (BOOL) isDebuggingEnabled
{
  return debugOn;
}

@end /* SOGoDraftObject */
