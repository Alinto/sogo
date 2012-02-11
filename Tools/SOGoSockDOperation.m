/* SOGoSockDOperation.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#include <ldap.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGStreams/NGActiveSocket.h>
#import <Contacts/SOGoContactFolder.h>
#import <Contacts/SOGoContactFolders.h>
#import <Contacts/NSString+LDIF.h>
#import <SOGo/SOGoProductLoader.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>

#import "SOGoSockDOperation.h"

Class SOGoContactSourceFolderKlass = Nil;

@interface _SOGoSockDOperationSearch : SOGoSockDOperation
@end

@interface _SOGoSockDOperationUnbind : SOGoSockDOperation
@end

@implementation SOGoSockDOperation

+ (void) initialize
{
  [[SOGoProductLoader productLoader]
    loadProducts: [NSArray arrayWithObjects: @"Contacts.SOGo", nil]];
  SOGoContactSourceFolderKlass
    = NSClassFromString (@"SOGoContactSourceFolder");
}

+ (SOGoSockDOperation *) operationWithMethod: (NSString *) method
                               andParameters: (NSDictionary *) opParameters
{
  static NSArray *operations = nil;
  NSString *className;
  SOGoSockDOperation *newOperation;

  if (!operations)
    operations = [[NSArray alloc] initWithObjects:
                                    @"SEARCH", @"UNBIND",
                                  nil];
  if ([operations containsObject: method])
    {
      className = [NSString stringWithFormat: @"_SOGoSockDOperation%@",
                            [method capitalizedString]];
      newOperation = [NSClassFromString (className) new];
      [newOperation autorelease];
      [newOperation setParameters: opParameters];
    }
  else
    newOperation = nil;

  return newOperation;
}

- (void) dealloc
{
  [parameters release];
  [super dealloc];
}

- (void) setParameters: (NSDictionary *) newParameters
{
  ASSIGN (parameters, newParameters);
}

- (void) _appendEntry: (NSDictionary *) entry
             toResult: (NSMutableString *) result
{
  static NSArray *ldifFields = nil;
  NSString *key, *value;
  int count, max;

  if (!ldifFields)
    {
      ldifFields = [NSArray arrayWithObjects: @"c_cn", @"c_givenname",
                            @"c_mail", @"c_o", @"c_screenname", @"c_sn",
                            @"c_telephonenumber", nil];
      [ldifFields retain];
    }

  if (singleEntryOperation)
    [result appendFormat: @"dn: %@\n", [parameters objectForKey: @"base"]];
  else
    [result appendFormat: @"dn: uid=%@,%@\n", [entry objectForKey: @"c_name"],
            [parameters objectForKey: @"base"]];
  [result appendString: @"objectClass: person\nobjectClass: inetOrgPerson\n"];
  [result appendFormat: @"uid: %@\n", [entry objectForKey: @"c_name"]];

  max = [ldifFields count];
  for (count = 0; count < max; count++)
    {
      key = [ldifFields objectAtIndex: count];
      value = [entry objectForKey: key];
      if ([value isKindOfClass: [NSString class]] && [value length] > 0)
        {
          if ([value mustEncodeLDIFValue])
            [result appendFormat: @"%@:: %@\n",
                    [key substringFromIndex: 2],
                    [value stringByEncodingBase64]];
          else
            [result appendFormat: @"%@: %@\n",
                    [key substringFromIndex: 2], value];
        }
    }
  [result appendString: @"\n"];
}

- (void) respondOnSocket: (NGActiveSocket *) responseSocket
{
  int count, max;
  NSMutableString *result;

  result = [NSMutableString string];

  max = [resultEntries count];
  for (count = 0; count < max; count++)
    [self _appendEntry: [resultEntries objectAtIndex: count]
              toResult: result];

  [result appendFormat: @"RESULT\ncode: %", resultCode];
  [responseSocket
    safeWriteData: [result dataUsingEncoding: NSASCIIStringEncoding]];
}

@end

@implementation _SOGoSockDOperationSearch

- (NSString *) _extractFirstValueFromDN: (NSString *) dn
{
  NSString *firstValue;
  NSRange charRange, valueRange;

  charRange = [dn rangeOfString: @"="];
  valueRange.location = charRange.location + 1;
  charRange = [dn rangeOfString: @","];
  if (charRange.location == NSNotFound)
    valueRange.length = [dn length] - valueRange.location;
  else
    valueRange.length = charRange.location - valueRange.location;
  firstValue = [dn substringFromRange: valueRange];

  return firstValue;
}

- (NSArray *) _extractIdsFromDN: (NSString *) dn
{
  NSRange suffixRange;
  NSString *prefix, *identifier;
  NSMutableArray *ids;
  NSArray *components;
  int count, max;

  ids = nil;

  suffixRange = [dn rangeOfString: [parameters objectForKey: @"suffix"]];
  if (suffixRange.length > 0)
    {
      if (suffixRange.location > 0)
        prefix = [dn substringToIndex: suffixRange.location - 1];
      else
        prefix = @"";
      components = [prefix componentsSeparatedByString: @","];
      max = [components count];
      ids = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          identifier = [self _extractFirstValueFromDN:
                            [components objectAtIndex: count]];
          [ids addObject: identifier];
        }
    }

  return ids;
}

- (NSString *) _convertLDAPFilter: (NSString *) ldapFilter
{
  /* Ultra hackish: we extract the value between the first "=" and the first
     ")", thereby assuming it will be the same for all search fields */
  NSString *filter;
  NSRange charRange, valueRange;

  charRange = [ldapFilter rangeOfString: @"="];
  valueRange.location = charRange.location + 1;
  charRange = [ldapFilter rangeOfString: @")"];
  valueRange.length = charRange.location - valueRange.location;
  filter = [ldapFilter substringFromRange: valueRange];
  charRange = [filter rangeOfString: @"*"];
  if (charRange.length == 1)
    {
      if (charRange.location == 0)
        filter = [filter substringFromIndex: 1];
      else
        filter = [filter substringToIndex: [filter length] - 1];
    }

  return filter;
}

