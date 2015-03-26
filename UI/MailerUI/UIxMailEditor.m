/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2008-2015 Inverse inc.

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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGHttp/NGHttpRequest.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoSubContext.h>
#define COMPILING_NGOBJWEB 1 /* we want httpRequest for parsing multi-part
                                form data */
#import <NGObjWeb/WORequest.h>
#undef COMPILING_NGOBJWEB
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSException+misc.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeHeaderFields.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimeType.h>

#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/WOResourceManager+SOGo.h>
#import <SOGoUI/UIxComponent.h>
#import <Mailer/SOGoDraftObject.h>
#import <Mailer/SOGoMailObject+Draft.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>
#import <Contacts/SOGoContactFolders.h>
#import <Contacts/SOGoContactFolder.h>
#import <Contacts/SOGoContactSourceFolder.h>

#import <UI/MailPartViewers/UIxMailSizeFormatter.h>

/*
  UIxMailEditor
  
  A mail editor component which works on SOGoDraftObject's.
*/

@interface UIxMailEditor : UIxComponent
{
  NSArray  *to;
  NSArray  *cc;
  NSArray  *bcc;
  NSString *subject;
  NSString *sourceUID;
  NSString *sourceFolder;
  NSString *text;
  NSMutableArray *fromEMails;
  NSString *from;
  SOGoMailFolder *sentFolder;
  BOOL isHTML;

  NSString *priority;
  NSString *receipt;
  id item;
  id currentFolder;

  /* these are for the inline attachment list */
  NSDictionary *attachment;
  NSArray  *attachmentAttrs;
  NSString *currentAttachment;
  NSMutableArray *attachedFiles;
}

@end

@implementation UIxMailEditor

static NSArray *infoKeys = nil;

+ (void) initialize
{
  if (!infoKeys)
    infoKeys = [[NSArray alloc] initWithObjects:
                                  @"subject", @"to", @"cc", @"bcc", 
                                @"from", @"inReplyTo",
                                @"replyTo",
                                @"priority", @"receipt", nil];
}

- (id) init
{
  if ((self = [super init]))
    {
      priority = @"NORMAL";
      receipt = nil;
      currentFolder = nil;
      currentAttachment = nil;
      attachmentAttrs = nil;
      attachedFiles = nil;
    }
  
  return self;
}

- (void) dealloc
{
  [item release];
  [priority release];
  [receipt release];
  [sentFolder release];
  [fromEMails release];
  [from release];
  [text release];
  [subject release];
  [to release];
  [cc release];
  [bcc release];
  [sourceUID release];
  [sourceFolder release];
  [attachment release];
  [currentAttachment release];
  [attachmentAttrs release];
  [attachedFiles release];
  [currentFolder release];
  [super dealloc];
}

/* accessors */
- (void) setItem: (id) _item
{
  ASSIGN (item, _item);
}

- (id) item
{
  return item;
}

- (NSString *) uid
{
  return [[self clientObject] nameInContainer];
}

- (NSArray *) priorityClasses
{
  static NSArray *priorities = nil;
  
  if (!priorities)
    {
      priorities = [NSArray arrayWithObjects: @"HIGHEST", @"HIGH",
                            @"NORMAL", @"LOW", @"LOWEST", nil];
      [priorities retain];
    }

  return priorities;
}

- (void) setPriority: (NSString *) _priority
{
  ASSIGN (priority, _priority);
}

- (NSString *) priority
{
  return priority;
}

- (void) setReceipt: (NSString *) newReceipt
{
  ASSIGN (receipt, newReceipt);
}

- (NSString *) receipt
{
  return receipt;
}

- (void) setIsHTML: (BOOL) aBool
{
  isHTML = aBool;
}

- (BOOL) isHTML
{
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];

  return [[ud mailComposeMessageType] isEqualToString: @"html"];
}

- (NSString *) itemPriorityText
{
  return [self labelForKey: [NSString stringWithFormat: @"%@", [item lowercaseString]]];
}

