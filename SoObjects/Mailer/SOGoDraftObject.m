/*
  Copyright (C) 2007-2018 Inverse inc.
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

#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest+So.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSFileManager+Extensions.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Envelope.h>
#import <NGImap4/NGImap4EnvelopeAddress.h>
#import <NGMail/NGMailAddress.h>
#import <NGMail/NGMailAddressParser.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>
#import <NGMail/NGMimeMessageParser.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeFileData.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimeType.h>
#import <NGMime/NGMimeHeaderFields.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoSystemDefaults.h>

#import <NGCards/NGVCard.h>

#import <Contacts/SOGoContactFolder.h>
#import <Contacts/SOGoContactFolders.h>
#import <Contacts/SOGoContactGCSEntry.h>

#import "NSData+Mail.h"
#import "NSData+SMIME.h"
#import "NSString+Mail.h"
#import "SOGoDraftsFolder.h"
#import "SOGoMailAccount.h"
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
//
//
@implementation SOGoDraftObject

static NGMimeType  *MultiMixedType = nil;
static NGMimeType  *MultiAlternativeType = nil;
static NGMimeType  *MultiRelatedType = nil;
static NSString    *userAgent      = nil;

+ (void) initialize
{
  MultiMixedType = [NGMimeType mimeType: @"multipart" subType: @"mixed"];
  [MultiMixedType retain];

  MultiAlternativeType = [NGMimeType mimeType: @"multipart" subType: @"alternative"];
  [MultiAlternativeType retain];

  MultiRelatedType = [NGMimeType mimeType: @"multipart" subType: @"related"];
  [MultiRelatedType retain];

  userAgent      = [NSString stringWithFormat: @"SOGoMail %@",
			     SOGoVersion];
  [userAgent retain];
}

- (id) init
{
  if ((self = [super init]))
    {
      sourceIMAP4ID = -1;
      IMAP4ID = -1;
      headers = [[NSMutableDictionary alloc] init];
      certificates = [[NSMutableDictionary alloc] init];
      text = @"";
      path = nil;
      sourceURL = nil;
      sourceFlag = nil;
      inReplyTo = nil;
      isHTML = NO;
      sign = NO;
      encrypt = NO;
    }

  return self;
}

- (void) dealloc
{
  [headers release];
  [certificates release];
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
      path = [[self userSpoolFolderPath] stringByAppendingPathComponent: nameInContainer];
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
  NSString *messageID, *priority, *pureSender, *replyTo, *receipt;

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
      messageID = [NSString generateMessageID];
      [headers setObject: messageID forKey: @"message-id"];
    }

  priority = [newHeaders objectForKey: @"X-Priority"];
  if (priority)
    {
      // newHeaders come from MIME message; convert X-Priority to Web representation
      [headers setObject: priority  forKey: @"X-Priority"];
      [headers removeObjectForKey: @"priority"];
      if ([priority isEqualToString: @"1 (Highest)"])
        {
          [headers setObject: @"HIGHEST"  forKey: @"priority"];
        }
      else if ([priority isEqualToString: @"2 (High)"])
        {
          [headers setObject: @"HIGH"  forKey: @"priority"];
        }
      else if ([priority isEqualToString: @"4 (Low)"])
        {
          [headers setObject: @"LOW"  forKey: @"priority"];
        }
      else if ([priority isEqualToString: @"5 (Lowest)"])
        {
          [headers setObject: @"LOWEST"  forKey: @"priority"];
        }
    }
  else
    {
      // newHeaders come from Web form; convert priority to MIME header representation
      priority = [newHeaders objectForKey: @"priority"];
      if ([priority intValue] == 1)
        {
          [headers setObject: @"1 (Highest)"  forKey: @"X-Priority"];
        }
      else if ([priority intValue] == 2)
        {
          [headers setObject: @"2 (High)"  forKey: @"X-Priority"];
        }
      else if ([priority intValue] == 4)
        {
          [headers setObject: @"4 (Low)"  forKey: @"X-Priority"];
        }
      else if ([priority intValue] == 5)
        {
          [headers setObject: @"5 (Lowest)"  forKey: @"X-Priority"];
        }
      else
        {
          [headers removeObjectForKey: @"X-Priority"];
        }
      if (priority)
        {
          [headers setObject: priority  forKey: @"priority"];
        }
    }

  replyTo = [headers objectForKey: @"replyTo"];
  if ([replyTo length] > 0)
    {
      [headers setObject: replyTo forKey: @"reply-to"];
    }
  [headers removeObjectForKey: @"replyTo"];

  receipt = [newHeaders objectForKey: @"Disposition-Notification-To"];
  if ([receipt length] > 0)
    {
      [headers setObject: @"true"  forKey: @"receipt"];
      [headers setObject: receipt forKey: @"Disposition-Notification-To"];
    }
  else
    {
      receipt = [newHeaders objectForKey: @"receipt"];
      if ([receipt boolValue])
        {
          [headers setObject: receipt  forKey: @"receipt"];
          pureSender = [[newHeaders objectForKey: @"from"] pureEMailAddress];
          if (pureSender)
            {
              [headers setObject: pureSender forKey: @"Disposition-Notification-To"];
            }
        }
      else
        {
          [headers removeObjectForKey: @"receipt"];
          [headers removeObjectForKey: @"Disposition-Notification-To"];
        }
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

- (void) setIsHTML: (BOOL) aBool
{
  isHTML = aBool;
}

- (BOOL) isHTML
{
  return isHTML;
}

- (void) setSign: (BOOL) aBool
{
  sign = aBool;
}
- (BOOL) sign
{
  return sign;
}

- (void) setEncrypt: (BOOL) aBool
{
  encrypt = aBool;
}

- (BOOL) encrypt
{
  return encrypt;
}

- (NSString *) inReplyTo
{
  return inReplyTo;
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

//
//
//
- (NSString *) sourceFolder
{
  return sourceFolder;
}

//
// Store the message definition in a plist file (.info.plist) in the spool directory
//
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
      if (sourceIMAP4ID > -1)
	[infos setObject: [NSString stringWithFormat: @"%i", sourceIMAP4ID]
		  forKey: @"sourceIMAP4ID"];
      if (IMAP4ID > -1)
	[infos setObject: [NSString stringWithFormat: @"%i", IMAP4ID]
		  forKey: @"IMAP4ID"];
      if (sourceURL && sourceFlag && sourceFolder)
	{
	  [infos setObject: sourceURL forKey: @"sourceURL"];
	  [infos setObject: sourceFlag forKey: @"sourceFlag"];
	  [infos setObject: sourceFolder forKey: @"sourceFolder"];
	}

      if ([infos writeToFile: [self infoPath]  atomically: YES])
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

//
//
//
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

  value = [infoDict objectForKey: @"sourceIMAP4ID"];
  if (value)
    [self setSourceIMAP4ID: [value intValue]];

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

//
//
//
- (NSString *) relativeImap4Name
{
  return [NSString stringWithFormat: @"%d", IMAP4ID];
}

//
//
//
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

//
//
//
- (void) setSourceIMAP4ID: (int) newSourceIMAP4ID
{
  sourceIMAP4ID = newSourceIMAP4ID;
}

//
//
//
- (int) sourceIMAP4ID
{
  return sourceIMAP4ID;
}

//
//
//
- (void) setIMAP4ID: (int) newIMAP4ID
{
  IMAP4ID = newIMAP4ID;
}

//
//
//
- (int) IMAP4ID
{
  return IMAP4ID;
}

//
//
//
- (NSException *) save
{
  NGImap4Client *client;
  NSException *error;
  NSData *message;
  NSString *folder;
  id result;

  error = nil;
  message = [self mimeMessageForRecipient: nil];

  if (!message)
    {
      error = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
					    reason: @"Message is too big"];
      return error;
    }

  client = [[self imap4Connection] client];

  if (![imap4 doesMailboxExistAtURL: [container imap4URL]])
    {
      [[self imap4Connection] createMailbox: [[self imap4Connection] imap4FolderNameForURL: [container imap4URL]]
				      atURL: [[self mailAccountFolder] imap4URL]];
      [imap4 flushFolderHierarchyCache];
    }

  folder = [imap4 imap4FolderNameForURL: [container imap4URL]];
  result = [client append: message toFolder: folder
                withFlags: [NSArray arrayWithObjects: @"draft", nil]];
  if ([[result objectForKey: @"result"] boolValue])
    {
      if (IMAP4ID > -1)
	error = [imap4 markURLDeleted: [self imap4URL]];
      [self setIMAP4ID: [self IMAP4IDFromAppendResult: result]];
      if (imap4URL)
        {
          // Invalidate the IMAP message URL since the message ID has changed
          [imap4URL release];
          imap4URL = nil;
        }
    }
  else
    error = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                                          reason: [result objectForKey: @"reason"]];

  return error;
}

//
//
//
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

//
//
//
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

//
//
//
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
	if (![currentAddress baseEMail] ||
            [currentRecipient
              caseInsensitiveCompare: [currentAddress baseEMail]]
            == NSOrderedSame)
	  {
	    [addresses removeObjectAtIndex: count];
	    max--;
	  }
      }
}

//
//
//
- (void) _fillInReplyAddresses: (NSMutableDictionary *) _info
		    replyToAll: (BOOL) _replyToAll
               fromSentMailbox: (BOOL) _fromSentMailbox
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
  */
  NSMutableArray *to, *addrs, *allRecipients;
  NSArray *envelopeAddresses;

  allRecipients = [NSMutableArray array];

  //
  // When we do a Reply-To or a Reply-To-All, we strip our own addresses
  // from the list of recipients so we don't reply to ourself! We check
  // which addresses we should use - that is the ones for the current
  // user if we're dealing with the default "SOGo mail account" or
  // the ones specified in the auxiliary IMAP accounts
  //
  if ([[[self->container mailAccountFolder] nameInContainer] intValue] == 0)
    {
      NSArray *userEmails;

      userEmails = [[context activeUser] allEmails];
      [allRecipients addObjectsFromArray: userEmails];
    }
  else
    {
      NSArray *identities;
      NSString *email;
      int i;

      identities = [[[self container] mailAccountFolder] identities];

      for (i = 0; i < [identities count]; i++)
        {
          email = [[identities objectAtIndex: i] objectForKey: @"email"];

          if (email)
            [allRecipients addObject: email];
        }
    }

  to = [NSMutableArray arrayWithCapacity: 2];

  addrs = [NSMutableArray array];
  envelopeAddresses = [_envelope replyTo];
  if (_fromSentMailbox)
    [addrs setArray: [_envelope to]];
  else if ([envelopeAddresses count])
    [addrs setArray: envelopeAddresses];
  else
    [addrs setArray: [_envelope from]];

  [self _purgeRecipients: allRecipients  fromAddresses: addrs];
  [self _addEMailsOfAddresses: addrs  toArray: to];
  [self _addRecipients: addrs  toArray: allRecipients];
  [_info setObject: to  forKey: @"to"];

  /* If "to" is empty, we add at least ourself as a recipient!
     This is for emails in the "Sent" folder that we reply to... */
  if (![to count])
    {
      if ([[_envelope replyTo] count])
	[self _addEMailsOfAddresses: [_envelope replyTo]  toArray: to];
      else
	[self _addEMailsOfAddresses: [_envelope from]  toArray: to];
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

  /* CC processing if we reply-to-all: - we add all 'to', 'cc' and 'bcc' fields */
  if (_replyToAll)
    {
      to = [NSMutableArray array];

      [addrs setArray: [_envelope to]];
      [self _purgeRecipients: allRecipients
               fromAddresses: addrs];
      [self _addEMailsOfAddresses: addrs toArray: to];
      [self _addRecipients: addrs toArray: allRecipients];

      [addrs setArray: [_envelope cc]];
      [self _purgeRecipients: allRecipients
               fromAddresses: addrs];
      [self _addEMailsOfAddresses: addrs toArray: to];
      [self _addRecipients: addrs toArray: allRecipients];
      [_info setObject: to forKey: @"cc"];

      if ([[_envelope bcc] count])
        {
          to = [NSMutableArray array];
          [addrs setArray: [_envelope bcc]];
          [self _purgeRecipients: allRecipients
                   fromAddresses: addrs];
          [self _addEMailsOfAddresses: addrs toArray: to];
          [_info setObject: to forKey: @"bcc"];
        }
    }
}

