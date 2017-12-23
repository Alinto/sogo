/*
  Copyright (C) 2017 Inverse inc.

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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSNull.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGMail/NGMimeMessageParser.h>

#import <SoObjects/Mailer/NSData+SMIME.h>
#import <UI/MailerUI/WOContext+UIxMailer.h>

#import "UIxMailRenderingContext.h"
#import "UIxMailPartEncryptedViewer.h"

@implementation UIxMailPartEncryptedViewer

/* nested viewers */

- (id) contentViewerComponent
{
  id info;

  info = [self childInfo];
  return [[[self context] mailRenderingContext] viewerForBodyInfo: info];
}

- (id) renderedPart
{
  id info, viewer;

  NSData *encryptedData;

#if 1
  NSData *pkcs12Data =  [NSData dataWithContentsOfFile: @"/home/sogo/dropbucket/lmarcotte@inverse.ca.p12"];
  [pkcs12Data convertPKCS12ToPEMUsingPassword: @"831af13d97576d74d574628c1d0e5abe"];
#endif
  
  
  encryptedData = [[self clientObject] content];
  [encryptedData writeToFile: @"/tmp/received.encrypted" atomically: 1];

  //NSData *pem = [NSData dataWithContentsOfFile: @"/home/sogo/dropbucket/lmarcotte@inverse.ca.pem"];
  NSData *pem = [NSData dataWithContentsOfFile: @"/tmp/foofoo.newpem"];
  NSData *decryptedData = [encryptedData decryptUsingCertificate: pem];

  NGMimeMessageParser *parser = [[NGMimeMessageParser alloc] init];
  id part = [[parser parsePartFromData: decryptedData] retain];

  info = [NSDictionary dictionaryWithObjectsAndKeys: [[part contentType] type], @"type",
                       [[part contentType] subType], @"subtype", nil];
  viewer = [[[self context] mailRenderingContext] viewerForBodyInfo: info];
  [viewer setBodyInfo: info];
  [viewer setFlatContent: decryptedData];
  [viewer setDecodedContent: [part body]];
  
  return [NSDictionary dictionaryWithObjectsAndKeys:
                         [self className], @"type",
                           [NSArray arrayWithObject: [viewer renderedPart]], @"content",
                       nil];
  //return [viewer renderedPart];
}

@end /* UIxMailPartAlternativeViewer */
