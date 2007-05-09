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

#import <Foundation/NSFileManager.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/WORequest.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>
#import <NGObjWeb/SoSubContext.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSException+misc.h>

#import <SoObjects/Mailer/SOGoDraftObject.h>
#import <SoObjects/Mailer/SOGoMailFolder.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/Mailer/SOGoMailAccounts.h>
#import <SoObjects/Mailer/SOGoMailIdentity.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/WOContext+Agenor.h>
#import <SOGoUI/UIxComponent.h>

/*
  UIxMailEditor
  
  An mail editor component which works on SOGoDraftObject's.
*/

@class NSArray, NSString;
@class SOGoMailFolder;

@interface UIxMailEditor : UIxComponent
{
  NSArray  *to;
  NSArray  *cc;
  NSArray  *bcc;
  NSString *subject;
  NSString *text;
  NSMutableArray  *fromEMails;
  NSString *from;
  SOGoMailFolder *sentFolder;

  /* these are for the inline attachment list */
  NSString *attachmentName;
  NSArray  *attachmentNames;
}

@end

@implementation UIxMailEditor

static BOOL         keepMailTmpFile      = NO;
static BOOL         showInternetMarker   = NO;
static BOOL         useLocationBasedSentFolder = NO;
static NSDictionary *internetMailHeaders = nil;
static NSArray      *infoKeys            = nil;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  infoKeys = [[NSArray alloc] initWithObjects:
				@"subject", @"text", @"to", @"cc", @"bcc", 
			        @"from", @"replyTo",
			      nil];
  
  keepMailTmpFile = [ud boolForKey:@"SOGoMailEditorKeepTmpFile"];
  if (keepMailTmpFile)
    NSLog(@"WARNING: keeping mail files.");
  
  useLocationBasedSentFolder =
    [ud boolForKey:@"SOGoUseLocationBasedSentFolder"];
  
  /* Internet mail settings */
  
  showInternetMarker = [ud boolForKey:@"SOGoShowInternetMarker"];
  if (!showInternetMarker) {
    NSLog(@"Note: visual Internet marker on mail editor disabled "
	  @"(SOGoShowInternetMarker)");
  }
  
  internetMailHeaders = 
    [[ud dictionaryForKey:@"SOGoInternetMailHeaders"] copy];
  NSLog(@"Note: specified %d headers for mails send via the Internet.", 
	[internetMailHeaders count]);
}

- (void)dealloc {
  [sentFolder release];
  [fromEMails release];
  [from    release];
  [text    release];
  [subject release];
  [to      release];
  [cc      release];
  [bcc     release];
  
  [attachmentName  release];
  [attachmentNames release];
  [super dealloc];
}

/* accessors */

- (void)setFrom:(NSString *)_value {
  ASSIGNCOPY(from, _value);
}
- (NSString *)from {
  if (![from isNotEmpty])
    return [[[self context] activeUser] primaryEmail];
  return from;
}

- (void)setReplyTo:(NSString *)_ignore {
}
- (NSString *)replyTo {
  /* we are here for future extensibility */
  return @"";
}

- (void)setSubject:(NSString *)_value {
  ASSIGNCOPY(subject, _value);
}
- (NSString *)subject {
  return subject ? subject : @"";
}

- (void)setText:(NSString *)_value {
  ASSIGNCOPY(text, _value);
}
- (NSString *)text {
  return [text isNotNull] ? text : @"";
}

- (void)setTo:(NSArray *)_value {
  ASSIGNCOPY(to, _value);
}
- (NSArray *)to {
  return [to isNotNull] ? to : [NSArray array];
}

- (void)setCc:(NSArray *)_value {
  ASSIGNCOPY(cc, _value);
}
- (NSArray *)cc {
  return [cc isNotNull] ? cc : [NSArray array];
}

- (void)setBcc:(NSArray *)_value {
  ASSIGNCOPY(bcc, _value);
}
- (NSArray *)bcc {
  return [bcc isNotNull] ? bcc : [NSArray array];
}

