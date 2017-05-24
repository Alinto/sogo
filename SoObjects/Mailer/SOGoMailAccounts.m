/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2007-2013 Inverse inc.

  This file is part of SOGo.

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


#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <DOM/DOMElement.h>

#import "../SOGo/NSArray+Utilities.h"
#import "../SOGo/NSObject+DAV.h"
#import "../SOGo/NSString+Utilities.h"
#import "../SOGo/SOGoUser.h"
#import "../SOGo/SOGoUserDefaults.h"
#import "SOGoMailAccount.h"

#import "SOGoMailAccounts.h"

#define XMLNS_INVERSEDAV @"urn:inverse:params:xml:ns:inverse-dav"

// TODO: prune redundant methods

@implementation SOGoMailAccounts

- (NSArray *) mailAccounts
{
  SOGoUser *user;
  
  user = [SOGoUser userWithLogin: [self ownerInContext: nil]];

  return [user mailAccounts];
}

- (NSArray *) toManyRelationshipKeys
{
  NSMutableArray *keys;
  NSArray *accounts;
  int count, max;
  SOGoUser *user;
  
  user = [SOGoUser userWithLogin: [self ownerInContext: nil]];
  accounts = [user mailAccounts];
  max = [accounts count];

  keys = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    [keys addObject: [NSString stringWithFormat: @"%d", count]];

  return keys;
}

/* name lookup */

- (id) lookupName: (NSString *) _key
        inContext: (id) _ctx
          acquire: (BOOL) _flag
{
  id obj;
  NSArray *accounts;
  NSString *key;
  SOGoUser *user;
  int keyCount;

  key = [_key fromCSSIdentifier];
  
  /* first check attributes directly bound to the application */
  obj = [super lookupName:key inContext:_ctx acquire:NO];
  if (!obj)
    {
      user = [SOGoUser userWithLogin: [self ownerInContext: nil]];
      accounts = [user mailAccounts];

      keyCount = [key intValue];
      if ([key isEqualToString: [NSString stringWithFormat: @"%d", keyCount]]
          && keyCount > -1 && keyCount < [accounts count])
        obj = [SOGoMailAccount objectWithName: key inContainer: self];
      else
        obj = [NSException exceptionWithHTTPStatus: 404 /* Not Found */];
    }

  return obj;
}

/*
  Mail labels/tags synchronization.

  Request:

  <D:propfind xmlns:D="DAV:" xmlns:x0="urn:inverse:params:xml:ns:inverse-dav"><D:prop><x0:mails-labels/></D:prop></D:propfind>

  Result:

<?xml version="1.0" encoding="UTF-8"?>
<D:multistatus>
  <D:response>
    <D:href>/SOGo/dav/sogo10/Mail/</D:href>
    <D:propstat>
      <D:status>HTTP/1.1 200 OK</D:status>
      <D:prop>
        <n1:mails-labels>
          <n1:label color="#f00" id="$label1">Important</n1:label>
          <n1:label color="#ff9a00" id="$label2">Work</n1:label>
          <n1:label color="#009a00" id="$label3">Personal</n1:label>
          <n1:label color="#3130ff" id="$label4">To Do</n1:label>
          <n1:label color="#9c309c" id="$label5">Later</n1:label>
        </n1:mails-labels>
      </D:prop>
    </D:propstat>
  </D:response>
</D:multistatus>

*/
- (SOGoWebDAVValue *) davMailsLabels
{
  NSDictionary *labelsFromDefaults, *labelValues, *attributes;
  NSMutableArray *davMailsLabels;
  NSUInteger count, max;
  SOGoUser *ownerUser;
  NSArray *allKeys, *values;
  NSString *key;

  ownerUser = [SOGoUser userWithLogin: owner];
  labelsFromDefaults = [[ownerUser userDefaults] mailLabelsColors];
  allKeys = [labelsFromDefaults allKeys];
  max = [allKeys count];

  davMailsLabels = [NSMutableArray arrayWithCapacity: max];

  for (count = 0; count < max; count++)
       {
         key = [allKeys objectAtIndex: count];
         values = [labelsFromDefaults objectForKey: key];
         
         attributes = [NSDictionary dictionaryWithObjectsAndKeys: key, @"id",
                                           [values objectAtIndex: 1], @"color",
                                    nil];
         
         labelValues = davElementWithAttributesAndContent(@"label",
                                                          attributes,
                                                          XMLNS_INVERSEDAV,
                                                          [values objectAtIndex: 0]);
         
         [davMailsLabels addObject: labelValues];
       }
  
  return [davElementWithContent (@"mails-labels",
                                 XMLNS_INVERSEDAV,
                                 davMailsLabels)
                                asWebDAVValue];
}

/*

  We get something like that:

  Request:

<?xml version="1.0" encoding="UTF-8"?>
<propertyupdate xmlns="DAV:" xmlns:i="urn:inverse:params:xml:ns:inverse-dav">
  <set>
    <prop>
      <i:mails-labels>
        <i:label color="#f00" id="$label1">Important</i:label>
        <i:label color="#ff9a00" id="$label2">Work</i:label>
        <i:label color="#009a00" id="$label3">Personal</i:label>
        <i:label color="#3130ff" id="$label4">To Do</i:label>
        <i:label color="#9c309c" id="$label5">Later</i:label>
      </i:mails-labels>
    </prop>
  </set>
</propertyupdate>

  Response:

<D:multistatus>
  <D:response>
    <D:href>/SOGo/dav/sogo10/Mail/</D:href>
    <D:propstat>
      <D:prop>
        <a:mails-labels/>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>

*/

/* No longer in use, causes objc-method-access warning

- (NSException *) setDavMailsLabels: (NSString *) newLabels
{
  id <DOMElement> documentElement, labelNode;
  id <DOMNodeList> labelNodes;
  id <DOMDocument> document;

  NSString *label, *name, *color;
  NSMutableDictionary *labels;
  NSMutableArray *values;
  SOGoUserDefaults *ud;
  SOGoUser *ownerUser;

  NSUInteger count, max;
  
  labels = [NSMutableDictionary dictionary];
  
  if ([newLabels length] > 0)
    {
      document = [[context request] contentAsDOMDocument];
      documentElement = [document documentElement];
      labelNodes = [documentElement getElementsByTagName: @"label"];
      max = [labelNodes length];

      for (count = 0; count < max; count++)
        {
          values = [NSMutableArray array];

          labelNode = [labelNodes objectAtIndex: count];
          
          label = [labelNode attribute: @"id"];
          name = [[labelNode firstChild] nodeValue];
          color = [labelNode attribute: @"color"];

          [values addObject: name];
          [values addObject: color];
          
          [labels setObject: values  forKey: label];
        }
    }

  ownerUser = [SOGoUser userWithLogin: owner];
  ud = [ownerUser userDefaults];
  [ud setMailLabelsColors: labels];
  [ud synchronize];

  return nil;
}
*/

@end /* SOGoMailAccounts */
