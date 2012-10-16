/* SOGoMailer.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGMail/NGSendMail.h>
#import <NGMail/NGSmtpClient.h>
#import <NGMime/NGMimePartGenerator.h>
#import <NGStreams/NGInternetSocketAddress.h>

#import "NSString+Utilities.h"
#import "SOGoAuthenticator.h"
#import "SOGoDomainDefaults.h"
#import "SOGoSystemDefaults.h"
#import "SOGoUser.h"

#import "SOGoMailer.h"

@implementation SOGoMailer

+ (SOGoMailer *) mailerWithDomainDefaults: (SOGoDomainDefaults *) dd
{
  return [[self alloc] initWithDomainDefaults: dd];
}

- (id) initWithDomainDefaults: (SOGoDomainDefaults *) dd
{
  if ((self = [self init]))
    {
      ASSIGN (mailingMechanism, [dd mailingMechanism]);
      ASSIGN (smtpServer, [dd smtpServer]);
      ASSIGN (authenticationType,
              [[dd smtpAuthenticationType] lowercaseString]);
    }

  return self;
}

- (id) init
{
  if ((self = [super init]))
    {
      mailingMechanism = nil;
      smtpServer = nil;
      authenticationType = nil;
    }

  return self;
}

- (void) dealloc
{
  [mailingMechanism release];
  [smtpServer release];
  [authenticationType release];
  [super dealloc];
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
{
  NGInternetSocketAddress *addr;
  NSString *currentTo, *host, *login, *password;
  NSMutableArray *toErrors;
  NSEnumerator *addresses; 
  NGSmtpClient *client;
  NSException *result = nil;
  NSRange r;
  unsigned int port;

  client = [NGSmtpClient smtpClient];
  host = smtpServer;
  port = 25;

  // We check if there is a port specified in the smtpServer ivar value
  r = [smtpServer rangeOfString: @":"];
  
  if (r.length)
    {
      port = [[smtpServer substringFromIndex: r.location+1] intValue];
      host = [smtpServer substringToIndex: r.location];
    }

  addr = [NGInternetSocketAddress addressWithPort: port
				  onHost: host];

  NS_DURING
    {
      [client connectToAddress: addr];
      if ([authenticationType isEqualToString: @"plain"])
        {
          login = [[authenticator userInContext: woContext] login];
          password = [authenticator passwordInContext: woContext];
          if ([login length] == 0
              || [login isEqualToString: @"anonymous"]
              || ![client plainAuthenticateUser: login
                                   withPassword: password])
            result = [NSException
                           exceptionWithHTTPStatus: 500
                                            reason: @"cannot send message:"
                       @" (smtp) authentication failure"];
        }
      else if (authenticationType)
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
            result = [NSException
                       exceptionWithHTTPStatus: 500
                                        reason: @"cannot send message: (smtp) originator not accepted"];
        }
      [client quit];
      [client disconnect];
    }
  NS_HANDLER
    {
      NSLog(@"Could not connect to the SMTP server %@ on port %d", host, port);
      result = [NSException exceptionWithHTTPStatus: 500
					     reason: @"cannot send message:"
			    @" (smtp) error when connecting"];
    }
  NS_ENDHANDLER;

  return result;
}

- (NSException *) sendMailData: (NSData *) data
		  toRecipients: (NSArray *) recipients
			sender: (NSString *) sender
             withAuthenticator: (id <SOGoAuthenticator>) authenticator
                     inContext: (WOContext *) woContext
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
	  if ([mailingMechanism isEqualToString: @"sendmail"])
	    result = [self _sendmailSendData: data
			   toRecipients: recipients
			   sender: [sender pureEMailAddress]];
	  else
	    result = [self _smtpSendData: data
                            toRecipients: recipients
                                  sender: [sender pureEMailAddress]
                       withAuthenticator: authenticator
                               inContext: woContext];
	}
    }

  return result;
}

- (NSException *) sendMimePart: (id <NGMimePart>) part
		  toRecipients: (NSArray *) recipients
			sender: (NSString *) sender
             withAuthenticator: (id <SOGoAuthenticator>) authenticator
                     inContext: (WOContext *) woContext
{
  NSData *mailData;

  mailData = [[NGMimePartGenerator mimePartGenerator]
	       generateMimeFromPart: part];

  return [self sendMailData: mailData
	       toRecipients: recipients
                     sender: sender
          withAuthenticator: authenticator
                  inContext: woContext];
}

- (NSException *) sendMailAtPath: (NSString *) filename
		    toRecipients: (NSArray *) recipients
			  sender: (NSString *) sender
               withAuthenticator: (id <SOGoAuthenticator>) authenticator
                       inContext: (WOContext *) woContext
{
  NSException *result;
  NSData *mailData;

  mailData = [NSData dataWithContentsOfFile: filename];
  if ([mailData length] > 0)
    result = [self sendMailData: mailData
		   toRecipients: recipients
                         sender: sender
              withAuthenticator: authenticator
                      inContext: woContext];
  else
    result = [NSException exceptionWithHTTPStatus: 500
			  reason: @"cannot send message: no data"
			  @" (missing or empty file?)"];

  return result;
}

@end