- (BOOL)hasOneOrMoreRecipients {
  if ([[self to]  count] > 0) return YES;
  if ([[self cc]  count] > 0) return YES;
  if ([[self bcc] count] > 0) return YES;
  return NO;
}

- (void)setAttachmentName:(NSString *)_attachmentName {
  ASSIGN(attachmentName, _attachmentName);
}
- (NSString *)attachmentName {
  return attachmentName;
}

/* from addresses */

- (NSArray *) fromEMails
{
  NSEnumerator *emails;
  SOGoUser *activeUser;
  NSString *cn, *fullMail, *email;
  
  if (!fromEMails)
    { 
      fromEMails = [NSMutableArray new];
      activeUser = [context activeUser];
      cn = [activeUser cn];
      if ([cn length] == 0)
	cn = nil;
      emails = [[activeUser allEmails] objectEnumerator];
      email = [emails nextObject];
      while (email)
	{
	  if (cn)
	    fullMail = [NSString stringWithFormat: @"%@ <%@>", cn, email];
	  else
	    fullMail = email;
	  [fromEMails addObject: fullMail];
	  email = [emails nextObject];
	}
    }

  return fromEMails;
}

/* title */

- (NSString *)panelTitle {
  return [self labelForKey:@"Compose Mail"];
}

/* detect webmail being accessed from the outside */

- (BOOL)isInternetRequest {
  // DEPRECATED
  return [[self context] isAccessFromIntranet] ? NO : YES;
}

- (BOOL)showInternetMarker {
  if (!showInternetMarker)
    return NO;
  return [[self context] isAccessFromIntranet] ? NO : YES;
}

/* info loading */

- (void)loadInfo:(NSDictionary *)_info {
  if (![_info isNotNull]) return;
  [self debugWithFormat:@"loading info ..."];
  [self takeValuesFromDictionary:_info];
}
- (NSDictionary *)storeInfo {
  [self debugWithFormat:@"storing info ..."];
  return [self valuesForKeys:infoKeys];
}

/* requests */

- (BOOL)shouldTakeValuesFromRequest:(WORequest *)_rq inContext:(WOContext*)_c{
  return YES;
}

/* IMAP4 store */

- (NSException *)patchFlagsInStore {
  /*
    Flags we should set:
      if the draft is a reply   => [message markAnswered]
      if the draft is a forward => [message addFlag:@"forwarded"]
      
    This is hard, we would need to find the original message in Cyrus.
  */
  return nil;
}

- (id)lookupSentFolderUsingAccount {
  SOGoMailAccount *account;
  SOGoMailFolder  *folder;
  
  if (sentFolder != nil)
    return [sentFolder isNotNull] ? sentFolder : nil;;
  
  account = [[self clientObject] mailAccountFolder];
  if ([account isKindOfClass:[NSException class]]) return account;
  
  folder = [account sentFolderInContext:[self context]];
  if ([folder isKindOfClass:[NSException class]]) return folder;
  return ((sentFolder = [folder retain]));
}

- (void)_presetFromBasedOnAccountsQueryParameter {
  /* preset the from field to the primary identity of the given account */
  /* Note: The compose action sets the 'accounts' query parameter */
  NSString         *accountID;
  SOGoMailAccounts *accounts;
  SOGoMailAccount  *account;
  SOGoMailIdentity *identity;

  if (useLocationBasedSentFolder) /* from will be based on location */
    return;

  if ([from isNotEmpty]) /* a from is already set */
    return;

  accountID = [[[self context] request] formValueForKey:@"account"];
  if (![accountID isNotEmpty])
    return;

  accounts = [[self clientObject] mailAccountsFolder];
  if ([accounts isExceptionOrNull])
    return; /* we don't treat this as an error but are tolerant */

  account = [accounts lookupName:accountID inContext:[self context]
		      acquire:NO];
  if ([account isExceptionOrNull])
    return; /* we don't treat this as an error but are tolerant */
  
  identity = [account valueForKey:@"preferredIdentity"];
  if (![identity isNotNull]) {
    [self warnWithFormat:@"Account has no preferred identity: %@", account];
    return;
  }
  
  [self setFrom: [identity email]];
}

