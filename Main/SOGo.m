/*
  Copyright (C) 2005-2011 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of SOGo

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSURL.h>

#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSAlarmsFolder.h>

#import <NGObjWeb/SoClassSecurityInfo.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest+So.h>
#import <NGObjWeb/WOResponse.h>

#import <NGExtensions/NGBundleManager.h>
#import <NGExtensions/NGLogger.h>
#import <NGExtensions/NGLoggerManager.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSProcessInfo+misc.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGExtensions/NSString+misc.h>

#import <WEExtensions/WEResourceManager.h>

#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoDAVAuthenticator.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoPublicBaseFolder.h>
#import <SOGo/SOGoProductLoader.h>
#import <SOGo/SOGoProxyAuthenticator.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoWebAuthenticator.h>
#import <SOGo/WORequest+SOGo.h>
#import <SOGo/WOResourceManager+SOGo.h>
#import <SOGo/NSObject+DAV.h>

#import "NSException+Stacktrace.h"

#import "SOGo.h"

#warning might be useful to have a SOGoObject-derived proxy class for \
  handling requests and avoid duplicating methods
@implementation SOGo

static unsigned int vMemSizeLimit;
static BOOL doCrashOnSessionCreate;
static BOOL hasCheckedTables;
static BOOL debugRequests;
static BOOL useRelativeURLs;
static BOOL trustProxyAuthentication;

#ifdef GNUSTEP_BASE_LIBRARY
static BOOL debugLeaks;
#endif

+ (void) logWithFormat: (NSString *) format, ...
{
  static NGLogger *sogoLogger = nil;
  NGLoggerManager *lmgr;
  va_list ap;
  
  if (!sogoLogger)
    {
      lmgr = [NGLoggerManager defaultLoggerManager];
      sogoLogger = [lmgr loggerForClass: [self class]];
    }
  va_start (ap, format);
  [sogoLogger logWithFormat: format arguments:ap];
  va_end (ap);
}

+ (void) applicationWillStart
{
  SOGoSystemDefaults *defaults;
  SoClassSecurityInfo *sInfo;
  NSArray *basicRoles;

  [self logWithFormat: @"version %@ (build %@) -- starting",
        SOGoVersion, SOGoBuildDate];

  defaults = [SOGoSystemDefaults sharedSystemDefaults];
  doCrashOnSessionCreate = [defaults crashOnSessionCreate];
  debugRequests = [defaults debugRequests];
#ifdef GNUSTEP_BASE_LIBRARY
  debugLeaks = [defaults debugLeaks];
  if (debugLeaks)
    [self logWithFormat: @"activating leak debugging"];
#endif

  /* vMem size check - default is 384MB */
  vMemSizeLimit = [defaults vmemLimit];
  if (vMemSizeLimit > 0)
    [self logWithFormat: @"vmem size check enabled: shutting down app when "
          @"vmem > %d MB", vMemSizeLimit];

  /* SoClass security declarations */
  sInfo = [self soClassSecurityInfo];

  /* to allow public access to all contained objects (subkeys) */
  [sInfo setDefaultAccess: @"allow"];

  /* require Authenticated role for View and WebDAV */
  basicRoles = [NSArray arrayWithObject: SoRole_Authenticated];
  [sInfo declareRoles: basicRoles asDefaultForPermission: SoPerm_View];
  [sInfo declareRoles: basicRoles asDefaultForPermission: SoPerm_WebDAVAccess];

  trustProxyAuthentication = [defaults trustProxyAuthentication];
  useRelativeURLs = [defaults useRelativeURLs];

  /* ensure core SoClass'es are setup */
  [$(@"SOGoObject") soClass];
  [$(@"SOGoContentObject") soClass];
  [$(@"SOGoFolder") soClass];

  /* load products */
  [[SOGoProductLoader productLoader] loadAllProducts];
}

- (id) init
{
  if ((self = [super init]))
    {
      WOResourceManager *rm;

      /* setup resource manager */
      rm = [[WEResourceManager alloc] init];
      [self setResourceManager:rm];
      [rm release];
    }

  return self;
}

