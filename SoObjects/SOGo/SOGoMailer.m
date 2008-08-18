/* SOGoMailer.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2008 Inverse groupe conseil
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
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGMail/NGSendMail.h>
#import <NGMail/NGSmtpClient.h>
#import <NGMime/NGMimePartGenerator.h>

#import "NSString+Utilities.h"
#import "SOGoMailer.h"

#define defaultMailingMechanism @"sendmail"
#define defaultSMTPServer @"localhost"

@implementation SOGoMailer

+ (id) sharedMailer
{
  static id sharedMailer = nil;

  if (!sharedMailer)
    sharedMailer = [self new];

  return sharedMailer;
}

- (id) init
{
  NSUserDefaults *ud;

  if ((self = [super init]))
    {
      ud = [NSUserDefaults standardUserDefaults];
      mailingMechanism = [ud stringForKey: @"SOGoMailingMechanism"];
      if (mailingMechanism)
	{
	  if (!([mailingMechanism isEqualToString: @"sendmail"]
		|| [mailingMechanism isEqualToString: @"smtp"]))
	    {
	      [self logWithFormat: @"mechanism '%@' is invalid and"
		    @" should be set to 'sendmail' or 'smtp' instead",
		    mailingMechanism];
	      [self logWithFormat: @"falling back to default '%@' mechanism",
		    defaultMailingMechanism];
	      mailingMechanism = defaultMailingMechanism;
	    }
	}
      else
	{
	  [self logWithFormat: @"default mailing mechanism set to '%@'",
		defaultMailingMechanism];
	  mailingMechanism = defaultMailingMechanism;
	}
      [mailingMechanism retain];

      if ([mailingMechanism isEqualToString: @"smtp"])
	{
	  smtpServer = [ud stringForKey: @"SOGoSMTPServer"];
	  if (!smtpServer)
	    {
	      [self logWithFormat: @"default smtp server set to '%@'",
		    defaultSMTPServer];
	      smtpServer = defaultSMTPServer;
	    }
	  [smtpServer retain];
	}
      else
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
      if ([client hello]
	  && [client mailFrom: sender])
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
