/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "AgenorUserManager.h"
#include "AgenorUserDefaults.h"
#include <NGExtensions/NGExtensions.h>
#include <NGLdap/NGLdap.h>
#include <NGCards/NGCards.h>
#include "SOGoLRUCache.h"

@interface AgenorUserManager (PrivateAPI)
- (NGLdapConnection *)ldapConnection;

- (void)_cacheCN:(NSString *)_cn forUID:(NSString *)_uid;
- (NSString *)_cachedCNForUID:(NSString *)_uid;
- (void)_cacheServer:(NSString *)_server forUID:(NSString *)_uid;
- (NSString *)_cachedServerForUID:(NSString *)_uid;
- (void)_cacheEmail:(NSString *)_email forUID:(NSString *)_uid;
- (NSString *)_cachedEmailForUID:(NSString *)_uid;
- (void)_cacheUID:(NSString *)_uid forEmail:(NSString *)_email;
- (NSString *)_cachedUIDForEmail:(NSString *)_email;

- (BOOL)primaryIsUserAllowedToChangeSOGoInternetAccess:(NSString *)_uid;

- (BOOL)primaryIsInternetAutoresponderEnabledForUser:(NSString *)_uid;
- (BOOL)primaryIsIntranetAutoresponderEnabledForUser:(NSString *)_uid;
- (NGLdapAttribute *)primaryGetMailAutoresponderAttribute:(NSString *)_uid;
- (BOOL)isAutoresponderEnabledForAttribute:(NGLdapAttribute *)_attr
  matchingPrefix:(NSString *)_prefix;
@end

// TODO: add a timer to flush LRU caches every some hours

@implementation AgenorUserManager

static BOOL     debugOn     = NO;
static BOOL     useLDAP     = NO;
static NSString *ldapHost   = nil;
static NSString *ldapBaseDN = nil;
static NSNull   *sharedNull = nil;
static NSString *fallbackIMAP4Server          = nil;
static NSString *defaultMailDomain            = nil;
static NSString *shareLDAPClass               = @"mineqMelBoite";
static NSString *shareLoginSeparator          = @".-.";
static NSString *mailEmissionAttrName         = @"mineqMelmailEmission";
static NSString *changeInternetAccessAttrName = @"mineqOgoAccesInternet";
static NSString *mailAutoresponderAttrName    = @"mineqMelReponse"; /* sic! */
static NSURL    *AgenorProfileURL             = nil;

static NSArray *fromEMailAttrs = nil;

static unsigned PoolScanInterval = 5 * 60 /* every five minutes */;

+ (void) initialize 
{
  static BOOL didInit = NO;
  NSUserDefaults *ud;
  NSString *tmp;

  if (didInit) return;
  didInit = YES;
  
  ud      = [NSUserDefaults standardUserDefaults];
  debugOn = [ud boolForKey:@"SOGoUserManagerDebugEnabled"];
  
  useLDAP = [ud boolForKey:@"SOGoUserManagerUsesLDAP"];
  if (useLDAP) {
    ldapHost   = [[ud stringForKey:@"SOGoLDAPHost"]   copy];
    ldapBaseDN = [[ud stringForKey:@"SOGoLDAPBaseDN"] copy];
    NSLog(@"Note: using LDAP host to manage accounts: %@", ldapHost);
  }
  else
    NSLog(@"Note: LDAP access is disabled.");
  
  fallbackIMAP4Server = [[ud stringForKey:@"SOGoFallbackIMAP4Server"] copy];
  if ([fallbackIMAP4Server length] > 0)
    NSLog(@"Note: using fallback IMAP4 server: '%@'", fallbackIMAP4Server);
  else
    {
      if (fallbackIMAP4Server)
        [fallbackIMAP4Server release];
      fallbackIMAP4Server = nil;
    }

  defaultMailDomain = [[ud stringForKey:@"SOGoDefaultMailDomain"] copy];
  if ([defaultMailDomain length] == 0)
    {
      if (defaultMailDomain)
        [defaultMailDomain release];
      defaultMailDomain = nil;
      NSLog(@"WARNING: no default mail domain (please specify"
            " 'SOGoDefaultMailDomain' in the user default db)");
    }

  fromEMailAttrs = 
    [[NSArray alloc] initWithObjects:mailEmissionAttrName, nil];

  sharedNull = [[NSNull null] retain];

  /* profile database URL */
  
  if ((tmp = [ud stringForKey:@"AgenorProfileURL"]) == nil)
    NSLog(@"ERROR: no 'AgenorProfileURL' database URL configured!");
  else if ((AgenorProfileURL = [[NSURL alloc] initWithString:tmp]) == nil)
    NSLog(@"ERROR: could not parse AgenorProfileURL: '%@'", tmp);
  else
    NSLog(@"Note: using profile at: %@", [AgenorProfileURL absoluteString]);

  if ((tmp = [ud stringForKey: @"SOGoDefaultMailDomain"]))
    {
      defaultMailDomain = [tmp copy];
    }
  
  PoolScanInterval = [[ud objectForKey:@"AgenorCacheCheckInterval"] intValue];
  if (PoolScanInterval == 0) 
    PoolScanInterval = 60 * 60 /* every hour */;
  NSLog(@"AgenorUserManager: flushing caches every %d minutes "
	@"(AgenorCacheCheckInterval)",
	PoolScanInterval / 60);
}

