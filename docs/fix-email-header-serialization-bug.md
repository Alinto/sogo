# Fix for Email Header Serialization Bug

## Bug Description

When SOGo sends emails with display names containing special characters (commas, parentheses, brackets), the display names are not properly quoted according to RFC 5322. This causes email parsers to incorrectly interpret the address, creating bogus recipients.

### Example from Bug Report

**Input to SOGo:** Address book entry with display name `"Lastname, Firstname (INFO)[MoreINFO]"` and email `user@example.com`

**Bug Behavior:** SOGo emits unquoted display name:
```
To: Lastname, Firstname (INFO)[MoreINFO] <user@example.com>
```

**Result:** Parser treats comma as address-list delimiter, creating bogus recipient `lastname@senderdomain.com` and causing bounce emails on reply-all.

### Expected Behavior (RFC 5322 Compliant)

Display names with special characters should be quoted:
```
To: "Lastname, Firstname (INFO)[MoreINFO]" <user@example.com>
```

## Root Cause

File: `/SoObjects/Mailer/SOGoDraftObject.m` - method `_quoteSpecials:` (original lines 1774-1820)

### Critical Flaws in Original Implementation:

1. **Blunt special character detection** - Checked for special characters **anywhere in the entire address string**, including the email part
   - Checks for `@` and `.` which are ALWAYS present in legitimate email addresses
   - This caused the condition to be ALWAYS true for all valid email addresses

2. **Incorrect substring extraction** (line 1804):
   ```objective-c
   part = [address substringToIndex: i - 1];
   ```
   - Assumed there's always whitespace before `<`
   - If no space exists before `<`, this loses the last character of the display name

3. **No check for already-formatted addresses** - Didn't detect if display name was:
   - Already quoted (`"Doe, John"`)
   - RFC 2047 encoded (`=?utf-8?q?=C3=80=C3=B1in=C3=A9oblabla?=`)

4. **Improper handling of address-only format** - For addresses like `<user@example.com>` or `user@example.com`, the logic was still executing the special character check

## Fix Implementation

### Complete Rewrite of `_quoteSpecials:` Method

The new implementation:
1. Properly parses address strings to separate display name from email
2. Only checks the **display name part** for special characters (not the email)
3. Detects already-formatted addresses (quoted strings and encoded words)
4. Follows RFC 5322 quoting rules precisely
5. Trims whitespace appropriately

### New Helper Methods Added:

1. **`_needsQuotingForPhrase:`** - Determines if a display name requires quoting based on RFC 5322 special characters:
   - Space, comma, semicolon, colon, at-sign, period
   - Angle brackets, square brackets, parentheses
   - Backslash, double quote

2. **`_alreadyProperlyFormatted:`** - Checks if display name is:
   - Already quoted (starts and ends with `"`)
   - RFC 2047 encoded (starts with `=?` and ends with `?=`)

3. **`_quoteAndEscape:`** - Properly quotes and escapes a display name:
   - Trims leading/trailing whitespace
   - Escapes backslashes (`\` → `\\`)
   - Escapes double quotes (`"` → `\"`)
   - Wraps in double quotes

### Test Coverage

Created comprehensive test file: `/Tests/Unit/TestSOGoDraftObjectQuoteSpecials.m`

Test cases cover:
- Display names with commas, parentheses, brackets
- Simple names without special characters
- Email-only addresses
- Already quoted display names
- RFC 2047 encoded words
- Backslash and quote escaping
- Colon and semicolon special characters
- At-sign and period in display names
- Trailing/leading whitespace handling
- Multiple addresses in arrays
- Nil and empty input handling

## Files Modified

1. `/SoObjects/Mailer/SOGoDraftObject.m`:
   - Completely rewrote `_quoteSpecials:` method (lines 1774-1825)
   - Added `_needsQuotingForPhrase:` method (lines 1827-1836)
   - Added `_alreadyProperlyFormatted:` method (lines 1838-1854)
   - Added `_quoteAndEscape:` method (lines 1856-1867)

2. `/Tests/Unit/GNUmakefile`:
   - Added `TestSOGoDraftObjectQuoteSpecials.m` to test file list

3. `/Tests/Unit/TestSOGoDraftObjectQuoteSpecials.m` (new file):
   - Created 18 comprehensive test cases

## RFC 5322 Compliance

The fix ensures SOGo complies with RFC 5322 Section 3.4 (Address Specification):

- **phrase** as defined in Section 3.2.5 
- **mailbox** format: `phrase <addr-spec>` or `addr-spec`
- Proper quoting of special characters in **phrase**
- Proper escaping within quoted strings

## Impact Assessment

### Positive Impact:
- Fixes email bounce issues caused by malformed headers
- Prevents creation of bogus recipients
- Enables proper reply-all functionality for addresses with special characters
- Improves interoperability with strict email parsers

### Minimal Risk:
- The helper methods are private (not in public API)
- Changes are localized to address formatting logic
- Comprehensive test coverage prevents regressions
- RFC 5322 standards compliance is well-established

## Testing Recommendations

Before deploying to production:
1. Run the unit tests: `make check` in `/Tests/Unit` directory
2. Manual testing scenarios:
   - Create address book entries with special characters: `( ) [ ] , ; : @ .`
   - Send emails to these recipients
   - Verify headers are properly formatted
   - Verify recipients receive emails correctly
   - Test reply-all functionality
3. Integration testing with existing email flows

## Notes

- The fix addresses the root cause but does not change other parts of the email sending pipeline
- Test file uses category `@interface SOGoDraftObject (Testing)` to expose private methods for testing
- Build system uses GNUstep; tests require proper configuration via `configure` script