/*
  Copyright (C) 2007-2010 Inverse inc.
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
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSURL.h>
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
#import <NGMime/NGMimeHeaderFields.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "NSData+Mail.h"
#import "NSString+Mail.h"
#import "SOGoMailAccount.h"
#import "SOGoMailFolder.h"
#import "SOGoMailObject.h"
#import "SOGoMailObject+Draft.h"
#import "SOGoSentFolder.h"

#import "SOGoDraftObject.h"

static NSString *contentTypeValue = @"text/plain; charset=utf-8";
static NSString *htmlContentTypeValue = @"text/html; charset=utf-8";
static NSString *headerKeys[] = {@"subject", @"to", @"cc", @"bcc", 
				 @"from", @"replyTo", @"message-id",
				 nil};

#warning -[NGImap4Connection postData:flags:toFolderURL:] should be enhanced \
  to return at least the new uid
@interface NGImap4Connection (SOGoHiddenMethods)

- (NSString *) imap4FolderNameForURL: (NSURL *) url;

@end

//
// Useful extension that comes from Pantomime which is also
// released under the LGPL. We should eventually merge
// this with the same category found in SOPE's NGSmtpClient.m
// or simply drop sope-mime in favor of Pantomime
//
@interface NSMutableData (DataCleanupExtension)

- (NSRange) rangeOfCString: (const char *) theCString;
- (NSRange) rangeOfCString: (const char *) theCString
		  options: (unsigned int) theOptions
		    range: (NSRange) theRange;
@end

@implementation NSMutableData (DataCleanupExtension)

- (NSRange) rangeOfCString: (const char *) theCString
{
  return [self rangeOfCString: theCString
	       options: 0
	       range: NSMakeRange(0,[self length])];
}

-(NSRange) rangeOfCString: (const char *) theCString
		  options: (unsigned int) theOptions
		    range: (NSRange) theRange
{
  const char *b, *bytes;
  int i, len, slen;
  
  if (!theCString)
    {
      return NSMakeRange(NSNotFound,0);
    }
  
  bytes = [self bytes];
  len = [self length];
  slen = strlen(theCString);
  
  b = bytes;
  
  if (len > theRange.location + theRange.length)
    {
      len = theRange.location + theRange.length;
    }

  if (theOptions == NSCaseInsensitiveSearch)
    {
      i = theRange.location;
      b += i;
      
      for (; i <= len-slen; i++, b++)
	{
	  if (!strncasecmp(theCString,b,slen))
	    {
	      return NSMakeRange(i,slen);
	    }
	}
    }
  else
    {
      i = theRange.location;
      b += i;
      
      for (; i <= len-slen; i++, b++)
	{
	  if (!memcmp(theCString,b,slen))
	    {
	      return NSMakeRange(i,slen);
	    }
	}
    }
  
  return NSMakeRange(NSNotFound,0);
}

@end

//
//
//
@implementation SOGoDraftObject

static NGMimeType  *MultiMixedType = nil;
static NSString    *userAgent      = nil;

+ (void) initialize
{
  MultiMixedType = [NGMimeType mimeType: @"multipart" subType: @"mixed"];
  [MultiMixedType retain];
  userAgent      = [NSString stringWithFormat: @"SOGoMail %d.%d.%d",
			     UIX_MAILER_MAJOR_VERSION,
			     UIX_MAILER_MINOR_VERSION,
			     UIX_MAILER_SUBMINOR_VERSION];
  [userAgent retain];
}

- (id) init
{
  if ((self = [super init]))
    {
      IMAP4ID = -1;
      headers = [NSMutableDictionary new];
      text = @"";
      path = nil;
      sourceURL = nil;
      sourceFlag = nil;
      inReplyTo = nil;
      isHTML = NO;
    }

  return self;
}

- (void) dealloc
{
  [headers release];
  [text release];
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

- (NSString *) _generateMessageID
{
  NSMutableString *messageID;
  NSString *pGUID;

  messageID = [NSMutableString string];
  [messageID appendFormat: @"<%@", [self globallyUniqueObjectId]];
  pGUID = [[NSProcessInfo processInfo] globallyUniqueString];
  [messageID appendFormat: @"@%u>", [pGUID hash]];

  return [messageID lowercaseString];
}

- (void) setHeaders: (NSDictionary *) newHeaders
{
  id headerValue;
  unsigned int count;
  NSString *messageID, *priority, *pureSender,*replyTo;

  for (count = 0; count < 8; count++)
    {
      headerValue = [newHeaders objectForKey: headerKeys[count]];
      if (headerValue)
	[headers setObject: headerValue
		 forKey: headerKeys[count]];
      else if ([headers objectForKey: headerKeys[count]])
	[headers removeObjectForKey: headerKeys[count]];
    }

  messageID = [headers objectForKey: @"message-id"];
  if (!messageID)
    {
      messageID = [self _generateMessageID];
      [headers setObject: messageID forKey: @"message-id"];
    }
  
  priority = [newHeaders objectForKey: @"priority"];
  if (!priority || [priority isEqualToString: @"NORMAL"])
    {
      [headers removeObjectForKey: @"X-Priority"];
    }
  else if ([priority isEqualToString: @"HIGHEST"])
    {
      [headers setObject: @"1 (Highest)"  forKey: @"X-Priority"];
    }
  else if ([priority isEqualToString: @"HIGH"])
    {
      [headers setObject: @"2 (High)"  forKey: @"X-Priority"];
    }
  else if ([priority isEqualToString: @"LOW"])
    {
      [headers setObject: @"4 (Low)"  forKey: @"X-Priority"];
    }
  else
    {
      [headers setObject: @"5 (Lowest)"  forKey: @"X-Priority"];
    }

  replyTo = [headers objectForKey: @"replyTo"];
  if ([replyTo length] > 0)
    {
      [headers setObject: replyTo forKey: @"reply-to"];
      [headers removeObjectForKey: @"replyTo"];
    }

  if ([[newHeaders objectForKey: @"receipt"] isEqualToString: @"true"])
    {
      pureSender = [[newHeaders objectForKey: @"from"] pureEMailAddress];
      if (pureSender)
        [headers setObject: pureSender forKey: @"Disposition-Notification-To"];
    }
  else
    [headers removeObjectForKey: @"Disposition-Notification-To"];
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

- (void) setIsHTML: (BOOL) aBool
{
  isHTML = aBool;
}

- (BOOL) isHTML
{
  return isHTML;
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

- (void) setSourceFolder: (NSString *) newSourceFolder
{
  ASSIGN (sourceFolder, newSourceFolder);
}

- (void) setSourceFolderWithMailObject: (SOGoMailObject *) sourceMail
{
  NSMutableArray *paths;
  id parent;

  parent = [sourceMail container];
  paths = [NSMutableArray arrayWithCapacity: 1];
  while (parent && ![parent isKindOfClass: [SOGoMailAccount class]])
    {
      [paths insertObject: [parent nameInContainer] atIndex: 0];
      parent = [parent container];
    }
  if (parent)
    [paths insertObject: [NSString stringWithFormat: @"/%@", [parent nameInContainer]]
		atIndex: 0];

  [self setSourceFolder: [paths componentsJoinedByString: @"/"]];
}

- (NSString *) sourceFolder
{
  return sourceFolder;
}

- (NSException *) storeInfo
{
  NSMutableDictionary *infos;
  NSException *error;

  if ([self _ensureDraftFolderPath])
    {
      infos = [NSMutableDictionary dictionary];
      [infos setObject: headers forKey: @"headers"];
      if (text)
	[infos setObject: text forKey: @"text"];
      [infos setObject: [NSNumber numberWithBool: isHTML]
                forKey: @"isHTML"];
      if (inReplyTo)
	[infos setObject: inReplyTo forKey: @"inReplyTo"];
      if (IMAP4ID > -1)
	[infos setObject: [NSString stringWithFormat: @"%i", IMAP4ID]
		  forKey: @"IMAP4ID"];
      if (sourceURL && sourceFlag && sourceFolder)
	{
	  [infos setObject: sourceURL forKey: @"sourceURL"];
	  [infos setObject: sourceFlag forKey: @"sourceFlag"];
	  [infos setObject: sourceFolder forKey: @"sourceFolder"];
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
  isHTML = [[infoDict objectForKey: @"isHTML"] boolValue];

  value = [infoDict objectForKey: @"IMAP4ID"];
  if (value)
    [self setIMAP4ID: [value intValue]];

  value = [infoDict objectForKey: @"sourceURL"];
  if (value)
    [self setSourceURL: value];
  value = [infoDict objectForKey: @"sourceFlag"];
  if (value)
    [self setSourceFlag: value];
  value = [infoDict objectForKey: @"sourceFolder"];
  if (value)
    [self setSourceFolder: value];

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

  if (![imap4 doesMailboxExistAtURL: [container imap4URL]])
    {
      [[self imap4Connection] createMailbox: [[self imap4Connection] imap4FolderNameForURL: [container imap4URL]]
				      atURL: [[self mailAccountFolder] imap4URL]];
      [imap4 flushFolderHierarchyCache];
    }
  
  folder = [imap4 imap4FolderNameForURL: [container imap4URL]];
  result
    = [client append: message toFolder: folder
	      withFlags: [NSArray arrayWithObjects: @"seen", @"draft", nil]];
  if ([[result objectForKey: @"result"] boolValue])
    {
      if (IMAP4ID > -1)
	error = [imap4 markURLDeleted: [self imap4URL]];
      IMAP4ID = [self IMAP4IDFromAppendResult: result];
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
  NSEnumerator *addresses;
  NGImap4EnvelopeAddress *currentAddress;

  addresses = [_addrs objectEnumerator];
  while ((currentAddress = [addresses nextObject]))
    if ([currentAddress email])
      [_ma addObject: [currentAddress email]];
}

- (void) _addRecipients: (NSArray *) recipients
	        toArray: (NSMutableArray *) array
{
  NSEnumerator *addresses;
  NGImap4EnvelopeAddress *currentAddress;

  addresses = [recipients objectEnumerator];
  while ((currentAddress = [addresses nextObject]))
    if ([currentAddress baseEMail])
      [array addObject: [currentAddress baseEMail]];
}

- (void) _purgeRecipients: (NSArray *) recipients
	    fromAddresses: (NSMutableArray *) addresses
{
  NSEnumerator *allRecipients;
  NSString *currentRecipient;
  NGImap4EnvelopeAddress *currentAddress;
  int count, max;

  max = [addresses count];

  allRecipients = [recipients objectEnumerator];
  while (max > 0
	 && ((currentRecipient = [allRecipients nextObject])))
    for (count = max - 1; count >= 0; count--)
      {
	currentAddress = [addresses objectAtIndex: count];
	if ([currentRecipient
              caseInsensitiveCompare: [currentAddress baseEMail]]
            == NSOrderedSame)
	  {
	    [addresses removeObjectAtIndex: count];
	    max--;
	  }
      }
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
  NSMutableArray *to, *addrs, *allRecipients;
  NSArray *envelopeAddresses, *userEmails;

  allRecipients = [NSMutableArray array];
  userEmails = [[context activeUser] allEmails];
  [allRecipients addObjectsFromArray: userEmails];

  to = [NSMutableArray arrayWithCapacity: 2];

  addrs = [NSMutableArray array];
  envelopeAddresses = [_envelope replyTo];
  if ([envelopeAddresses count])
    [addrs setArray: envelopeAddresses];
  else
    [addrs setArray: [_envelope from]];

  [self _purgeRecipients: allRecipients
	fromAddresses: addrs];
  [self _addEMailsOfAddresses: addrs toArray: to];
  [self _addRecipients: addrs toArray: allRecipients];
  [_info setObject: to forKey: @"to"];

  /* If "to" is empty, we add at least ourself as a recipient!
     This is for emails in the "Sent" folder that we reply to... */
  if (![to count])
    {
      if ([[_envelope replyTo] count])
	[self _addEMailsOfAddresses: [_envelope replyTo] toArray: to];
      else
	[self _addEMailsOfAddresses: [_envelope from] toArray: to];
    }

  /* If we have no To but we have Cc recipients, let's move the Cc
     to the To bucket... */
  if ([[_info objectForKey: @"to"] count] == 0 && [_info objectForKey: @"cc"])
    {
      id o;

      o = [_info objectForKey: @"cc"];
      [_info setObject: o  forKey: @"to"];
      [_info removeObjectForKey: @"cc"];
    }

  /* CC processing if we reply-to-all: add all 'to' and 'cc'  */
  if (_replyToAll)
    {
      to = [NSMutableArray new];

      [addrs setArray: [_envelope to]];
      [self _purgeRecipients: allRecipients
	    fromAddresses: addrs];
      [self _addEMailsOfAddresses: addrs toArray: to];
      [self _addRecipients: addrs toArray: allRecipients];

      [addrs setArray: [_envelope cc]];
      [self _purgeRecipients: allRecipients
	    fromAddresses: addrs];
      [self _addEMailsOfAddresses: addrs toArray: to];
    
      [_info setObject: to forKey: @"cc"];

      [to release];
    }
}

