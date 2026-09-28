/* TestNSString+Mail.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
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
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

/* This file is encoded in utf-8. */

#import "SOGoTest.h"

#import "NSString+Mail.h"

@interface TestNSString_plus_Mail : SOGoTest
@end

static unsigned
countOccurrencesOfSubstring (NSString *s, NSString *sub)
{
  unsigned count;
  NSRange r, sr;

  count = 0;
  sr = NSMakeRange (0, [s length]);
  while (NSMaxRange (sr) > 0)
    {
      r = [s rangeOfString: sub options: 0 range: sr];
      if (r.location == NSNotFound)
        break;
      count++;
      sr.location = NSMaxRange (r);
      sr.length = [s length] - sr.location;
    }

  return count;
}

@implementation TestNSString_plus_Mail

/* Bug #6201: a calendar invite sent through the iTIP scheduler ended up
   with "Message-Id: <uuid@example.org>>" - a duplicated closing bracket
   caused by an unsanitized domain part. */
- (void) test_generateMessageID
{
  NSString *mid, *error;

  /* full email address */
  mid = [NSString generateMessageID: @"user@example.org"];
  error = [NSString stringWithFormat: @"message-id '%@' must start with '<'", mid];
  testWithMessage ([mid hasPrefix: @"<"], error);
  error = [NSString stringWithFormat: @"message-id '%@' must end with '@example.org>'", mid];
  testWithMessage ([mid hasSuffix: @"@example.org>"], error);
  error = [NSString stringWithFormat: @"message-id '%@' must contain exactly one '>'", mid];
  testWithMessage (countOccurrencesOfSubstring (mid, @">") == 1, error);

  /* display name with email, as passed by the iTIP scheduler */
  mid = [NSString generateMessageID: @"Doe, John <user@example.org>"];
  error = [NSString stringWithFormat: @"message-id '%@' must contain exactly one '>'", mid];
  testWithMessage (countOccurrencesOfSubstring (mid, @">") == 1, error);
  error = [NSString stringWithFormat: @"message-id '%@' must end with '@example.org>'", mid];
  testWithMessage ([mid hasSuffix: @"@example.org>"], error);

  /* stray closing bracket */
  mid = [NSString generateMessageID: @"user@example.org>"];
  error = [NSString stringWithFormat: @"message-id '%@' must contain exactly one '>'", mid];
  testWithMessage (countOccurrencesOfSubstring (mid, @">") == 1, error);

  /* trailing comment after the address */
  mid = [NSString generateMessageID: @"Doe, John <user@example.org> (work)"];
  error = [NSString stringWithFormat: @"message-id '%@' must contain exactly one '>'", mid];
  testWithMessage (countOccurrencesOfSubstring (mid, @">") == 1, error);
  error = [NSString stringWithFormat: @"message-id '%@' must end with '@example.org>'", mid];
  testWithMessage ([mid hasSuffix: @"@example.org>"], error);

  /* domain-only value */
  mid = [NSString generateMessageID: @"Example.ORG"];
  error = [NSString stringWithFormat: @"message-id '%@' must be lowercased and well terminated", mid];
  testWithMessage ([mid hasSuffix: @"@example.org>"], error);

  /* header injection attempt through the domain part */
  mid = [NSString generateMessageID: @"user@example.org\r\nX-Evil: 1"];
  error = [NSString stringWithFormat: @"message-id '%@' must be a single line", mid];
  testWithMessage ([mid rangeOfCharacterFromSet:
                     [NSCharacterSet newlineCharacterSet]].location == NSNotFound, error);

  /* empty domain still yields a well-formed message-id, without an
     empty domain clause */
  mid = [NSString generateMessageID: @""];
  error = [NSString stringWithFormat: @"message-id '%@' must start with '<' and end with '>'", mid];
  testWithMessage ([mid hasPrefix: @"<"] && [mid hasSuffix: @">"], error);
  error = [NSString stringWithFormat: @"message-id '%@' must not hold an empty domain", mid];
  testWithMessage (countOccurrencesOfSubstring (mid, @"@") == 0, error);

  /* nil must still produce a syntactically valid message-id */
  mid = [NSString generateMessageID: nil];
  error = [NSString stringWithFormat: @"message-id '%@' must start with '<'", mid];
  testWithMessage ([mid hasPrefix: @"<"], error);
  error = [NSString stringWithFormat: @"message-id '%@' must end with '>'", mid];
  testWithMessage ([mid hasSuffix: @">"], error);
  error = [NSString stringWithFormat: @"message-id '%@' must contain exactly one '>'", mid];
  testWithMessage (countOccurrencesOfSubstring (mid, @">") == 1, error);
}