//
//
//
- (void) _fetchAttachmentsFromMail: (SOGoMailObject *) sourceMail
{
  NSDictionary *currentInfo;
  NSArray *attachments;

  unsigned int max, count;

  attachments = [sourceMail fetchFileAttachments];
  max = [attachments count];
  for (count = 0; count < max; count++)
    {
      currentInfo = [attachments objectAtIndex: count];
      [self saveAttachment: [currentInfo objectForKey: @"body"]
              withMetadata: currentInfo];
    }
}

//
//
//
- (void) _fileAttachmentsFromPart: (id) thePart
{
  // Small hack to avoid SOPE's stupid behavior to wrap a multipart
  // object in a NGMimeBodyPart.
  if ([thePart isKindOfClass: [NGMimeBodyPart class]] &&
      [[[thePart contentType] type] isEqualToString: @"multipart"])
     thePart = [thePart body];

  if ([thePart isKindOfClass: [NGMimeBodyPart class]])
    {
      NSString *filename, *mimeType;
      id body;

      mimeType = [[thePart contentType] stringValue];
      body = [thePart body];
      filename = [(NGMimeContentDispositionHeaderField *)[thePart headerForKey: @"content-disposition"] filename];

      if (!filename)
        filename = [mimeType asPreferredFilenameUsingPath: nil];

      if (filename)
        {
          NSDictionary *currentInfo;

          currentInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                            filename, @"filename",
                                      mimeType, @"mimetype",
                                      nil];
          [self saveAttachment: body
                  withMetadata: currentInfo];
        }
    }
  else if ([thePart isKindOfClass: [NGMimeMultipartBody class]])
    {
      NSArray *parts;
      int i;

      parts = [thePart parts];
      for (i = 0; i < [parts count]; i++)
        {
          [self _fileAttachmentsFromPart: [parts objectAtIndex: i]];
        }
    }
}


