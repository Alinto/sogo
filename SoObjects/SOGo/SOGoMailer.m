/* SOGoMailer.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2015 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSArray.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSURL+misc.h>
#import <NGMail/NGSendMail.h>
#import <NGMail/NGSmtpClient.h>
#import <NGMime/NGMimePartGenerator.h>
#import <NGStreams/NGInternetSocketAddress.h>

#import "NSString+Utilities.h"
#import "SOGoStaticAuthenticator.h"
#import "SOGoEmptyAuthenticator.h"
#import "SOGoSystemDefaults.h"
#import "SOGoUser.h"
#import "SOGoUserManager.h"
#import "SOGoMailer.h"

//
// Useful extension that comes from Pantomime which is also
// released under the LGPL. We should eventually merge
// this with the same category found in SOPE's NGSmtpClient.m
// or simply drop sope-mime in favor of Pantomime
//
@interface NSMutableData (DataCleanupExtension)

- (unichar) characterAtIndex: (int) theIndex;
- (NSRange) rangeOfCString: (const char *) theCString;
- (NSRange) rangeOfCString: (const char *) theCString
		  options: (unsigned int) theOptions
		    range: (NSRange) theRange;
@end

@implementation NSMutableData (DataCleanupExtension)

- (unichar) characterAtIndex: (int) theIndex
{
  const char *bytes;
  int i, len;

  len = [self length];

  if (len == 0 || theIndex >= len)
    {
      [[NSException exceptionWithName: NSRangeException
                    reason: @"Index out of range."
                    userInfo: nil] raise];

      return (unichar)0;
    }

  bytes = [self bytes];

  for (i = 0; i < theIndex; i++)
    {
      bytes++;
    }

  return (unichar)*bytes;
}

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

@implementation SOGoMailer

+ (SOGoMailer *) mailerWithDomainDefaults: (SOGoDomainDefaults *) dd
{
  return [[self alloc] initWithDomainDefaults: dd];
}

+ (SOGoMailer *) mailerWithDomainDefaultsAndSmtpUrl: (SOGoDomainDefaults *) dd
                                            smtpUrl: (NSURL *) smtpUrl
                                            userIdAccount: (NSString *) _userIdAccount
{
  return [[self alloc] initWithDomainDefaultsAndSmtpUrl: dd
                                                smtpUrl: smtpUrl
                                                 userIdAccount: _userIdAccount];
}

- (id) initWithDomainDefaults: (SOGoDomainDefaults *) dd
{
  if ((self = [self init]))
    {
      ASSIGN (mailingMechanism, [dd mailingMechanism]);
      ASSIGN (smtpServer, [dd smtpServer]);
      smtpMasterUserEnabled = [dd smtpMasterUserEnabled];
      ASSIGN (smtpMasterUserUsername, [dd smtpMasterUserUsername]);
      ASSIGN (smtpMasterUserPassword, [dd smtpMasterUserPassword]);
      ASSIGN (authenticationType, [[dd smtpAuthenticationType] lowercaseString]);
      ASSIGN (userIdAccount, @"0");
    }

  return self;
}

- (id) initWithDomainDefaultsAndSmtpUrl: (SOGoDomainDefaults *) dd
                                smtpUrl: (NSURL *) smtpUrl
                                userIdAccount: (NSString *) _userIdAccount
{
  if ((self = [self init]))
    {
      ASSIGN (mailingMechanism, [dd mailingMechanism]);
      ASSIGN (smtpServer, [smtpUrl absoluteString]);
      smtpMasterUserEnabled = [dd smtpMasterUserEnabled];
      ASSIGN (smtpMasterUserUsername, [dd smtpMasterUserUsername]);
      ASSIGN (smtpMasterUserPassword, [dd smtpMasterUserPassword]);
      ASSIGN (authenticationType, [[dd smtpAuthenticationType] lowercaseString]);
      ASSIGN (userIdAccount, _userIdAccount);
    }

  return self;
}

- (id) init
{
  if ((self = [super init]))
    {
      mailingMechanism = nil;
      smtpServer = nil;
      smtpMasterUserEnabled = NO;
      smtpMasterUserUsername = nil;
      smtpMasterUserPassword = nil;
      authenticationType = nil;
      userIdAccount = nil;
    }

  return self;
}

- (void) dealloc
{
  [mailingMechanism release];
  [smtpServer release];
  [smtpMasterUserUsername release];
  [smtpMasterUserPassword release];
  [authenticationType release];
  [userIdAccount release];
  [super dealloc];
}

- (BOOL) requiresAuthentication
{
  return ![mailingMechanism isEqualToString: @"sendmail"] && authenticationType;
}

- (NSException *) _sendmailSendData: (NSData *) mailData
		       toRecipients: (NSArray *) recipients
			     sender: (NSString *) sender
{
  NSException *result;
  NGSendMail *mailer;

  mailer = [NGSendMail sharedSendMail];
  if ([mailer isSendMailAvailable])
    result = [mailer sendMailData: mailData
		     toRecipients: recipients
		     sender: sender];
  else
    result = [NSException exceptionWithHTTPStatus: 500
			  reason: @"cannot send message:"
			  @" no sendmail binary!"];

  return result;
}

- (NSException *) _sendMailData: (NSData *) mailData
		     withClient: (NGSmtpClient *) client
{
  NSException *result;

  if ([client sendData: mailData])
    result = nil;
  else
    result = [NSException exceptionWithHTTPStatus: 500
			  reason: @"cannot send message:"
			  @" (smtp) failure when sending data"];

  return result;
}

- (NSException *) _smtpSendData: (NSData *) mailData
                   toRecipients: (NSArray *) recipients
                         sender: (NSString *) sender
              withAuthenticator: (id <SOGoAuthenticator>) authenticator
                      inContext: (WOContext *) woContext
                  systemMessage: (BOOL) isSystemMessage
{
  NSString *currentTo, *login, *password;
  NSDictionary *currentAcount;
  NSMutableArray *toErrors;
  NSEnumerator *addresses;
  NGSmtpClient *client;
  NSException *result;
  NSURL * smtpUrl;
  SOGoUser* user;
  BOOL doSmtpAuth;

  result = nil;
  doSmtpAuth = NO;

  //find the smtpurl for the account
  smtpUrl = [[[NSURL alloc] initWithString: smtpServer] autorelease];
  client = [NGSmtpClient clientWithURL: smtpUrl];

  //Get the user and the current account 
  int userId = [userIdAccount intValue];
  user = [SOGoUser userWithLogin: [[woContext activeUser] login]];
  currentAcount = [[user mailAccounts] objectAtIndex: userId];

  //Check if we do an smtp authentication
  doSmtpAuth = [authenticationType isEqualToString: @"plain"] && ![authenticator isKindOfClass: [SOGoEmptyAuthenticator class]];
  if(!doSmtpAuth && userId > 0)
  {
    doSmtpAuth = [currentAcount objectForKey: @"smtpAuth"] ? [[currentAcount objectForKey: @"smtpAuth"] boolValue] : NO;
  }

  NS_DURING
    {
      [client connect];
      if (doSmtpAuth)
        {
          //Check if the ccurent mail folder if for an auxiliary account (userId > 0)
          if(userId > 0)
          {
            login = [currentAcount objectForKey: @"userName"];
            password = [currentAcount objectForKey: @"password"];
          }
          else
          {
            /* XXX Allow static credentials by peeking at the classname */
            if ([authenticator isKindOfClass: [SOGoStaticAuthenticator class]])
              login = [(SOGoStaticAuthenticator *)authenticator username];
            else
              login = [[SOGoUserManager sharedUserManager]
                        getExternalLoginForUID: [[authenticator userInContext: woContext] loginInDomain]
                                      inDomain: [[authenticator userInContext: woContext] domain]];

            password = [authenticator passwordInContext: woContext];
          }


          if (isSystemMessage 
              && ![[[SOGoUserManager sharedUserManager] getEmailForUID: [[authenticator userInContext: woContext] loginInDomain]] isEqualToString: sender] 
              && smtpMasterUserEnabled) {
            if (![client plainAuthenticateUser: smtpMasterUserUsername
                                   withPassword: smtpMasterUserPassword]) {
              result = [NSException exceptionWithHTTPStatus: 500
                                                   reason: @"cannot send message:"
                                  @" (smtp) authentication failure"];
              [self errorWithFormat: @"Could not connect to the SMTP server with master credentials %@", smtpServer];
            }
          } 
          else
          {
            if ([login length] == 0
              || [login isEqualToString: @"anonymous"]
              || ![client plainAuthenticateUser: login
                                   withPassword: password])
              result = [NSException exceptionWithHTTPStatus: 500
                                                    reason: @"cannot send message:"
                                    @" (smtp) authentication failure"];
          }
        }
      else if (authenticationType && ![authenticator isKindOfClass: [SOGoEmptyAuthenticator class]])
        result = [NSException
                   exceptionWithHTTPStatus: 500
                   reason: @"cannot send message:"
                   @" unsupported authentication method"];
      if (!result)
        {
          if ([client mailFrom: sender])
            {
              toErrors = [NSMutableArray array];
              addresses = [recipients objectEnumerator];
              currentTo = [addresses nextObject];
              while (currentTo)
                {
                  if (![client recipientTo: [currentTo pureEMailAddress]])
                    {
                      [self logWithFormat: @"error with recipient '%@'", currentTo];
                      [toErrors addObject: [currentTo pureEMailAddress]];
                    }
                  currentTo = [addresses nextObject];
                }
              if ([toErrors count] == [recipients count])
                result = [NSException exceptionWithHTTPStatus: 500
                                                       reason: @"cannot send message:"
                                      @" (smtp) all recipients discarded"];
              else if ([toErrors count] > 0)
                result = [NSException exceptionWithHTTPStatus: 500
                                                       reason: [NSString stringWithFormat:
                                                                           @"cannot send message (smtp) - recipients discarded:\n%@",
                                                                         [toErrors componentsJoinedByString: @", "]]];
              else
                result = [self _sendMailData: mailData withClient: client];
            }
          else
            result = [NSException exceptionWithHTTPStatus: 500
                                                   reason: @"cannot send message: (smtp) originator not accepted"];
        }
      [client quit];
      [client disconnect];
    }
  NS_HANDLER
    {
      [self errorWithFormat: @"Could not connect to the SMTP server %@", smtpServer];
      if ([localException reason])
        {
          result = [NSException exceptionWithHTTPStatus: 500
                                                 reason: [localException reason]];
        }
      else
        {
          result = [NSException exceptionWithHTTPStatus: 500
                                                 reason: @"cannot send message:"
                                @" (smtp) error when connecting"];
        }
    }
  NS_ENDHANDLER;

  return result;
}