- (id <SOGoContactFolder>) _getFolderWithId: (NSString *) folderId
                                    forUser: (NSString *) uid
{
  SOGoUserFolder *userFolder;
  SOGoContactFolders *parentFolder;
  id <SOGoContactFolder> folder;

  userFolder = [SOGoUserFolder objectWithName: uid inContainer: nil];
  parentFolder = [userFolder lookupName: @"Contacts"
                              inContext: nil acquire: NO];
  /* Note that this prevent lookup on subscribed addressbooks. */
  folder = [parentFolder lookupPersonalFolder: folderId
                               ignoringRights: YES];

  return folder;
}

- (void) _performSearch
{
  NSString *bindDN, *baseDN, *uid, *filter;
  id <SOGoContactFolder> folder;
  id singleEntry;
  NSArray *dnIDs;
  int idCount;

  bindDN = [parameters objectForKey: @"binddn"];
  baseDN = [parameters objectForKey: @"base"];
  if ([bindDN length] && [baseDN length])
    {
      uid = [self _extractFirstValueFromDN: bindDN];
      dnIDs = [self _extractIdsFromDN: baseDN];
      idCount = [dnIDs count];
      if (idCount && idCount < 3)
        {
          folder = [self _getFolderWithId: [dnIDs lastObject] forUser: uid];
          if (folder)
            {
              if (idCount == 1)
                {
                  singleEntryOperation = NO;
                  filter = [self _convertLDAPFilter:
                                   [parameters objectForKey: @"filter"]];
                  if ([filter length] == 0
                      && [folder isKindOfClass: SOGoContactSourceFolderKlass])
                    filter = @".";
                  resultEntries
                    = [folder lookupContactsWithFilter: filter
                                            onCriteria: @"name_or_address"
                                                sortBy: @"c_cn"
                                              ordering: NSOrderedAscending
                                              inDomain: nil];
                }
              else
                {
                  singleEntryOperation = YES;
                  singleEntry = [folder lookupContactWithName:
                                         [dnIDs objectAtIndex: 0]];
                  resultEntries = [NSArray arrayWithObject: singleEntry];
                }
            }
          else
            resultCode = LDAP_NO_SUCH_OBJECT;
        }
      else
        resultCode = LDAP_NO_SUCH_OBJECT;
    }
  else
    resultCode = LDAP_PROTOCOL_ERROR;
}

- (void) respondOnSocket: (NGActiveSocket *) responseSocket
{
  [self _performSearch];
  [super respondOnSocket: responseSocket];
}

@end

@implementation _SOGoSockDOperationUnbind
@end