//
//
//
- (void) _fetchAttachmentsFromEncryptedMail: (SOGoMailObject *) sourceMail
{
  NSData *certificate;

  certificate = [[self mailAccountFolder] certificate];

  // If we got a user certificate, let's use it. Otherwise we fallback we
  // don't try to get any attachments from the encrypted content
  if (certificate)
    {
      NGMimeMessage *m;

      m = [[sourceMail content] messageFromEncryptedDataAndCertificate: certificate];
      [self _fileAttachmentsFromPart: [m body]];
    }
}


//
//
//
- (void) fetchMailForEditing: (SOGoMailObject *) sourceMail
{
  NSString *subject, *msgid;
  NSMutableDictionary *info;
  NSDictionary *h;
  NSMutableArray *addresses;
  NGImap4Envelope *sourceEnvelope;
  SOGoUserDefaults *ud;
  id priority, receipt;

  [sourceMail fetchCoreInfos];

  [self _fetchAttachmentsFromMail: sourceMail];
  info = [NSMutableDictionary dictionaryWithCapacity: 16];
  subject = [sourceMail subject];
  if ([subject length] > 0)
    [info setObject: subject forKey: @"subject"];

  sourceEnvelope = [sourceMail envelope];
  msgid = [sourceEnvelope messageID];
  if ([msgid length] > 0)
    [info setObject: msgid forKey: @"message-id"];

  addresses = [NSMutableArray array];
  [self _addEMailsOfAddresses: [sourceEnvelope from] toArray: addresses];
  if ([addresses count])
    [info setObject: [addresses objectAtIndex: 0] forKey: @"from"];
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

  h = [sourceMail mailHeaders];
  priority = [h objectForKey: @"x-priority"];
  if ([priority isNotEmpty] && [priority isKindOfClass: [NSString class]])
      [info setObject: (NSString*)priority forKey: @"X-Priority"];
  receipt = [h objectForKey: @"disposition-notification-to"];
  if ([receipt isNotEmpty] && [receipt isKindOfClass: [NSString class]])
      [info setObject: (NSString*)receipt forKey: @"Disposition-Notification-To"];

  ud = [[context activeUser] userDefaults];

  [self setHeaders: info];
  [self setText: [sourceMail contentForEditing]];
  [self setIMAP4ID: [[sourceMail nameInContainer] intValue]];
  [self setIsHTML: [[ud mailComposeMessageType] isEqualToString: @"html"]];
}

