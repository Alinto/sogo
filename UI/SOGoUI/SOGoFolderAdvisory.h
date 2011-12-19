/* SOGoFolderAdvisory.h - this file is part of SOGo
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

#ifndef SOGOFOLDERADVISORY_H
#define SOGOFOLDERADVISORY_H

#import "UIxComponent.h"
#import <SOGo/SOGoFolder.h>

@interface SOGoFolderAdvisory : UIxComponent
{
  NSString *recipientUID;
  SOGoFolder *folderObject;
  BOOL isSubject;
  BOOL isBody;
}

- (void) setFolderObject: (SOGoFolder *) theFolder;
- (void) setRecipientUID: (NSString *) newRecipientUID;
- (void) send;

- (BOOL) isSubject;
- (BOOL) isBody;

- (NSString *) subject;
- (NSString *) body;
- (NSString *) folderMethod;

@end

@interface SOGoFolderAdditionAdvisory : SOGoFolderAdvisory
@end

@interface SOGoFolderRemovalAdvisory : SOGoFolderAdvisory
@end

@interface SOGoFolderBrazilianPortugueseAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderBrazilianPortugueseRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderCzechAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderCzechRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderDanishAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderDanishRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderDutchAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderDutchRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderEnglishAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderEnglishRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderFrenchAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderFrenchRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderGermanAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderGermanRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderHungarianAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderHungarianRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderIcelandicAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderIcelandicRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderItalianAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderItalianRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderNorwegianBokmalAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderNorwegianBokmalRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderNorwegianNynorskAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderNorwegianNynorskRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderPolishAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderPolishRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderRussianAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderRussianRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderSpanishSpainAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderSpanishSpainRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderSpanishArgentinaAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderSpanishArgentinaRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

@interface SOGoFolderSwedishAdditionAdvisory : SOGoFolderAdditionAdvisory
@end

@interface SOGoFolderSwedishRemovalAdvisory : SOGoFolderRemovalAdvisory
@end

#endif /* SOGOFOLDERADVISORY_H */
