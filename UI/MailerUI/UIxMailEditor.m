/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2008-2010 Inverse inc.

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

#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSString.h>

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

#import <SOGo/SOGoUserDefaults.h>
#import <SoObjects/Mailer/SOGoDraftObject.h>
#import <SoObjects/Mailer/SOGoMailFolder.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/Mailer/SOGoMailAccounts.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SOGoUI/UIxComponent.h>

#import "../../Main/SOGo.h"

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

  NSString *priority;
  id item;

  /* these are for the inline attachment list */
  NSString *attachmentName;
  NSArray  *attachmentNames;
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
                                @"from", @"replyTo", @"inReplyTo",
                                @"priority", nil];
}

- (id) init
{
  if ((self = [super init]))
    {
      priority = @"NORMAL";
    }
  
  return self;
}

- (void) dealloc
{
  [item release];
  [priority release];
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
  [attachmentName release];
  [attachmentNames release];
  [attachedFiles release];
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
  ASSIGN(priority, _priority);
}

- (NSString *) priority
{
  return priority;
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
  SOGoUserDefaults *ud;
  NSDictionary *locale;
  
  ud = [[context activeUser] userDefaults];
  locale = [[WOApplication application]
                 localeForLanguageNamed: [ud language]];

  // WARNING : NSLocaleCode is not defined in <Foundation/NSUserDefaults.h>
  return [locale objectForKey: @"NSLocaleCode"];
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

// - (void) setReplyTo: (NSString *) ignore
// {
// }

// - (NSString *) replyTo
// {
//   /* we are here for future extensibility */
//   return @"";
// }

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

- (void) setAttachmentName: (NSString *) newAttachmentName
{
  ASSIGN (attachmentName, newAttachmentName);
}

- (NSString *) attachmentName
{
  return attachmentName;
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
  [self takeValuesFromDictionary:_info];
}

- (NSDictionary *) storeInfo
{
  [self debugWithFormat:@"storing info ..."];
  return [self valuesForKeys:infoKeys];
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
  NSMutableDictionary *filenames;
  NSDictionary *attachment;
  NSArray *parts;
  unsigned int count, max;
  NGMimeBodyPart *part;
  NGMimeContentDispositionHeaderField *header;
  NSString *mimeType, *filename;

  parts = [httpBody parts];
  max = [parts count];
  filenames = [NSMutableDictionary dictionaryWithCapacity: max];

  for (count = 0; count < max; count++)
    {
      part = [parts objectAtIndex: count];
      header = (NGMimeContentDispositionHeaderField *)
	[part headerForKey: @"content-disposition"];
      mimeType = [(NGMimeType *)
		   [part headerForKey: @"content-type"] stringValue];
      filename = [self _fixedFilename: [header filename]];
      attachment = [NSDictionary dictionaryWithObjectsAndKeys:
				   filename, @"filename",
				 mimeType, @"mimetype", nil];
      [filenames setObject: attachment forKey: [header name]];
    }

  return filenames;
}

- (BOOL) _saveAttachments
{
  WORequest *request;
  NSEnumerator *allKeys;
  NSString *key;
  BOOL success;
  NSDictionary *filenames;
  id httpBody;
  SOGoDraftObject *co;

  success = YES;
  request = [context request];

  httpBody = [[request httpRequest] body];
  filenames = [self _scanAttachmentFilenamesInRequest: httpBody];

  co = [self clientObject];
  allKeys = [[request formValueKeys] objectEnumerator];
  while ((key = [allKeys nextObject]) && success)
    if ([key hasPrefix: @"attachment"])
      success
	= (![co saveAttachment: (NSData *) [request formValueForKey: key]
		withMetadata: [filenames objectForKey: key]]);

  return success;
}

- (BOOL) _saveFormInfo
{
  NSDictionary *info;
  NSException *error;
  BOOL success;
  SOGoDraftObject *co;

  co = [self clientObject];
  [co fetchInfo];

  success = YES;

  if ([self _saveAttachments])
    {
      info = [self storeInfo];
      [co setHeaders: info];
      [co setText: text];
      error = [co storeInfo];
      if (error)
	{
	  [self errorWithFormat: @"failed to store draft: %@", error];
	  // TODO: improve error handling
	  success = NO;
	}
    }
  else
    success = NO;

  // TODO: wrap content
  
  return success;
}

- (id) failedToSaveFormResponse
{
  // TODO: improve error handling
  return [NSException exceptionWithHTTPStatus:500 /* server error */
		      reason:@"failed to store draft object on server!"];
}

/* attachment helper */

- (NSArray *) attachmentNames
{
  NSArray *a;

  if (!attachmentNames)
    {
      a = [[self clientObject] fetchAttachmentNames];
      ASSIGN (attachmentNames,
	      [a sortedArrayUsingSelector: @selector (compare:)]);
    }

  return attachmentNames;
}

- (BOOL) hasAttachments
{
  return [[self attachmentNames] count] > 0 ? YES : NO;
}

- (NSString *) uid
{
  return [[self clientObject] nameInContainer];
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

  if ([self _saveFormInfo])
    {
      result = [[self clientObject] save];
      if (!result)
	result = [self responseWith204];
    }
  else
    result = [self failedToSaveFormResponse];

  return result;
}

- (NSException *) validateForSend
{
  NSException *error;

  if (![self hasOneOrMoreRecipients])
    error = [NSException exceptionWithHTTPStatus: 400 /* Bad Request */
			 reason: @"Please select a recipient!"];
  else if ([[self subject] length] == 0)
    error = [NSException exceptionWithHTTPStatus: 400 /* Bad Request */
			 reason: @"Please set a subject!"];
  else
    error = nil;
  
  return error;
}

- (WOResponse *) sendAction
{
  SOGoDraftObject *co;
  NSDictionary *jsonResponse;
  NSException *error;

  co = [self clientObject];

  /* first, save form data */
  error = [self validateForSend];
  if (!error)
    {
      if ([self _saveFormInfo])
        error = [co sendMail];
      else
	error = [self failedToSaveFormResponse];
    }

  if (error)
    jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"failure", @"status",
                                 [error reason], @"message",
                                 nil];
  else
    jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"success", @"status",
                                 [co sourceFolder], @"sourceFolder",
                                 [NSNumber numberWithInt: [co IMAP4ID]], @"messageID",
                                 nil];

  return [self responseWithStatus: 200
                        andString: [jsonResponse jsonRepresentation]];
}

@end /* UIxMailEditor */