//
//
//
- (void) fetchMailForReplying: (SOGoMailObject *) sourceMail
			toAll: (BOOL) toAll
{
  BOOL fromSentMailbox;
  NSString *msgID;
  NSMutableArray *addresses;
  NSMutableDictionary *info;
  NGImap4Envelope *sourceEnvelope;
  SOGoUserDefaults *ud;

  fromSentMailbox = [[sourceMail container] isKindOfClass: [SOGoSentFolder class]];
  [sourceMail fetchCoreInfos];

  info = [NSMutableDictionary dictionaryWithCapacity: 16];
  [info setObject: [sourceMail subjectForReply] forKey: @"subject"];

  sourceEnvelope = [sourceMail envelope];
  [self _fillInReplyAddresses: info
                   replyToAll: toAll
              fromSentMailbox: fromSentMailbox
                     envelope: sourceEnvelope];
  msgID = [sourceEnvelope messageID];
  if ([msgID length] > 0)
    [self setInReplyTo: msgID];

  addresses = [NSMutableArray array];
  [self _addEMailsOfAddresses: [sourceEnvelope to] toArray: addresses];
  if ([addresses count])
    [info setObject: [addresses objectAtIndex: 0] forKey: @"from"];

  ud = [[context activeUser] userDefaults];

  [self setText: [sourceMail contentForReply]];
  [self setHeaders: info];
  [self setIsHTML: [[ud mailComposeMessageType] isEqualToString: @"html"]];
  [self setSourceURL: [sourceMail imap4URLString]];
  [self setSourceFlag: @"Answered"];
  [self setSourceIMAP4ID: [[sourceMail nameInContainer] intValue]];
  [self setSourceFolderWithMailObject: sourceMail];

  [self storeInfo];
}

- (void) fetchMailForForwarding: (SOGoMailObject *) sourceMail
{
  NSDictionary *info, *attachment;
  NSString *signature, *nl;
  SOGoUserDefaults *ud;

  [sourceMail fetchCoreInfos];

  if ([sourceMail subjectForForward])
    {
      info = [NSDictionary dictionaryWithObject: [sourceMail subjectForForward]
			   forKey: @"subject"];
      [self setHeaders: info];
    }

  [self setSourceURL: [sourceMail imap4URLString]];
  [self setSourceFlag: @"$Forwarded"];
  [self setSourceIMAP4ID: [[sourceMail nameInContainer] intValue]];
  [self setSourceFolderWithMailObject: sourceMail];

  /* attach message */
  ud = [[context activeUser] userDefaults];
  if ([[ud mailMessageForwarding] isEqualToString: @"inline"])
    {
      [self setText: [sourceMail contentForInlineForward]];
      if ([sourceMail isEncrypted])
        [self _fetchAttachmentsFromEncryptedMail: sourceMail];
      else
        [self _fetchAttachmentsFromMail: sourceMail];
    }
  else
    {
      // TODO: use subject for filename?
      // error = [newDraft saveAttachment:content withName:@"forward.eml"];
      signature = [[self mailAccountFolder] signature];
      if ([signature length])
        {
          nl = (isHTML ? @"<br/>" : @"\n");
          [self setText: [NSString stringWithFormat: @"%@%@-- %@%@", nl, nl, nl, signature]];
        }
      attachment = [NSDictionary dictionaryWithObjectsAndKeys:
				   [sourceMail filenameForForward], @"filename",
				 @"message/rfc822", @"mimetype",
				 nil];
      [self saveAttachment: [sourceMail content]
              withMetadata: attachment];
    }

  // Save the message to the IMAP store so the user can eventually view the attached file(s)
  // from the Web interface
  [self save];

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

//
// Return the attributes (name, size and mime body part) of the files found in the draft folder
// on the local filesystem
//
- (NSArray *) fetchAttachmentAttrs
{
  NSMutableArray *ma;
  NSFileManager *fm;
  NSArray *files;
  NSString *filename;
  NSDictionary *fileAttrs;
  NGMimeBodyPart *bodyPart;
  unsigned count, max;

  fm = [NSFileManager defaultManager];
  files = [fm directoryContentsAtPath: [self draftFolderPath]];

  max = [files count];
  ma = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      filename = [files objectAtIndex: count];
      if (![filename hasPrefix: @"."])
        {
          fileAttrs = [fm fileAttributesAtPath: [self pathToAttachmentWithName: filename] traverseLink: YES];
          bodyPart = [self bodyPartForAttachmentWithName: filename];
          [ma addObject: [NSDictionary dictionaryWithObjectsAndKeys: filename, @"filename",
                                       [fileAttrs objectForKey: @"NSFileSize"], @"size",
                                       bodyPart, @"part", nil]];
        }
    }

  return ma;
}


