/* SOGoMailReply.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2015 Inverse inc.
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
}

- (void) setOutlookMode: (BOOL) newOutlookMode;
- (BOOL) outlookMode;
- (void) setReplyPlacement: (NSString *) newPlacement;
- (BOOL) replyPlacementOnTop;
- (NSString *) messageBody;

@end

@interface SOGoMailArabicReply : SOGoMailReply
@end

@interface SOGoMailBosnianReply : SOGoMailReply
@end

@interface SOGoMailBrazilianPortugueseReply : SOGoMailReply
@end

@interface SOGoMailBulgarianReply : SOGoMailReply
@end

@interface SOGoMailCatalanReply : SOGoMailReply
@end

@interface SOGoMailChineseChinaReply : SOGoMailReply
@end

@interface SOGoMailChineseTaiwanReply : SOGoMailReply
@end

@interface SOGoMailCroatianReply : SOGoMailReply
@end

@interface SOGoMailCzechReply : SOGoMailReply
@end

@interface SOGoMailDanishReply : SOGoMailReply
@end

@interface SOGoMailDutchReply : SOGoMailReply
@end

@interface SOGoMailEnglishReply : SOGoMailReply
@end

@interface SOGoMailFinnishReply : SOGoMailReply
@end

@interface SOGoMailFrenchReply : SOGoMailReply
@end

@interface SOGoMailGermanReply : SOGoMailReply
@end

@interface SOGoMailHebrewReply : SOGoMailReply
@end

@interface SOGoMailHungarianReply : SOGoMailReply
@end

@interface SOGoMailIndonesianReply : SOGoMailReply
@end

@interface SOGoMailIcelandicReply : SOGoMailReply
@end

@interface SOGoMailItalianReply : SOGoMailReply
@end

@interface SOGoMailJapaneseReply : SOGoMailReply
@end

@interface SOGoMailKazakhReply : SOGoMailReply
@end

@interface SOGoMailLatvianReply : SOGoMailReply
@end

@interface SOGoMailLithuanianReply : SOGoMailReply
@end

@interface SOGoMailMacedonianReply : SOGoMailReply
@end

@interface SOGoMailMontenegrinReply : SOGoMailReply
@end

@interface SOGoMailNorwegianBokmalReply : SOGoMailReply
@end

@interface SOGoMailNorwegianNynorskReply : SOGoMailReply
@end

@interface SOGoMailPolishReply : SOGoMailReply
@end

@interface SOGoMailPortugueseReply : SOGoMailReply
@end

@interface SOGoMailRomanianReply : SOGoMailReply
@end

@interface SOGoMailRussianReply : SOGoMailReply
@end

@interface SOGoMailSerbianReply : SOGoMailReply
@end

@interface SOGoMailSerbianLatinReply : SOGoMailReply
@end

@interface SOGoMailSlovakReply : SOGoMailReply
@end

@interface SOGoMailSlovenianReply : SOGoMailReply
@end

@interface SOGoMailSpanishSpainReply : SOGoMailReply
@end

@interface SOGoMailSpanishArgentinaReply : SOGoMailReply
@end

@interface SOGoMailSwedishReply : SOGoMailReply
@end

@interface SOGoMailTurkishTurkeyReply : SOGoMailReply
@end

@interface SOGoMailUkrainianReply : SOGoMailReply
@end

@interface SOGoMailWelshReply : SOGoMailReply
@end

#endif /* SOGOMAILREPLY_H */
