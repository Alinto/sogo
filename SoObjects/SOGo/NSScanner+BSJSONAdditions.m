//
//  BSJSONAdditions
//
//  Created by Blake Seely on 2/1/06.
//  Copyright 2006 Blake Seely - http://www.blakeseely.com  All rights reserved.
//  Permission to use this code:
//
//  Feel free to use this code in your software, either as-is or 
//  in a modified form. Either way, please include a credit in 
//  your software's "About" box or similar, mentioning at least 
//  my name (Blake Seely).
//
//  Permission to redistribute this code:
//
//  You can redistribute this code, as long as you keep these 
//  comments. You can also redistribute modified versions of the 
//  code, as long as you add comments to say that you've made 
//  modifications (keeping these original comments too).
//
//  If you do use or redistribute this code, an email would be 
//  appreciated, just to let me know that people are finding my 
//  code useful. You can reach me at blakeseely@mac.com
//
//
//  Version 1.2: Includes modifications by Bill Garrison: http://www.standardorbit.com , which included
//    Unit Tests adapted from Jonathan Wight's CocoaJSON code: http://www.toxicsoftware.com 
//    I have included those adapted unit tests in this package.

#import <Foundation/NSArray.h>
#import <Foundation/NSDecimalNumber.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSValue.h>

#import "NSScanner+BSJSONAdditions.h"

NSString *jsonObjectStartString = @"{";
NSString *jsonObjectEndString = @"}";
NSString *jsonArrayStartString = @"[";
NSString *jsonArrayEndString = @"]";
NSString *jsonKeyValueSeparatorString = @":";
NSString *jsonValueSeparatorString = @",";
NSString *jsonStringDelimiterString = @"\"";
NSString *jsonStringEscapedDoubleQuoteString = @"\\\"";
NSString *jsonStringEscapedSlashString = @"\\\\";
NSString *jsonTrueString = @"true";
NSString *jsonFalseString = @"false";
NSString *jsonNullString = @"null";

@implementation NSScanner (PrivateBSJSONAdditions)

- (BOOL)scanJSONObject:(NSDictionary **)dictionary
{
  //[self setCharactersToBeSkipped:nil];
	
  BOOL result = NO;
	
  /* START - April 21, 2006 - Updated to bypass irrelevant characters at the beginning of a JSON string */
  NSString *ignoredString;
  [self scanUpToString:jsonObjectStartString intoString:&ignoredString];
  /* END - April 21, 2006 */

  if (![self scanJSONObjectStartString]) {
    // TODO: Error condition. For now, return false result, do nothing with the dictionary handle
  } else {
    NSMutableDictionary *jsonKeyValues = [[[NSMutableDictionary alloc] init] autorelease];
    NSString *key = nil;
    id value;
    [self scanJSONWhiteSpace];
    while (([self scanJSONString:&key]) && ([self scanJSONKeyValueSeparator]) && ([self scanJSONValue:&value])) {
      [jsonKeyValues setObject:value forKey:key];
      [self scanJSONWhiteSpace];
      // check to see if the character at scan location is a value separator. If it is, do nothing.
      if ([[[self string] substringWithRange:NSMakeRange([self scanLocation], 1)] isEqualToString:jsonValueSeparatorString]) {
	[self scanJSONValueSeparator];
      }
    }
    if ([self scanJSONObjectEndString]) {
      // whether or not we found a key-val pair, we found open and close brackets - completing an object
      result = YES;
      *dictionary = jsonKeyValues;
    }
  }
  return result;
}

- (BOOL)scanJSONArray:(NSArray **)array
{
  BOOL result = NO;
  NSMutableArray *values = [[[NSMutableArray alloc] init] autorelease];
  [self scanJSONArrayStartString];
  id value = nil;
	
  while ([self scanJSONValue:&value]) {
    [values addObject:value];
    [self scanJSONWhiteSpace];
    if ([[[self string] substringWithRange:NSMakeRange([self scanLocation], 1)] isEqualToString:jsonValueSeparatorString]) {
      [self scanJSONValueSeparator];
    }
  }
  if ([self scanJSONArrayEndString]) {
    result = YES;
    *array = values;
  }
	
  return result;
}

