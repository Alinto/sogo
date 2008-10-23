/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  Copyright (C) 2008 Inverse inc.

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

#import <Foundation/NSFileManager.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoSubContext.h>
#import <NGObjWeb/WORequest.h>
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

#import <SoObjects/Mailer/SOGoDraftObject.h>
#import <SoObjects/Mailer/SOGoMailFolder.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/Mailer/SOGoMailAccounts.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SOGoUI/UIxComponent.h>

/*
  UIxMailEditor
  
  An mail editor component which works on SOGoDraftObject's.
*/

@interface UIxMailEditor : UIxComponent
{
  NSArray  *to;
  NSArray  *cc;
  NSArray  *bcc;
  NSString *subject;
  NSString *text;
  NSArray *fromEMails;
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

static BOOL showInternetMarker = NO;
static NSDictionary *internetMailHeaders = nil;
static NSArray *infoKeys = nil;

+ (void) initialize
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  infoKeys = [[NSArray alloc] initWithObjects:
				@"subject", @"to", @"cc", @"bcc", 
			      @"from", @"replyTo", @"inReplyTo",
			      @"priority", nil];
  
  /* Internet mail settings */
  
  showInternetMarker = [ud boolForKey:@"SOGoShowInternetMarker"];
  if (!showInternetMarker)
    NSLog(@"Note: visual Internet marker on mail editor disabled "
	  @"(SOGoShowInternetMarker)");
  
  internetMailHeaders = 
    [[ud dictionaryForKey:@"SOGoInternetMailHeaders"] copy];
  NSLog (@"Note: specified %d headers for mails send via the Internet.", 
	[internetMailHeaders count]);
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

- (void) setFrom: (NSString *) newFrom
{
  ASSIGN (from, newFrom);
}

- (NSString *) from
{
  NSDictionary *identity;

  if (!from)
    {
      identity = [[context activeUser] primaryIdentity];
      from = [identity keysWithFormat: @"%{fullName} <%{email}>"];
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
  NSArray *allIdentities;

  if (!fromEMails)
    { 
      allIdentities = [[context activeUser] allIdentities];
      fromEMails = [allIdentities keysWithFormat: @"%{fullName} <%{email}>"];
      [fromEMails retain];
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

- (id) defaultAction
{
  SOGoDraftObject *co;

  co = [self clientObject];
  [co fetchInfo];
  [self loadInfo: [co headers]];
  [self setText: [co text]];

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

- (id <WOActionResults>) sendAction
{
  id <WOActionResults> result;

  // TODO: need to validate whether we have a To etc
  
  /* first, save form data */
  result = [self validateForSend];
  if (!result)
    {
      if ([self _saveFormInfo])
	{
	  result = [[self clientObject] sendMail];
	  if (!result)
	    result = [self jsCloseWithRefreshMethod: @"refreshCurrentFolder()"];
	}
      else
	result = [self failedToSaveFormResponse];
    }

  return result;
}

@end /* UIxMailEditor */
