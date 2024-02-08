/* SOGoMailer.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2014 Inverse inc.
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

#ifndef SOGOMAILER_H
#define SOGOMAILER_H


@class NSArray;
@class NSException;
@class NSString;

@class WOContext;
@class SOGoDomainDefaults;

@protocol NGMimePart;
@protocol SOGoAuthenticator;

@interface SOGoMailer : NSObject
{
  NSString *mailingMechanism;
  NSString *smtpServer;
  BOOL *smtpMasterUserEnabled;
  NSString *smtpMasterUserUsername;
  NSString *smtpMasterUserPassword;
  NSString *authenticationType;
  NSString* userIdAccount;
}

+ (SOGoMailer *) mailerWithDomainDefaults: (SOGoDomainDefaults *) dd;
+ (SOGoMailer *) mailerWithDomainDefaultsAndSmtpUrl: (SOGoDomainDefaults *) dd
                                            smtpUrl: (NSURL *) smtpUrl
                                            userIdAccount: (NSString *) userIdAccount;


- (id) initWithDomainDefaults: (SOGoDomainDefaults *) dd;
- (BOOL) requiresAuthentication;
- (NSException *)sendMailData:(NSData *)data
                 toRecipients:(NSArray *)recipients
                       sender:(NSString *)sender
            withAuthenticator:(id<SOGoAuthenticator>)authenticator
                    inContext:(WOContext *)woContext
                systemMessage:(BOOL)isSystemMessage;
- (NSException *)sendMailAtPath:(NSString *)filename
                   toRecipients:(NSArray *)recipients
                         sender:(NSString *)sender
              withAuthenticator:(id<SOGoAuthenticator>)authenticator
                      inContext:(WOContext *)woContext
                  systemMessage:(BOOL)isSystemMessage;
- (NSException *)sendMimePart:(id<NGMimePart>)part
                 toRecipients:(NSArray *)recipients
                       sender:(NSString *)sender
            withAuthenticator:(id<SOGoAuthenticator>)authenticator
                    inContext:(WOContext *)woContext
                systemMessage:(BOOL)isSystemMessage;

@end

#endif /* SOGOMAILER_H */