#warning the following methods should be replaced with helpers in GCSSpecialQueries
- (NSString *) _sqlScriptForTable: (NSString *) tableName
			 withType: (NSString *) tableType
		    andFileSuffix: (NSString *) fileSuffix
{
  NSString *tableFile, *descFile;
  NGBundleManager *bm;
  NSBundle *bundle;
  unsigned int length;

  bm = [NGBundleManager defaultBundleManager];

  bundle = [bm bundleWithName: @"MainUI" type: @"SOGo"];
  length = [tableType length] - 3;
  tableFile = [tableType substringToIndex: length];
  descFile
    = [bundle pathForResource: [NSString stringWithFormat: @"%@-%@",
					 tableFile, fileSuffix]
	      ofType: @"sql"];
  if (!descFile)
    descFile = [bundle pathForResource: tableFile ofType: @"sql"];

  return [[NSString stringWithContentsOfFile: descFile]
	   stringByReplacingString: @"@{tableName}"
	   withString: tableName];
}

- (void) _checkTableWithCM: (GCSChannelManager *) cm
		  tableURL: (NSString *) url
		   andType: (NSString *) tableType
{
  NSString *tableName, *fileSuffix, *tableScript;
  EOAdaptorChannel *tc;
  NSURL *channelURL;

  channelURL = [NSURL URLWithString: url];
  fileSuffix = [channelURL scheme];
  tc = [cm acquireOpenChannelForURL: channelURL];

  tableName = [url lastPathComponent];
  if ([tc evaluateExpressionX:
	    [NSString stringWithFormat: @"SELECT count(*) FROM %@",
		      tableName]])
    {
      tableScript = [self _sqlScriptForTable: tableName
			  withType: tableType
			  andFileSuffix: fileSuffix];
      if (![tc evaluateExpressionX: tableScript])
	[self logWithFormat: @"table '%@' successfully created!", tableName];
    }
  else
    [tc cancelFetch];

  [cm releaseChannel: tc];
}

- (BOOL) _checkMandatoryTables
{
  GCSChannelManager *cm;
  GCSFolderManager *fm;
  NSString *urlStrings[] = {@"SOGoProfileURL", @"OCSFolderInfoURL", nil};
  NSString **urlString;
  NSString *value;
  SOGoSystemDefaults *defaults;
  BOOL ok;

  defaults = [SOGoSystemDefaults sharedSystemDefaults];
  ok = YES;
  cm = [GCSChannelManager defaultChannelManager];

  urlString = urlStrings;
  while (ok && *urlString)
    {
      value = [defaults stringForKey: *urlString];
      if (value)
	{
	  [self _checkTableWithCM: cm tableURL: value andType: *urlString];
	  urlString++;
	}
      else
	{
	  NSLog (@"No value specified for '%@'", *urlString);
	  ok = NO;
	}
    }

  if (ok)
    {
      fm = [GCSFolderManager defaultFolderManager];

      // Create the sessions table
      [[fm sessionsFolder] createFolderIfNotExists];
      
      // Create the email alarms table, if required
      if ([defaults enableEMailAlarms])
	{
	  [[fm alarmsFolder] createFolderIfNotExists];
	}
    }

  return ok;
}

- (void) run
{
  if (!hasCheckedTables)
    {
      hasCheckedTables = YES;
      [self _checkMandatoryTables];
    }
  [super run];
}

/* authenticator */

- (id) authenticatorInContext: (WOContext *) context
{
  id authenticator;

  if (trustProxyAuthentication)
    authenticator = [SOGoProxyAuthenticator sharedSOGoProxyAuthenticator];
  else
    {
      if ([[context request] handledByDefaultHandler])
        authenticator = [SOGoWebAuthenticator sharedSOGoWebAuthenticator];
      else
        authenticator = [SOGoDAVAuthenticator sharedSOGoDAVAuthenticator];
    }

  return authenticator;
}

/* name lookup */