- (NSException *) sendMailData: (NSData *) data
		  toRecipients: (NSArray *) recipients
			sender: (NSString *) sender
             withAuthenticator: (id <SOGoAuthenticator>) authenticator
                     inContext: (WOContext *) woContext
                 systemMessage: (BOOL) isSystemMessage
{
  NSException *result;

  if (![recipients count])
    result = [NSException exceptionWithHTTPStatus: 500
			  reason: @"cannot send message: no recipients set"];
  else
    {
      if (![sender length])
	result = [NSException exceptionWithHTTPStatus: 500
			      reason: @"cannot send message: no sender set"];
      else
	{
	  NSMutableData *cleaned_message;
	  NSRange r1;
	  unsigned int limit;

	  //
	  // We now look for the Bcc: header. If it is present, we remove it.
	  // Some servers, like qmail, do not remove it automatically.
	  //
#warning FIXME - we should fix the case issue when we switch to Pantomime
	  cleaned_message = [NSMutableData dataWithData: data];

	  // We search only in the headers so we start at 0 until
	  // we find \r\n\r\n, which is the headers delimiter
	  r1 = [cleaned_message rangeOfCString: "\r\n\r\n"];
	  limit = r1.location-1;

	  // We check if the mail actually *starts* with the Bcc: header
	  r1 = [cleaned_message rangeOfCString: "Bcc: "
				       options: 0
					 range: NSMakeRange(0,5)];

	  // It does not, let's search in the entire headers
	  if (r1.location == NSNotFound)
	    {
	      r1 = [cleaned_message rangeOfCString: "\r\nBcc: "
					   options: 0
					     range: NSMakeRange(0,limit)];
	      if (r1.location != NSNotFound)
		r1.location += 2;
	    }

	  if (r1.location != NSNotFound)
	    {
	      // We search for the first \r\n AFTER the Bcc: header and
	      // replace the whole thing with \r\n.
	      unsigned int i;

	      for (i = r1.location+7; i < limit; i++)
		{
		  if ([cleaned_message characterAtIndex: i] == '\r' &&
		      (i+1 < limit && [cleaned_message characterAtIndex: i+1] == '\n') &&
		      (i+2 < limit && !isspace([cleaned_message characterAtIndex: i+2])))
		    break;
		}

	      [cleaned_message replaceBytesInRange: NSMakeRange(r1.location, i-r1.location+2)
					 withBytes: NULL
					    length: 0];
	    }

	  if ([mailingMechanism isEqualToString: @"sendmail"])
	    result = [self _sendmailSendData: cleaned_message
			   toRecipients: recipients
			   sender: [sender pureEMailAddress]];
	  else
	    result = [self _smtpSendData: cleaned_message
                            toRecipients: recipients
                                  sender: [sender pureEMailAddress]
                       withAuthenticator: authenticator
                               inContext: woContext 
                           systemMessage: isSystemMessage];
	}
    }

  return result;
}

