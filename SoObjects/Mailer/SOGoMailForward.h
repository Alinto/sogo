/* SOGoMailForward.h - this file is part of SOGo
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

#ifndef SOGOMAILFORWARD_H
#define SOGOMAILFORWARD_H

#import <NGObjWeb/SoComponent.h>

@class SOGoMailObject;

@interface SOGoMailForward : SoComponent
{
  SOGoMailObject *sourceMail;
  NSString *field;
  NSString *currentValue;
  BOOL htmlComposition;
  NSString *signaturePlacement;
}

- (void) setSourceMail: (SOGoMailObject *) newSourceMail;
- (void) setSignaturePlacement: (NSString *) newPlacement;
- (BOOL) signaturePlacementOnTop;

@end

@interface SOGoMailArabicForward : SOGoMailForward
@end

@interface SOGoMailBrazilianPortugueseForward : SOGoMailForward
@end

@interface SOGoMailCatalanForward : SOGoMailForward
@end

@interface SOGoMailChineseTaiwanForward : SOGoMailForward
@end

@interface SOGoMailCroatianForward : SOGoMailForward
@end

@interface SOGoMailCzechForward : SOGoMailForward
@end

@interface SOGoMailDanishForward : SOGoMailForward
@end

@interface SOGoMailDutchForward : SOGoMailForward
@end

@interface SOGoMailEnglishForward : SOGoMailForward
@end

@interface SOGoMailFinnishForward : SOGoMailForward
@end

@interface SOGoMailFrenchForward : SOGoMailForward
@end

@interface SOGoMailGermanForward : SOGoMailForward
@end

@interface SOGoMailHebrewForward : SOGoMailForward
@end

@interface SOGoMailHungarianForward : SOGoMailForward
@end

@interface SOGoMailIcelandicForward : SOGoMailForward
@end

@interface SOGoMailItalianForward : SOGoMailForward
@end

@interface SOGoMailLithuanianForward : SOGoMailForward
@end

@interface SOGoMailMacedonianForward : SOGoMailForward
@end

@interface SOGoMailNorwegianBokmalForward : SOGoMailForward
@end

@interface SOGoMailNorwegianNynorskForward : SOGoMailForward
@end

@interface SOGoMailPolishForward : SOGoMailForward
@end

@interface SOGoMailPortugueseForward : SOGoMailForward
@end

@interface SOGoMailRussianForward : SOGoMailForward
@end

@interface SOGoMailSerbianForward : SOGoMailForward
@end

@interface SOGoMailSlovakForward : SOGoMailForward
@end

@interface SOGoMailSlovenianForward : SOGoMailForward
@end

@interface SOGoMailSpanishSpainForward : SOGoMailForward
@end

@interface SOGoMailSpanishArgentinaForward : SOGoMailForward
@end

@interface SOGoMailSwedishForward : SOGoMailForward
@end

@interface SOGoMailTurkishTurkeyForward : SOGoMailForward
@end

@interface SOGoMailUkrainianForward : SOGoMailForward
@end

@interface SOGoMailWelshForward : SOGoMailForward
@end

#endif /* SOGOMAILFORWARD_H */