- (BOOL)scanJSONString:(NSString **)string
{
  BOOL result = NO;
  if ([self scanJSONStringDelimiterString]) {
    NSMutableString *chars = [[[NSMutableString alloc] init] autorelease];
    NSString *characterFormat = @"%C";
		
    // process character by character until we finish the string or reach another double-quote
    while ((![self isAtEnd]) && ([[self string] characterAtIndex:[self scanLocation]] != '\"')) {
      unichar currentChar = [[self string] characterAtIndex:[self scanLocation]];
      unichar nextChar;
      if (currentChar != '\\') {
	[chars appendFormat:characterFormat, currentChar];
	[self setScanLocation:([self scanLocation] + 1)];
      } else {
	nextChar = [[self string] characterAtIndex:([self scanLocation] + 1)];
	switch (nextChar) {
	case '\"':
	  [chars appendString:@"\""];
	  [self setScanLocation:([self scanLocation] + 2)];
	  break;
	case '\\':
	  [chars appendString:@"\\"]; // debugger shows result as having two slashes, but final output is correct. Possible debugger error?
	  [self setScanLocation:([self scanLocation] + 2)];
	  break;
	  /* TODO: json.org docs mention this seq, so does yahoo, but not recognized here by xcode, note from crockford: not a required escape
	     case '\/':
	     [chars appendString:@"\/"];
	     [self setScanLocation:([self scanLocation] + 2)];
	     break;
	  */
	case 'b':
	  [chars appendString:@"\b"];
	  [self setScanLocation:([self scanLocation] + 2)];
	  break;
	case 'f':
	  [chars appendString:@"\f"];
	  [self setScanLocation:([self scanLocation] + 2)];
	  break;
	case 'n':
	  [chars appendString:@"\n"];
	  [self setScanLocation:([self scanLocation] + 2)];
	  break;
	case 'r':
	  [chars appendString:@"\r"];
	  [self setScanLocation:([self scanLocation] + 2)];
	  break;
	case 't':
	  [chars appendString:@"\t"];
	  [self setScanLocation:([self scanLocation] + 2)];
	  break;
	case 'u': // unicode sequence - get string of hex chars, convert to int, convert to unichar, append
	  [self setScanLocation:([self scanLocation] + 2)]; // advance past '\u'
	  NSString *digits = [[self string] substringWithRange:NSMakeRange([self scanLocation], 4)];
	  /* START Updated code modified from code fix submitted by Bill Garrison - March 28, 2006 - http://www.standardorbit.net */
	  NSScanner *hexScanner = [NSScanner scannerWithString:digits];
	  NSString *verifiedHexDigits;
	  NSCharacterSet *hexDigitSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
	  if (NO == [hexScanner scanCharactersFromSet:hexDigitSet intoString:&verifiedHexDigits])
	    return NO;
	  if (4 != [verifiedHexDigits length])
	    return NO;
                        
	  // Read in the hex value
	  [hexScanner setScanLocation:0];
	  unsigned unicodeHexValue;
	  if (NO == [hexScanner scanHexInt:&unicodeHexValue]) {
	    return NO;
	  }
	  [chars appendFormat:characterFormat, unicodeHexValue];
	  /* END update - March 28, 2006 */
	  [self setScanLocation:([self scanLocation] + 4)];
	  break;
	default:
	  [chars appendFormat:@"\\%C", nextChar];
	  [self setScanLocation:([self scanLocation] + 2)];
	  break;
	}
      }
    }
		
    if (![self isAtEnd]) {
      result = [self scanJSONStringDelimiterString];
      *string = chars;
    }
		
    return result;
	
    /* this code is more appropriate if you have a separate method to unescape the found string
       for example, between inputting json and outputting it, it may make more sense to have a category on NSString to perform
       escaping and unescaping. Keeping this code and looking into this for a future update.
       unsigned int searchLength = [[self string] length] - [self scanLocation];
       unsigned int quoteLocation = [[self string] rangeOfString:jsonStringDelimiterString options:0 range:NSMakeRange([self scanLocation], searchLength)].location;
       searchLength = [[self string] length] - quoteLocation;
       while (([[[self string] substringWithRange:NSMakeRange((quoteLocation - 1), 2)] isEqualToString:jsonStringEscapedDoubleQuoteString]) &&
       (quoteLocation != NSNotFound) &&
       (![[[self string] substringWithRange:NSMakeRange((quoteLocation -2), 2)] isEqualToString:jsonStringEscapedSlashString])){
       searchLength = [[self string] length] - (quoteLocation + 1);
       quoteLocation = [[self string] rangeOfString:jsonStringDelimiterString options:0 range:NSMakeRange((quoteLocation + 1), searchLength)].location;
       }
		
       *string = [[self string] substringWithRange:NSMakeRange([self scanLocation], (quoteLocation - [self scanLocation]))];
       // TODO: process escape sequences out of the string - replacing with their actual characters. a function that does just this belongs
       // in another class. So it may make more sense to change this whole implementation to just go character by character instead.
       [self setScanLocation:(quoteLocation + 1)];
    */
    result = YES;
		
  }
	
  return result;
}

