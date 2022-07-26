/* SOGoPasswordPolicy.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2022 Alinto
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSException.h>

#import "SOGoPasswordPolicy.h"

static const NSString *POLICY_MIN_LOWERCASE_LETTER = @"POLICY_MIN_LOWERCASE_LETTER";
static const NSString *POLICY_MIN_UPPERCASE_LETTER = @"POLICY_MIN_UPPERCASE_LETTER";
static const NSString *POLICY_MIN_DIGIT = @"POLICY_MIN_DIGIT";
static const NSString *POLICY_MIN_SPECIAL_SYMBOLS = @"POLICY_MIN_SPECIAL_SYMBOLS";
static const NSString *POLICY_MIN_LENGTH = @"POLICY_MIN_LENGTH";

@implementation SOGoPasswordPolicy

- (id) init
{
  return [super init];
}

- (void) dealloc
{
  [super dealloc];
}

+ (NSArray *) policies {
   return [NSArray arrayWithObjects: POLICY_MIN_LOWERCASE_LETTER, 
                                                          POLICY_MIN_UPPERCASE_LETTER, 
                                                          POLICY_MIN_DIGIT, 
                                                          POLICY_MIN_SPECIAL_SYMBOLS, 
                                                          POLICY_MIN_LENGTH,
                                                          nil];
}

+ (NSArray *) regexPoliciesWithCount:(NSNumber *) count {
    return [NSArray arrayWithObjects: [NSString stringWithFormat:@"(.*[a-z].*){%i}", [count intValue]], 
                                                          [NSString stringWithFormat:@"(.*[A-Z].*){%i}", [count intValue]], 
                                                          [NSString stringWithFormat:@"(.*[0-9].*){%i}", [count intValue]],  
                                                          [NSString stringWithFormat:@"([%$&*(){}!?\\@#].*){%i,}", [count intValue]], 
                                                          [NSString stringWithFormat:@".{%i,}", [count intValue]],
                                                          nil];
}

+ (NSArray *) createPasswordPolicyRegex: (NSArray *) userPasswordPolicy
{
  NSMutableArray *passwordPolicy = [[NSMutableArray alloc] init];
  [passwordPolicy autorelease];
  for (NSDictionary *policy in userPasswordPolicy) {
      NSString *label = [policy objectForKey:@"label"];
      if ([[self policies] containsObject: label]) {
        NSNumber *value = [policy objectForKey:@"value"];
        NSInteger index = [[self policies] indexOfObject: label];
        
        if (0 < value) {
          NSMutableDictionary *newPolicy = [NSMutableDictionary dictionaryWithDictionary: policy];
          [newPolicy setObject:[[self regexPoliciesWithCount: value] objectAtIndex: index] forKey:@"regex"]; 
          [passwordPolicy addObject: newPolicy];
        } else {
            // Do nothing
        }
      } else {
        [passwordPolicy addObject: policy];
      }
  }
  return passwordPolicy;
}

+ (NSArray *) createPasswordPolicyLabels: (NSArray *) userPasswordPolicy
                        withTranslations: (NSDictionary *) translations
{
    NSMutableArray *userTranslatedPasswordPolicy = [[NSMutableArray alloc] init];
    [userTranslatedPasswordPolicy autorelease];
    for (NSDictionary *policy in userPasswordPolicy) {
        NSString *label = [policy objectForKey:@"label"];
        if ([[self policies] containsObject: label]) {
            NSNumber *value = [policy objectForKey:@"value"];
            if (0 < value) {
                NSString *newLabel = [[translations objectForKey: label] 
                                    stringByReplacingOccurrencesOfString: @"%{0}"
                                    withString: [value stringValue]];
                [userTranslatedPasswordPolicy addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                newLabel, @"label", 
                                                [policy objectForKey:@"regex"], @"regex",
                                                nil]];
            } else {
                // Do nothing
            }
        } else {
            [userTranslatedPasswordPolicy addObject: policy];
        }
    }

    return userTranslatedPasswordPolicy;
}

@end
