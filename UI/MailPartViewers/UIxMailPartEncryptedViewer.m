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
  NSData *certificate; 
  id info, viewer;

  certificate = [[[self clientObject] mailAccountFolder] certificate];

  if (certificate)
    {
      NSData *decryptedData, *encryptedData;

      encryptedData = [[self clientObject] content];
      decryptedData = [encryptedData decryptUsingCertificate: certificate];

      if (decryptedData)
        {
          NGMimeMessageParser *parser;
          id part;

          parser = [[NGMimeMessageParser alloc] init];
          part = [[parser parsePartFromData: decryptedData] retain];

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
        }
    }

  // Decryption failed, let's return the master viewer
  // FIXME - does not work for now.
  info = [NSDictionary dictionaryWithObjectsAndKeys: @"multipart", @"type",
                       @"mixed", @"subtype", nil];
  [self setFlatContent: nil];
  viewer = [[[self context] mailRenderingContext] viewerForBodyInfo: info];
  [viewer setBodyInfo: info];

  return [viewer renderedPart];
}

@end /* UIxMailPartAlternativeViewer */
