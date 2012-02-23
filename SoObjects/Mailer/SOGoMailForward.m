/* SOGoMailForward.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse inc.
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

#import <Foundation/NSDictionary.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSString+misc.h>

#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "SOGoMailAccount.h"
#import "SOGoMailObject+Draft.h"
#import "SOGoMailForward.h"

@implementation SOGoMailForward

- (id) init
{
  SOGoUserDefaults *ud;

  if ((self = [super init]))
    {
      ud = [[context activeUser] userDefaults];
      htmlComposition
        = [[ud mailComposeMessageType] isEqualToString: @"html"];
      sourceMail = nil;
      currentValue = nil;
    }

  return self;
}

- (void) dealloc
{
  [sourceMail release];
  [currentValue release];
  [super dealloc];
}

- (void) setSourceMail: (SOGoMailObject *) newSourceMail
{
  ASSIGN (sourceMail, newSourceMail);
}

- (NSString *) newLine
{
  NSString *rc = [NSString stringWithString: @" "];
  
  if (htmlComposition)
    rc = [NSString stringWithString: @"<br/>"];

  return rc;
}

- (NSString *) subject
{
  return [sourceMail decodedSubject];
}

- (NSString *) date
{
  SOGoDateFormatter *formatter;

  formatter = [[context activeUser] dateFormatterInContext: context];

  return [formatter formattedDateAndTime: [sourceMail date]];
}

- (NSString *) from
{
  NSString *rc;

  if (htmlComposition)
    rc = [[[sourceMail mailHeaders] objectForKey: @"from"]
           stringByEscapingHTMLString];
  else
    rc = [[sourceMail mailHeaders] objectForKey: @"from"];

  return rc;
}

- (NSString *) _headerField: (NSString *) fieldName
{
  if (![field isEqualToString: fieldName])
    {
      [currentValue release];
      currentValue = [[sourceMail mailHeaders] objectForKey: fieldName];
      [currentValue retain];
    }

  return currentValue;
}

- (BOOL) hasReplyTo
{
  return ([[self _headerField: @"reply-to"] length] > 0);
}

- (NSString *) replyTo
{
  NSString *rc;

  if (htmlComposition)
    rc = [NSString stringWithFormat: @"%@<br/>", 
          [[self _headerField: @"reply-to"] stringByEscapingHTMLString]];
  else
    rc = ([NSString stringWithFormat: @"%@\n", [self _headerField: @"reply-to"]]);

  return rc;
}

- (BOOL) hasOrganization
{
  return ([[self _headerField: @"organization"] length] > 0);
}

- (NSString *) organization
{
  NSString *rc;

  if (htmlComposition)
    rc = [NSString stringWithFormat: @"%@<br/>", [self _headerField: @"organization"]];
  else
    rc = [NSString stringWithFormat: @"%@\n", [self _headerField: @"organization"]];

  return rc;
}

- (NSString *) to
{
  NSString *rc;

  if (htmlComposition)
    rc = [[[sourceMail mailHeaders] objectForKey: @"to"] stringByEscapingHTMLString];
  else
    rc = [[sourceMail mailHeaders] objectForKey: @"to"];

  return rc;
}

- (BOOL) hasCc
{
  return ([[self _headerField: @"cc"] length] > 0);
}

- (NSString *) cc
{
  NSString *rc;

  if (htmlComposition)
    rc = [NSString stringWithFormat: @"%@<br/>", 
          [[self _headerField: @"cc"] stringByEscapingHTMLString]];
  else
    rc = ([NSString stringWithFormat: @"%@\n", [self _headerField: @"cc"]]);

  return rc;
}

- (BOOL) hasNewsGroups
{
  return ([[self _headerField: @"newsgroups"] length] > 0);
}

- (NSString *) newsgroups
{
  NSString *rc;

  if (htmlComposition)
    rc = [NSString stringWithFormat: @"%@<br/>", [self _headerField: @"newsgroups"]];
  else
    rc = [NSString stringWithFormat: @"%@\n", [self _headerField: @"newsgroups"]];

  return rc;
}

- (BOOL) hasReferences
{
  return ([[self _headerField: @"references"] length] > 0);
}

- (NSString *) references
{
  NSString *rc;

  if (htmlComposition)
    rc = [NSString stringWithFormat: @"%@<br/>", [self _headerField: @"references"]];
  else
    rc = [NSString stringWithFormat: @"%@\n", [self _headerField: @"references"]];

  return rc;
}

- (NSString *) messageBody
{
  return [sourceMail contentForEditing];
}

- (NSString *) signature
{
  NSString *signature, *mailSignature;

  signature = [[sourceMail mailAccountFolder] signature];
  if ([signature length])
    mailSignature = [NSString stringWithFormat: @"-- \n%@", signature];
  else
    mailSignature = @"";

  return mailSignature;
}

@end

@implementation SOGoMailBrazilianPortugueseForward
@end

@implementation SOGoMailCatalanForward
@end

@implementation SOGoMailCzechForward
@end

@implementation SOGoMailDanishForward
@end

@implementation SOGoMailDutchForward
@end

@implementation SOGoMailEnglishForward
@end

@implementation SOGoMailFrenchForward
@end

@implementation SOGoMailGermanForward
@end

@implementation SOGoMailHungarianForward
@end

@implementation SOGoMailIcelandicForward
@end

@implementation SOGoMailItalianForward
@end

@implementation SOGoMailNorwegianBokmalForward
@end

@implementation SOGoMailNorwegianNynorskForward
@end

@implementation SOGoMailSpanishSpainForward
@end

@implementation SOGoMailSpanishArgentinaForward
@end

@implementation SOGoMailSwedishForward
@end

@implementation SOGoMailPolishForward
@end

@implementation SOGoMailRussianForward
@end

@implementation SOGoMailUkrainianForward
@end

@implementation SOGoMailWelshForward
@end