+ (id)sharedUserManager {
  static AgenorUserManager *mgr = nil;
  if (mgr == nil)
    mgr = [[self alloc] init];
  return mgr;
}

- (id)init {
  self = [super init];
  if(self) {
    self->serverCache     = 
      [[NSMutableDictionary alloc] initWithCapacity:10000];
    self->cnCache         = 
      [[NSMutableDictionary alloc] initWithCapacity:10000];
    self->uidCache        = 
      [[NSMutableDictionary alloc] initWithCapacity:10000];
    self->emailCache      = 
      [[NSMutableDictionary alloc] initWithCapacity:10000];
    self->shareStoreCache = 
      [[NSMutableDictionary alloc] initWithCapacity:10000];
    self->shareEMailCache = 
      [[NSMutableDictionary alloc] initWithCapacity:10000];
    self->changeInternetAccessCache =
      [[NSMutableDictionary alloc] initWithCapacity:10000];
    self->internetAutoresponderFlagCache =
      [[NSMutableDictionary alloc] initWithCapacity:10000];
    self->intranetAutoresponderFlagCache =
      [[NSMutableDictionary alloc] initWithCapacity:10000];
    
    self->gcTimer = [[NSTimer scheduledTimerWithTimeInterval:
				PoolScanInterval
			      target:self selector:@selector(_garbageCollect:)
			      userInfo:nil repeats:YES] retain];
  }
  return self;
}

- (void)dealloc {
  if (self->gcTimer) [self->gcTimer invalidate];
  [self->serverCache     release];
  [self->cnCache         release];
  [self->uidCache        release];
  [self->emailCache      release];
  [self->shareStoreCache release];
  [self->shareEMailCache release];
  [self->changeInternetAccessCache      release];
  [self->internetAutoresponderFlagCache release];
  [self->intranetAutoresponderFlagCache release];
  [self->gcTimer release];
  [super dealloc];
}

/* cache */

- (void)flush {
  [self->cnCache         removeAllObjects];
  [self->serverCache     removeAllObjects];
  [self->uidCache        removeAllObjects];
  [self->emailCache      removeAllObjects];
  [self->shareStoreCache removeAllObjects];
  [self->shareEMailCache removeAllObjects];
  
  [self->changeInternetAccessCache      removeAllObjects];
  [self->internetAutoresponderFlagCache removeAllObjects];
  [self->intranetAutoresponderFlagCache removeAllObjects];
}

- (void)_garbageCollect:(NSTimer *)_timer {
  [self debugWithFormat:@"flushing caches."];
  [self flush];
}

/* LDAP */

- (NGLdapConnection *)ldapConnection {
  static NGLdapConnection *ldapConnection = nil;
  if(!ldapConnection) {
    ldapConnection = [[NGLdapConnection alloc] initWithHostName:ldapHost];
#if 0
    [ldapConnection setUseCache:YES];
#endif
  }
  return ldapConnection;
}


/* private cache helpers */
// TODO: this is really unnecessary, no?

- (void)_cacheCN:(NSString *)_cn forUID:(NSString *)_uid {
  if (_cn == nil) return;
  [self->cnCache setObject:_cn forKey:_uid];
}
- (NSString *)_cachedCNForUID:(NSString *)_uid {
  return [self->cnCache objectForKey:_uid];
}

- (void)_cacheServer:(NSString *)_server forUID:(NSString *)_uid {
  if (_server == nil) return;
  [self->serverCache setObject:_server forKey:_uid];
}
- (NSString *)_cachedServerForUID:(NSString *)_uid {
  return [self->serverCache objectForKey:_uid];
}

- (void)_cacheEmail:(NSString *)_email forUID:(NSString *)_uid {
  if (_email == nil) return;
  [self->emailCache setObject:_email forKey:_uid];
}
- (NSString *)_cachedEmailForUID:(NSString *)_uid {
  return [self->emailCache objectForKey:_uid];
}

- (void)_cacheUID:(NSString *)_uid forEmail:(NSString *)_email {
  if (_uid == nil) return;
  [self->uidCache setObject:_uid forKey:_email];
}
- (NSString *)_cachedUIDForEmail:(NSString *)_email {
  return [self->uidCache objectForKey:_email];
}


/* uid <-> email mapping */