- (NSString *) pathToAttachmentWithName: (NSString *) _name
{
  if ([_name length] == 0)
    return nil;

  return [[self draftFolderPath] stringByAppendingPathComponent:_name];
}


/**
 * Write attachment file to the spool directory of the draft and write a dot
 * file with its mime type.
 */
- (NSException *) saveAttachment: (NSData *) _attach
		    withMetadata: (NSDictionary *) metadata
{
  NSString *p, *pmime, *name, *mimeType;

  if (![_attach isNotNull])
    {
      return [NSException exceptionWithHTTPStatus: 400 /* Bad Request */
                                           reason: @"Missing attachment content!"];
    }

  if (![self _ensureDraftFolderPath])
    {
      return [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                                           reason: @"Could not create folder for draft!"];
    }

  name = [[metadata objectForKey: @"filename"] asSafeFilename];
  p = [self pathToAttachmentWithName: name];

  if (![_attach writeToFile: p atomically: YES])
    {
      return [NSException exceptionWithHTTPStatus: 500 /* Server Error */
			  reason: @"Could not write attachment to draft!"];
    }

  mimeType = [metadata objectForKey: @"mimetype"];
  if ([mimeType length] > 0)
    {
      pmime = [self pathToAttachmentWithName: [NSString stringWithFormat: @".%@.mime", name]];
      if (![[mimeType dataUsingEncoding: NSUTF8StringEncoding] writeToFile: pmime  atomically: YES])
        {
          [[NSFileManager defaultManager] removeFileAtPath: p  handler: nil];
          return [NSException exceptionWithHTTPStatus: 500 /* Server Error */
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
  fm = [NSFileManager defaultManager];
  p = [self pathToAttachmentWithName: [_name asSafeFilename]];
  if ([fm fileExistsAtPath: p])
    if (![fm removeFileAtPath: p handler: nil])
      error = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                                            reason: @"Could not delete attachment from draft!"];

  return error;
}

//
// Only called when converting text/html to text/plain parts
//
- (NGMimeBodyPart *) plainTextBodyPartForText
{
  NGMutableHashMap *map;
  NGMimeBodyPart   *bodyPart;
  NSString *plainText;

  /* prepare header of body part */
  map = [[[NGMutableHashMap alloc] initWithCapacity: 1] autorelease];

  [map setObject: contentTypeValue forKey: @"content-type"];

   /* prepare body content */
  bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];

  plainText = [text htmlToText];
  [bodyPart setBody: plainText];

  return bodyPart;
}


//
//
//
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
  if (text)
    [map setObject: (isHTML ? htmlContentTypeValue : contentTypeValue)
            forKey: @"content-type"];

  /* prepare body content */
  bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];
  [bodyPart setBody: text];

  return bodyPart;
}

