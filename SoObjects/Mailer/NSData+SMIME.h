/* NSData+SMIME.h - this file is part of SOGo
 *
 * Copyright (C) 2017-2018 Inverse inc.
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

#ifndef NSDATA_SMIME_H
#define NSDATA_SMIME_H

#import <Foundation/NSData.h>

#import <NGMail/NGMimeMessage.h>

@interface NSData (SOGoMailSMIME)

- (NSData *) signUsingCertificateAndKey: (NSData *) theData;
- (NSData *) encryptUsingCertificate: (NSData *) theData;
- (NSData *) decryptUsingCertificate: (NSData *) theData;
- (NGMimeMessage *) messageFromEncryptedDataAndCertificate: (NSData *) theCertificate;
- (NSData *) embeddedContent;
- (NGMimeMessage *) messageFromOpaqueSignedData;
- (NSData *) convertPKCS12ToPEMUsingPassword: (NSString *) thePassword;
- (NSData *) signersFromPKCS7;
- (NSDictionary *) certificateDescription;

@end

#endif /* NSDATA_SMIME_H */