- (NSException *) sendMimePart: (id <NGMimePart>) part
		  toRecipients: (NSArray *) recipients
			sender: (NSString *) sender
             withAuthenticator: (id <SOGoAuthenticator>) authenticator
                     inContext: (WOContext *) woContext
                 systemMessage: (BOOL) isSystemMessage
{
  NSData *mailData;

  mailData = [[NGMimePartGenerator mimePartGenerator]
	       generateMimeFromPart: part];

  return [self sendMailData: mailData
	       toRecipients: recipients
                     sender: sender
          withAuthenticator: authenticator
                  inContext: woContext
              systemMessage: isSystemMessage];
}

- (NSException *) sendMailAtPath: (NSString *) filename
		    toRecipients: (NSArray *) recipients
			  sender: (NSString *) sender
               withAuthenticator: (id <SOGoAuthenticator>) authenticator
                       inContext: (WOContext *) woContext
                   systemMessage: (BOOL) isSystemMessage
{
  NSException *result;
  NSData *mailData;

  mailData = [NSData dataWithContentsOfFile: filename];
  if ([mailData length] > 0)
    result = [self sendMailData: mailData
		   toRecipients: recipients
                         sender: sender
              withAuthenticator: authenticator
                      inContext: woContext
                  systemMessage: isSystemMessage];
  else
    result = [NSException exceptionWithHTTPStatus: 500
			  reason: @"cannot send message: no data"
			  @" (missing or empty file?)"];

  return result;
}

@end