/*
 UPDATE: the email excerpt below has been marked by Maxime as being
         wrong. This algorithm can not be expected to work, thus
         the mapping has been replaced with an LDAP query.

 --- snip ---
 The uid field is in bijection this the email adress :
 this field can be construct from the email. Email are uniques.
 
 So, we can use email adresse from identifier. 
 The field is made like this :
 _ if the email is equipement.gouv.fr then the login
 is the part before the @
 for example : fisrtName.lastName
 _ if the email is not equipement.gouv.fr then the login
 is the full email adress where @ is change to . (dot)
 for example : fisrtName.lastName.subDomain.domain.tld
 --- snap ---

 NOTE: mapping email -> uid is easy, but can also generate uid's not known
       to the system (i.e. for private addressbook entries, obvious).
       The reverse mapping can work _only_ if "firstName.lastname." is
       guaranteed, because the second dot would be mapped to '@'. This
       is probably error prone.
       Only LDAP fetches would guarantee correctness in both cases.
*/

- (NSString *)primaryGetAgenorUIDForEmail:(NSString *)_email {
  static NSArray   *uidAttrs = nil;
  NGLdapConnection *conn;
  EOQualifier      *q;
  NSEnumerator     *resultEnum;
  NGLdapEntry      *entry;
  NGLdapAttribute  *uidAttr;
  NSString         *uid;

  if (uidAttrs == nil)
    uidAttrs = [[NSArray alloc] initWithObjects:@"uid", nil];
    
  q = [EOQualifier qualifierWithQualifierFormat:@"mail = %@", _email];
    
  conn       = [self ldapConnection];
  resultEnum = [conn deepSearchAtBaseDN:ldapBaseDN
		     qualifier:q
		     attributes:uidAttrs];
  entry = [resultEnum nextObject];
  if (entry == nil) {
    if(debugOn) {
      [self logWithFormat:@"%s Didn't find LDAP entry for email '%@'!",
	    __PRETTY_FUNCTION__,
	    _email];
    }
    return nil;
  }
  uidAttr = [entry attributeWithName:@"uid"];
  if (!uidAttr)
    return nil; /* can happen, not unlikely */
  uid = [uidAttr stringValueAtIndex:0];
  return uid;
}

- (NSString *)getUIDForEmail:(NSString *)_email {
  NSString *uid;
  
  if ((uid = [self _cachedUIDForEmail:_email]) != nil)
    return uid;
    
  if (useLDAP) {
    uid = [self primaryGetAgenorUIDForEmail:_email];
  }
  else {
    NSRange r;
    NSString *domain;
    
    if(!_email || [_email length] == 0)
      return nil;
    
    r = [_email rangeOfString:@"@"];
    if (r.length == 0)
      return nil;
    
    domain = [_email substringFromIndex:NSMaxRange(r)];
    if (![domain isEqualToString:defaultMailDomain])
      uid = _email;
    else
      uid = [_email substringToIndex:r.location];
  }
  
  [self _cacheUID:uid forEmail:_email];
  return uid;
}

- (NSString *)getUIDForICalPerson:(iCalPerson *)_person {
  return [self getUIDForEmail:[_person rfc822Email]];
}

  /* may insert NSNulls into returned array */
- (NSArray  *)getUIDsForICalPersons:(NSArray *)_persons
  applyStrictMapping:(BOOL)_mapStrictly
{
  NSMutableArray *ma;
  unsigned       i, count;

  count = [_persons count];
  ma    = [[[NSMutableArray alloc] initWithCapacity:count] autorelease];
  for (i = 0; i < count; i++) {
    iCalPerson *p;
    id         uid;
    
    p   = [_persons objectAtIndex:i];
    uid = [self getUIDForICalPerson:p];
    if (uid != nil)
      [ma addObject:uid];
    else if (uid == nil && _mapStrictly)
      [ma addObject:sharedNull];
  }
  return ma;
}

- (NSString *)primaryGetEmailForAgenorUID:(NSString *)_uid {
  NGLdapConnection *conn;
  EOQualifier      *q;
  NSEnumerator     *resultEnum;
  NGLdapEntry      *entry;
  NGLdapAttribute  *emailAttr;
  NSString         *email;
  unsigned         count;
    
  q = [EOQualifier qualifierWithQualifierFormat:@"uid = %@", _uid];
    
  conn       = [self ldapConnection];
  resultEnum = [conn deepSearchAtBaseDN:ldapBaseDN
		     qualifier:q
		     attributes:fromEMailAttrs];
  entry = [resultEnum nextObject];
  if (entry == nil) {
      if(debugOn) {
        [self logWithFormat:@"%s Didn't find LDAP entry for uid '%@'!",
                              __PRETTY_FUNCTION__,
                              _uid];
      }
      return nil;
  }
  emailAttr = [entry attributeWithName:mailEmissionAttrName];
  if (emailAttr == nil)
    return nil; /* shit happens */
  
  email = nil;
  count = [emailAttr count];
#if 0 // TODO: explain why this is commented out!
  if (count > 1) {
        unsigned i;

        /* in case there are multiple email addresses, select the first
           which doesn't have '@equipement.gouv.fr' in it */
        for (i = 0; i < count; i++) {
          NSString *candidate;
          
          candidate = [emailAttr stringValueAtIndex:i];
          if (![candidate hasSuffix:defaultMailDomain]) {
	    // TODO: also check for '@'
            email = candidate;
            break;
          }
        }
  }
#endif
  if (email == nil && count > 0)
    email = [emailAttr stringValueAtIndex:0];
  
  return email;
}

