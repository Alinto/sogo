/* JWT.m - this file is part of SOGo
 *
 * Copyright (C) 2022 Alinto
 *
 * This file is part of SOGo.
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

#import "JWT.h"
#import <Foundation/NSDictionary.h>
#import <Foundation/NSData.h>
#import <GNUstepBase/GSMime.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#include <openssl/hmac.h>
#include <openssl/evp.h>

#define HS256_TOKEN_LENGH 43

static const NSString *kExpKey = @"exp";
static const NSString *kAlgKey = @"alg";
static const NSString *kTypKey = @"typ";
static const NSString *kAlg = @"HS256";
static const NSString *kTyp = @"JWT";

@implementation JWT

- (id) init
{
  if ((self = [super init]))
  {
    self->JWTSecret = [[SOGoSystemDefaults sharedSystemDefaults] JWTSecret];
  }

  return self;
}

- (void) dealloc
{
  [super dealloc];
}

+ (JWT *)sharedInstance
{
  static JWT *sharedInstance = nil;

  if (!sharedInstance)
    {
      sharedInstance = [[self alloc] init];
      [sharedInstance retain];
    }

  return sharedInstance;
}

/**
 * Encode base64 data
 * @param data The input data
 * @param length The input data length
 * @return Data encoded in base64
 */
