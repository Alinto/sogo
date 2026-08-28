/* TestSOGoDraftObjectQuoteSpecials.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Test Implementation
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
#import "SOGoTest.h"

@interface TestSOGoDraftObjectQuoteSpecials : SOGoTest
@end

/*
 * Testing helper to expose private _quoteSpecials: method for testing
 */
@interface SOGoDraftObject (Testing)
- (NSString *) _quoteSpecials: (NSString *) address;
@end

@implementation TestSOGoDraftObjectQuoteSpecials

/* Test case for the reported bug: display name with comma, parenthesis, brackets */
- (void) test_quoteSpecials_displayNameWithCommaAndParenthesisAndBrackets_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  /* The bug case from the report */
  input = @"Lastname, Firstname (INFO)[MoreINFO] <user@example.com>";
  expected = @"\"Lastname, Firstname (INFO)[MoreINFO]\" <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: simple email without display name should not be modified */
- (void) test_quoteSpecials_simpleEmail_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"user@example.com";
  expected = @"user@example.com";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: email with simple display name (no specials) should not be modified */
- (void) test_quoteSpecials_simpleDisplayName_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"John Doe <user@example.com>";
  expected = @"John Doe <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: display name with comma should be quoted */
- (void) test_quoteSpecials_displayNameWithComma_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"Doe, John <user@example.com>";
  expected = @"\"Doe, John\" <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: display name with parenthesis should be quoted */
- (void) test_quoteSpecials_displayNameWithParenthesis_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"John (Manager) <user@example.com>";
  expected = @"\"John (Manager)\" <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: display name with brackets should be quoted */
- (void) test_quoteSpecials_displayNameWithBrackets_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"John [Dept] <user@example.com>";
  expected = @"\"John [Dept]\" <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: email in angle brackets only should not be modified */
- (void) test_quoteSpecials_emailInBrackets_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"<user@example.com>";
  expected = @"<user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: already quoted display name should not be double-quoted */
- (void) test_quoteSpecials_alreadyQuotedDisplayeName_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"\"Doe, John\" <user@example.com>";
  expected = @"\"Doe, John\" <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: RFC 2047 encoded display name should not be modified */
- (void) test_quoteSpecials_encodedWordDisplayeName_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"=?utf-8?q?=C3=80=C3=B1in=C3=A9oblabla?= <user@example.com>";
  expected = @"=?utf-8?q?=C3=80=C3=B1in=C3=A9oblabla?= <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: display name with backslash should be escaped when quoted */
- (void) test_quoteSpecials_displayNameWithBackslash_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"John\\Doe <user@example.com>";
  expected = @"\"John\\\\Doe\" <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: display name with double quote should be escaped when quoted */
- (void) test_quoteSpecials_displayNameWithDoubleQuote_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"John \"The Boss\" Doe <user@example.com>";
  expected = @"\"John \\\"The Boss\\\" Doe\" <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: display name with colon should be quoted (RFC 5322 special char) */
- (void) test_quoteSpecials_displayNameWithColon_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"Sales: John Doe <user@example.com>";
  expected = @"\"Sales: John Doe\" <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: display name with semicolon should be quoted (RFC 5322 special char) */
- (void) test_quoteSpecials_displayNameWithSemicolon_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"Team; John Doe <user@example.com>";
  expected = @"\"Team; John Doe\" <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: display name without < should be quoted if it contains specials */
- (void) test_quoteSpecials_displayNameNoBracketsWithSpecials_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"Doe, John";
  expected = @"\"Doe, John\"";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: display name without < and without specials should not be quoted */
- (void) test_quoteSpecials_displayNameNoBracketsNoSpecials_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"John Doe";
  expected = @"John Doe";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: trailing/leading whitespace around display name should be trimmed */
- (void) test_quoteSpecials_whitespaceAroundDisplayName_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"  John Doe  <user@example.com>";
  expected = @"John Doe <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: multiple addresses in array via _quoteSpecialsInArray */
- (void) test_quoteSpecialsInArray_multipleAddresses_value_
{
  SOGoDraftObject *draft;
  NSArray *input, *result;
  NSString *expected1, *expected2;

  draft = [SOGoDraftObject new];

  input = [NSArray arrayWithObjects:
           @"Doe, John <john@example.com>",
           @"Jane Smith <jane@example.com>",
           nil];

  expected1 = @"\"Doe, John\" <john@example.com>";
  expected2 = @"Jane Smith <jane@example.com>";

  result = [draft _quoteSpecialsInArray: input];

  testWithMessage([result count] == 2,
                  [NSString stringWithFormat: @"Expected 2 addresses, got %lu", (unsigned long)[result count]]);

  testWithMessage([[result objectAtIndex: 0] isEqualToString: expected1],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected1, [result objectAtIndex: 0]]);

  testWithMessage([[result objectAtIndex: 1] isEqualToString: expected2],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected2, [result objectAtIndex: 1]]);

  [draft release];
}

/* Test: nil or empty input */
- (void) test_quoteSpecials_nilOrEmpty_value_
{
  SOGoDraftObject *draft;
  NSString *result;

  draft = [SOGoDraftObject new];

  /* Test nil */
  result = [draft _quoteSpecials: nil];
  testWithMessage(result == nil, @"Nil input should return nil");

  /* Test empty string */
  result = [draft _quoteSpecials: @""];
  testWithMessage([result isEqualToString: @""] , @"Empty input should return empty string");

  [draft release];
}

/* Test: display name with at sign should be quoted */
- (void) test_quoteSpecials_displayNameWithAtSign_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"John@Home <user@example.com>";
  expected = @"\"John@Home\" <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

/* Test: display name with dot should be quoted (it's special in angle-addr context in RFC 5322) */
- (void) test_quoteSpecials_displayNameWithDot_value_
{
  SOGoDraftObject *draft;
  NSString *input, *result, *expected;

  draft = [SOGoDraftObject new];

  input = @"J.R. Smith <user@example.com>";
  expected = @"\"J.R. Smith\" <user@example.com>";

  result = [draft _quoteSpecials: input];

  testWithMessage([result isEqualToString: expected],
                  [NSString stringWithFormat: @"Expected '%@', got '%@'", expected, result]);

  [draft release];
}

@end