- (NGMimeMessage *) mimeMessageForContentWithHeaderMap: (NGMutableHashMap *) map
{
  NGMimeMessage *message;
  id body;

  message = [[[NGMimeMessage alloc] initWithHeader: map] autorelease];

  if (!isHTML)
    {
      [message setHeader: contentTypeValue  forKey: @"content-type"];
      body = text;
    }
  else
    {
      body = [[[NGMimeMultipartBody alloc] initWithPart: message] autorelease];
      [message setHeader: MultiAlternativeType forKey: @"content-type"];

      // Get the text part from it and add it
      [body addBodyPart: [self plainTextBodyPartForText]];

      // Add the HTML part
      [body addBodyPart: [self bodyPartForText]];
    }

  [message setBody: body];

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

  p = [self pathToAttachmentWithName: [NSString stringWithFormat: @".%@.mime", _name]];
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
	s = [s stringByAppendingFormat: @"; name=\"%@\"", [_name stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
    }

  return s;
}

- (NSString *) contentDispositionForAttachmentWithName: (NSString *) _name
                                        andContentType: (NSString *) _type
{
  NSString *cdtype;
  NSString *cd;
  SOGoDomainDefaults *dd;

  if ([_type hasPrefix: @"text/"])
    {
      dd = [[context activeUser] domainDefaults];
      cdtype = [dd mailAttachTextDocumentsInline] ? @"inline" : @"attachment";
    }
  else if ([_type hasPrefix: @"image/"] || [_type hasPrefix: @"message"])
    cdtype = @"inline";
  else
    cdtype = @"attachment";

  cd = [cdtype stringByAppendingString: @"; filename=\""];
  cd = [cd stringByAppendingString: [_name stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
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
  p  = [self pathToAttachmentWithName: _name];
  if (![fm isReadableFileAtPath: p]) {
    [self errorWithFormat: @"did not find attachment: '%@'", _name];
    return nil;
  }
  attachAsString = NO;
  attachAsRFC822 = NO;

  /* prepare header of body part */

  map = [[[NGMutableHashMap alloc] initWithCapacity: 4] autorelease];

  if ((s = [self contentTypeForAttachmentWithName:_name]) != nil) {
    [map setObject: s forKey: @"content-type"];
    if ([s hasPrefix: @"text/plain"] || [s hasPrefix: @"text/html"])
      attachAsString = YES;
    else if ([s hasPrefix: @"message/rfc822"])
      attachAsRFC822 = YES;
  }
  if ((s = [self contentDispositionForAttachmentWithName: _name andContentType: s]))
    {
      NGMimeContentDispositionHeaderField *o;

      o = [[NGMimeContentDispositionHeaderField alloc] initWithString: s];
      [map setObject: o forKey: @"content-disposition"];
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
      }
    else
      {
	content = [content dataByEncodingBase64];
        [map setObject: @"base64" forKey: @"content-transfer-encoding"];
      }
    [map setObject: [NSNumber numberWithInt: [content length]]
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

//
// returns nil on error
//
- (NSArray *) bodyPartsForAllAttachments
{
  NGMimeBodyPart *bodyPart;
  NSMutableArray *bodyParts;
  NSArray  *attrs;
  unsigned i, count, size, limit;

  attrs = [self fetchAttachmentAttrs];
  count = [attrs count];
  size = 0;

  // We first check if we don't go over our message size limit
  limit = [[SOGoSystemDefaults sharedSystemDefaults] maximumMessageSizeLimit] * 1024;
  for (i = 0; i < count; i++)
    size += [[[attrs objectAtIndex: i] objectForKey: @"size"] intValue];

  if (limit && size > limit)
    return nil;

  bodyParts = [NSMutableArray arrayWithCapacity: count];

  for (i = 0; i < count; i++)
    {
      bodyPart = [self bodyPartForAttachmentWithName: [[attrs objectAtIndex: i] objectForKey: @"filename"]];
      [bodyParts addObject: bodyPart];
    }

  return bodyParts;
}

//
//
//
- (NGMimeBodyPart *) mimeMultipartAlternative: (NSArray *) extractedBodyParts
{
  NGMimeMultipartBody *textParts;
  NGMutableHashMap *header;
  NGMimeBodyPart *part;

  header = [NGMutableHashMap hashMap];
  [header addObject: MultiAlternativeType forKey: @"content-type"];

  part = [NGMimeBodyPart bodyPartWithHeader: header];

  textParts = [[NGMimeMultipartBody alloc] initWithPart: part];

  // Get the text part from it and add it
  [textParts addBodyPart: [self plainTextBodyPartForText]];

  if ([extractedBodyParts count])
    {
      // Create a multipart/related part and add this.
      // We have inline image to avoid Thunderbird bug #61815 (https://bugzilla.mozilla.org/show_bug.cgi?id=61815)
      NGMutableHashMap *relatedHeader;
      NGMimeBodyPart *relatedPart;
      NGMimeMultipartBody *relatedParts;
      int i;

      relatedHeader = [NGMutableHashMap hashMap];
      [relatedHeader addObject: MultiRelatedType forKey: @"content-type"];
      relatedPart = [NGMimeBodyPart bodyPartWithHeader: relatedHeader];
      relatedParts = [[NGMimeMultipartBody alloc] initWithPart: relatedPart];

      [relatedParts addBodyPart: [self bodyPartForText]];

      for (i = 0; i < [extractedBodyParts count]; i++)
        {
          [relatedParts addBodyPart: [extractedBodyParts objectAtIndex: i]];
        }

      [relatedPart setBody: relatedParts];
      [textParts addBodyPart: relatedPart];
    }
  else
    {
      // Add the HTML part
      [textParts addBodyPart: [self bodyPartForText]];
    }

  [part setBody: textParts];
  RELEASE(textParts);

  return part;
}

//
//
//
- (NGMimeMessage *) mimeMultiPartMessageWithHeaderMap: (NGMutableHashMap *) map
                                   extractedBodyParts: (NSArray *) extractedBodyParts
  					 andBodyParts: (NSArray *) _bodyParts
                                             bodyOnly: (BOOL) _bodyOnly
{
  NGMimeMessage       *message;
  NGMimeMultipartBody *mBody;
  NSEnumerator        *e;
  id                  part;

  [map addObject: MultiMixedType forKey: @"content-type"];

  message = [[NGMimeMessage alloc] initWithHeader: map];
  [message autorelease];
  mBody = [[NGMimeMultipartBody alloc] initWithPart: message];

  if (!isHTML)
    part = [self bodyPartForText];
  else
    part = [self mimeMultipartAlternative: extractedBodyParts];

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

//
//
//
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
  id emails, from, replyTo;

  map = [[[NGMutableHashMap alloc] initWithCapacity:16] autorelease];

  /* add recipients */
  if ((emails = [headers objectForKey: @"to"]) != nil && [emails isKindOfClass: [NSArray class]])
    [map setObjects: [self _quoteSpecialsInArray: emails] forKey: @"to"];
  if ((emails = [headers objectForKey: @"cc"]) != nil && [emails isKindOfClass: [NSArray class]])
    [map setObjects: [self _quoteSpecialsInArray: emails] forKey: @"cc"];
  if ((emails = [headers objectForKey: @"bcc"]) != nil && [emails isKindOfClass: [NSArray class]])
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

  if ([(s = [headers objectForKey: @"message-id"]) length] > 0)
    [map setObject: s
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

//
//
//
- (NGMimeMessage *) mimeMessageWithHeaders: (NSDictionary *) _headers
				 excluding: (NSArray *) _exclude
                          extractingImages: (BOOL) _extractImages
                                  bodyOnly: (BOOL) _bodyOnly
{
  NSMutableArray *extractedBodyParts;
  NGMimeMessage *message;
  NSArray *allBodyParts;
  NGMutableHashMap *map;
  NSString *newText;

  message = nil;
  extractedBodyParts = [NSMutableArray array];

  if (_extractImages)
    {
      newText = [text htmlByExtractingImages: extractedBodyParts];
      if ([extractedBodyParts count])
        [self setText: newText];
    }

  map = [self mimeHeaderMapWithHeaders: _headers
                             excluding: _exclude];

  if (map)
    {
      //[self debugWithFormat: @"MIME Envelope: %@", map];
      allBodyParts = [self bodyPartsForAllAttachments];

      if (!allBodyParts)
	return nil;

      //[self debugWithFormat: @"attachments: %@", bodyParts];

      if ([extractedBodyParts count] == 0 && [allBodyParts count] == 0)
        {
          // no attachment
          message = [self mimeMessageForContentWithHeaderMap: (_bodyOnly ? nil : map)];
        }
      else
        {
          message = [self mimeMultiPartMessageWithHeaderMap: (_bodyOnly ? [NGMutableHashMap hashMap] : map)
                                         extractedBodyParts: extractedBodyParts
                                               andBodyParts: allBodyParts
                                                   bodyOnly: _bodyOnly];
          //[self debugWithFormat: @"message: %@", message];
        }
    }

  return message;
}

//
// Return a NGMimeMessage object with inline HTML images (<img src=data>) extracted as attachments (<img src=cid>).
//
- (NSData *) mimeMessageForRecipient: (NSString *) theRecipient
{
  NGMimeMessageGenerator *generator, *partGenerator;
  NGMimeMessage *mimeMessage;
  NSData *certificate, *content;
  NGMutableHashMap *hashMap;
  NGMimeMessage *message;
  NSMutableData *d;

  // Nothing to sign or encrypt, let's generate the message and return immediately
  if (![self sign] && ![self encrypt])
    {
      mimeMessage = [self mimeMessageWithHeaders: nil  excluding: nil  extractingImages: YES  bodyOnly: NO];
      if (mimeMessage)
        {
          generator = [[[NGMimeMessageGenerator alloc] init] autorelease];
          return [generator generateMimeFromPart: mimeMessage];
        }
      else
        return nil;
    }

  // We'll sign and/or encrypt our message. Let's generate the actual body of the message to work with
  partGenerator = [[[NGMimePartGenerator alloc] init] autorelease];
  content = [partGenerator generateMimeFromPart: [self mimeMessageWithHeaders: nil  excluding: nil  extractingImages: YES  bodyOnly: YES]];

  if ([self sign])
    {
      certificate = [[self mailAccountFolder] certificate];
      content = [content signUsingCertificateAndKey: certificate];

      if (!content)
        return nil;

      if (![self encrypt])
        goto finish_smime;
    }

  if ([self encrypt])
    {
      if (theRecipient)
        {
          SOGoContactFolders *contactFolders;

          contactFolders = [[[context activeUser] homeFolderInContext: context]
                                  lookupName: @"Contacts"
                                   inContext: context
                                     acquire: NO];
          certificate = [[contactFolders certificateForEmail: theRecipient] convertPKCS7ToPEM];
        }
      else
        certificate =  [[self mailAccountFolder] certificate];

      // We check if we have a valid certificate. We can have nil here coming from [[self mailAccountFolder] certificate].
      // This can happen if one sends an encrypted mail, but actually never uploaded
      // a PKCS#12 file to SOGo for his/her own usage and we're trying to save an encrypted
      // version of the message in the current user's Sent folder
      if (certificate)
        content = [content encryptUsingCertificate: certificate];
    }

 finish_smime:
  // We got our mime part, let's add our mail headers
  hashMap = [self mimeHeaderMapWithHeaders: nil
                                 excluding: [NSArray arrayWithObjects: @"MIME-Version", @"Content-Type", @"Content-Transfer-Encoding", nil]];
  message = [NGMimeMessage messageWithHeader: hashMap];
  generator = [[[NGMimeMessageGenerator alloc] init] autorelease];
  d = [NSMutableData dataWithData: [generator generateMimeFromPart: message]];
  [d replaceBytesInRange: NSMakeRange([d length]-4, 4)
                          withBytes: NULL
                             length: 0];
  [d appendData: content];

  return d;
}

//
//
//
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

//
//
//
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

//
//
//
- (NSException *) sendMail
{
  SOGoContactFolders *contactFolders;
  SOGoUserDefaults *ud;
  NSArray *recipients;
  NSString *recipient;
  int i;

  ud = [[context activeUser] userDefaults];

  // If we are trying to sign an email but we don't have a S/MIME certificate for that
  // IMAP account, we abort
  if ([self sign] && ![[self mailAccountFolder] certificate])
    {
      return [NSException exceptionWithHTTPStatus: 500 /* server error */
                                           reason: @"cannot sign email without certificate"]; 
    }

  // If we are encrypting emails, we must make sure that we have the certificate
  // for all recipients otherwise we cannot, of course, encrypt the email.
  if ([self encrypt])
    {
      NSData *certificate;

      contactFolders = [[[context activeUser] homeFolderInContext: context]
                               lookupName: @"Contacts"
                                inContext: context
                                  acquire: NO];
      recipients = [self allBareRecipients];
      for (i = 0; i < [recipients count]; i++)
        {
          recipient = [recipients objectAtIndex: i];

          if ([[context activeUser] hasEmail: recipient])
            certificate = [[self mailAccountFolder] certificate];
          else
            certificate = [contactFolders certificateForEmail: recipient];

          if (!certificate)
            return [NSException exceptionWithHTTPStatus: 500 /* server error */
                                                 reason: @"cannot encrypt email without recipient certificate"];

          [certificates setObject: certificate  forKey: recipient];
        }
    }

  if ([ud mailAddOutgoingAddresses])
    {
      NSString *emailAddress, *addressBook, *uid;
      NSArray *matchingContacts;
      SOGoContactGCSEntry *newContact;
      NGMailAddress *parsedRecipient;
      NGMailAddressParser *parser;
      SOGoFolder <SOGoContactFolder> *folder;
      NGVCard *card;

      // Get all the addressbooks
      contactFolders = [[[context activeUser] homeFolderInContext: context]
                         lookupName: @"Contacts"
                          inContext: context
                            acquire: NO];
      // Get all the recipients from the current email
      recipients = [self allRecipients];
      for (i = 0; i < [recipients count]; i++)
        {
          // The address contains a string. ex: "John Doe <sogo1@exemple.com>"
          recipient = [recipients objectAtIndex: i];
          parser = [NGMailAddressParser mailAddressParserWithString: recipient];
          parsedRecipient = [parser parse];
          emailAddress = [parsedRecipient address];

          matchingContacts = [contactFolders allContactsFromFilter: emailAddress
                                                     excludeGroups: YES
                                                      excludeLists: YES];
        }
      // If we don't get any results from the autocompletion code, we add it..
      if ([matchingContacts count] == 0)
        {
          // Get the selected addressbook from the user preferences where the new address will be added
          addressBook = [ud selectedAddressBook];
          folder = [contactFolders lookupName: addressBook inContext: context  acquire: NO];
          uid = [folder globallyUniqueObjectId];

          if (folder && uid)
            {
              card = [NGVCard cardWithUid: uid];
              [card addEmail: emailAddress types: nil];
              [card setFn: [parsedRecipient displayName]];

              newContact = [SOGoContactGCSEntry objectWithName: uid  inContainer: folder];
              [newContact setIsNew: YES];
              [newContact saveComponent: card];
            }
        }
    }

  return [self sendMailAndCopyToSent: YES];
}

//
//
//
- (NSException *) sendMailAndCopyToSent: (BOOL) copyToSent
{
  NSData *message, *messageForSent;
  SOGoMailFolder *sentFolder;
  SOGoDomainDefaults *dd;
  NSURL *sourceIMAP4URL;
  NSException *error;

  dd = [[context activeUser] domainDefaults];
  messageForSent = nil;

  // If we are encrypting mails, let's generate and
  // send them individually
  if ([self encrypt])
    {
      NSArray *recipients;
      NSString *recipient;
      int i;

      recipients = [self allBareRecipients];

      for (i = 0; i < [recipients count]; i++)
        {
          recipient = [recipients objectAtIndex: i];

          if ([[context activeUser] hasEmail: recipient])
            message = messageForSent = [self mimeMessageForRecipient: nil];
          else
            message = [self mimeMessageForRecipient: recipient];;

          if (!message)
            return  [NSException exceptionWithHTTPStatus: 500
                                                  reason: @"could not generate message content"];

          error = [[SOGoMailer mailerWithDomainDefaults: dd]
                    sendMailData: message
                    toRecipients: [NSArray arrayWithObject: recipient]
                          sender: [self sender]
                    withAuthenticator: [self authenticatorInContext: context]
                       inContext: context];

          if (error)
            return error;
        }

      // If the current user isn't part of the recipient list for encrypted emails
      // let's generate a crypted email for its sent folder.
      if (!messageForSent)
        messageForSent = [self mimeMessageForRecipient: nil];
    }
  else
    {
      // Encryption is done or not, if we didn't have to.
      message = messageForSent = [self mimeMessageForRecipient: nil];

      if (!message)
        return  [NSException exceptionWithHTTPStatus: 500
                                          reason: @"could not generate message content"];

      error = [[SOGoMailer mailerWithDomainDefaults: dd]
                  sendMailData: message
                  toRecipients: [self allBareRecipients]
                        sender: [self sender]
                withAuthenticator: [self authenticatorInContext: context]
                     inContext: context];
    }

  if (!error && copyToSent)
    {
      sentFolder = [[self mailAccountFolder] sentFolderInContext: context];
      if ([sentFolder isKindOfClass: [NSException class]])
        error = (NSException *) sentFolder;
      else
        {
          error = [sentFolder postData: messageForSent flags: @"seen"];
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

  // Expunge Drafts mailbox if
  //  - message was sent and saved to Sent mailbox if necessary;
  //  - SOGoMailKeepDraftsAfterSend is not set;
  //  - draft is successfully deleted;
  //  - drafts mailbox exists.
  if (!error &&
      ![dd mailKeepDraftsAfterSend] &&
      ![self delete] &&
      [imap4 doesMailboxExistAtURL: [container imap4URL]])
    [(SOGoDraftsFolder *) container expunge];

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

  message = [self mimeMessageForRecipient: nil];
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