- (NSArray *) _attachmentBodiesFromPaths: (NSArray *) paths
		       fromResponseFetch: (NSDictionary *) fetch;
{
  NSEnumerator *attachmentKeys;
  NSMutableArray *bodies;
  NSString *currentKey;
  NSDictionary *body;

  bodies = [NSMutableArray array];

  attachmentKeys = [paths objectEnumerator];
  while ((currentKey = [attachmentKeys nextObject]))
    {
      body = [fetch objectForKey: [currentKey lowercaseString]];
      [bodies addObject: [body objectForKey: @"data"]];
    }

  return bodies;
}

- (void) _fetchAttachments: (NSArray *) parts
                  fromMail: (SOGoMailObject *) sourceMail
{
  unsigned int count, max;
  NSArray *paths, *bodies;
  NSData *body;
  NSDictionary *currentInfo;
  NGHashMap *response;

  max = [parts count];
  if (max > 0)
    {
      paths = [parts keysWithFormat: @"BODY[%{path}]"];
      response = [[sourceMail fetchParts: paths] objectForKey: @"RawResponse"];
      bodies = [self _attachmentBodiesFromPaths: paths
		     fromResponseFetch: [response objectForKey: @"fetch"]];
      for (count = 0; count < max; count++)
	{
	  currentInfo = [parts objectAtIndex: count];
	  body = [[bodies objectAtIndex: count]
		   bodyDataFromEncoding: [currentInfo
					   objectForKey: @"encoding"]];
	  [self saveAttachment: body withMetadata: currentInfo];
	}
    }
}

