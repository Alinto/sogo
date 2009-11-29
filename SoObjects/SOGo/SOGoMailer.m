/* SOGoMailer.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2009 Inverse inc.
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

#import "NSString+Utilities.h"
#import "SOGoDomainDefaults.h"
#import "SOGoSystemDefaults.h"

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
    }

  return self;
}

- (id) init
{
  if ((self = [super init]))
    {
      mailingMechanism = nil;
      smtpServer = nil;
    }

  return self;
}

- (void) dealloc
{
  [mailingMechanism release];
  [smtpServer release];
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
		  andRejections: (unsigned int) toErrors
{
  NSException *result;

  if (toErrors > 0)
    [self logWithFormat: @"sending email despite address rejections"];
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
{
  NGSmtpClient *client;
  NSEnumerator *addresses;
  NSString *currentTo;
  unsigned int toErrors;
  NSException *result;

  client = [NGSmtpClient smtpClient];
  if ([client connectToHost: smtpServer])
    {
      if ([client mailFrom: sender])
	{
	  toErrors = 0;
	  addresses = [recipients objectEnumerator];
	  currentTo = [addresses nextObject];
	  while (currentTo)
	    {
	      if (![client recipientTo: [currentTo pureEMailAddress]])
		{
		  [self logWithFormat: @"error with recipient '%@'", currentTo];
		  toErrors++;
		}
	      currentTo = [addresses nextObject];
	    }
	  if (toErrors == [recipients count])
	    result = [NSException exceptionWithHTTPStatus: 500
				  reason: @"cannot send message:"
				  @" (smtp) all recipients discarded"];
	  else
	    result = [self _sendMailData: mailData withClient: client
			   andRejections: toErrors];
	}
      else
	result = [NSException exceptionWithHTTPStatus: 500
			      reason: @"cannot send message:"
			      @" (smtp) error when connecting"];
      [client quit];
      [client disconnect];
    }

  return result;
}

- (NSException *) sendMailData: (NSData *) data
		  toRecipients: (NSArray *) recipients
			sender: (NSString *) sender
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
			   sender: [sender pureEMailAddress]];
	}
    }

  return result;
}

- (NSException *) sendMimePart: (id <NGMimePart>) part
		  toRecipients: (NSArray *) recipients
			sender: (NSString *) sender
{
  NSData *mailData;

  mailData = [[NGMimePartGenerator mimePartGenerator]
	       generateMimeFromPart: part];

  return [self sendMailData: mailData
	       toRecipients: recipients
	       sender: sender];
}

- (NSException *) sendMailAtPath: (NSString *) filename
		    toRecipients: (NSArray *) recipients
			  sender: (NSString *) sender
{
  NSException *result;
  NSData *mailData;

  mailData = [NSData dataWithContentsOfFile: filename];
  if ([mailData length] > 0)
    result = [self sendMailData: mailData
		   toRecipients: recipients
		   sender: sender];
  else
    result = [NSException exceptionWithHTTPStatus: 500
			  reason: @"cannot send message: no data"
			  @" (missing or empty file?)"];

  return nil;
}

@end
