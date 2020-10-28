/* SOGoSieveManager.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2019 Inverse inc.
 *
 * Author: Inverse <info@inverse.ca>
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoTextTemplateFile.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+Ext.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGSieveClient.h>
#import <NGObjWeb/NSException+HTTP.h>

#import "../Mailer/SOGoMailAccount.h"

#import "SOGoSieveManager.h"

typedef enum {
  UIxFilterFieldTypeAddress,
  UIxFilterFieldTypeHeader,
  UIxFilterFieldTypeBody,
  UIxFilterFieldTypeSize,
} UIxFilterFieldType;

static NSArray *sieveOperators = nil;
static NSArray *sieveSizeOperators = nil;
static NSMutableDictionary *fieldTypes = nil;
static NSDictionary *sieveFields = nil;
static NSDictionary *sieveFlags = nil;
static NSDictionary *typeRequirements = nil;
static NSDictionary *operatorRequirements = nil;
static NSMutableDictionary *methodRequirements = nil;
static NSString *sieveScriptName = @"sogo";


@interface NSString (SOGoSieveExtension)

- (NSString *) asSieveQuotedString;

@end

@implementation NSString (SOGoSieveExtension)

- (NSString *) _asSingleLineSieveQuotedString
{
  NSString *escapedString;

  escapedString =  [[self stringByReplacingString: @"\\"
                                       withString: @"\\\\"]
                                    stringByReplacingString: @"\""
                                                 withString: @"\\\""];

  return [NSString stringWithFormat: @"\"%@\"", escapedString];
}

- (NSString *) _asMultiLineSieveQuotedString
{
  NSArray *lines;
  NSMutableArray *newLines;
  NSString *line, *newText;
  int count, max;

  lines = [self componentsSeparatedByString: @"\n"];
  max = [lines count];
  newLines = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      line = [lines objectAtIndex: count];
      if ([line length] > 0 && [line characterAtIndex: 0] == '.')
        [newLines addObject: [NSString stringWithFormat: @".%@", line]];
      else
        [newLines addObject: line];
    }

  newText = [NSString stringWithFormat: @"text:\r\n%@\r\n.\r\n",
                      [newLines componentsJoinedByString: @"\n"]];

  return newText;
}

- (NSString *) asSieveQuotedString
{
  NSRange nlRange;

  nlRange = [self rangeOfString: @"\n"];

  return ((nlRange.length > 0)
          ? [self _asMultiLineSieveQuotedString]
          : [self _asSingleLineSieveQuotedString]);
}

@end

@implementation SOGoSieveManager

+ (void) initialize
{
  NSArray *fields;

  if (!sieveOperators)
    {
      sieveOperators = [NSArray arrayWithObjects: @"is", @"contains",
                                @"matches", @"regex",
                                @"over", @"under", nil];
      [sieveOperators retain];
    }
  if (!sieveSizeOperators)
    {
      sieveSizeOperators = [NSArray arrayWithObjects: @"over", @"under", nil];
      [sieveSizeOperators retain];
    }
  if (!fieldTypes)
    {
      fieldTypes = [NSMutableDictionary new];
      fields = [NSArray arrayWithObjects: @"to", @"cc", @"to_or_cc", @"from",
                        nil];
      [fieldTypes setObject: [NSNumber numberWithInt: UIxFilterFieldTypeAddress]
                    forKeys: fields];
      fields = [NSArray arrayWithObjects: @"header", @"subject", nil];
      [fieldTypes setObject: [NSNumber numberWithInt: UIxFilterFieldTypeHeader]
                    forKeys: fields];
      [fieldTypes setObject: [NSNumber numberWithInt: UIxFilterFieldTypeBody]
                     forKey: @"body"];
      [fieldTypes setObject: [NSNumber numberWithInt: UIxFilterFieldTypeSize]
                     forKey: @"size"];
    }
  if (!sieveFields)
    {
      sieveFields
        = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"\"to\"",  @"to",
                        @"\"cc\"", @"cc",
                        @"[\"to\", \"cc\"]", @"to_or_cc",
                        @"\"from\"", @"from",
                        @"\"subject\"", @"subject",
                        nil];
      [sieveFields retain];
    }
  if (!sieveFlags)
    {
      sieveFlags
        = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"\\Answered", @"answered",
                        @"\\Deleted", @"deleted",
                        @"\\Draft", @"draft",
                        @"\\Flagged", @"flagged",
                        @"Junk", @"junk",
                        @"NotJunk", @"not_junk",
                        @"\\Seen", @"seen",
                        nil];
      [sieveFlags retain];
    }
  if (!typeRequirements)
    {
      typeRequirements
        = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"body", [NSNumber numberWithInt: UIxFilterFieldTypeBody],
                        nil];
      [typeRequirements retain];
    }
  if (!operatorRequirements)
    {
      operatorRequirements
        = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"regex", @"regex",
                        nil];
      [operatorRequirements retain];
    }
  if (!methodRequirements)
    {
      methodRequirements
        = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 @"imapflags", @"addflag",
                               @"imapflags", @"removeflag",
                               @"imapflags", @"flag",
                               @"vacation", @"vacation",
                               @"notify", @"notify",
                               @"fileinto", @"fileinto",
                               @"reject", @"reject",
                               @"regex", @"regex",
                               nil];
      [methodRequirements retain];
    }
}

+ (id) sieveManagerForUser: (SOGoUser *) newUser
{
  SOGoSieveManager *newManager;

  newManager = [[self alloc] initForUser: newUser];
  [newManager autorelease];

  return newManager;
}

- (id) init
{
  if ((self = [super init]))
    {
      user = nil;
      requirements = nil;
      scriptError = nil;
    }

  return self;
}

- (id) initForUser: (SOGoUser *) newUser
{
  if ((self = [self init]))
    {
      ASSIGN (user, newUser);
    }

  return self;
}

- (void) dealloc
{
  [user release];
  [requirements release];
  [scriptError release];
  [super dealloc];
}

- (BOOL) _saveFilters
{
  return YES;
}

- (NSString *) _extractRequirementsFromContent: (NSString *) theContent
                                     intoArray: (NSMutableArray *) theRequirements
{
  NSString *line, *v;
  NSArray *lines;
  id o;

  int i, count;

  lines = [theContent componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
  count = [lines count];

  for (i = 0; i < count; i++)
    {
      line = [[lines objectAtIndex: i] stringByTrimmingSpaces];
      if ([line hasPrefix: @"require "])
        {
          line = [line substringFromIndex: 8];
          // Handle lines like: require "imapflags";
          if ([line characterAtIndex: 0] == '"')
            {
              v = [line substringToIndex: [line length]-2];
              [theRequirements addObject: v];
            }
          // Else handle lines like: require ["imapflags","vacation"];
          else if ([line characterAtIndex: 0] == '[')
            {
              o = [[line substringToIndex: [line length]-1] objectFromJSONString];
              [theRequirements addObjectsFromArray: o];
            }
        }
      else
        break;
    }

  return [[lines subarrayWithRange: NSMakeRange(i, count-i)] componentsJoinedByString: @"\n"];
}

- (BOOL) _extractRuleField: (NSString **) field
                  fromRule: (NSDictionary *) rule
                   andType: (UIxFilterFieldType *) type
{
  NSNumber *fieldType;
  NSString *jsonField, *customHeader, *requirement;

  jsonField = [rule objectForKey: @"field"];
  if (jsonField)
    {
      fieldType = [fieldTypes objectForKey: jsonField];
      if (fieldType)
        {
          *type = [fieldType intValue];
          if ([jsonField isEqualToString: @"header"])
            {
              customHeader = [rule objectForKey: @"custom_header"];
              if ([customHeader length])
                *field = [customHeader asSieveQuotedString];
              else
                scriptError = (@"Pseudo-header field 'header' without"
                               @" 'custom_header' parameter.");
            }
          else if ([jsonField isEqualToString: @"body"] ||
                   [jsonField isEqualToString: @"size"])
            *field = nil;
          else
            *field = [sieveFields objectForKey: jsonField];

          requirement = [typeRequirements objectForKey: fieldType];
          if (requirement)
            [requirements addObjectUniquely: requirement];
        }
      else
        scriptError
          = [NSString stringWithFormat: @"Rule based on unknown field '%@'",
                      jsonField];
    }
  else
    scriptError = @"Rule without any specified field.";

  return (scriptError == nil);
}

- (BOOL) _extractRuleOperator: (NSString **) operator
                     fromRule: (NSDictionary *) rule
                        isNot: (BOOL *) isNot
{
  NSString *jsonOperator, *baseOperator, *requirement;
  int baseLength;

  jsonOperator = [rule objectForKey: @"operator"];
  if (jsonOperator)
    {
      *isNot = [jsonOperator hasSuffix: @"_not"];
      if (*isNot)
        {
          baseLength = [jsonOperator length] - 4;
          baseOperator
            = [jsonOperator substringWithRange: NSMakeRange (0, baseLength)];
        }
      else
        baseOperator = jsonOperator;

      if ([sieveOperators containsObject: baseOperator])
        {
          requirement = [operatorRequirements objectForKey: baseOperator];
          if (requirement)
            [requirements addObjectUniquely: requirement];
          *operator = baseOperator;
        }
      else
        scriptError = [NSString stringWithFormat:
                                  @"Rule has unknown operator '%@'",
                                baseOperator];
    }
  else
    scriptError = @"Rule without any specified operator";

  return (scriptError == nil);
}

- (BOOL) _validateRuleOperator: (NSString *) operator
                 withFieldType: (UIxFilterFieldType) type
{
  BOOL rc;

  if (type == UIxFilterFieldTypeSize)
    rc = [sieveSizeOperators containsObject: operator];
  else
    // Header and Body types
    rc = (![sieveSizeOperators containsObject: operator]
          && [sieveOperators containsObject: operator]);

  return rc;
}

- (BOOL) _extractRuleValue: (NSString **) value
                  fromRule: (NSDictionary *) rule
             withFieldType: (UIxFilterFieldType) type
{
  NSString *extractedValue;

  extractedValue = [rule objectForKey: @"value"];
  if (extractedValue)
    {
      if (type == UIxFilterFieldTypeSize)
        *value = [NSString stringWithFormat: @"%d",
                           [extractedValue intValue]];
      else
        *value = [extractedValue asSieveQuotedString];
    }
  else
    scriptError = @"Rule lacks a 'value' parameter";

  return (scriptError == nil);
}

- (NSString *) _composeSieveRuleOnField: (NSString *) field
                               withType: (UIxFilterFieldType) type
                               operator: (NSString *) operator
                                 revert: (BOOL) revert
                               andValue: (NSString *) value
{
  NSMutableString *sieveRule;

  sieveRule = [NSMutableString stringWithCapacity: 100];
  if (revert)
    [sieveRule appendString: @"not "];

  if (type == UIxFilterFieldTypeAddress)
    [sieveRule appendString: @"address "];
  else if (type == UIxFilterFieldTypeHeader)
    [sieveRule appendString: @"header "];
  else if (type == UIxFilterFieldTypeBody)
    [sieveRule appendString: @"body :text "];
  else if (type == UIxFilterFieldTypeSize)
    [sieveRule appendString: @"size "];
  [sieveRule appendFormat: @":%@ ", operator];

  if (type == UIxFilterFieldTypeSize)
    [sieveRule appendFormat: @"%@K", value];
  else if (field)
    [sieveRule appendFormat: @"%@ %@", field, value];
  else
    [sieveRule appendFormat: @"%@", value];

  return sieveRule;
}

- (NSString *) _extractSieveRule: (NSDictionary *) rule
{
  NSString *field, *operator, *value;
  UIxFilterFieldType type;
  BOOL isNot;

  return (([self _extractRuleField: &field fromRule: rule andType: &type]
           && [self _extractRuleOperator: &operator fromRule: rule
                                   isNot: &isNot]
           && [self _validateRuleOperator: operator
                            withFieldType: type]
           && [self _extractRuleValue: &value fromRule: rule
                        withFieldType: type])
          ? [self _composeSieveRuleOnField: field
                                  withType: type
                                  operator: operator
                                    revert: isNot
                                  andValue: value]
          : nil);
}

- (NSArray *) _extractSieveRules: (NSArray *) rules
{
  NSMutableArray *sieveRules;
  NSString *sieveRule;
  int count, max;

  max = [rules count];
  if (max)
    {
      sieveRules = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; !scriptError && count < max; count++)
        {
          sieveRule = [self _extractSieveRule: [rules objectAtIndex: count]];
          if (sieveRule)
            [sieveRules addObject: sieveRule];
        }
    }
  else
    sieveRules = nil;

  return sieveRules;
}

- (NSString *) _extractSieveAction: (NSDictionary *) action
                         delimiter: (NSString *) delimiter
{
  NSString *sieveAction, *method, *requirement, *argument, *flag, *mailbox;
  NSDictionary *mailLabels;

  sieveAction = nil;

  method = [action objectForKey: @"method"];
  if (method)
    {
      argument = [action objectForKey: @"argument"];
      if ([method isEqualToString: @"discard"]
          || [method isEqualToString: @"keep"]
          || [method isEqualToString: @"stop"])
        sieveAction = method;
      else
        {
          if (argument)
            {
              if ([method isEqualToString: @"addflag"])
                {
                  flag = [sieveFlags objectForKey: argument];
                  if (!flag)
                    {
                      mailLabels = [[user userDefaults] mailLabelsColors];
                      if ([mailLabels objectForKey: argument])
                        flag = argument;
                    }
                  if (flag)
                    sieveAction = [NSString stringWithFormat: @"%@ %@",
                                            method, [flag asSieveQuotedString]];
                  else
                    scriptError
                      = [NSString stringWithFormat:
                                    @"Action with invalid flag argument '%@'",
                                  argument];
                }
              else if ([method isEqualToString: @"fileinto"])
                {
                  mailbox
                    = [[argument componentsSeparatedByString: @"/"]
                          componentsJoinedByString: delimiter];
                  sieveAction = [NSString stringWithFormat: @"%@ %@",
                                          method, [mailbox asSieveQuotedString]];
                }
              else if ([method isEqualToString: @"redirect"])
                sieveAction = [NSString stringWithFormat: @"%@ %@",
                                        method, [argument asSieveQuotedString]];
              else if ([method isEqualToString: @"reject"])
                sieveAction = [NSString stringWithFormat: @"%@ %@",
                                method, [argument asSieveQuotedString]];
              else
                scriptError
                  = [NSString stringWithFormat: @"Action has unknown method '%@'",
                              method];
            }
          else
            scriptError = @"Action missing 'argument' parameter";
        }
      if (method)
        {
          requirement = [methodRequirements objectForKey: method];
          if (requirement)
            [requirements addObjectUniquely: requirement];
        }
    }
  else
    scriptError = @"Action missing 'method' parameter";

  return sieveAction;
}

- (NSArray *) _extractSieveActions: (NSArray *) actions
                         delimiter: (NSString *) delimiter
{
  NSMutableArray *sieveActions;
  NSString *sieveAction;
  int count, max;

  max = [actions count];
  sieveActions = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; !scriptError && count < max; count++)
    {
      sieveAction = [self _extractSieveAction: [actions objectAtIndex: count]
                                    delimiter: delimiter];
      if (!scriptError)
        [sieveActions addObject: sieveAction];
    }

  return sieveActions;
}

- (NSString *) _convertScriptToSieve: (NSDictionary *) newScript
                           delimiter: (NSString *) delimiter
{
  NSMutableString *sieveText;
  NSString *match;
  NSArray *sieveRules, *sieveActions;

  sieveText = [NSMutableString stringWithCapacity: 1024];
  match = [newScript objectForKey: @"match"];
  if ([match isEqualToString: @"allmessages"])
    match = nil;
  if (match)
    {
      if ([match isEqualToString: @"all"] || [match isEqualToString: @"any"])
        {
          sieveRules = [self _extractSieveRules: [newScript objectForKey: @"rules"]];
          if (sieveRules)
            [sieveText appendFormat: @"if %@of (%@) {\r\n",
                       match,
                       [sieveRules componentsJoinedByString: @", "]];
          else
            scriptError = [NSString stringWithFormat:
                                    @"Test '%@' used without any"
                                    @" specified rule",
                                    match];
        }
      else
        scriptError = [NSString stringWithFormat: @"Bad test: %@", match];
    }
  sieveActions = [self _extractSieveActions: [newScript objectForKey: @"actions"]
                                  delimiter: delimiter];
  if ([sieveActions count])
    [sieveText appendFormat: @"    %@;\r\n",
               [sieveActions componentsJoinedByString: @";\r\n    "]];

  if (match)
    [sieveText appendFormat: @"}\r\n"];

  return sieveText;
}

- (NSString *) sieveScriptWithRequirements: (NSMutableArray *) newRequirements
                                 delimiter: (NSString *) delimiter
{
  NSMutableString *sieveScript;
  NSString *sieveText;
  NSArray *scripts;
  int count, max;
  NSDictionary *currentScript;

  sieveScript = [NSMutableString string];

  ASSIGN(requirements, newRequirements);
  [scriptError release];
  scriptError = nil;

  scripts = [[user userDefaults] sieveFilters];
  max = [scripts count];
  if (max)
    {
      for (count = 0; !scriptError && count < max; count++)
        {
          currentScript = [scripts objectAtIndex: count];
          if ([[currentScript objectForKey: @"active"] boolValue])
            {
              sieveText = [self _convertScriptToSieve: currentScript
                                            delimiter: delimiter];
              [sieveScript appendString: sieveText];
            }
        }
    }

  [scriptError retain];
  DESTROY(requirements);

  if (scriptError)
    sieveScript = nil;

  return sieveScript;
}

- (NSString *) lastScriptError
{
  return scriptError;
}

//
//
//
- (NGSieveClient *) clientForAccount: (SOGoMailAccount *) theAccount
{
  return [self clientForAccount: theAccount withUsername: nil andPassword: nil];
}

//
//
//
- (NGSieveClient *) clientForAccount: (SOGoMailAccount *) theAccount
                        withUsername: (NSString *) theUsername
                         andPassword: (NSString *) thePassword
{
  NSDictionary *result;
  NSString *login, *authname, *password;
  SOGoDomainDefaults *dd;
  NGSieveClient *client;
  NSString *sieveServer, *sieveScheme, *sieveQuery, *imapServer;
  NSURL *url, *cUrl;
  int sievePort;
  BOOL connected;

  dd = [user domainDefaults];
  connected = YES;

  // Extract credentials from mail account
  login = [[theAccount imap4URL] user];
  if (!theUsername && !thePassword)
    {
      authname = [[theAccount imap4URL] user];
      password = [theAccount imap4PasswordRenewed: NO];
    }
  else
    {
      authname = theUsername;
      password = thePassword;
    }

  // We connect to our Sieve server and check capabilities, in order
  // to generate the right script, based on capabilities
  //
  // sieveServer might have the following format:
  //
  // sieve://localhost
  // sieve://localhost:4190
  // sieve://localhost:4190/?tls=YES
  //
  // Values such as "localhost" or "localhost:4190" are NOT supported.
  //
  // We first try to get the user's preferred Sieve server
  sieveServer = [[[user mailAccounts] objectAtIndex: 0] objectForKey: @"sieveServerName"];
  imapServer = [[[user mailAccounts] objectAtIndex: 0] objectForKey: @"serverName"];

  cUrl = [NSURL URLWithString: (sieveServer ? sieveServer : @"")];

  if ([dd sieveServer] && [[dd sieveServer] length] > 0)
    url = [NSURL URLWithString: [dd sieveServer]];
  else
    url = [NSURL URLWithString: @"localhost"];

  if ([cUrl host])
    sieveServer = [cUrl host];
  if (!sieveServer && [url host])
    sieveServer = [url host];
  if (!sieveServer && [dd sieveServer])
    sieveServer = [dd sieveServer];
  if (!sieveServer && imapServer)
    sieveServer = [[NSURL URLWithString: imapServer] host];
  if (!sieveServer)
    sieveServer = @"localhost";

  sieveScheme = [cUrl scheme] ? [cUrl scheme] : [url scheme];
  if (!sieveScheme)
    sieveScheme = @"sieve";

  if ([cUrl port])
    sievePort = [[cUrl port] intValue];
  else
    if ([url port])
      sievePort = [[url port] intValue];
    else
      sievePort = 4190;

  sieveQuery = [cUrl query] ? [cUrl query] : [url query];
  if (sieveQuery)
    sieveQuery = [NSString stringWithFormat: @"/?%@", sieveQuery];
  else
    sieveQuery = @"";

  url = [NSURL URLWithString: [NSString stringWithFormat: @"%@://%@:%d%@",
                               sieveScheme, sieveServer, sievePort, sieveQuery]];

  client = [[NGSieveClient alloc] initWithURL: url];

  if (!client) {
    [self errorWithFormat: @"Sieve connection failed on %@", [url description]];
    return nil;
  }

  if (!password) {
    [client closeConnection];
    return nil;
  }

  NS_DURING
    {
      result = [client login: login  authname: authname  password: password];
    }
  NS_HANDLER
    {
      connected = NO;
    }
  NS_ENDHANDLER

  if (!connected)
    {
      [self errorWithFormat: @"Sieve connection failed on %@", [url description]];
      return nil;
    }

  if (![[result valueForKey:@"result"] boolValue] && !theUsername && !thePassword) {
    [self logWithFormat: @"failure. Attempting with a renewed password (no authname supported)"];
    password = [theAccount imap4PasswordRenewed: YES];
    result = [client login: login  password: password];
  }

  if (![[result valueForKey:@"result"] boolValue]) {
    [self logWithFormat: @"Could not login '%@' on Sieve server: %@: %@",
	  login, client, result];
    [client closeConnection];
    return nil;
  }

  return [client autorelease];
}

- (BOOL) hasActiveExternalSieveScripts: (NGSieveClient *) client
{
  NSDictionary *scripts;
  NSEnumerator *keys;
  NSString *key;

  scripts = [client listScripts];

  keys = [scripts keyEnumerator];
  while ((key = [keys nextObject]))
    {
      if ([key caseInsensitiveCompare: @"sogo"] != NSOrderedSame &&
          [[scripts objectForKey: key] intValue] > 0)
        return YES;
    }

  return NO;
}

//
//
//
- (NSException *) updateFiltersForAccount: (SOGoMailAccount *) theAccount
{
  return [self updateFiltersForAccount: theAccount
                          withUsername: nil
                           andPassword: nil
                       forceActivation: NO];
}

//
//
//
- (NSException *) updateFiltersForAccount: (SOGoMailAccount *) theAccount
                    withUsername: (NSString *) theUsername
                     andPassword: (NSString *) thePassword
                 forceActivation: (BOOL) forceActivation
{
  NSString *filterScript, *v, *delimiter, *content, *message;
  NSMutableArray *req;
  NSMutableString *script, *header;
  NSDictionary *result, *values;
  NSException *error;
  SOGoUserDefaults *ud;
  SOGoDomainDefaults *dd;
  NGSieveClient *client;
  NGImap4Client *imapClient;
  BOOL b, activate, dateCapability;
  unsigned int now;

  error = nil;
  dd = [user domainDefaults];
  if (!([dd sieveScriptsEnabled] || [dd vacationEnabled] || [dd forwardEnabled]))
    return error;

  req = [NSMutableArray arrayWithCapacity: 15];
  ud = [user userDefaults];

  client = [self clientForAccount: theAccount  withUsername: theUsername  andPassword: thePassword];
  if (!client)
    {
      error = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                                            reason: @"Error while connecting to Sieve server."];
      return error;
    }


  // Activate script Sieve when forced or when no external script is enabled
  activate = forceActivation || ![self hasActiveExternalSieveScripts: client];

  // We adjust the "methodRequirements" based on the server's
  // capabilities. Cyrus exposes "imapflags" while Dovecot (and
  // potentially others) expose "imap4flags" as specified in RFC5332
  if ([client hasCapability: @"imap4flags"])
    {
      [methodRequirements setObject: @"imap4flags"  forKey: @"addflag"];
      [methodRequirements setObject: @"imap4flags"  forKey: @"removeflag"];
      [methodRequirements setObject: @"imap4flags"  forKey: @"flag"];
    }

  dateCapability = [client hasCapability: @"date"] && [client hasCapability: @"relational"];

  //
  // Now let's generate the script
  //
  script = [NSMutableString string];

  // We grab the IMAP4 delimiter using the supplied username/password
  if (thePassword)
    {
      imapClient = [NGImap4Client clientWithURL: [theAccount imap4URL]];
      [imapClient login: theUsername  password: thePassword];
    }
  else
    imapClient = [[theAccount imap4Connection] client];

  delimiter = [imapClient delimiter];

  if (!delimiter)
    [imapClient list: @"INBOX"  pattern: @""];

  if (!delimiter)
    delimiter = [dd stringForKey: @"NGImap4ConnectionStringSeparator"];

  // We first handle filters
  filterScript = [self sieveScriptWithRequirements: req
                                         delimiter: delimiter];
  if (filterScript)
    {
      if ([filterScript length])
        {
          b = YES;
          [script appendString: filterScript];
        }
    }
  else
    {
      message = [NSString stringWithFormat: @"Sieve generation failure: %@", [self lastScriptError]];
      [self errorWithFormat: message];
      [client closeConnection];
      error = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                                            reason: message];
      return error;
    }

  //
  // We handle vacation messages.
  // See http://ietfreport.isoc.org/idref/draft-ietf-sieve-vacation/
  //
  values = [ud vacationOptions];
  now = [[NSCalendarDate calendarDate] timeIntervalSince1970];

  if (values && [[values objectForKey: @"enabled"] boolValue] &&
      (![[values objectForKey: @"startDateEnabled"] boolValue] ||
       dateCapability || [[values objectForKey: @"startDate"] intValue] < now) &&
      (![[values objectForKey: @"endDateEnabled"] boolValue] ||
       dateCapability || [[values objectForKey: @"endDate"] intValue] > now))
    {
      NSCalendarDate *startDate, *endDate;
      NSMutableArray *allConditions;
      NSMutableString *vacation_script;
      NSArray *addresses;
      NSString *text, *templateFilePath, *customSubject;
      SOGoTextTemplateFile *templateFile;

      BOOL ignore, alwaysSend, useCustomSubject, discardMails;
      int days, i;

      allConditions = [NSMutableArray array];
      days = [[values objectForKey: @"daysBetweenResponse"] intValue];
      addresses = [values objectForKey: @"autoReplyEmailAddresses"];
      alwaysSend = [[values objectForKey: @"alwaysSend"] boolValue];
      discardMails = [[values objectForKey: @"discardMails"] boolValue];
      ignore = [[values objectForKey: @"ignoreLists"] boolValue];
      useCustomSubject = [[values objectForKey: @"customSubjectEnabled"] boolValue];
      customSubject = [values objectForKey: @"customSubject"];
      text = [values objectForKey: @"autoReplyText"];
      b = YES;

      if (!text)
        text = @"";

      if (!useCustomSubject)
        {
          // If user has not specified a custom subject, fallback to the domain's defaults
          customSubject = [dd vacationDefaultSubject];
          useCustomSubject = [customSubject length] > 0;
        }

      /* Add autoresponder header if configured */
      templateFilePath = [dd vacationHeaderTemplateFile];
      if (templateFilePath)
        {
          templateFile = [SOGoTextTemplateFile textTemplateFromFile: templateFilePath];
          if (templateFile)
            text = [NSString stringWithFormat: @"%@%@", [templateFile textForUser: user], text];
        }

      /* Add autoresponder footer if configured */
      templateFilePath = [dd vacationFooterTemplateFile];
      if (templateFilePath)
        {
          templateFile = [SOGoTextTemplateFile textTemplateFromFile: templateFilePath];
          if (templateFile)
            text = [NSString stringWithFormat: @"%@%@", text, [templateFile textForUser: user]];
        }

      if (days == 0)
        days = 7;

      vacation_script = [NSMutableString string];

      [req addObjectUniquely: @"vacation"];

      // Skip mailing lists
      if (ignore)
        {
          [allConditions addObject: @"not exists [\"list-help\", \"list-unsubscribe\", \"list-subscribe\", \"list-owner\", \"list-post\", \"list-archive\", \"list-id\", \"Mailing-List\"]"];
          [allConditions addObject: @"not header :comparator \"i;ascii-casemap\" :is \"Precedence\" [\"list\", \"bulk\", \"junk\"]"];
          [allConditions addObject: @"not header :comparator \"i;ascii-casemap\" :matches \"To\" \"Multiple recipients of*\""];
        }

      // Start date of auto-reply
      if ([dd vacationPeriodEnabled] &&
          [[values objectForKey: @"startDateEnabled"] boolValue] &&
          dateCapability)
        {
          [req addObjectUniquely: @"date"];
          [req addObjectUniquely: @"relational"];
          startDate = [NSCalendarDate dateWithTimeIntervalSince1970:
                                              [[values objectForKey: @"startDate"] intValue]];
          [allConditions addObject: [NSString stringWithFormat: @"currentdate :value \"ge\" \"date\" \"%@\"",
                                              [startDate descriptionWithCalendarFormat: @"%Y-%m-%d"]]];
        }

      // End date of auto-reply
      if ([dd vacationPeriodEnabled] &&
          [[values objectForKey: @"endDateEnabled"] boolValue] &&
          dateCapability)
        {
          [req addObjectUniquely: @"date"];
          [req addObjectUniquely: @"relational"];
          endDate = [NSCalendarDate dateWithTimeIntervalSince1970:
                                              [[values objectForKey: @"endDate"] intValue]];
          [allConditions addObject: [NSString stringWithFormat: @"currentdate :value \"le\" \"date\" \"%@\"",
                                              [endDate descriptionWithCalendarFormat: @"%Y-%m-%d"]]];
        }

      // Apply conditions
      if ([allConditions count])
        [vacation_script appendFormat: @"if allof ( %@ ) { ",
                         [allConditions componentsJoinedByString: @", "]];

      // Custom subject
      if (useCustomSubject)
        {
          if (([customSubject rangeOfString: @"${subject}"].location != NSNotFound) &&
              [client hasCapability: @"variables"])
            {
              [req addObjectUniquely: @"variables"];
              [vacation_script appendString: @"if header :matches \"Subject\" \"*\" { set \"subject\" \"${1}\"; } "];
            }
        }

      [vacation_script appendFormat: @"vacation :days %d", days];

      if (useCustomSubject)
        [vacation_script appendFormat: @" :subject %@", [customSubject doubleQuotedString]];

      [vacation_script appendString: @" :addresses ["];
      for (i = 0; i < [addresses count]; i++)
        {
          [vacation_script appendFormat: @"\"%@\"", [addresses objectAtIndex: i]];

          if (i == [addresses count]-1)
            [vacation_script appendString: @"] "];
          else
            [vacation_script appendString: @", "];
        }

      [vacation_script appendFormat: @"text:\r\n%@\r\n.\r\n;\r\n", text];

      // Should we discard incoming mails during vacation?
      if (discardMails)
        [vacation_script appendString: @"discard;\r\n"];

      // Closing bracket of conditions
      if ([allConditions count])
        [vacation_script appendString: @"}\r\n"];

      //
      // See https://sogo.nu/bugs/view.php?id=2332 for details
      //
      if (alwaysSend)
        [script insertString: vacation_script  atIndex: 0];
      else
        [script appendString: vacation_script];
    }


  // We handle mail forward
  values = [ud forwardOptions];

  if (values && [[values objectForKey: @"enabled"] boolValue])
    {
      id addresses;
      int i;

      b = YES;

      addresses = [values objectForKey: @"forwardAddress"];
      if ([addresses isKindOfClass: [NSString class]])
        addresses = [addresses componentsSeparatedByString: @","];

      for (i = 0; i < [addresses count]; i++)
        {
          v = [addresses objectAtIndex: i];
          if (v && [v length] > 0)
            [script appendFormat: @"redirect \"%@\";\r\n", v];
        }

      if ([[values objectForKey: @"keepCopy"] boolValue])
        [script appendString: @"keep;\r\n"];
    }

  // We handle header/footer Sieve scripts
  if ((v = [dd sieveScriptHeaderTemplateFile]))
    {
      content = [NSString stringWithContentsOfFile: v
                                          encoding: NSUTF8StringEncoding
                                             error: NULL];
      if (content)
        {
          v = [self _extractRequirementsFromContent: content
                                          intoArray: req];
          [script insertString: v  atIndex: 0];
          b = YES;
        }
    }

  if ((v = [dd sieveScriptFooterTemplateFile]))
    {
      content = [NSString stringWithContentsOfFile: v
                                          encoding: NSUTF8StringEncoding
                                             error: NULL];
      if (content)
        {
          v = [self _extractRequirementsFromContent: content
                                          intoArray: req];
          [script appendString: @"\n"];
          [script appendString: v];
          b = YES;
        }
    }

  if ([req count])
    {
      header = [NSString stringWithFormat: @"require [\"%@\"];\r\n",
                         [[req uniqueObjects] componentsJoinedByString: @"\",\""]];
      [script insertString: header  atIndex: 0];
    }


  /* We ensure to deactive the current active script since it could prevent
     its deletion from the server. */
  if (activate)
    result = [client setActiveScript: @""];
  // We delete the existing Sieve script
  result = [client deleteScript: sieveScriptName];

  if (![[result valueForKey:@"result"] boolValue])
    [self warnWithFormat: @"Could not delete Sieve script: %@", [[result objectForKey: @"RawResponse"] objectForKey: @"reason"]];

  /* We put and activate the script only if we actually have a script
     that does something... */
  if (b && [script length])
    {
      result = [client putScript: sieveScriptName  script: script];

      if (![[result valueForKey:@"result"] boolValue])
        {
          message = [NSString stringWithFormat: @"Could not upload Sieve script: %@", [[result objectForKey: @"RawResponse"] objectForKey: @"reason"]];
          [self errorWithFormat: message];
          [client closeConnection];
          error = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                                            reason: message];
          return error;
        }

      if (activate)
        {
          result = [client setActiveScript: sieveScriptName];
          if (![[result valueForKey:@"result"] boolValue])
            {
              message = [NSString stringWithFormat: @"Could not enable Sieve script: %@", [[result objectForKey: @"RawResponse"] objectForKey: @"reason"]];
              [self errorWithFormat: message];
              [client closeConnection];
              error = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                                                    reason: message];
              return error;
            }
        }
    }

  [client closeConnection];
  return error;
}

@end
