/* SOGoSieveManager.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2015 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGStreams/NGInternetSocketAddress.h>
#import <NGImap4/NGSieveClient.h>

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
{
  NSString *sieveAction, *method, *requirement, *argument, *flag, *mailbox;
  NSDictionary *mailLabels;
  SOGoDomainDefaults *dd;

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
                  dd = [user domainDefaults];
                  mailbox
                    = [[argument componentsSeparatedByString: @"/"]
                          componentsJoinedByString: [dd imapFolderSeparator]];
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
{
  NSMutableArray *sieveActions;
  NSString *sieveAction;
  int count, max;

  max = [actions count];
  sieveActions = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; !scriptError && count < max; count++)
    {
      sieveAction = [self _extractSieveAction: [actions objectAtIndex: count]];
      if (!scriptError)
        [sieveActions addObject: sieveAction];
    }

  return sieveActions;
}

- (NSString *) _convertScriptToSieve: (NSDictionary *) newScript
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
  sieveActions = [self _extractSieveActions: [newScript objectForKey: @"actions"]];
  if ([sieveActions count])
    [sieveText appendFormat: @"    %@;\r\n",
               [sieveActions componentsJoinedByString: @";\r\n    "]];

  if (match)
    [sieveText appendFormat: @"}\r\n"];

  return sieveText;
}

- (NSString *) sieveScriptWithRequirements: (NSMutableArray *) newRequirements
{
  NSMutableString *sieveScript;
  NSString *sieveText;
  NSArray *scripts;
  int count, max;
  NSDictionary *currentScript;

  sieveScript = [NSMutableString string];

  ASSIGN (requirements, newRequirements);
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
              sieveText = [self _convertScriptToSieve: currentScript];
              [sieveScript appendString: sieveText];
            }
        }
    }

  [scriptError retain];
  [requirements release];
  requirements = nil;

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
  // sieve://localhost:2000
  // sieve://localhost:2000/?tls=YES
  //
  // Values such as "localhost" or "localhost:2000" are NOT supported.
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
      sievePort = 2000;

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


//
//
//
- (BOOL) updateFiltersForAccount: (SOGoMailAccount *) theAccount
{
  return [self updateFiltersForAccount: theAccount
                          withUsername: nil
                           andPassword: nil];
}

//
//
//
- (BOOL) updateFiltersForAccount: (SOGoMailAccount *) theAccount
                    withUsername: (NSString *) theUsername
                     andPassword: (NSString *) thePassword
{
  NSMutableArray *req;
  NSMutableString *script, *header;
  NSDictionary *result, *values;
  SOGoUserDefaults *ud;
  SOGoDomainDefaults *dd;
  NGSieveClient *client;
  NSString *filterScript, *v;
  BOOL b;

  dd = [user domainDefaults];
  if (!([dd sieveScriptsEnabled] || [dd vacationEnabled] || [dd forwardEnabled]))
    return YES;

  req = [NSMutableArray arrayWithCapacity: 15];
  ud = [user userDefaults];

  client = [self clientForAccount: theAccount  withUsername: theUsername  andPassword: thePassword];
  if (!client)
    return NO;

  // We adjust the "methodRequirements" based on the server's 
  // capabilities. Cyrus exposes "imapflags" while Dovecot (and
  // potentially others) expose "imap4flags" as specified in RFC5332
  if ([client hasCapability: @"imap4flags"])
    {
      [methodRequirements setObject: @"imap4flags"  forKey: @"addflag"];
      [methodRequirements setObject: @"imap4flags"  forKey: @"removeflag"];
      [methodRequirements setObject: @"imap4flags"  forKey: @"flag"];
    }
  
  //
  // Now let's generate the script
  //
  script = [NSMutableString string];

  // We first handle filters
  filterScript = [self sieveScriptWithRequirements: req];
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
      [self errorWithFormat: @"Sieve generation failure: %@", [self lastScriptError]];
      [client closeConnection];
      return NO;
    }

  // We handle vacation messages.
  // See http://ietfreport.isoc.org/idref/draft-ietf-sieve-vacation/
  values = [ud vacationOptions];

  if (values && [[values objectForKey: @"enabled"] boolValue])
    {
      NSMutableString *vacation_script;
      NSArray *addresses;
      NSString *text;
      
      BOOL ignore, alwaysSend;
      int days, i;
      
      days = [[values objectForKey: @"daysBetweenResponse"] intValue];
      addresses = [values objectForKey: @"autoReplyEmailAddresses"];
      alwaysSend = [[values objectForKey: @"alwaysSend"] boolValue];
      ignore = [[values objectForKey: @"ignoreLists"] boolValue];
      text = [values objectForKey: @"autoReplyText"];
      b = YES;

      if (days == 0)
        days = 7;

      vacation_script = [NSMutableString string];
      
      [req addObjectUniquely: @"vacation"];

      // Skip mailing lists
      if (ignore)
        [vacation_script appendString: @"if allof ( not exists [\"list-help\", \"list-unsubscribe\", \"list-subscribe\", \"list-owner\", \"list-post\", \"list-archive\", \"list-id\", \"Mailing-List\"], not header :comparator \"i;ascii-casemap\" :is \"Precedence\" [\"list\", \"bulk\", \"junk\"], not header :comparator \"i;ascii-casemap\" :matches \"To\" \"Multiple recipients of*\" ) {"];
      
      [vacation_script appendFormat: @"vacation :days %d :addresses [", days];

      for (i = 0; i < [addresses count]; i++)
        {
          [vacation_script appendFormat: @"\"%@\"", [addresses objectAtIndex: i]];
	  
          if (i == [addresses count]-1)
            [vacation_script appendString: @"] "];
          else
            [vacation_script appendString: @", "];
        }
      
      [vacation_script appendFormat: @"text:\r\n%@\r\n.\r\n;\r\n", text];
      
      if (ignore)
        [vacation_script appendString: @"}\r\n"];

      //
      // See http://sogo.nu/bugs/view.php?id=2332 for details
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
        addresses = [NSArray arrayWithObject: addresses];

      for (i = 0; i < [addresses count]; i++)
        {
          v = [addresses objectAtIndex: i];
          if (v && [v length] > 0)
            [script appendFormat: @"redirect \"%@\";\r\n", v];
        }
      
      if ([[values objectForKey: @"keepCopy"] boolValue])
        [script appendString: @"keep;\r\n"];
    }
  
  if ([req count])
    {
      header = [NSString stringWithFormat: @"require [\"%@\"];\r\n",
                         [req componentsJoinedByString: @"\",\""]];
      [script insertString: header  atIndex: 0];
    }


  /* We ensure to deactive the current active script since it could prevent
     its deletion from the server. */
  result = [client setActiveScript: @""];
  // We delete the existing Sieve script
  result = [client deleteScript: sieveScriptName];
  
  if (![[result valueForKey:@"result"] boolValue]) {
    [self logWithFormat: @"WARNING: Could not delete Sieve script - continuing...: %@", result];
  }

  // We put and activate the script only if we actually have a script
  // that does something...
  if (b && [script length])
    {
      result = [client putScript: sieveScriptName  script: script];
      
      if (![[result valueForKey:@"result"] boolValue]) {
        [self logWithFormat: @"Could not upload Sieve script: %@", result];
        [client closeConnection];	
        return NO;
      }
      
      result = [client setActiveScript: sieveScriptName];
      if (![[result valueForKey:@"result"] boolValue]) {
        [self logWithFormat: @"Could not enable Sieve script: %@", result];
        [client closeConnection];
        return NO;
      }
  }

  [client closeConnection];
  return YES;
}

@end