- (NSString *)getEmailForUID:(NSString *)_uid {
  NSString *email;
  
  if (![_uid isNotNull] || [_uid length] == 0)
    return nil;
  if ((email = [self _cachedEmailForUID:_uid]) != nil)
    return email;
  
  if (useLDAP) {
    email = [self primaryGetEmailForAgenorUID:_uid];
  }
  else {
    NSRange r;
    
    r = [_uid rangeOfString:@"@"];
    email = (r.length > 0)
      ? _uid
      : [[_uid stringByAppendingString:@"@"]
	       stringByAppendingString:defaultMailDomain];
  }
  
  [self _cacheEmail:email forUID:_uid];
  return email;
}


/* CN */

- (NSString *)primaryGetCNForAgenorUID:(NSString *)_uid {
  static NSArray   *cnAttrs = nil;
  NGLdapConnection *conn;
  EOQualifier      *q;
  NSEnumerator     *resultEnum;
  NGLdapEntry      *entry;
  NGLdapAttribute  *cnAttr;
  NSString         *cn;

  if (cnAttrs == nil)
    cnAttrs = [[NSArray alloc] initWithObjects:@"cn", nil];
  
  q = [EOQualifier qualifierWithQualifierFormat:@"uid = %@", _uid];
  
  conn = [self ldapConnection];
  resultEnum = [conn deepSearchAtBaseDN:ldapBaseDN
		     qualifier:q
		     attributes:cnAttrs];
  entry = [resultEnum nextObject];
  if (entry == nil) {
      if(debugOn) {
        [self logWithFormat:@"%s Didn't find LDAP entry for uid '%@'!",
                              __PRETTY_FUNCTION__,
                              _uid];
      }
      return nil;
  }
  cnAttr = [entry attributeWithName:@"cn"];
  if(cnAttr == nil && debugOn) {
      [self logWithFormat:@"%s LDAP entry for uid '%@' has no common name?",
                            __PRETTY_FUNCTION__,
                            _uid];
      return nil; /* nothing we can do about it */
  }
  cn = [cnAttr stringValueAtIndex:0];
  return cn;
}

- (NSString *)getCNForUID:(NSString *)_uid {
  NSString *cn;

  if ((cn = [self _cachedCNForUID:_uid]) != nil)
    return cn;
  
  if (useLDAP) {
    cn = [self primaryGetCNForAgenorUID:_uid];
  }
  else {
    NSString *s;
    NSRange  r;
    
    s = _uid;
    if ([s length] < 10)
      return s;
    
    // TODO: algorithm might be inappropriate, depends on the actual UID
    r = [s rangeOfString:@"."];
    if (r.length == 0)
      cn = s;
    else
      cn = [s substringToIndex:r.location];
  }
  
  [self _cacheCN:cn forUID:_uid];
  return cn;
}


/* Servers, IMAP */

- (NSString *)getIMAPAccountStringForUID:(NSString *)_uid {
  NSString *server;
  
  server = [self getServerForUID:_uid];
  if (server == nil)
    return nil;
  return [NSString stringWithFormat:@"%@@%@", _uid, server];
}

- (NSArray *)mailServerDiscoveryAttributes {
  static NSArray *attrs = nil;

  if (attrs == nil) {
    attrs = [[NSArray alloc] initWithObjects:
			       @"uid", /* required for shares */
			       @"mineqMelRoutage", 
			       @"mineqMelServeurPrincipal",
			       @"mineqMelPartages",
			       mailEmissionAttrName,
			     nil];
  }
  return attrs;
}

- (NGLdapEntry *)_fetchEntryForAgenorUID:(NSString *)_uid {
  // TODO: badly named, this fetches the mail server discovery attributes
  /* called by -primaryGetServerForAgenorUID: */
  NGLdapConnection *conn;
  EOQualifier      *q;
  NSEnumerator     *resultEnum;
  NGLdapEntry      *entry;
  
  q = [EOQualifier qualifierWithQualifierFormat:@"uid = %@", _uid];
  
  conn = [self ldapConnection];
  resultEnum = [conn deepSearchAtBaseDN:ldapBaseDN
		     qualifier:q
		     attributes:[self mailServerDiscoveryAttributes]];
  /* we just expect one entry, thus drop the rest */
  entry = [resultEnum nextObject];
  if (entry == nil) {
      if(debugOn) {
        NSLog(@"%s Didn't find LDAP entry for uid '%@'!",
              __PRETTY_FUNCTION__,
              _uid);
      }
      return nil;
  }
  return entry;
}

