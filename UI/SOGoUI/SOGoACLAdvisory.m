/* SOGoACLAdvisory.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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

#import <Foundation/NSURL.h>

#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NGHashMap.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeMultipartBody.h>

#import <SoObjects/SOGo/SOGoMailer.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoObject.h>
#import <SoObjects/SOGo/LDAPUserManager.h>
#import <SoObjects/SOGo/NSCalendarDate+SOGo.h>
#import <SoObjects/SOGo/NSString+Utilities.h>

#import "SOGoACLAdvisory.h"

@implementation SOGoACLAdvisory

- (id) init
{
  if ((self = [super init]))
    {
      aclObject = nil;
      recipientUID = nil;

      isSubject = NO;
      isBody = NO;
    }

  return self;
}

- (void) dealloc
{
  [recipientUID release];
  [aclObject release];
  [super dealloc];
}

- (void) setACLObject: (SOGoObject *) newACLObject
{
  ASSIGN (aclObject, newACLObject);
}

- (void) setRecipientUID: (NSString *) newRecipientUID
{
  ASSIGN (recipientUID, newRecipientUID);
}

- (BOOL) isSubject
{
  return isSubject;
}

- (BOOL) isBody
{
  return isBody;
}

- (NSString *) currentUserName
{
  return [[context activeUser] cn];
}

- (NSString *) httpAdvisoryURL
{
  NSMutableString *url;

#warning the url returned by SOGoMail may be empty, we need to handle that
  url
    = [NSMutableString stringWithString:
			 [aclObject httpURLForAdvisoryToUser: recipientUID]];
  if (![url hasSuffix: @"/"])
    [url appendString: @"/"];

  return url;
}

- (NSString *) httpFolderURL
{
  NSString *absoluteString;
  NSMutableString *url;

#warning the url returned by SOGoMail may be empty, we need to handle that
  absoluteString = [[aclObject soURL] absoluteString];
  url = [NSMutableString stringWithString: absoluteString];

  if (![url hasSuffix: @"/"])
    [url appendString: @"/"];

  return url;
}

- (NSString *) resourceName
{
  return [aclObject nameInContainer];
}

- (NSString *) subject
{
  NSString *subject;

  isSubject = YES;
  subject = [[self generateResponse] contentAsString];
  isSubject = NO;

  return [[subject stringByTrimmingSpaces] asQPSubjectString: @"utf-8"];
}

- (NSString *) body
{
  NSString *body;

  isBody = YES;
  body = [[self generateResponse] contentAsString];
  isBody = NO;

  return [body stringByTrimmingSpaces];
}

- (NSString *) aclMethod
{
  [self subclassResponsibility: _cmd];
  
  return nil;
}

- (NGMimeBodyPart *) _textPart
{
  NGMutableHashMap *headerMap;
  NGMimeBodyPart *part;
  NSData *body;

  headerMap = [NGMutableHashMap hashMapWithCapacity: 1];
  [headerMap setObject: @"text/plain; charset=utf-8" forKey: @"content-type"];

  part = [NGMimeBodyPart bodyPartWithHeader: headerMap];
  body = [[self body] dataUsingEncoding: NSUTF8StringEncoding];
  [part setBody: [self body]];

  return part;
}

- (NGMimeBodyPart *) _sogoNotificationPart
{
  NGMutableHashMap *headerMap;
  NGMimeBodyPart *part;
  NSData *body;

  /* calendar part */
  headerMap = [NGMutableHashMap hashMapWithCapacity: 1];
  [headerMap setObject: [NSString stringWithFormat:
				    @"%@; method=%@; type=%@; charset=%@",
				  @"application/x-sogo-notification",
				  [self aclMethod], [aclObject folderType],
				  @"utf-8"]
	     forKey: @"content-type"];

  part = [NGMimeBodyPart bodyPartWithHeader: headerMap];
  body = [[aclObject resourceURLForAdvisoryToUser: recipientUID]
	   dataUsingEncoding: NSUTF8StringEncoding];
  [part setBody: body];

  return part;
}

- (void) send
{
  NSString *recipient, *date;
  NGMutableHashMap *headerMap;
  NGMimeMessage *message;
  NGMimeMultipartBody *body;
  SOGoUser *activeUser;
  NSDictionary *identity;
  NSString *from, *fullMail;

  activeUser = [context activeUser];
  identity = [activeUser primaryIdentity];
  from = [identity objectForKey: @"email"];
  fullMail = [NSString stringWithFormat: @"%@ <%@>",
		       [identity objectForKey: @"fullName"], from];

  recipient = [[LDAPUserManager sharedUserManager]
		getFullEmailForUID: recipientUID];

  headerMap = [NGMutableHashMap hashMapWithCapacity: 5];
  [headerMap setObject: @"multipart/alternative" forKey: @"content-type"];
  [headerMap setObject: fullMail forKey: @"From"];
  [headerMap setObject: recipient forKey: @"To"];
  date = [[NSCalendarDate date] rfc822DateString];
  [headerMap setObject: date forKey: @"Date"];
  [headerMap setObject: [self subject] forKey: @"Subject"];
  message = [NGMimeMessage messageWithHeader: headerMap];

  body = [[NGMimeMultipartBody alloc] initWithPart: message];
  [body addBodyPart: [self _textPart]];
  [body addBodyPart: [self _sogoNotificationPart]];
  [message setBody: body];
  [body release];

  [[SOGoMailer sharedMailer] sendMimePart: message
			     toRecipients: [NSArray arrayWithObject: recipient]
			     sender: from];
}

@end

@implementation SOGoACLAdditionAdvisory

- (NSString *) aclMethod { return @"add"; }

@end

@implementation SOGoACLRemovalAdvisory

- (NSString *) aclMethod { return @"remove"; }

@end

@implementation SOGoACLModificationAdvisory

- (NSString *) aclMethod { return @"modify"; }

@end

@implementation SOGoACLEnglishAdditionAdvisory
@end

@implementation SOGoACLFrenchAdditionAdvisory
@end

@implementation SOGoACLGermanAdditionAdvisory
@end

@implementation SOGoACLItalianAdditionAdvisory
@end

@implementation SOGoACLEnglishModificationAdvisory
@end

@implementation SOGoACLFrenchModificationAdvisory
@end

@implementation SOGoACLGermanModificationAdvisory
@end

@implementation SOGoACLItalianModificationAdvisory
@end

@implementation SOGoACLEnglishRemovalAdvisory
@end

@implementation SOGoACLFrenchRemovalAdvisory
@end

@implementation SOGoACLGermanRemovalAdvisory
@end

@implementation SOGoACLItalianRemovalAdvisory
@end