- (NSString *) isMailReply
{
  return ([to count] > 0 ? @"true" : @"false");
}

- (NSString *) localeCode
{
  // WARNING : NSLocaleCode is not defined in <Foundation/NSUserDefaults.h>
  // Region subtag must be separated by a dash
  NSMutableString *s = [NSMutableString stringWithString: [locale objectForKey: @"NSLocaleCode"]];

  [s replaceOccurrencesOfString: @"_"
                     withString: @"-"
                        options: 0
                          range: NSMakeRange(0, [s length])];
  
  return s;
}

- (void) setFrom: (NSString *) newFrom
{
  ASSIGN (from, newFrom);
}

- (NSString *) _emailFromIdentity: (NSDictionary *) identity
{
  NSString *fullName, *format;

  fullName = [identity objectForKey: @"fullName"];
  if ([fullName length])
    format = @"%{fullName} <%{email}>";
  else
    format = @"%{email}";

  return [identity keysWithFormat: format];
}

- (NSString *) from
{
  NSDictionary *identity;

  if (!from)
    {
      identity = [[context activeUser] primaryIdentity];
      from = [self _emailFromIdentity: identity];
      [from retain];
    }

  return from;
}

- (NSString *) replyTo
{
  NSString *value;
  
  value = nil;

  //
  // We add the correct replyTo here. That is, the one specified in the defaults
  // for the main "SOGo mail account" versus the one specified in the auxiliary
  // IMAP accounts.
  //
  if ([[[[self clientObject] mailAccountFolder] nameInContainer] intValue] == 0)
    {
      SOGoUserDefaults *ud;
      
      ud = [[context activeUser] userDefaults];
      value = [ud mailReplyTo];
    }
  else
    {
      NSArray *identities;
      
      identities = [[[self clientObject] mailAccountFolder] identities];

      if ([identities count])
        value = [[identities objectAtIndex: 0] objectForKey: @"replyTo"];
    }

  return value;
}

- (void) setSubject: (NSString *) newSubject
{
  ASSIGN (subject, newSubject);
}

- (NSString *) subject
{
  return subject;
}

- (void) setText: (NSString *) newText
{
  ASSIGN (text, newText);
}

- (NSString *) text
{
  return text;
}

- (void) setSourceUID: (int) newSourceUID
{
  NSString *s;

  s = [NSString stringWithFormat: @"%i", newSourceUID];
  ASSIGN (sourceUID, s);
}

- (NSString *) sourceUID
{
  return sourceUID;
}

- (void) setSourceFolder: (NSString *) newSourceFolder
{
  ASSIGN (sourceFolder, newSourceFolder);
}

- (NSString *) sourceFolder
{
  return sourceFolder;
}

- (void) setTo: (NSArray *) newTo
{
  if ([newTo isKindOfClass: [NSNull class]])
    newTo = nil;

  ASSIGN (to, newTo);
}

- (NSArray *) to
{
  return to;
}

- (void) setCc: (NSArray *) newCc
{
  if ([newCc isKindOfClass: [NSNull class]])
    newCc = nil;

  ASSIGN (cc, newCc);
}

- (NSArray *) cc
{
  return cc;
}

- (void) setBcc: (NSArray *) newBcc
{
  if ([newBcc isKindOfClass: [NSNull class]])
    newBcc = nil;

  ASSIGN (bcc, newBcc);
}

- (NSArray *) bcc
{
  return bcc;
}

- (BOOL) hasOneOrMoreRecipients
{
  return (([to count] + [cc count] + [bcc count]) > 0);
}

- (void) setAttachment: (NSDictionary *) newAttachment
{
  ASSIGN (attachment, newAttachment);
}

- (NSDictionary *) attachment
{
  return attachment;
}

- (NSFormatter *) sizeFormatter
{
  return [UIxMailSizeFormatter sharedMailSizeFormatter];
}

/* from addresses */

