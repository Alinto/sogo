/* SOGoSystemDefaults.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2014 Inverse inc.
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

#ifndef SOGOSYSTEMDEFAULTS_H
#define SOGOSYSTEMDEFAULTS_H

#import <SOGo/SOGoDomainDefaults.h>

@interface SOGoSystemDefaults : SOGoDomainDefaults
{
  NSArray *loginDomains;
}

+ (SOGoSystemDefaults *) sharedSystemDefaults;

- (NSArray *) domainIds;
- (BOOL) enableDomainBasedUID;
- (NSArray *) loginDomains;
- (NSArray *) visibleDomainsForDomain: (NSString *) domain;

- (BOOL) crashOnSessionCreate;
- (BOOL) debugRequests;
- (BOOL) debugLeaks;
- (int) vmemLimit;
- (BOOL) trustProxyAuthentication;
- (NSString *) encryptionKey;
- (BOOL) useRelativeURLs;
- (NSString *) sieveFolderEncoding;

- (BOOL) isWebAccessEnabled;
- (BOOL) isCalendarDAVAccessEnabled;
- (BOOL) isAddressBookDAVAccessEnabled;

- (BOOL) enableEMailAlarms;

- (NSString *) faviconRelativeURL;
- (NSString *) zipPath;
- (int) port;
- (int) workers;
- (NSString *) logFile;
- (NSString *) pidFile;

- (NSTimeInterval) cacheCleanupInterval;
- (NSString *) memcachedHost;

- (BOOL) userCanChangePassword;
- (BOOL) uixAdditionalPreferences;

- (BOOL) uixDebugEnabled;
- (NSString *) pageTitle;

- (NSArray *) supportedLanguages;
- (NSString *) loginSuffix;

- (NSString *) authenticationType;
- (NSString *) davAuthenticationType;

- (NSString *) CASServiceURL;
- (BOOL) CASLogoutEnabled;

- (NSString *) SAML2PrivateKeyLocation;
- (NSString *) SAML2CertificateLocation;
- (NSString *) SAML2IdpMetadataLocation;
- (NSString *) SAML2IdpPublicKeyLocation;
- (NSString *) SAML2IdpCertificateLocation;
- (NSString *) SAML2LoginAttribute;
- (BOOL) SAML2LogoutEnabled;
- (NSString *) SAML2LogoutURL;

- (BOOL) enablePublicAccess;

- (int) maximumFailedLoginCount;
- (int) maximumFailedLoginInterval;
- (int) failedLoginBlockInterval;

- (int) maximumMessageSubmissionCount;
- (int) maximumRecipientCount;
- (int) maximumSubmissionInterval;
- (int) messageSubmissionBlockInterval;

- (int) maximumPingInterval;
- (int) maximumSyncInterval;
- (int) internalSyncInterval;
- (int) maximumSyncWindowSize;
- (int) maximumSyncResponseSize;

@end

#endif /* SOGOSYSTEMDEFAULTS_H */