- (id) lookupUser: (NSString *) _key
	inContext: (id)_ctx
{
  SOGoUser *user;
  id userFolder;

  user = [SOGoUser userWithLogin: _key roles: nil];
  if (user)
    userFolder = [$(@"SOGoUserFolder") objectWithName: _key
                                          inContainer: self];
  else
    userFolder = nil;

  return userFolder;
}

- (void) _setupLocaleInContext: (WOContext *) _ctx
{
  NSArray      *langs;
  NSDictionary *locale;
  
  if ([[_ctx valueForKey:@"locale"] isNotNull])
    return;

  langs = [[_ctx request] browserLanguages];
  locale = [self currentLocaleConsideringLanguages:langs];
  [_ctx takeValue:locale forKey:@"locale"];
}

- (id) lookupName: (NSString *) _key
        inContext: (id) _ctx
          acquire: (BOOL) _flag
{
  id obj;
  WORequest *request;
  BOOL isDAVRequest;
  SOGoSystemDefaults *sd;

  /* put locale info into the context in case it's not there */
  [self _setupLocaleInContext:_ctx];

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  request = [_ctx request];
  isDAVRequest = [[request requestHandlerKey] isEqualToString:@"dav"];
  if (isDAVRequest || [sd isWebAccessEnabled])
    {
      if (isDAVRequest)
        {
          if ([_key isEqualToString: @"public"] && [sd enablePublicAccess])
            obj = [SOGoPublicBaseFolder objectWithName: @"public" inContainer: self];
          else if ([[request method] isEqualToString: @"REPORT"])
            obj = [self davReportInvocationForKey: _key];
          else
            obj = nil;
        }
      else
        {
          /* first check attributes directly bound to the application */
          obj = [super lookupName:_key inContext:_ctx acquire:_flag];
        }

      if (!obj)
        {
          /* 
             The problem is, that at this point we still get request for
             resources, eg 'favicon.ico'.
             
             Addition: we also get queries for various other methods, like
             "GET" if no method was provided in the query path.
          */
          if ([_key length] > 0 && ![_key isEqualToString:@"favicon.ico"])
            obj = [self lookupUser: _key inContext: _ctx];
        }
    }
  else
    obj = nil;

  return obj;
}

- (BOOL) isInPublicZone
{
  return NO;
}

/* WebDAV */

- (NSString *) davDisplayName
{
  /* this is used in the UI, eg in the navigation */
  return @"SOGo";
}

/* exception handling */

- (WOResponse *) handleException: (NSException *) _exc
                       inContext: (WOContext *) _ctx
{
  printf("EXCEPTION: %s\n", [[_exc description] cString]);
  abort();
}

/* runtime maintenance */

- (void) checkIfDaemonHasToBeShutdown
{
  unsigned int vmem;

  if (vMemSizeLimit > 0)
    {
      vmem = [[NSProcessInfo processInfo] virtualMemorySize]/1048576;

      if (vmem > vMemSizeLimit)
        {
          [self logWithFormat:
                  @"terminating app, vMem size limit (%d MB) has been reached"
                @" (currently %d MB)",
                vMemSizeLimit, vmem];
          [self terminate];
        }
    }
}