- (NSArray *) fromEMails
{
  NSArray *identities;
  int count, max;
  NSString *email;
  SOGoMailAccount *account;

  if (!fromEMails)
    { 
      account = [[self clientObject] mailAccountFolder];
      identities = [account identities];
      max = [identities count];
      fromEMails = [[NSMutableArray alloc] initWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          email
            = [self _emailFromIdentity: [identities objectAtIndex: count]];
          [fromEMails addObjectUniquely: email];
        }
    }

  return fromEMails;
}

/* info loading */

- (void) loadInfo: (NSDictionary *) _info
{
  if (![_info isNotNull]) return;
  [self debugWithFormat:@"loading info ..."];
  [self setValuesForKeysWithDictionary:_info];
}

- (NSDictionary *) storeInfo
{
  [self debugWithFormat:@"storing info ..."];
  return [self dictionaryWithValuesForKeys: infoKeys];
}

/* contacts search */
- (NSArray *) contactFolders
{
  SOGoContactFolders *folderContainer;

  folderContainer = (SOGoContactFolders *) [[[self clientObject] lookupUserFolder] privateContacts: @"Contacts"
                                                                                        inContext: nil];
  
  return [folderContainer subFolders];
}

- (NSArray *) personalContactInfos
{
  SOGoContactFolders *folderContainer;
  id <SOGoContactFolder> folder;
  NSArray *contactInfos;

  folderContainer = (SOGoContactFolders *) [[[self clientObject] lookupUserFolder] privateContacts: @"Contacts"
                                                                                           inContext: nil];
  
  folder = [folderContainer lookupPersonalFolder: @"personal" ignoringRights: YES];

  // If the folder doesn't exist anymore or if the database is down, we
  // return an empty array.
  if ([folder isKindOfClass: [NSException class]])
      return [NSArray array];

  contactInfos = [folder lookupContactsWithFilter: nil
				       onCriteria: nil
					   sortBy: @"c_cn"
					 ordering: NSOrderedAscending
                                         inDomain: nil];
  
  return contactInfos;
}

- (void) setCurrentFolder: (id) _currentFolder
{
  ASSIGN (currentFolder, _currentFolder);
}

- (NSString *) currentContactFolderId
{
  return [NSString stringWithFormat: @"/%@", [currentFolder nameInContainer]];
}

- (NSString *) currentContactFolderName
{
  return [currentFolder displayName];
}

- (NSString *) currentContactFolderOwner
{
  return [currentFolder ownerInContext: context];
}

- (NSString *) currentContactFolderClass
{
  return ([currentFolder isKindOfClass: [SOGoContactSourceFolder class]]
          ? @"remote" : @"local");
}

/* requests */

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) request
			   inContext: (WOContext*) localContext
{
  return YES;
}

/* actions */
- (NSString *) _fixedFilename: (NSString *) filename
{
  NSString *newFilename, *baseFilename, *extension;
  unsigned int variation;

  if (!attachedFiles)
    attachedFiles = [NSMutableArray new];

  newFilename = filename;

  baseFilename = [filename stringByDeletingPathExtension];
  extension = [filename pathExtension];
  variation = 0;
  while ([attachedFiles containsObject: newFilename])
    {
      variation++;
      newFilename = [NSString stringWithFormat: @"%@-%d.%@", baseFilename,
			      variation, extension];
    }
  [attachedFiles addObject: newFilename];

  return newFilename;
}

- (NSDictionary *) _scanAttachmentFilenamesInRequest: (id) httpBody
{
  NSMutableDictionary *files;
  NSDictionary *file;
  NSArray *parts;
  unsigned int count, max;
  NGMimeBodyPart *part;
  NGMimeContentDispositionHeaderField *header;
  NSString *mimeType, *filename;

  parts = [httpBody parts];
  max = [parts count];
  files = [NSMutableDictionary dictionaryWithCapacity: max];

  for (count = 0; count < max; count++)
    {
      part = [parts objectAtIndex: count];
      header = (NGMimeContentDispositionHeaderField *)[part headerForKey: @"content-disposition"];
      if ([[header name] hasPrefix: @"attachments"])
        {
          mimeType = [(NGMimeType *)[part headerForKey: @"content-type"] stringValue];
          filename = [self _fixedFilename: [header filename]];
          file = [NSDictionary dictionaryWithObjectsAndKeys:
                                 filename, @"filename",
                                 mimeType, @"mimetype",
                                 [part body], @"body",
                                 nil];
          [files setObject: file forKey: [NSString stringWithFormat: @"%@_%@", [header name], filename]];
        }
    }

  return files;
}

