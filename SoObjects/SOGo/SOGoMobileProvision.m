
/* SOGoMobileProvision.m - this file is part of SOGo
 *
 * Copyright (C) 2023 Alinto
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

#import <Foundation/Foundation.h>

#import "SOGoMobileProvision.h"
#import "SOGoUser.h"

typedef NS_ENUM(NSInteger, ProvisioningType) {
  ProvisioningTypeCalendar,
  ProvisioningTypeContact
};

@implementation SOGoMobileProvision

+ (NSString *)_plistWithContext:(WOContext *)context andPath:(NSString *)path andType:(ProvisioningType) provisioningType
{
  NSData *plistData;
  SOGoUser *activeUser;
  NSURL *serverURL;
  NSDictionary *provisioning;
  NSError *error;
  NSString *payloadType, *prefix, *type;

  activeUser = [context activeUser];
  serverURL = [context serverURL];

  if (!context || !path) {
    [self errorWithFormat: @"Invalid provisioning profile - no parameters"];
    return nil;
  }

  switch(provisioningType) {
    case ProvisioningTypeCalendar:
      payloadType = @"com.apple.caldav.account";
      prefix = @"CalDAV";
      type = @"Calendar";
    break;
    case ProvisioningTypeContact:
      payloadType = @"com.apple.carddav.account";
      prefix = @"CardDAV";
      type = @"Contact";
    break;
  }

  provisioning = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSArray arrayWithObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSString stringWithFormat:@"%@ %@", type, [activeUser login]], [NSString stringWithFormat:@"%@%@", prefix, @"AccountDescription"],
                                              [serverURL host], [NSString stringWithFormat:@"%@%@", prefix, @"HostName"],
                                              [serverURL port], [NSString stringWithFormat:@"%@%@", prefix, @"Port"],
                                              path, [NSString stringWithFormat:@"%@%@", prefix, @"PrincipalURL"],
                                              [NSNumber numberWithBool:[[serverURL scheme] isEqualToString:@"https"]], [NSString stringWithFormat:@"%@%@", prefix, @"UseSSL"],
                                              [activeUser login], [NSString stringWithFormat:@"%@%@", prefix, @"Username"],
                                              [NSString stringWithFormat: @"SOGo %@ provisioning", prefix], @"PayloadDescription",
                                              [NSString stringWithFormat:@"%@ %@", type,  [activeUser login]], @"PayloadDisplayName",
                                              [NSString stringWithFormat:@"%@.apple.%@", [serverURL host], [prefix lowercaseString]], @"PayloadIdentifier",
                                              [serverURL host], @"PayloadOrganization",
                                              payloadType, @"PayloadType",
                                              [SOGoObject globallyUniqueObjectId], @"PayloadUUID",
                                              [NSNumber numberWithInt: 1], @"PayloadVersion",
                                              nil]], @"PayloadContent",
                                              [NSString stringWithFormat:@"SOGo %@ provisioning", prefix], @"PayloadDescription",
                                              [NSString stringWithFormat: @"%@ (%@)", [activeUser login], type], @"PayloadDisplayName",
                                              [NSString stringWithFormat:@"%@.%@.apple", [prefix lowercaseString], [serverURL host]], @"PayloadIdentifier",
                                              @"SOGo", @"PayloadOrganization",
                                              [NSNumber numberWithBool: NO], @"PayloadRemovalDisallowed",
                                              @"Configuration", @"PayloadType",
                                              [SOGoObject globallyUniqueObjectId], @"PayloadUUID",
                                              [NSNumber numberWithInt: 1], @"PayloadVersion",
                                            nil];
  
  return [NSPropertyListSerialization dataWithPropertyList: provisioning
                                     format: NSPropertyListXMLFormat_v1_0
                                     options: 0
                                     error: &error];
}

+ (NSString *)plistForCalendarsWithContext:(WOContext *)context andPath:(NSString *)path
{
  NSData *plistData;
  SOGoUser *activeUser;

  plistData = [self _plistWithContext: context andPath: path andType: ProvisioningTypeCalendar];
  if (nil != plistData) {
    return [[[NSString alloc] initWithData:plistData encoding:NSUTF8StringEncoding] autorelease];
  } else {
    [self errorWithFormat: @"Invalid provisioning profile plist for account : %@", [activeUser login]];
    return nil;
  }
}

+ (NSString *)plistForContactsWithContext:(WOContext *)context andPath:(NSString *)path
{
  NSData *plistData;
  SOGoUser *activeUser;

  plistData = [self _plistWithContext: context andPath: path andType: ProvisioningTypeContact];
  if (nil != plistData) {
    return [[[NSString alloc] initWithData:plistData encoding:NSUTF8StringEncoding] autorelease];
  } else {
    [self errorWithFormat: @"Invalid provisioning profile plist for account : %@", [activeUser login]];
    return nil;
  }
}


@end