- (WOResponse *) dispatchRequest: (WORequest *) _request
{
  static NSArray *runLoopModes = nil;
  static BOOL debugOn = NO;
  WOResponse *resp;
  NSDate *startDate;
  NSTimeInterval timeDelta;

  if (debugRequests)
    {
      [self logWithFormat: @"starting method '%@' on uri '%@'",
	    [_request method], [_request uri]];
      startDate = [NSDate date];
    }

  cache = [SOGoCache sharedCache];
#ifdef GNUSTEP_BASE_LIBRARY
  if (debugLeaks)
    {
      if (debugOn)
        NSLog (@"allocated classes:\n%s", GSDebugAllocationList (YES));
      else
        {
          debugOn = YES;
          GSDebugAllocationActive (YES);
        }
    }
#endif

  resp = [super dispatchRequest: _request];
  [cache killCache];

  if (debugRequests)
    {
      timeDelta = [[NSDate date] timeIntervalSinceDate: startDate];
      [self logWithFormat: @"request took %f seconds to execute",
            timeDelta];
      [resp setHeader: [NSString stringWithFormat: @"%f", timeDelta]
               forKey: @"SOGo-Request-Duration"];
    }

  if (![self isTerminating])
    {
      if (!runLoopModes)
        runLoopModes = [[NSArray alloc] initWithObjects: NSDefaultRunLoopMode, nil];
  
      // TODO: a bit complicated? (-perform:afterDelay: doesn't work?)
      [[NSRunLoop currentRunLoop] performSelector:
                                    @selector (checkIfDaemonHasToBeShutdown)
                                  target: self argument: nil
                                  order:1 modes:runLoopModes];
    }

  return resp;
}

/* session management */

- (NSString *) sessionIDFromRequest: (WORequest *) _rq
{
  return nil;
}

- (id) createSessionForRequest: (WORequest *) _request
{
  [self warnWithFormat: @"session creation requested!"];
  if (doCrashOnSessionCreate)
    abort();
  return [super createSessionForRequest:_request];
}

/* localization */

- (NSDictionary *) currentLocaleConsideringLanguages: (NSArray *) langs
{
  NSEnumerator *enumerator;
  NSString *lname;
  NSDictionary *locale;

  enumerator = [langs objectEnumerator];
  lname = nil;
  locale = nil;
  lname = [enumerator nextObject];
  while (lname && !locale)
    {
      locale = [[self resourceManager] localeForLanguageNamed: lname];
      lname = [enumerator nextObject];
    }

  if (!locale)
    // no appropriate language, fallback to default
    locale = [[self resourceManager] localeForLanguageNamed: @"English"];

  return locale;
}

- (NSURL *) _urlPreferringParticle: (NSString *) expected
		       overThisOne: (NSString *) possible
{
  NSURL *serverURL, *url;
  NSMutableArray *path;
  NSString *baseURL, *urlMethod;
  WOContext *context;

  context = [self context];
  serverURL = [context serverURL];
  baseURL = [[self baseURLInContext: context] stringByUnescapingURL];
  path = [NSMutableArray arrayWithArray: [baseURL componentsSeparatedByString:
						    @"/"]];
  if ([baseURL hasPrefix: @"http"])
    {
      [path removeObjectAtIndex: 1];
      [path removeObjectAtIndex: 0];
      [path replaceObjectAtIndex: 0 withObject: @""];
    }
  urlMethod = [path objectAtIndex: 2];
  if (![urlMethod isEqualToString: expected])
    {
      if ([urlMethod isEqualToString: possible])
	[path replaceObjectAtIndex: 2 withObject: expected];
      else
	[path insertObject: expected atIndex: 2];
    }

  url = [[NSURL alloc] initWithScheme: [serverURL scheme]
		       host: [serverURL host]
		       path: [path componentsJoinedByString: @"/"]];
  [url autorelease];

  return url;
}

- (NSURL *) davURL
{
  return [self _urlPreferringParticle: @"dav" overThisOne: @"so"];
}

- (NSString *) davURLAsString
{
  NSURL *davURL;
  NSString *davURLAsString;
  WORequest *request;

  /* we know that GNUstep returns a "/" suffix for the absoluteString but not
     for the path method. Therefore we add one. */
  if (useRelativeURLs)
    {
      request = [[self context] request];
      davURLAsString = [NSString stringWithFormat: @"/%@/dav/",
                                 [request applicationName]];
    }
  else
    {
      davURL = [self davURL];
      davURLAsString = [davURL absoluteString];
    }

  return davURLAsString;
}

- (NSURL *) soURL
{
  return [self _urlPreferringParticle: @"so" overThisOne: @"dav"];
}

/* name (used by the WEResourceManager) */

- (NSString *) name
{
  return @"SOGo";
}

@end /* SOGo */