- (void) fetchMailForEditing: (SOGoMailObject *) sourceMail
{
  NSString *subject, *msgid;
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
  msgid = [sourceEnvelope messageID];
  if ([msgid length] > 0)
    [info setObject: msgid forKey: @"message-id"];

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
  [self setIMAP4ID: [[sourceMail nameInContainer] intValue]];
  [self setSourceFolderWithMailObject: sourceMail];

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
  [self setIMAP4ID: [[sourceMail nameInContainer] intValue]];
  [self setSourceFolderWithMailObject: sourceMail];

  [self storeInfo];
}

- (void) fetchMailForForwarding: (SOGoMailObject *) sourceMail
{
  NSDictionary *info, *attachment;
  SOGoUserDefaults *ud;
  NSString *signature;

  [sourceMail fetchCoreInfos];
  
  if ([sourceMail subjectForForward])
    {
      info = [NSDictionary dictionaryWithObject: [sourceMail subjectForForward] 
			   forKey: @"subject"];
      [self setHeaders: info];
    }
  
  [self setSourceURL: [sourceMail imap4URLString]];
  [self setSourceFlag: @"$Forwarded"];
  [self setIMAP4ID: [[sourceMail nameInContainer] intValue]];
  [self setSourceFolderWithMailObject: sourceMail];

  /* attach message */
  ud = [[context activeUser] userDefaults];
  if ([[ud mailMessageForwarding] isEqualToString: @"inline"])
    {
      [self setText: [sourceMail contentForInlineForward]];
      [self _fetchAttachments: [sourceMail fetchFileAttachmentKeys]
	    fromMail: sourceMail];
    }
  else
    {
  // TODO: use subject for filename?
//   error = [newDraft saveAttachment:content withName:@"forward.eml"];
      signature = [[self mailAccountFolder] signature];
      if ([signature length])
	[self setText: [NSString stringWithFormat: @"\n-- \n%@", signature]];
      attachment = [NSDictionary dictionaryWithObjectsAndKeys:
				   [sourceMail filenameForForward], @"filename",
				 @"message/rfc822", @"mimetype",
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

- (BOOL) isValidAttachmentName: (NSString *) filename
{
  return (!([filename rangeOfString: @"/"].length
	    || [filename isEqualToString: @"."]
	    || [filename isEqualToString: @".."]));
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
  NSRange r;

  if (![_attach isNotNull]) {
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			reason: @"Missing attachment content!"];
  }
  
  if (![self _ensureDraftFolderPath]) {
    return [NSException exceptionWithHTTPStatus:500 /* Server Error */
			reason: @"Could not create folder for draft!"];
  }

  name = [metadata objectForKey: @"filename"];
  r = [name rangeOfString: @"\\"
	    options: NSBackwardsSearch];
  if (r.length > 0)
    name = [name substringFromIndex: r.location + 1];

  if (![self isValidAttachmentName: name])
    return [self invalidAttachmentNameError: name];
  
  p = [self pathToAttachmentWithName: name];
  if (![_attach writeToFile: p atomically: YES])
    {
      return [NSException exceptionWithHTTPStatus:500 /* Server Error */
			  reason: @"Could not write attachment to draft!"];
    }

  mimeType = [metadata objectForKey: @"mimetype"];
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
    [map setObject: (isHTML ? htmlContentTypeValue : contentTypeValue)
            forKey: @"content-type"];

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
      [map setObject: (isHTML ? htmlContentTypeValue : contentTypeValue)
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
  if ([_ext isEqualToString: @"eml"]) return @"message/rfc822";
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
  SOGoDomainDefaults *dd;
  
  type = [self contentTypeForAttachmentWithName:_name];

  if ([type hasPrefix: @"text/"])
    {
      dd = [[context activeUser] domainDefaults];
      cdtype = [dd mailAttachTextDocumentsInline] ? @"inline" : @"attachment";
    }
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
  BOOL             attachAsString, attachAsRFC822;
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
  attachAsRFC822 = NO;
  
  /* prepare header of body part */

  map = [[[NGMutableHashMap alloc] initWithCapacity:4] autorelease];

  if ((s = [self contentTypeForAttachmentWithName:_name]) != nil) {
    [map setObject:s forKey: @"content-type"];
    if ([s hasPrefix: @"text/plain"] || [s hasPrefix: @"text/html"])
      attachAsString = YES;
    else if ([s hasPrefix: @"message/rfc822"])
      attachAsRFC822 = YES;
  }
  if ((s = [self contentDispositionForAttachmentWithName:_name]))
    {
      NGMimeContentDispositionHeaderField *o;
      
      o = [[NGMimeContentDispositionHeaderField alloc] initWithString: s];
      [map setObject:o forKey: @"content-disposition"];
      [o release];
    }
  
  /* prepare body content */
  
  if (attachAsString) { // TODO: is this really necessary?
    NSString *s;
    
    content = [[NSData alloc] initWithContentsOfMappedFile:p];
    
    s = [[NSString alloc] initWithData: content
                              encoding: [NSString defaultCStringEncoding]];
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
  else {
    /* 
       Note: in OGo this is done in LSWImapMailEditor.m:2477. Apparently
             NGMimeFileData objects are not processed by the MIME generator!
    */
    content = [[NSData alloc] initWithContentsOfMappedFile:p];
    [content autorelease];

    if (attachAsRFC822)
      {
        [map setObject: @"8bit" forKey: @"content-transfer-encoding"];
        [map setObject: @"inline" forKey: @"content-disposition"];
      }
    else
      {
	content = [content dataByEncodingBase64];
        [map setObject: @"base64" forKey: @"content-transfer-encoding"];
      }
    [map setObject:[NSNumber numberWithInt:[content length]] 
	 forKey: @"content-length"];
    
    /* Note: the -init method will create a temporary file! */
    body = [[NGMimeFileData alloc] initWithBytes:[content bytes]
                                          length:[content length]];
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

- (NSString *) _quoteSpecials: (NSString *) address
{
  NSString *result, *part, *s2;
  int i, len;

  // We want to correctly send mails to recipients such as :
  // foo.bar
  // foo (bar) <foo@zot.com>
  // bar, foo <foo@zot.com>
  if ([address indexOf: '('] >= 0 || [address indexOf: ')'] >= 0
      || [address indexOf: '<'] >= 0 || [address indexOf: '>'] >= 0
      || [address indexOf: '@'] >= 0 || [address indexOf: ','] >= 0
      || [address indexOf: ';'] >= 0 || [address indexOf: ':'] >= 0
      || [address indexOf: '\\'] >= 0 || [address indexOf: '"'] >= 0
      || [address indexOf: '.'] >= 0
      || [address indexOf: '['] >= 0 || [address indexOf: ']'] >= 0)
    {
      // We search for the first instance of < from the end
      // and we quote what was before if we need to
      len = [address length];
      i = -1;
      while (len--)
        if ([address characterAtIndex: len] == '<')
          {
            i = len;
            break;
          }

      if (i > 0)
        {
          part = [address substringToIndex: i - 1];
          s2 = [[part stringByReplacingString: @"\\" withString: @"\\\\"]
                     stringByReplacingString: @"\"" withString: @"\\\""];
          result = [NSString stringWithFormat: @"\"%@\" %@", s2, [address substringFromIndex: i]];
        }
      else
        {
          s2 = [[address stringByReplacingString: @"\\" withString: @"\\\\"]
                     stringByReplacingString: @"\"" withString: @"\\\""];
          result = [NSString stringWithFormat: @"\"%@\"", s2];
        }
    }
  else
    result = address;

  return result;
}

- (NSArray *) _quoteSpecialsInArray: (NSArray *) addresses
{
  NSMutableArray *result;
  NSString *address;
  int count, max;

  max = [addresses count];
  result = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      address = [self _quoteSpecials: [addresses objectAtIndex: count]];
      [result addObject: address];
    }

  return result;
}

- (NGMutableHashMap *) mimeHeaderMapWithHeaders: (NSDictionary *) _headers
				      excluding: (NSArray *) _exclude
{
  NSString *s, *dateString;
  NGMutableHashMap *map;
  NSArray *emails;
  id from, replyTo;
  
  map = [[[NGMutableHashMap alloc] initWithCapacity:16] autorelease];
  
  /* add recipients */
  if ((emails = [headers objectForKey: @"to"]) != nil)
    [map setObjects: [self _quoteSpecialsInArray: emails] forKey: @"to"];
  if ((emails = [headers objectForKey: @"cc"]) != nil)
    [map setObjects: [self _quoteSpecialsInArray: emails] forKey: @"cc"];
  if ((emails = [headers objectForKey: @"bcc"]) != nil)
    [map setObjects: [self _quoteSpecialsInArray: emails] forKey: @"bcc"];

  /* add senders */
  from = [headers objectForKey: @"from"];
  
  if (![self isEmptyValue:from]) {
    if ([from isKindOfClass:[NSArray class]])
      [map setObjects: [self _quoteSpecialsInArray: from] forKey: @"from"];
    else
      [map setObject: [self _quoteSpecials: from] forKey: @"from"];
  }

  if ((replyTo = [headers objectForKey: @"reply-to"]))
    [map setObject: replyTo forKey: @"reply-to"];

  if (inReplyTo)
    [map setObject: inReplyTo forKey: @"in-reply-to"];

  /* add subject */
  if ([(s = [headers objectForKey: @"subject"]) length] > 0)
    [map setObject: [s asQPSubjectString: @"utf-8"]
	 forKey: @"subject"];

  [map setObject: [headers objectForKey: @"message-id"]
       forKey: @"message-id"];

  /* add standard headers */
  dateString = [[NSCalendarDate date] rfc822DateString];
  [map addObject: dateString forKey: @"date"];
  [map addObject: @"1.0" forKey: @"MIME-Version"];
  [map addObject: userAgent forKey: @"User-Agent"];

  /* add custom headers */
  if ([(s = [[context request] headerForKey:@"x-webobjects-remote-host"]) length] > 0 &&
      [s compare: @"localhost"] != NSOrderedSame)
    [map addObject: s
	    forKey: @"X-Forward"];
  if ([(s = [headers objectForKey: @"X-Priority"]) length] > 0)
    [map setObject: s
	 forKey: @"X-Priority"];
  if ([(s = [headers objectForKey: @"Disposition-Notification-To"]) length] > 0)
    [map setObject: s
	 forKey: @"Disposition-Notification-To"];

  [self _addHeaders: _headers toHeaderMap: map];
  
  // We remove what we have to...
  if (_exclude)
    {
      int i;
  
      for (i = 0; i < [_exclude count]; i++)
	[map removeAllObjectsForKey: [_exclude objectAtIndex: i]];
    }
  
  return map;
}

- (NGMimeMessage *) mimeMessageWithHeaders: (NSDictionary *) _headers
				 excluding: (NSArray *) _exclude
{
  NGMutableHashMap  *map;
  NSArray           *bodyParts;
  NGMimeMessage     *message;

  message = nil;

  map = [self mimeHeaderMapWithHeaders: _headers
	      excluding: _exclude];
  if (map)
    {
      //[self debugWithFormat: @"MIME Envelope: %@", map];
  
      bodyParts = [self bodyPartsForAllAttachments];
      if (bodyParts)
	{
	  //[self debugWithFormat: @"attachments: %@", bodyParts];
  
	  if ([bodyParts count] == 0)
	    /* no attachments */
	    message = [self mimeMessageForContentWithHeaderMap: map];
	  else
	    /* attachments, create multipart/mixed */
	    message = [self mimeMultiPartMessageWithHeaderMap: map 
			    andBodyParts: bodyParts];
	  //[self debugWithFormat: @"message: %@", message];
	}
      else
	[self errorWithFormat:
		@"could not create body parts for attachments!"];
    }

  return message;
}

- (NGMimeMessage *) mimeMessage
{
  return [self mimeMessageWithHeaders: nil  excluding: nil];
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

- (NSArray *) allBareRecipients
{
  NSMutableArray *bareRecipients;
  NSEnumerator *allRecipients;
  NSString *recipient;

  bareRecipients = [NSMutableArray array];

  allRecipients = [[self allRecipients] objectEnumerator];
  while ((recipient = [allRecipients nextObject]))
    [bareRecipients addObject: [recipient pureEMailAddress]];

  return bareRecipients;
}

- (NSException *) sendMail
{
  return [self sendMailAndCopyToSent: YES];
}

- (NSException *) sendMailAndCopyToSent: (BOOL) copyToSent
{
  NSMutableData *cleaned_message;
  SOGoMailFolder *sentFolder;
  SOGoDomainDefaults *dd;
  NSURL *sourceIMAP4URL;
  NSException *error;
  NSData *message;
  NSRange r1, r2;
  
  /* send mail */

  // We strip the BCC fields prior sending any mails
  NGMimeMessageGenerator *generator;

  generator = [[[NGMimeMessageGenerator alloc] init] autorelease];
  message = [generator generateMimeFromPart: [self mimeMessageWithHeaders: nil 
                                                                excluding: nil]];
      
  //
  // We now look for the Bcc: header. If it is present, we remove it.
  // Some servers, like qmail, do not remove it automatically.
  //
#warning FIXME - we should fix the case issue when we switch to Pantomime
  cleaned_message = [NSMutableData dataWithData: message];
  r1 = [cleaned_message rangeOfCString: "\r\n\r\n"];
  r1 = [cleaned_message rangeOfCString: "\r\nbcc: "
                               options: 0
                                 range: NSMakeRange(0,r1.location-1)];
      
  if (r1.location != NSNotFound)
    {
      // We search for the first \r\n AFTER the Bcc: header and
      // replace the whole thing with \r\n.
      r2 = [cleaned_message rangeOfCString: "\r\n"
                                   options: 0
                                     range: NSMakeRange(NSMaxRange(r1)+1,[cleaned_message length]-NSMaxRange(r1)-1)];
      [cleaned_message replaceBytesInRange: NSMakeRange(r1.location, NSMaxRange(r2)-r1.location)
                                 withBytes: "\r\n"
                                    length: 2];
    }

  dd = [[context activeUser] domainDefaults];
  error = [[SOGoMailer mailerWithDomainDefaults: dd]
                  sendMailData: cleaned_message
                  toRecipients: [self allBareRecipients]
                        sender: [self sender]
             withAuthenticator: [self authenticatorInContext: context]
                     inContext: context];
  if (!error && copyToSent)
    {
      sentFolder = [[self mailAccountFolder] sentFolderInContext: context];
      if ([sentFolder isKindOfClass: [NSException class]])
        error = (NSException *) sentFolder;
      else
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
            }
        }
    }

  if (!error && ![dd mailKeepDraftsAfterSend])
    [self delete];

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

@end /* SOGoDraftObject */