- (NSException *) _saveAttachments
{
  NSException *error;
  WORequest *request;
  NSEnumerator *allAttachments;
  NSDictionary *attrs, *filenames;
  NGMimeType *mimeType;
  id httpBody;
  SOGoDraftObject *co;

  error = nil;
  request = [context request];

  mimeType = [[request httpRequest] contentType];
  if ([[mimeType type] isEqualToString: @"multipart"])
    {
      httpBody = [[request httpRequest] body];
      filenames = [self _scanAttachmentFilenamesInRequest: httpBody];

      co = [self clientObject];
      allAttachments = [filenames objectEnumerator];
      while ((attrs = [allAttachments nextObject]) && !error)
        {
          error = [co saveAttachment: (NSData *) [attrs objectForKey: @"body"]
                        withMetadata: attrs];
          // Keep the name of the last attachment saved
          ASSIGN(currentAttachment, [attrs objectForKey: @"filename"]);
        }
    }

  return error;
}

- (NSException *) _saveFormInfo
{
  NSDictionary *info;
  NSException *error;
  SOGoDraftObject *co;

  co = [self clientObject];
  [co fetchInfo];

  error = [self _saveAttachments];
  if (!error)
    {
      info = [self storeInfo];
      [co setHeaders: info];
      [co setIsHTML: isHTML];
      [co setText: (isHTML ? [NSString stringWithFormat: @"<html>%@</html>", text] : text)];;
      error = [co storeInfo];
    }

  return error;
}

- (id) failedToSaveFormResponse: (NSString *) msg
{
  NSDictionary *d;

  d = [NSDictionary dictionaryWithObjectsAndKeys: msg, @"textStatus", nil];

  return [self responseWithStatus: 500
                        andString: [d jsonRepresentation]];
}

/* attachment helper */

- (NSArray *) attachmentAttrs
{
  SOGoDraftObject *co;
  SOGoMailObject *mail;
  NSArray *a;

  co = [self clientObject];
  if (!attachmentAttrs || ![co imap4URL])
  {
      [co fetchInfo];
      if ((![co inReplyTo] || currentAttachment) && [co IMAP4ID] > -1)
        {
          // When currentAttachment is defined, it means we just attached a new file to the mail
          mail = [[[SOGoMailObject alloc] initWithImap4URL: [co imap4URL] inContainer: [co container]] autorelease];
          a = [mail fetchFileAttachmentKeys];
          ASSIGN (attachmentAttrs, a);
        }
  }

  if (currentAttachment)
    {
      // When currentAttachment is defined, only return the attributes of the last
      // attachment saved
      NSEnumerator *allAttachments;
      NSDictionary* attrs;

      allAttachments = [attachmentAttrs objectEnumerator];
      while ((attrs = [allAttachments nextObject]))
        {
          if ([[attrs objectForKey: @"filename"] isEqualToString: currentAttachment])
            {
              return [NSArray arrayWithObject: attrs];
            }
        }
    }

  return attachmentAttrs;
}

- (BOOL) hasAttachments
{
  return [[self attachmentAttrs] count] > 0 ? YES : NO;
}

- (id) defaultAction
{
  SOGoDraftObject *co;

  co = [self clientObject];
  [co fetchInfo];
  [self loadInfo: [co headers]];
  [self setText: [co text]];
  [self setSourceUID: [co IMAP4ID]];
  [self setSourceFolder: [co sourceFolder]];

  return self;
}