- (NSArray *)_serverCandidatesForMineqMelRoutage:(NGLdapAttribute *)attr {
  /*
    eg:
      "Baluh.Hommes.Tests-Montee-En-Charge-Ogo%equipement.gouv.fr@\
       amelie-01.ac.melanie2.i2"
  */
  NSMutableArray *serverCandidates;
  unsigned i, count;

  count            = [attr count];
  serverCandidates = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSRange  r;
    NSString *route;
    unsigned length;
    unsigned start;
    NSRange  serverNameRange;
    NSString *serverName;
    
    route = [attr stringValueAtIndex:i];

    /* check for melanie suffix and ignore other entries */
    
    r = [route rangeOfString:@".melanie2.i2" options:NSBackwardsSearch];
    if (r.length == 0) {
#if 0
      [self logWithFormat:@"found no melanie in route: '%@'", route];
#endif
      continue;
    }

    /* check for @ inside the string, searching backwards (ignoring suffix) */
    
    // be clever: TODO: in what way is this clever?
    length = [route length];
    r = NSMakeRange(0, length - r.length); /* cut of suffix (.melanie2.i2) */
    r = [route rangeOfString:@"@" options:NSBackwardsSearch range:r];
    if (r.length == 0) {
#if 0
      [self logWithFormat:@"found no @ in route: '%@'", route];
#endif
      continue;
    }
    
    /* check for percent sign */
    
    start = NSMaxRange(r); /* start behind the @ */
    
    /* this range covers everything after @: 'amelie-01.ac.melanie2.i2' */
    serverNameRange = NSMakeRange(start, length - start);
    
    /* and this range covers everything to the @ */
    r = NSMakeRange(0, start - 1);
    r = [route rangeOfString:@"%" options:NSBackwardsSearch range:r];
    if (r.length == 0) {
#if 0
      [self logWithFormat:@"found no %% in route: '%@' / '%@'", 
	    route, [route substringWithRange:NSMakeRange(0, length - start)]];
#endif
      continue;
    }
    
    serverName = [route substringWithRange:serverNameRange];
    [serverCandidates addObject:serverName];
  }
  return serverCandidates;
}

- (NSString *)serverFromEntry:(NGLdapEntry *)_entry {
  NSString        *server;
  NGLdapAttribute *attr;

  server = nil;
  
  attr = [_entry attributeWithName:@"mineqMelRoutage"];
  if (attr != nil) {
    NSArray *serverCandidates;
    
    serverCandidates = [self _serverCandidatesForMineqMelRoutage:attr];
    if ([serverCandidates count] > 0)
      server = [serverCandidates objectAtIndex:0];
    
    if ([serverCandidates count] > 1) {
      [self logWithFormat:
	      @"WARNING: more than one value for 'mineqMelRoutage': %@",
	      serverCandidates];
    }
  }
  else {
    [self debugWithFormat:
	    @"%s LDAP entry '%@' has no mineqMelRoutage entry?",
	    __PRETTY_FUNCTION__, [_entry dn]];
  }
  
  /* last resort */
  if (server == nil) {
    attr = [_entry attributeWithName:@"mineqMelServeurPrincipal"];
    if ([attr count] > 0)
      server = [attr stringValueAtIndex:0];
  }
  
  return server;
}

- (NSString *)primaryGetServerForAgenorUID:(NSString *)_uid {
  /*
   First of all : for a particular user IMAP and SMTP are served on the same
   host.
   
   The name of the machine is determined by applying a regex on every values of
   the mineqMelRoutage LDAP attribute.
   The regex is :   .*%.*@(.*\.melanie2\.i2$)
   It extracts the substring that follows '@', ends with 'melanie2', on
   adresses which have a '%' before the '@'
   
   Example: helge.hesse%opengroupware.org@servername1.melanie2.i2
   -> servername1.melanie2.i2
   
   If only one server name is found by applying the regex on every value of the
   attribute, then this name is the IMAP/SMTP server for that user.
   Note that this is the case when we got a unique (well formed) value for the
   attribute.
   If the regex finds more than one servername when applied to the differents
   values, then the IMAP/SMTP server name is to be found in the
   mineqMelServeurPrincipal attribute of the user.
  */
  NSString    *server;
  NGLdapEntry *entry;
  
  if ((entry = [self _fetchEntryForAgenorUID:_uid]) == nil)
    return nil;
  
  if ((server = [self serverFromEntry:entry]) != nil)
    return server;
  
  [self debugWithFormat:
	  @"%s no chance of getting at server info for user '%@', "
	  @"tried everything. Sorry.",
	  __PRETTY_FUNCTION__, _uid];
  return nil;
}

