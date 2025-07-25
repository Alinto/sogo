/* SOGoSystemDefaults.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2021 Inverse inc.
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
#import <SOGo/NSString+Utilities.h>

static const NSString *kDisableSharingMail = @"Mail";
static const NSString *kDisableSharingContacts = @"Contacts";
static const NSString *kDisableSharingCalendar = @"Calendar";

@interface SOGoSystemDefaults : SOGoDomainDefaults
{
  NSArray *loginDomains;
}

+ (SOGoSystemDefaults *) sharedSystemDefaults;

- (NSArray *) domainIds;
- (BOOL) doesLoginTypeByDomain;
- (NSString *) getLoginTypeForDomain: (NSString*) _domain;
- (NSString *) getLoginConfigForDomain: (NSDictionary*) _domain;
- (NSString *) getImapAuthMechForDomain: (NSString*) _domain;
- (NSString *) getSmtpAuthMechForDomain: (NSString*) _domain;
- (BOOL) forbidUnknownDomainsAuth;
- (NSArray *) domainsAllowed;
- (BOOL) enableDomainBasedUID;
- (NSArray *) loginDomains;
- (NSArray *) visibleDomainsForDomain: (NSString *) domain;

- (BOOL) crashOnSessionCreate;
- (BOOL) debugRequests;
- (BOOL) debugLeaks;
- (int) vmemLimit;
- (BOOL) trustProxyAuthentication;
- (NSString *) encryptionKey;
- (BOOL) isSogoSecretSet;
- (NSString *) sogoSecretValue;
- (BOOL) useRelativeURLs;
- (NSString *) sieveFolderEncoding;

- (BOOL) isWebAccessEnabled;
- (BOOL) isCalendarDAVAccessEnabled;
- (BOOL) isCalendarJitsiLinkEnabled;
- (BOOL) isAddressBookDAVAccessEnabled;

- (BOOL) enableEMailAlarms;

- (BOOL) disableOrganizerEventCheck;

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
- (BOOL) easDebugEnabled;
- (BOOL) openIdDebugEnabled;
- (BOOL) apiDebugEnabled;
- (BOOL) tnefDecoderDebugEnabled;
- (BOOL) xsrfValidationEnabled;

- (NSString *) pageTitle;
- (NSString *) helpURL;

NSComparisonResult languageSort(id el1, id el2, void *context);

- (NSArray *) supportedLanguages;
- (NSString *) loginSuffix;

- (NSString *) authenticationType;
- (BOOL) isSsoUsed: (NSString *) domain;
- (NSString *) davAuthenticationType;

- (NSString *) CASServiceURL;
- (BOOL) CASLogoutEnabled;

- (NSString *) openIdConfigUrl;
- (NSString *) openIdScope;
- (NSString *) openIdClient;
- (NSString *) openIdClientSecret;
- (NSString *) openIdEmailParam;
- (NSString *) openIdHttpVersion;
- (BOOL) openIdEnableRefreshToken;
- (BOOL) openIdLogoutEnabled: (NSString *) _domain;
- (int) openIdTokenCheckInterval;
- (BOOL) openIdSendDomainInfo;

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

- (int) maximumMessageSizeLimit;

- (NSUInteger) maximumMessageSubmissionCount;
- (NSUInteger) maximumRecipientCount;
- (int) maximumSubmissionInterval;
- (int) messageSubmissionBlockInterval;

- (int) maximumRequestCount;
- (int) maximumRequestInterval;
- (int) requestBlockInterval;


- (int) maximumPingInterval;
- (int) maximumSyncInterval;
- (int) internalSyncInterval;
- (int) maximumSyncWindowSize;
- (int) maximumSyncResponseSize;
- (int) maximumPictureSize;
- (BOOL) easSearchInBody;
- (BOOL) isEasUIDisabled;

- (BOOL)isPasswordRecoveryEnabled;
- (NSArray *) passwordRecoveryDomains;
- (NSString *) JWTSecret;

- (NSArray *) disableSharing;
- (NSArray *) disableSharingAnyAuthUser;
- (NSArray *) disableExport;

- (BOOL)isURLEncryptionEnabled;
- (NSString *)urlEncryptionPassphrase;
- (BOOL)enableMailCleaning;

@end

#endif /* SOGOSYSTEMDEFAULTS_H */