- (id <WOActionResults>) saveAction
{
  id result;

  result = [self _saveFormInfo];
  if (!result)
    {
      result = [[self clientObject] save];
    }
  if (!result)
    {
      attachmentAttrs = nil;
      NSArray *attrs = [self attachmentAttrs];
      result = [self responseWithStatus: 200
                              andString: [attrs jsonRepresentation]];
    }
  else
    result = [self failedToSaveFormResponse: [result reason]];

  return result;
}

- (NSException *) validateForSend
{
  NSException *error;

  if (![self hasOneOrMoreRecipients])
    error = [NSException exceptionWithHTTPStatus: 400 /* Bad Request */
                                          reason: [self labelForKey: @"error_missingrecipients"]];
  else
    error = nil;
  
  return error;
}

//
//
//
- (WOResponse *) sendAction
{
  SOGoDraftObject *co;
  NSDictionary *jsonResponse;
  NSException *error;
  NSMutableArray *errorMsg;
  NSDictionary *messageSubmissions;
  SOGoSystemDefaults *dd;

  int messages_count, recipients_count;

  messageSubmissions = [[SOGoCache sharedCache] messageSubmissionsCountForLogin: [[context activeUser] login]];
  dd = [SOGoSystemDefaults sharedSystemDefaults];
  messages_count = recipients_count = 0;

  if (messageSubmissions)
    {
      unsigned int current_time, start_time, delta, block_time;

      current_time = [[NSCalendarDate date] timeIntervalSince1970];
      start_time = [[messageSubmissions objectForKey: @"InitialDate"] unsignedIntValue];
      delta = current_time - start_time;

      block_time = [dd messageSubmissionBlockInterval];
      messages_count = [[messageSubmissions objectForKey: @"MessagesCount"] intValue];
      recipients_count =  [[messageSubmissions objectForKey: @"RecipientsCount"] intValue];
      
      if ((messages_count >= [dd maximumMessageSubmissionCount] || recipients_count >= [dd maximumRecipientCount]) &&
          delta <= block_time)
        {
          jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"failure", @"status",
                                                  [self labelForKey: @"Tried to send too many mails. Please wait."],
                                       @"message",
                                       nil];
          return [self responseWithStatus: 200
                                andString: [jsonResponse jsonRepresentation]];
        }
      
      if (delta > block_time ||
          (delta >= [dd maximumSubmissionInterval] && messages_count < [dd maximumMessageSubmissionCount] && recipients_count < [dd maximumRecipientCount]))
        {
          [[SOGoCache sharedCache] setMessageSubmissionsCount: 0
                                              recipientsCount: 0
                                                     forLogin: [[context activeUser] login]];
        }
    }

  co = [self clientObject];

  /* first, save form data */
  error = [self validateForSend];
  if (!error)
    {
      error = [self _saveFormInfo];
      if (!error)
        error = [co sendMail];
      else
	error = [self failedToSaveFormResponse: [error reason]];
    }

  if (error)
    {
      // Only the first line is translated
      errorMsg = [NSMutableArray arrayWithArray: [[error reason] componentsSeparatedByString: @"\n"]];
      [errorMsg replaceObjectAtIndex: 0
			  withObject: [self labelForKey: [errorMsg objectAtIndex: 0]]];
      jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
				     @"failure", @"status",
			           [errorMsg componentsJoinedByString: @"\n"],
				   @"message",
				   nil];
    }
  else
    {
      jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"success", @"status",
                                   [co sourceFolder], @"sourceFolder",
                                        [NSNumber numberWithInt: [co sourceIMAP4ID]], @"sourceMessageID",
                                   nil];
     
      recipients_count += [[co allRecipients] count];
      messages_count += 1;
      
      if ([dd maximumMessageSubmissionCount] > 0 && [dd maximumRecipientCount] > 0)
        {
          [[SOGoCache sharedCache] setMessageSubmissionsCount: messages_count
                                              recipientsCount: recipients_count
                                                     forLogin: [[context activeUser] login]];
        }
    }

  return [self responseWithStatus: 200
                        andString: [jsonResponse jsonRepresentation]];
}

@end /* UIxMailEditor */