- (SOGoMailIdentity *)selectedMailIdentity {
  SOGoMailAccounts *accounts;
  NSEnumerator     *e;
  SOGoMailIdentity *identity;
  
  accounts = [[self clientObject] mailAccountsFolder];
  if ([accounts isExceptionOrNull]) return (id)accounts;
  
  // TODO: This is still a hack because we detect the identity based on the
  //       from. In Agenor all of the identities have unique emails, but this
  //       is not required for SOGo.
  
  if ([[self from] length] == 0)
    return nil;
  
  e = [[accounts fetchIdentitiesWithEmitterPermissions] objectEnumerator];
  while ((identity = [e nextObject]) != nil) {
    if ([[identity email] isEqualToString:[self from]])
      return identity;
  }
  return nil;
}

- (id)lookupSentFolderUsingFrom {
  // TODO: if we have the identity we could also support BCC
  SOGoMailAccounts *accounts;
  SOGoMailIdentity *identity;
  SoSubContext *ctx;
  NSString     *sentFolderName;
  NSArray      *sentFolderPath;
  NSException  *error = nil;
  
  if (sentFolder != nil)
    return [sentFolder isNotNull] ? sentFolder : nil;;
  
  identity = [self selectedMailIdentity];
  if ([identity isKindOfClass:[NSException class]]) return identity;
  
  if (![(sentFolderName = [identity sentFolderName]) isNotEmpty]) {
    [self warnWithFormat:@"Identity has no sent folder name: %@", identity];
    return nil;
  }
  
  // TODO: fixme, we treat the foldername as a hardcoded path from SOGoAccounts
  // TODO: escaping of foldernames with slashes
  // TODO: maybe the SOGoMailIdentity should have an 'account-identifier'
  //       which is used to lookup the account and _then_ perform an account
  //       local folder lookup? => would not be possible to have identities
  //       saving to different accounts.
  sentFolderPath = [sentFolderName componentsSeparatedByString:@"/"];
  
  accounts = [[self clientObject] mailAccountsFolder];
  if ([accounts isKindOfClass:[NSException class]]) return (id)accounts;
  
  ctx = [[SoSubContext alloc] initWithParentContext:[self context]];
  
  sentFolder = [[accounts traversePathArray:sentFolderPath
				inContext:ctx error:&error
				acquire:NO] retain];
  [ctx release]; ctx = nil;
  if (error != nil) {
    [self errorWithFormat:@"Sent-Folder lookup for identity %@ failed: %@",
	    identity, sentFolderPath];
    return error;
  }
  
#if 0
  [self logWithFormat:@"Sent-Folder: %@", sentFolderName];
  [self logWithFormat:@"  object:    %@", sentFolder];
#endif
  return sentFolder;
}

- (NSException *)storeMailInSentFolder:(NSString *)_path {
  SOGoMailFolder *folder;
  NSData *data;
  id result;
  
  folder = useLocationBasedSentFolder 
    ? [self lookupSentFolderUsingAccount]
    : [self lookupSentFolderUsingFrom];
  if ([folder isKindOfClass:[NSException class]]) return (id)folder;
  if (folder == nil) return nil;
  
  if ((data = [[NSData alloc] initWithContentsOfMappedFile:_path]) == nil) {
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason:@"could not find temporary draft file!"];
  }
  
  result = [folder postData:data flags:@"seen"];
  [data release]; data = nil;
  return result;
}

/* actions */

- (BOOL)_saveFormInfo {
  NSDictionary *info;
  
  if ((info = [self storeInfo]) != nil) {
    NSException *error;
    
    if ((error = [[self clientObject] storeInfo:info]) != nil) {
      [self errorWithFormat:@"failed to store draft: %@", error];
      // TODO: improve error handling
      return NO;
    }
  }
  
  // TODO: wrap content
  
  return YES;
}
- (id)failedToSaveFormResponse {
  // TODO: improve error handling
  return [NSException exceptionWithHTTPStatus:500 /* server error */
		      reason:@"failed to store draft object on server!"];
}

/* attachment helper */