- (BOOL)scanJSONValue:(id *)value
{
  BOOL result = NO;
	
  [self scanJSONWhiteSpace];
  NSString *substring = [[self string] substringWithRange:NSMakeRange([self scanLocation], 1)];
  unsigned int trueLocation = [[self string] rangeOfString:jsonTrueString options:0 range:NSMakeRange([self scanLocation], ([[self string] length] - [self scanLocation]))].location;
  unsigned int falseLocation = [[self string] rangeOfString:jsonFalseString options:0 range:NSMakeRange([self scanLocation], ([[self string] length] - [self scanLocation]))].location;
  unsigned int nullLocation = [[self string] rangeOfString:jsonNullString options:0 range:NSMakeRange([self scanLocation], ([[self string] length] - [self scanLocation]))].location;
	
  if ([substring isEqualToString:jsonStringDelimiterString]) {
    result = [self scanJSONString:value];
  } else if ([substring isEqualToString:jsonObjectStartString]) {
    result = [self scanJSONObject:value];
  } else if ([substring isEqualToString:jsonArrayStartString]) {
    result = [self scanJSONArray:value];
  } else if ([self scanLocation] == trueLocation) {
    result = YES;
    *value = [NSNumber numberWithBool:YES];
    [self setScanLocation:([self scanLocation] + [jsonTrueString length])];
  } else if ([self scanLocation] == falseLocation) {
    result = YES;
    *value = [NSNumber numberWithBool:NO];
    [self setScanLocation:([self scanLocation] + [jsonFalseString length])];
  } else if ([self scanLocation] == nullLocation) {
    result = YES;
    *value = [NSNull null];
    [self setScanLocation:([self scanLocation] + [jsonNullString length])];
  } else if (([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[[self string] characterAtIndex:[self scanLocation]]]) ||
	     ([[self string] characterAtIndex:[self scanLocation]] == '-')){ // check to make sure it's a digit or -
    result =  [self scanJSONNumber:value];
  }
  return result;
}

- (BOOL)scanJSONNumber:(NSNumber **)number
{
  //NSDecimal decimal;
  //BOOL result = [self scanDecimal:&decimal];
  //*number = [NSDecimalNumber decimalNumberWithDecimal:decimal];
  int value;
  BOOL result = [self scanInt: &value];
  *number = [NSNumber numberWithInt: value];
  return result;
}

- (BOOL)scanJSONWhiteSpace
{
  //NSLog(@"Scanning white space - here are the next ten chars ---%@---", [[self string] substringWithRange:NSMakeRange([self scanLocation], 10)]);
  BOOL result = NO;
  NSCharacterSet *space = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  while ([space characterIsMember:[[self string] characterAtIndex:[self scanLocation]]]) {
    [self setScanLocation:([self scanLocation] + 1)];
    result = YES;
  }
  //NSLog(@"Done Scanning white space - here are the next ten chars ---%@---", [[self string] substringWithRange:NSMakeRange([self scanLocation], 10)]);
  return result;
}

- (BOOL)scanJSONKeyValueSeparator
{
  return [self scanString:jsonKeyValueSeparatorString intoString:NULL];
}

- (BOOL)scanJSONValueSeparator
{
  return [self scanString:jsonValueSeparatorString intoString:NULL];
}

- (BOOL)scanJSONObjectStartString
{
  return [self scanString:jsonObjectStartString intoString:NULL];
}

- (BOOL)scanJSONObjectEndString
{
  return [self scanString:jsonObjectEndString intoString:NULL];
}

- (BOOL)scanJSONArrayStartString
{
  return [self scanString:jsonArrayStartString intoString:NULL];
}

- (BOOL)scanJSONArrayEndString
{
  return [self scanString:jsonArrayEndString intoString:NULL];
}

- (BOOL)scanJSONStringDelimiterString;
{
  return [self scanString:jsonStringDelimiterString intoString:NULL];
}

@end
