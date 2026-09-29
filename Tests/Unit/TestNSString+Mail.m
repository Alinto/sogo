#import "SOGoTest.h"

#import "Mailer/NSString+Mail.h"

static NSString *
MessageIDShape(NSString *mailOrDomain)
{
  NSString *messageID = [NSString generateMessageID: mailOrDomain];

  return [@"<UUID" stringByAppendingString: [messageID substringFromIndex: 37]];
}

@interface TestNSString_plus_Mail : SOGoTest
@end

@implementation TestNSString_plus_Mail

- (void) test_generateMessageID_fromAddressOrDomain
{
  testEquals(MessageIDShape(@"user@example.org"), @"<UUID@example.org>");
  testEquals(MessageIDShape(@"Example.ORG"), @"<UUID@example.org>");
}

- (void) test_generateMessageID_fromSenderWithDisplayName
{
  testEquals(MessageIDShape(@"Doe, John <user@example.org>"), @"<UUID@example.org>");
  testEquals(MessageIDShape(@"Doe, John <user@example.org> (work)"), @"<UUID@example.org>");
  testEquals(MessageIDShape(@"user@example.org>"), @"<UUID@example.org>");
}

- (void) test_generateMessageID_rejectsInjectedDomains
{
  testEquals(MessageIDShape(@"user@example.org\r\nBcc: victim"),
             @"<UUID@example.org>");
  testEquals(MessageIDShape(@"user@example.org Bcc: victim"),
             @"<UUID@example.org>");
}

- (void) test_generateMessageID_withoutDomain
{
  testEquals(MessageIDShape(@""), @"<UUID>");
  testEquals(MessageIDShape(nil), @"<UUID>");
}

@end
