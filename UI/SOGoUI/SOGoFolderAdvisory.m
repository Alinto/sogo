/* SOGoFolderAdvisory.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2010 Inverse inc.
 *
 * Author: Ludovic Marcotte <ludovic@inverse.ca>
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NGHashMap.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeMultipartBody.h>

#import <SoObjects/SOGo/SOGoMailer.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoObject.h>
#import <SoObjects/SOGo/SOGoUserManager.h>
#import <SoObjects/SOGo/NSCalendarDate+SOGo.h>
#import <SoObjects/SOGo/NSString+Utilities.h>

#import "SOGoFolderAdvisory.h"

@implementation SOGoFolderAdvisory

- (id) init
{
  if ((self = [super init]))
    {
      recipientUID = nil;
      folderObject = nil;
      isSubject = NO;
      isBody = NO;
    }

  return self;
}

- (void) dealloc
{
  [recipientUID release];
  [folderObject release];
  [super dealloc];
}

- (void) setFolderObject: (SOGoFolder *) theFolder
{
  ASSIGN(folderObject, theFolder);
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

- (NSString *) displayName
{
  return [folderObject displayName];
}

- (NSString *) httpFolderURL
{
  NSString *absoluteString;
  NSMutableString *url;

#warning the url returned by SOGoMail may be empty, we need to handle that
  absoluteString = [[folderObject soURL] absoluteString];
  url = [NSMutableString stringWithString: absoluteString];

  if (![url hasSuffix: @"/"])
    [url appendString: @"/"];

  return url;
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

- (NSString *) folderMethod
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
  [part setBody: body];

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
				  [self folderMethod], [folderObject folderType],
				  @"utf-8"]
	     forKey: @"content-type"];

  part = [NGMimeBodyPart bodyPartWithHeader: headerMap];
  body = [[self httpFolderURL] dataUsingEncoding: NSUTF8StringEncoding];
  [part setBody: body];

  return part;
}

- (void) send
{
  NSString *recipient, *date;
  NGMutableHashMap *headerMap;
  NGMimeMessage *message;
  NGMimeMultipartBody *body;
  SOGoDomainDefaults *dd;
  SOGoUser *activeUser;
  NSDictionary *identity;
  NSString *from, *fullMail;

  activeUser = [context activeUser];
  identity = [activeUser primaryIdentity];
  from = [identity objectForKey: @"email"];
  fullMail = [NSString stringWithFormat: @"%@ <%@>",
		       [identity objectForKey: @"fullName"], from];

  recipient = [[SOGoUserManager sharedUserManager]
		getFullEmailForUID: recipientUID];

#warning SOPE is just plain stupid here - if you change the case of keys, it will break the encoding of fields
  headerMap = [NGMutableHashMap hashMapWithCapacity: 5];
  [headerMap setObject: @"multipart/alternative" forKey: @"content-type"];
  [headerMap setObject: fullMail forKey: @"from"];
  [headerMap setObject: recipient forKey: @"to"];
  date = [[NSCalendarDate date] rfc822DateString];
  [headerMap setObject: date forKey: @"date"];
  [headerMap setObject: [self subject] forKey: @"subject"];
  message = [NGMimeMessage messageWithHeader: headerMap];

  body = [[NGMimeMultipartBody alloc] initWithPart: message];
  [body addBodyPart: [self _textPart]];
  [body addBodyPart: [self _sogoNotificationPart]];
  [message setBody: body];
  [body release];

  dd = [activeUser domainDefaults];
  [[SOGoMailer mailerWithDomainDefaults: dd]
           sendMimePart: message
           toRecipients: [NSArray arrayWithObject: recipient]
                 sender: from
      withAuthenticator: [self authenticatorInContext: context]
              inContext: context];
}

@end

@implementation SOGoFolderAdditionAdvisory

- (NSString *) folderMethod { return @"add"; }

@end

@implementation SOGoFolderRemovalAdvisory

- (NSString *) folderMethod { return @"remove"; }

@end

@implementation SOGoFolderBrazilianPortugueseAdditionAdvisory
@end

@implementation SOGoFolderBrazilianPortugueseRemovalAdvisory
@end

@implementation SOGoFolderCzechAdditionAdvisory
@end

@implementation SOGoFolderCzechRemovalAdvisory
@end

@implementation SOGoFolderDanishAdditionAdvisory
@end

@implementation SOGoFolderDanishRemovalAdvisory
@end

@implementation SOGoFolderDutchAdditionAdvisory
@end

@implementation SOGoFolderDutchRemovalAdvisory
@end

@implementation SOGoFolderEnglishAdditionAdvisory
@end

@implementation SOGoFolderEnglishRemovalAdvisory
@end

@implementation SOGoFolderFrenchAdditionAdvisory
@end

@implementation SOGoFolderFrenchRemovalAdvisory
@end

@implementation SOGoFolderGermanAdditionAdvisory
@end

@implementation SOGoFolderGermanRemovalAdvisory
@end

@implementation SOGoFolderHungarianAdditionAdvisory
@end

@implementation SOGoFolderHungarianRemovalAdvisory
@end

@implementation SOGoFolderIcelandicAdditionAdvisory
@end

@implementation SOGoFolderIcelandicRemovalAdvisory
@end

@implementation SOGoFolderItalianAdditionAdvisory
@end

@implementation SOGoFolderItalianRemovalAdvisory
@end

@implementation SOGoFolderNorwegianBokmalAdditionAdvisory
@end

@implementation SOGoFolderNorwegianBokmalRemovalAdvisory
@end

@implementation SOGoFolderNorwegianNynorskAdditionAdvisory
@end

@implementation SOGoFolderNorwegianNynorskRemovalAdvisory
@end

@implementation SOGoFolderPolishAdditionAdvisory
@end

@implementation SOGoFolderPolishRemovalAdvisory
@end

@implementation SOGoFolderRussianAdditionAdvisory
@end

@implementation SOGoFolderRussianRemovalAdvisory
@end

@implementation SOGoFolderSpanishSpainAdditionAdvisory
@end

@implementation SOGoFolderSpanishSpainRemovalAdvisory
@end

@implementation SOGoFolderSpanishArgentinaAdditionAdvisory
@end

@implementation SOGoFolderSpanishArgentinaRemovalAdvisory
@end

@implementation SOGoFolderSwedishAdditionAdvisory
@end

@implementation SOGoFolderSwedishRemovalAdvisory
@end