- (NSString *)getServerForUID:(NSString *)_uid {
  NSString *server;

  if (_uid == nil || [_uid length] == 0)
    return nil;
  
  if ((server = [self _cachedServerForUID:_uid]) != nil)
    return server;
  
  if (useLDAP)
    server = [self primaryGetServerForAgenorUID:_uid];
  else if (fallbackIMAP4Server != nil)
    server = fallbackIMAP4Server;
  else {
    [self logWithFormat:@"ERROR: could not get server for uid '%@', "
	  @"neither LDAP (SOGoUserManagerUsesLDAP) nor "
	  @"a fallback (SOGoFallbackIMAP4Server) is configured.",
	  _uid];
    server = nil;
  }
  
  [self _cacheServer:server forUID:_uid];
  return server;
}

/* shared mailboxes */

- (NSArray *)getSharedMailboxAccountStringsForUID:(NSString *)_uid {
  NSArray *k;
  
  k = [[self getSharedMailboxesAndEMailsForUID:_uid] allKeys];
  
  /* ensure that ordering is always the same */
  return [k sortedArrayUsingSelector:@selector(compare:)];
}

- (NSString *)emissionEMailFromEntry:(NGLdapEntry *)_entry {
  id emissionAttr;
  
  emissionAttr = [_entry attributeWithName:mailEmissionAttrName];
  if ([emissionAttr count] == 0) {
    [self logWithFormat:@"WARNING: share has no %@ attr: %@",
	    mailEmissionAttrName, [_entry dn]];
    return nil;
  }
    
  if ([emissionAttr count] > 1) {
    [self logWithFormat:
	    @"WARNING: share has more than one value in %@ attr: %@",
	    mailEmissionAttrName, [_entry dn]];
    return nil;
  }
  
  return [emissionAttr stringValueAtIndex:0];
}

- (NSArray *)getSharedMailboxEMailsForUID:(NSString *)_uid {
  NSMutableArray   *shares = nil;
  NGLdapConnection *conn;
  EOQualifier      *q;
  NSString         *gPattern, *cPattern;
  NSEnumerator     *resultEnum;
  NGLdapEntry      *entry;
  
  if ([_uid length] == 0)
    return nil;
  
  if (!useLDAP) {
    [self logWithFormat:
	    @"Note: LDAP access is disabled, returning no shared froms."];
    return nil;
  }
  
  /* check cache */
  if ((shares = [self->shareEMailCache objectForKey:_uid]) != nil)
    return shares;
  
  /* G and C mean "emission access" */
  gPattern = [_uid stringByAppendingString:@":G"];
  cPattern = [_uid stringByAppendingString:@":C"];
  
  q = [EOQualifier qualifierWithQualifierFormat:
		     @"((mineqMelPartages = %@) OR (mineqMelPartages = %@)) "
		     @"AND (objectclass = %@)",
		   gPattern, cPattern, shareLDAPClass];
  
  conn = [self ldapConnection];
  
  resultEnum = [conn deepSearchAtBaseDN:ldapBaseDN
		     qualifier:q
		     attributes:fromEMailAttrs];
  
  while ((entry = [resultEnum nextObject]) != nil) {
    NSString *emissionAttr;

    if ((emissionAttr = [self emissionEMailFromEntry:entry]) == nil)
      continue;
    
    if (shares == nil) shares = [NSMutableArray arrayWithCapacity:4];
    [shares addObject:emissionAttr];
  }
  
  /* ensure that ordering is always the same */
  [shares sortUsingSelector:@selector(compare:)];
  
  /* cache */
  shares = (shares == nil) ? [NSArray array] : [[shares copy] autorelease];
  [self->shareEMailCache setObject:shares forKey:_uid];
  return shares;
}

/* identities */

- (BOOL)hasUser:(NSString *)_uid partageAccess:(char *)_rightset
  inEntry:(NGLdapEntry *)_entry
{
  NGLdapAttribute *attr;
  unsigned i, count;
  
  attr = [_entry attributeWithName:@"mineqMelPartages"];
  if ((count = [attr count]) == 0) {
    [self logWithFormat:@"WARNING: share has no 'mineqMelPartages' attr: %@",
	    [_entry dn]];
    return NO;
  }
  
  for (i = 0; i < count; i++) {
    NSString *p;
    NSRange  r;
    unichar  c;
    register unsigned j;
    
    p = [attr stringValueAtIndex:i];
    r = [p rangeOfString:@":"];
    if (r.length == 0) {
      [self errorWithFormat:@"Invalid mineqMelPartages value: '%@'", p];
      continue;
    }
    
    /* check whether prefix matches, eg: "helian.h:G" */
    if (r.location != [_uid length]) /* check length */
      continue;
    if (![p hasPrefix:_uid])
      continue;
    
    c = [p characterAtIndex:(r.location + r.length)];
    
    /* check whether permissions match */
    for (j = 0; _rightset[j] != '\0'; j++) {
      if (c == _rightset[j])
	return YES;
    }
  }
  return NO;
}