- (NSArray *)attachmentNames {
  NSArray *a;
  
  if (attachmentNames != nil)
    return attachmentNames;
  
  a = [[self clientObject] fetchAttachmentNames];
  a = [a sortedArrayUsingSelector:@selector(compare:)];
  attachmentNames = [a copy];
  return attachmentNames;
}
- (BOOL)hasAttachments {
  return [[self attachmentNames] count] > 0 ? YES : NO;
}

- (NSString *)initialLeftsideStyle {
  if ([self hasAttachments])
    return @"width: 67%";
  return @"width: 100%";
}

- (NSString *)initialRightsideStyle {
  if ([self hasAttachments])
    return @"display: block";
  return @"display: none";
}

- (id)defaultAction {
  return [self redirectToLocation:@"edit"];
}

- (id)editAction {
#if 0
  [self logWithFormat:@"edit action, load content from: %@",
	  [self clientObject]];
#endif
  
  [self loadInfo:[[self clientObject] fetchInfo]];
  [self _presetFromBasedOnAccountsQueryParameter];
  return self;
}

- (id)saveAction {
  return [self _saveFormInfo] ? self : [self failedToSaveFormResponse];
}

- (NSException *)validateForSend {
  // TODO: localize errors
  
  if (![self hasOneOrMoreRecipients]) {
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			reason:@"Please select a recipient!"];
  }
  if ([[self subject] length] == 0) {
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			reason:@"Please set a subject!"];
  }
  
  return nil;
}

- (id <WOActionResults>) sendAction
{
  NSException  *error;
  NSString     *mailPath;
  NSDictionary *h;
  id <WOActionResults> result;

  // TODO: need to validate whether we have a To etc
  
  /* first, save form data */
  
  if (![self _saveFormInfo])
    return [self failedToSaveFormResponse];
  
  /* validate for send */
  
  if ((error = [self validateForSend]) != nil) {
    id url;
    
    url = [[error reason] stringByEscapingURL];
    url = [@"edit?error=" stringByAppendingString:url];
    return [self redirectToLocation:url];
  }
  
  /* setup some extra headers if required */
  
  h = [[self context] isAccessFromIntranet] ? nil : internetMailHeaders;
  
  /* save mail to file (so that we can upload the mail to Cyrus) */
  // TODO: all this could be handled by the SOGoDraftObject?
  
  mailPath = [[self clientObject] saveMimeMessageToTemporaryFileWithHeaders:h];

  /* then, send mail */
  
  if ((error = [[self clientObject] sendMimeMessageAtPath:mailPath]) != nil) {
    // TODO: improve error handling
    [[NSFileManager defaultManager] removeFileAtPath:mailPath handler:nil];
    return error;
  }
  
  /* patch flags in store for replies etc */
  
  if ((error = [self patchFlagsInStore]) != nil)
     return error;
  
  /* finally store in Sent */
  
  if ((error = [self storeMailInSentFolder:mailPath]) != nil)
    return error;
  
  /* delete temporary mail file */
  
  if (keepMailTmpFile)
    [self warnWithFormat:@"keeping mail file: '%@'", mailPath];
  else
    [[NSFileManager defaultManager] removeFileAtPath:mailPath handler:nil];
  mailPath = nil;
  
  /* delete draft */
  
  if ((error = [[self clientObject] delete]) != nil)
    return error;

  if ([[[[self context] request] formValueForKey: @"nojs"] intValue])
    result = [self redirectToLocation: [self applicationPath]];
  else
    result = [self jsCloseWithRefreshMethod: nil];

  return result;
}

- (id)deleteAction {
  NSException *error;
  id page;
  
  if ((error = [[self clientObject] delete]) != nil) {
    /* Note: we ignore 404: those are drafts which were not yet saved */
    if (![error httpStatus] == 404)
      return error;
  }
  
#if 1
  page = [self pageWithName:@"UIxMailWindowCloser"];
  [page takeValue:@"YES" forKey:@"refreshOpener"];
  return page;
#else
  // TODO: if we just return nil, we produce a 500
  return [NSException exceptionWithHTTPStatus:204 /* No Content */
		      reason:@"object was deleted."];
#endif
}

@end /* UIxMailEditor */