/* Bug #6227: display names holding a comma and square brackets were not
   quoted per RFC 5322, splitting addresses at the comma and generating
   "@MISSING_DOMAIN" recipients. */
- (void) test_stringByQuotingAddressSpecials
{
  const char *inStrings[] = {
    /* the exact report: "<surname>, <given name> [department]" */
    "Muster, Max [ABC] <Max.Muster@ab-cd.df>",
    "Lastname, Firstname (INFO)[MoreINFO] <user@example.com>",
    /* bare address must never be quoted */
    "user@example.com",
    /* simple display name stays unquoted */
    "John Doe <user@example.com>",
    /* no space before the address bracket */
    "Doe, John<user@example.com>",
    /* address-only form */
    "<user@example.com>",
    /* display name only, with specials */
    "Doe, John",
    /* display name only, without specials */
    "Doe John",
    /* already quoted display name must not be quoted twice */
    "\"Doe, John\" <user@example.com>",
    /* RFC 2047 encoded display name stays untouched */
    "=?utf-8?q?Doe=2C_John?= <user@example.com>",
    /* quotes and backslashes inside the display name are escaped */
    "\"evil\" name <user@example.com>",
    "back\\slash <user@example.com>",
    /* extra whitespace around the display name is normalized */
    "  Doe, John   <user@example.com>",
    /* dots alone do not require quoting anymore */
    "foo.bar",
    "John Q. Public <user@example.com>",
    /* bare address holding a comment is left untouched */
    "user@example.com (John)",
    /* whitespace-only display name collapses to the address part */
    "   <user@example.com>",
    /* a phrase ending with an unbalanced quote gets escaped and quoted */
    "Doe\" <user@example.com>",
    NULL
  };
  const char *outStrings[] = {
    "\"Muster, Max [ABC]\" <Max.Muster@ab-cd.df>",
    "\"Lastname, Firstname (INFO)[MoreINFO]\" <user@example.com>",
    "user@example.com",
    "John Doe <user@example.com>",
    "\"Doe, John\" <user@example.com>",
    "<user@example.com>",
    "\"Doe, John\"",
    "Doe John",
    "\"Doe, John\" <user@example.com>",
    "=?utf-8?q?Doe=2C_John?= <user@example.com>",
    "\"\\\"evil\\\" name\" <user@example.com>",
    "\"back\\\\slash\" <user@example.com>",
    "\"Doe, John\" <user@example.com>",
    "foo.bar",
    "John Q. Public <user@example.com>",
    "user@example.com (John)",
    "<user@example.com>",
    "\"Doe\\\"\" <user@example.com>",
    NULL
  };
  const char **inString, **outString;
  NSString *result, *error;

  inString = inStrings;
  outString = outStrings;
  while (*inString)
    {
      result = [[NSString stringWithUTF8String: *inString] stringByQuotingAddressSpecials];
      error = [NSString stringWithFormat: @"input '%s': expected '%s', got '%@'",
                         *inString, *outString, result];
      testWithMessage ([result isEqualToString:
                          [NSString stringWithUTF8String: *outString]],
                       error);
      inString++;
      outString++;
    }
}

@end
