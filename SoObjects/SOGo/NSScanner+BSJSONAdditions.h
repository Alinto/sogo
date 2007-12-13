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

#import <Foundation/NSScanner.h>

@class NSArray;
@class NSDictionary;
@class NSNumber;
@class NSString;

extern NSString *jsonObjectStartString;
extern NSString *jsonObjectEndString;
extern NSString *jsonArrayStartString;
extern NSString *jsonArrayEndString;
extern NSString *jsonKeyValueSeparatorString;
extern NSString *jsonValueSeparatorString;
extern NSString *jsonStringDelimiterString;
extern NSString *jsonStringEscapedDoubleQuoteString;
extern NSString *jsonStringEscapedSlashString;
extern NSString *jsonTrueString;
extern NSString *jsonFalseString;
extern NSString *jsonNullString;


@interface NSScanner (PrivateBSJSONAdditions)

- (BOOL)scanJSONObject:(NSDictionary **)dictionary;
- (BOOL)scanJSONArray:(NSArray **)array;
- (BOOL)scanJSONString:(NSString **)string;
- (BOOL)scanJSONValue:(id *)value;
- (BOOL)scanJSONNumber:(NSNumber **)number;

- (BOOL)scanJSONWhiteSpace;
- (BOOL)scanJSONKeyValueSeparator;
- (BOOL)scanJSONValueSeparator;
- (BOOL)scanJSONObjectStartString;
- (BOOL)scanJSONObjectEndString;
- (BOOL)scanJSONArrayStartString;
- (BOOL)scanJSONArrayEndString;
- (BOOL)scanJSONArrayEndString;
- (BOOL)scanJSONStringDelimiterString;

@end