- (NSString *) base64EncodeWithData: (NSData *)data length: (NSUInteger)length {
  NSData *dataBase64;
  dataBase64 = [GSMimeDocument encodeBase64: data];
  return [[
              [[NSString stringWithCString: [dataBase64 bytes] length: length]
                stringByReplacingOccurrencesOfString:@"+" withString:@"-"]
                stringByReplacingOccurrencesOfString:@"/" withString:@"_"]
                stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

/**
 * Encode base64 string
 * @param data The input string
 * @param length The input data length
 * @return Data encoded in base64
 */
- (NSString *) base64EncodeWithString: (NSString *)data {
  return [[
              [[GSMimeDocument encodeBase64String: data] 
                stringByReplacingOccurrencesOfString:@"+" withString:@"-"]
                stringByReplacingOccurrencesOfString:@"/" withString:@"_"]
                stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

/**
 * Decode base64 string
 * @param data The base64 input string
 * @return Decoded data
 */
- (NSDictionary *) base64DecodeWithString: (NSString *)data {
  NSString *decodedData;
  NSDictionary *output;

  output = nil;
  decodedData = [GSMimeDocument decodeBase64String: data];
  if ([decodedData isJSONString]) {
    output = (NSDictionary *)[decodedData objectFromJSONString];
  } 
  return output;
}

/**
 * Generate JWT Token encoded with HS256 algorithm
 * @param dict The payload content
 * @return A valid JWT token (header + payload + signature)
 */
- (NSString *) getHS256TokenForData: (NSDictionary *)dict withSecret: (NSString *)secret {
   unsigned char hs256[HS256_TOKEN_LENGH] = {};
   NSString *headerBase64, *payloadBase64, *content, *token;
   NSArray *sortedKeys;
   NSMutableDictionary *sortedDict

   // Reorder dictionary keys
   sortedKeys = [[dict allKeys] sortedArrayUsingSelector: @selector(compare:)];
   sortedDict = [NSMutableDictionary dictionary];
   for (NSString *key in sortedKeys)
     [sortedDict setObject:[dict objectForKey: key] forKey: key];

   headerBase64 = [self base64EncodeWithString: 
      [[NSDictionary dictionaryWithObjectsAndKeys:kAlg, kAlgKey, kTyp, kTypKey, nil] jsonRepresentation]];
   payloadBase64 = [self base64EncodeWithString: [sortedDict jsonRepresentation]];
   content = [NSString stringWithFormat: @"%@.%@", headerBase64, payloadBase64, nil];

   HMAC(EVP_sha256(), 
        [secret UTF8String], [secret length],
        [content UTF8String], [content length],
        hs256, NULL);

    token = [self base64EncodeWithData: [NSData dataWithBytes:hs256 length: HS256_TOKEN_LENGH] length: HS256_TOKEN_LENGH];
    
    return [NSString stringWithFormat: @"%@.%@", content, token, nil];
}

/**
 * Generate JWT Token encoded with HS256 algorithm
 * @param data The payload content
 * @param validitySec Validity duration, in seconds
 * @return A valid JWT token (header + payload + signature)
 */
- (NSString *)getJWTWithData: (NSDictionary *)data andValidity: (int)validitySec {
  NSMutableDictionary *dict;
  dict = [NSMutableDictionary dictionaryWithDictionary: data];
  [dict setObject:[NSString stringWithFormat:@"%.0f", ([[NSDate date] timeIntervalSince1970] + validitySec)] forKey: kExpKey];

  return [self getHS256TokenForData: dict withSecret: self->JWTSecret];
}

/**
 * Get JWT token data and check validity token
 * @param JWTToken A JWT complete token (header + payload + signature)
 * @param isValid Reference parameter - NO if token is invalid
 * @param isExpired Reference parameter - YES if token is expired
 * @return Payload content
 */
- (NSDictionary *)getDataWithJWT: (NSString *)JWTToken andValidity: (BOOL *)isValid isExpired: (BOOL *)isExpired {
  NSArray *components, *reencodedComponents;
  NSString *header, *payload, *reencodedJWTToken, *signature, *reencodedSignature;
  NSDictionary *headerDict, *payloadDict;
  NSTimeInterval tokenTime;
  NSMutableDictionary *result;

  *isValid = YES;
  *isExpired = NO;
  result = nil;
  components = [JWTToken componentsSeparatedByString:@"."];

  if (3 != [components count]) {
    // Invalid number of components
    *isValid = NO;
    return result;
  }

  // Check header
  ///////////////
  header = (NSString *)[components objectAtIndex: 0];
  if (!header) {
    // No header
    *isValid = NO;
    return result;
  }
  headerDict = [self base64DecodeWithString: header];
  if (!headerDict) {
    // No header
    *isValid = NO;
    return result;
  }
  if (![headerDict objectForKey: kTypKey] || ![[headerDict objectForKey: kTypKey] isEqualToString: kTyp]) {
    // Invalid type
    *isValid = NO;
    return result;
  }
  if (![headerDict objectForKey: kAlgKey] || ![[headerDict objectForKey: kAlgKey] isEqualToString: kAlg]) {
    // Invalid algorithm
    *isValid = NO;
    return result;
  }
  
  // Check payload
  ///////////////
  payload = (NSString *)[components objectAtIndex: 1];
  if (!payload) {
    // No payload
    *isValid = NO;
    return result;
  }
  payloadDict = [self base64DecodeWithString: payload];
  if (!payloadDict) {
    // No payload
    *isValid = NO;
    return result;
  }
  if (![payloadDict objectForKey: kExpKey]) {
    // No expiration token
    *isValid = NO;
    return result;
  }
  // Check expiration
  tokenTime = [[payloadDict objectForKey: kExpKey] doubleValue];
  if (0 != tokenTime) { // 0 for infinity validation
    if ([[NSDate date] timeIntervalSince1970] > tokenTime) {
      // Token expired
      *isValid = NO;
      *isExpired = YES;
      return result;
    }
  }

  // Check signature
  ///////////////
  reencodedJWTToken = [self getHS256TokenForData: payloadDict withSecret: self->JWTSecret];
  reencodedComponents = [reencodedJWTToken componentsSeparatedByString:@"."];
  if (3 != [reencodedComponents count]) {
    // Invalid number of reencoded components
    *isValid = NO;
    return result;
  }
  signature = (NSString *)[components objectAtIndex: 2];
  reencodedSignature = (NSString *)[reencodedComponents objectAtIndex: 2];
  if (![signature isEqualToString: reencodedSignature]) {
    // Invalid signature
    *isValid = NO;
    return result;
  }

  // All is OK !
  result = [NSMutableDictionary dictionaryWithDictionary: payloadDict];
  [result removeObjectForKey: kExpKey];

  return result;
}

@end