- (NSDictionary *)getSharedMailboxesAndEMailsForUID:(NSString *)_uid {
  /*
    Sample:
      "(&(mineqMelPartages=guizmo.g:*)(objectclass=mineqMelBoite))"
      "guizmo.g" is the uid of the user
    
    Login:
      guizmo.g.-.baluh.hommes.tests-montee-en-charge-ogo
      (uid + ".-." + share-uid)
    
    Note: shared mailboxes can be on different hosts!
    
    This returns a dictionary where the keys are the IMAP4 connect strings
    while the values are the emitter addresses for the box or NSNull if the
    uid is not allowed to emit for this box.
  */
  NSMutableDictionary *shares = nil;
  NGLdapConnection *conn;
  EOQualifier      *q;
  NSString         *sharePattern;
  NSEnumerator     *resultEnum;
  NGLdapEntry      *entry;
  
  if ([_uid length] == 0)
    return nil;
  
  if (!useLDAP) {
    [self logWithFormat:
	    @"Note: LDAP access is disabled, returning no shared accounts."];
    return nil;
  }

  /* check cache */
  if ((shares = [self->shareStoreCache objectForKey:_uid]) != nil)
    return shares;
  
  sharePattern = [_uid stringByAppendingString:@":*"];
  
  q = [EOQualifier qualifierWithQualifierFormat:
		     @"(mineqMelPartages = %@) AND (objectclass = %@)",
		     sharePattern, shareLDAPClass];
  
  conn = [self ldapConnection];

  resultEnum = [conn deepSearchAtBaseDN:ldapBaseDN
		     qualifier:q
		     attributes:[self mailServerDiscoveryAttributes]];
  
  while ((entry = [resultEnum nextObject]) != nil) {
    NSString *server, *shareLogin;
    id shareUid, emitterAddress;

    /* calculate server connect string */
    
    if ([(server = [self serverFromEntry:entry]) length] == 0) {
      [self errorWithFormat:@"found no mail server host for share: %@",
	      [entry dn]];
      continue;
    }
    
    shareUid = [entry attributeWithName:@"uid"];
    if ([shareUid count] < 1) {
      [self errorWithFormat:@"found no 'uid' for share: %@", [entry dn]];
      continue;
    }
    shareUid = [shareUid stringValueAtIndex:0];
    
    shareLogin = [_uid stringByAppendingString:shareLoginSeparator];
    shareLogin = [shareLogin stringByAppendingString:shareUid];
    
    if (shares == nil)
      shares = [NSMutableDictionary dictionaryWithCapacity:4];
    
    shareLogin = [shareLogin stringByAppendingString:@"@"];
    shareLogin = [shareLogin stringByAppendingString:server];
    
    /* calculate emitter address (check for proper access right) */
    
    if ([self hasUser:_uid partageAccess:"GC" inEntry:entry])
      emitterAddress = [self emissionEMailFromEntry:entry];
    else
      emitterAddress = [NSNull null];
    
    /* set value */
    
    [shares setObject: emitterAddress
	    forKey: shareLogin];
  }
  
  /* cache */
  shares = (shares == nil) 
    ? [NSDictionary dictionary] 
    : [[shares copy] autorelease];
  [self->shareStoreCache setObject:shares forKey:_uid];
  return shares;
}

/* free busy */

- (NSURL *)getFreeBusyURLForUID:(NSString *)_uid {
  [self logWithFormat:@"TODO(%s): implement", __PRETTY_FUNCTION__];
  return nil;
}

/* defaults */

- (NSUserDefaults *)getUserDefaultsForUID:(NSString *)_uid {
  id defaults;
  
  if (AgenorProfileURL == nil) {
    [self warnWithFormat:
	    @"no profile configured, cannot retrieve defaults for user: '%@'",
	    _uid];
    return nil;
  }
  
  /* Note: do not cache, otherwise updates can be quite tricky */
  defaults = [[[AgenorUserDefaults alloc] 
		initWithTableURL:AgenorProfileURL uid:_uid] autorelease];
  return defaults;
}

/* internet access lock */

- (BOOL)isUserAllowedToChangeSOGoInternetAccess:(NSString *)_uid {
  NSNumber *bv;
  
  bv = [self->changeInternetAccessCache objectForKey:_uid];
  if (!bv) {
    BOOL value;
    
    value = [self primaryIsUserAllowedToChangeSOGoInternetAccess:_uid];
    bv    = [NSNumber numberWithBool:value];
    [self->changeInternetAccessCache setObject:bv forKey:_uid];
  }
  return [bv boolValue];
}

