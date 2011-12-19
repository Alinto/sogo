/* SOGoMailReply.m - this file is part of SOGo
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

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSString+misc.h>
#import <NGImap4/NGImap4Envelope.h>

#import <SoObjects/SOGo/SOGoDateFormatter.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import "SOGoMailObject+Draft.h"
#import "SOGoMailReply.h"

@implementation SOGoMailReply

- (id) init
{
  if ((self = [super init]))
    {
      outlookMode = NO;
    }

  return self;
}

- (void) setOutlookMode: (BOOL) newOutlookMode
{
  outlookMode = newOutlookMode;
}

- (BOOL) outlookMode
{
  return outlookMode;
}

- (void) setReplyPlacement: (NSString *) newPlacement
{
  replyPlacement = newPlacement;
}

- (BOOL) replyPlacementOnTop
{
  return [replyPlacement isEqual: @"above"];
}

- (void) setSignaturePlacement: (NSString *) newPlacement
{
  signaturePlacement = newPlacement;
}

- (BOOL) signaturePlacementOnTop
{
  return [signaturePlacement isEqual: @"above"];
}

- (NSString *) messageBody
{
  NSString *s, *msgid;
  NSRange r;
  
  s = [sourceMail contentForEditing];

  if (s)
    {
      if (htmlComposition)
        {
          msgid = [[sourceMail envelope] messageID];
          r = NSMakeRange (1, [msgid length] - 2);
          msgid = [msgid substringWithRange: r];
          s = [NSString stringWithFormat: 
               @"<blockquote type=\"cite\" cite=\"%@\">%@</blockquote>", 
               msgid, s];
        }
      else
        {
          s = [s stringByApplyingMailQuoting]; //adds "> " on each line
        }
    }

  return s;
}

@end

@implementation SOGoMailBrazilianPortugueseReply
@end

@implementation SOGoMailCatalanReply
@end

@implementation SOGoMailCzechReply
@end

@implementation SOGoMailDanishReply
@end

@implementation SOGoMailDutchReply
@end

@implementation SOGoMailEnglishReply
@end

@implementation SOGoMailFrenchReply
@end

@implementation SOGoMailGermanReply
@end

@implementation SOGoMailHungarianReply
@end

@implementation SOGoMailIcelandicReply
@end

@implementation SOGoMailItalianReply
@end

@implementation SOGoMailNorwegianBokmalReply
@end

@implementation SOGoMailNorwegianNynorskReply
@end

@implementation SOGoMailSpanishSpainReply
@end

@implementation SOGoMailSpanishArgentinaReply
@end

@implementation SOGoMailSwedishReply
@end

@implementation SOGoMailPolishReply
@end

@implementation SOGoMailRussianReply
@end

@implementation SOGoMailUkrainianReply
@end

@implementation SOGoMailWelshReply
@end
