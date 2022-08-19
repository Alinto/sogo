#ifndef SOGO_PASSWORD_POLICY_H
#define SOGO_PASSWORD_POLICY_H

#import <Foundation/NSObject.h>

@interface SOGoPasswordPolicy : NSObject
{

}

+ (NSArray *) policies;
+ (NSArray *) regexPoliciesWithCount:(NSNumber *) count;
+ (NSArray *) createPasswordPolicyRegex: (NSArray *) userPasswordPolicy;
+ (NSArray *) createPasswordPolicyLabels: (NSArray *) userPasswordPolicy
                        withTranslations: (NSDictionary *) translations;

@end

#endif /* SOGO_PASSWORD_POLICY_H */