- (BOOL)primaryIsUserAllowedToChangeSOGoInternetAccess:(NSString *)_uid {
  static NSArray   *attrs = nil;
  NGLdapConnection *conn;
  EOQualifier      *q;
  NSEnumerator     *resultEnum;
  NGLdapEntry      *entry;
  NGLdapAttribute  *attr;
  NSString         *value;
  
  if (attrs == nil)
    attrs = [[NSArray alloc] initWithObjects:changeInternetAccessAttrName, nil];
  
  q = [EOQualifier qualifierWithQualifierFormat:@"uid = %@", _uid];
  
  conn       = [self ldapConnection];
  resultEnum = [conn deepSearchAtBaseDN:ldapBaseDN
                     qualifier:q
                     attributes:attrs];
  entry = [resultEnum nextObject];
  if (entry == nil) {
    if(debugOn) {
      [self logWithFormat:@"%s Didn't find LDAP entry for uid '%@'!",
        __PRETTY_FUNCTION__,
        _uid];
    }
    return NO;
  }
  attr = [entry attributeWithName:changeInternetAccessAttrName];
  if(attr == nil && debugOn) {
    [self logWithFormat:@"%s LDAP entry for uid '%@' "
                        @"has no mineqOgoAccesInternet attribute?",
                        __PRETTY_FUNCTION__,
                        _uid];
    return NO; /* nothing we can do about it */
  }
  value = [attr stringValueAtIndex:0];
  return [value boolValue];
}

- (BOOL)isInternetAutoresponderEnabledForUser:(NSString *)_uid {
  NSNumber *bv;

  bv = [self->internetAutoresponderFlagCache objectForKey:_uid];
  if (!bv) {
    BOOL value;
    
    value = [self primaryIsInternetAutoresponderEnabledForUser:_uid];
    bv    = [NSNumber numberWithBool:value];
    [self->internetAutoresponderFlagCache setObject:bv forKey:_uid];
  }
  return [bv boolValue];
}

- (BOOL)primaryIsInternetAutoresponderEnabledForUser:(NSString *)_uid {
  NGLdapAttribute *attr;
  
  attr = [self primaryGetMailAutoresponderAttribute:_uid];
  if (!attr) return NO;
  return [self isAutoresponderEnabledForAttribute:attr matchingPrefix:@"60~"];
}

- (BOOL)isIntranetAutoresponderEnabledForUser:(NSString *)_uid {
  NSNumber *bv;
  
  bv = [self->intranetAutoresponderFlagCache objectForKey:_uid];
  if (!bv) {
    BOOL value;
    
    value = [self primaryIsIntranetAutoresponderEnabledForUser:_uid];
    bv    = [NSNumber numberWithBool:value];
    [self->intranetAutoresponderFlagCache setObject:bv forKey:_uid];
  }
  return [bv boolValue];
}

- (BOOL)primaryIsIntranetAutoresponderEnabledForUser:(NSString *)_uid {
  NGLdapAttribute *attr;
  
  attr = [self primaryGetMailAutoresponderAttribute:_uid];
  if (!attr) return NO;
  return [self isAutoresponderEnabledForAttribute:attr matchingPrefix:@"50~"];
}

- (BOOL)isAutoresponderEnabledForAttribute:(NGLdapAttribute *)_attr
  matchingPrefix:(NSString *)_prefix
{
  unsigned i, count;
  
  count = [_attr count];
  for (i = 0; i < count; i++) {
    NSString *value;
    
    value = [_attr stringValueAtIndex:i];
    if ([value hasPrefix:_prefix]) {
      if ([value rangeOfString:@"DFIN:0"].length > 0)
        return NO;
      return YES;
    }
  }
  return NO;
}

- (NGLdapAttribute *)primaryGetMailAutoresponderAttribute:(NSString *)_uid {
  static NSArray   *attrs = nil;
  NGLdapConnection *conn;
  EOQualifier      *q;
  NSEnumerator     *resultEnum;
  NGLdapEntry      *entry;
  NGLdapAttribute  *attr;
  
  if (attrs == nil)
    attrs = [[NSArray alloc] initWithObjects:mailAutoresponderAttrName, nil];

  q = [EOQualifier qualifierWithQualifierFormat:@"uid = %@", _uid];
  
  conn       = [self ldapConnection];
  resultEnum = [conn deepSearchAtBaseDN:ldapBaseDN
                     qualifier:q
                     attributes:attrs];
  entry = [resultEnum nextObject];
  if (entry == nil) {
    if(debugOn) {
      [self logWithFormat:@"%s Didn't find LDAP entry for uid '%@'!",
        __PRETTY_FUNCTION__,
        _uid];
    }
    return nil;
  }
  attr = [entry attributeWithName:mailAutoresponderAttrName];
  return attr;
}

- (iCalPerson *) iCalPersonWithUid: (NSString *) uid
{
  iCalPerson *person;

  person = [iCalPerson new];
  [person autorelease];
  [person setCn: [self getCNForUID: uid]];
  [person setEmail: [self getEmailForUID: uid]];

  return person;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:16];
  [ms appendFormat:@"<0x%08X[%@]", self, NSStringFromClass([self class])];
  [ms appendString:@">"];
  return ms;
}

@end /* AgenorUserManager */
