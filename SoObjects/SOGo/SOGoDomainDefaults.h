/* SOGoDomainDefaults.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2019 Inverse inc.
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

#ifndef SOGODOMAINDEFAULTS_H
#define SOGODOMAINDEFAULTS_H

#import <SOGo/SOGoLDAPDefaults.h>
#import <SOGo/SOGoUserDefaults.h>

@interface SOGoDomainDefaults : SOGoUserDefaults <SOGoLDAPDefaults>

+ (SOGoDomainDefaults *) defaultsForDomain: (NSString *) domainId;

- (NSString *) profileURL;
- (NSString *) folderInfoURL;

- (NSArray *) superUsernames;

- (NSArray *) userSources;

- (BOOL) mailCustomFromEnabled;
- (BOOL) mailAuxiliaryUserAccountsEnabled;

- (NSString *) mailDomain;
- (NSString *) imapServer;
- (NSString *) sieveServer;
- (NSString *) imapCASServiceName;
- (NSString *) imapAclStyle;
- (NSString *) imapAclGroupIdPrefix;
- (BOOL) imapAclConformsToIMAPExt;
- (BOOL) forceExternalLoginWithEmail;
- (BOOL) externalAvatarsEnabled;
- (BOOL) sieveScriptsEnabled;
- (NSString *) sieveScriptHeaderTemplateFile;
- (NSString *) sieveScriptFooterTemplateFile;
- (BOOL) forwardEnabled;
- (int) forwardConstraints;
- (NSArray *) forwardConstraintsDomains;
- (BOOL) vacationEnabled;
- (BOOL) vacationPeriodEnabled;
- (NSString *) vacationDefaultSubject;
- (NSString *) vacationHeaderTemplateFile;
- (NSString *) vacationFooterTemplateFile;
- (NSString *) mailingMechanism;
- (NSString *) smtpServer;
- (NSString *) smtpAuthenticationType;
- (NSString *) mailSpoolPath;
- (float) softQuotaRatio;
- (BOOL) mailKeepDraftsAfterSend;
- (BOOL) mailAttachTextDocumentsInline;
- (NSArray *) mailListViewColumnsOrder;
- (BOOL) mailCertificateEnabled;

- (BOOL) aclSendEMailNotifications;
- (BOOL) appointmentSendEMailNotifications;
- (BOOL) foldersSendEMailNotifications;
- (NSArray *) calendarDefaultRoles;
- (NSArray *) contactsDefaultRoles;
- (NSArray *) refreshViewIntervals;
- (NSString *) subscriptionFolderFormat;

- (NSArray *) freeBusyDefaultInterval;
- (int) davCalendarStartTimeLimit;

- (BOOL) ldapGroupExpansionEnabled;

- (BOOL) iPhoneForceAllDayTransparency;

- (NSArray *) additionalJSFiles;

- (BOOL) hideSystemEMail;

- (int) searchMinimumWordLength;
- (BOOL) notifyOnPersonalModifications;
- (BOOL) notifyOnExternalModifications;

- (NSDictionary *) mailJunkSettings;

@end

#endif /* SOGODOMAINDEFAULTS_H */
