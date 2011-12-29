/* SOGoMailReply.h - this file is part of SOGo
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

#ifndef SOGOMAILREPLY_H
#define SOGOMAILREPLY_H

#import "SOGoMailForward.h"

@class SOGoMailObject;

@interface SOGoMailReply : SOGoMailForward
{
  BOOL outlookMode;
  NSString *replyPlacement;
  NSString *signaturePlacement;
}

- (void) setOutlookMode: (BOOL) newOutlookMode;
- (BOOL) outlookMode;
- (void) setReplyPlacement: (NSString *) newPlacement;
- (BOOL) replyPlacementOnTop;
- (void) setSignaturePlacement: (NSString *) newPlacement;
- (BOOL) signaturePlacementOnTop;
- (NSString *) messageBody;

@end

@interface SOGoMailBrazilianPortugueseReply : SOGoMailReply
@end

@interface SOGoMailCatalanReply : SOGoMailReply
@end

@interface SOGoMailCzechReply : SOGoMailReply
@end

@interface SOGoMailDanishReply : SOGoMailReply
@end

@interface SOGoMailDutchReply : SOGoMailReply
@end

@interface SOGoMailEnglishReply : SOGoMailReply
@end

@interface SOGoMailFrenchReply : SOGoMailReply
@end

@interface SOGoMailGermanReply : SOGoMailReply
@end

@interface SOGoMailHungarianReply : SOGoMailReply
@end

@interface SOGoMailIcelandicReply : SOGoMailReply
@end

@interface SOGoMailItalianReply : SOGoMailReply
@end

@interface SOGoMailNorwegianBokmalReply : SOGoMailReply
@end

@interface SOGoMailNorwegianNynorskReply : SOGoMailReply
@end

@interface SOGoMailSpanishSpainReply : SOGoMailReply
@end

@interface SOGoMailSpanishArgentinaReply : SOGoMailReply
@end

@interface SOGoMailSwedishReply : SOGoMailReply
@end

@interface SOGoMailPolishReply : SOGoMailReply
@end

@interface SOGoMailRussianReply : SOGoMailReply
@end

@interface SOGoMailUkrainianReply : SOGoMailReply
@end

@interface SOGoMailWelshReply : SOGoMailReply
@end

#endif /* SOGOMAILREPLY_H */
