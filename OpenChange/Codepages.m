/* Codepages.m - this file is part of SOGo
 *
 * Copyright (C) 2014 Jesús García Sáez
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#import "Codepages.h"
#import <Foundation/NSArray.h>

@implementation Codepages

+ (NSDictionary *) getCodepagesTable
{
  static NSDictionary *table = nil;

  if (table == nil)
    {
      /* http://msdn.microsoft.com/en-us/library/dd317756%28v=vs.85%29.aspx */
      table = [[NSDictionary dictionaryWithObjectsAndKeys:
                  [NSNumber numberWithInt: 37], @"ibm037",
                  [NSNumber numberWithInt: 437], @"ibm437",
                  [NSNumber numberWithInt: 500], @"ibm500",
                  [NSNumber numberWithInt: 708], @"asmo-708",
                  [NSNumber numberWithInt: 720], @"dos-720",
                  [NSNumber numberWithInt: 737], @"ibm737",
                  [NSNumber numberWithInt: 775], @"ibm775",
                  [NSNumber numberWithInt: 850], @"ibm850",
                  [NSNumber numberWithInt: 852], @"ibm852",
                  [NSNumber numberWithInt: 855], @"ibm855",
                  [NSNumber numberWithInt: 857], @"ibm857",
                  [NSNumber numberWithInt: 858], @"ibm00858",
                  [NSNumber numberWithInt: 860], @"ibm860",
                  [NSNumber numberWithInt: 861], @"ibm861",
                  [NSNumber numberWithInt: 862], @"dos-862",
                  [NSNumber numberWithInt: 863], @"ibm863",
                  [NSNumber numberWithInt: 864], @"ibm864",
                  [NSNumber numberWithInt: 865], @"ibm865",
                  [NSNumber numberWithInt: 866], @"cp866",
                  [NSNumber numberWithInt: 869], @"ibm869",
                  [NSNumber numberWithInt: 870], @"ibm870",
                  [NSNumber numberWithInt: 874], @"windows-874",
                  [NSNumber numberWithInt: 875], @"cp875",
                  [NSNumber numberWithInt: 932], @"shift_jis",
                  [NSNumber numberWithInt: 936], @"gb2312",
                  [NSNumber numberWithInt: 949], @"ks_c_5601-1987",
                  [NSNumber numberWithInt: 950], @"big5",
                  [NSNumber numberWithInt: 1026], @"ibm1026",
                  [NSNumber numberWithInt: 1047], @"ibm01047",
                  [NSNumber numberWithInt: 1140], @"ibm01140",
                  [NSNumber numberWithInt: 1141], @"ibm01141",
                  [NSNumber numberWithInt: 1142], @"ibm01142",
                  [NSNumber numberWithInt: 1143], @"ibm01143",
                  [NSNumber numberWithInt: 1144], @"ibm01144",
                  [NSNumber numberWithInt: 1145], @"ibm01145",
                  [NSNumber numberWithInt: 1146], @"ibm01146",
                  [NSNumber numberWithInt: 1147], @"ibm01147",
                  [NSNumber numberWithInt: 1148], @"ibm01148",
                  [NSNumber numberWithInt: 1149], @"ibm01149",
                  [NSNumber numberWithInt: 1200], @"utf-16",
                  [NSNumber numberWithInt: 1201], @"unicodefffe",
                  [NSNumber numberWithInt: 1250], @"windows-1250",
                  [NSNumber numberWithInt: 1251], @"windows-1251",
                  [NSNumber numberWithInt: 1252], @"windows-1252",
                  [NSNumber numberWithInt: 1253], @"windows-1253",
                  [NSNumber numberWithInt: 1254], @"windows-1254",
                  [NSNumber numberWithInt: 1255], @"windows-1255",
                  [NSNumber numberWithInt: 1256], @"windows-1256",
                  [NSNumber numberWithInt: 1257], @"windows-1257",
                  [NSNumber numberWithInt: 1258], @"windows-1258",
                  [NSNumber numberWithInt: 1361], @"johab",
                  [NSNumber numberWithInt: 10000], @"macintosh",
                  [NSNumber numberWithInt: 10001], @"x-mac-japanese",
                  [NSNumber numberWithInt: 10002], @"x-mac-chinesetrad",
                  [NSNumber numberWithInt: 10003], @"x-mac-korean",
                  [NSNumber numberWithInt: 10004], @"x-mac-arabic",
                  [NSNumber numberWithInt: 10005], @"x-mac-hebrew",
                  [NSNumber numberWithInt: 10006], @"x-mac-greek",
                  [NSNumber numberWithInt: 10007], @"x-mac-cyrillic",
                  [NSNumber numberWithInt: 10008], @"x-mac-chinesesimp",
                  [NSNumber numberWithInt: 10010], @"x-mac-romanian",
                  [NSNumber numberWithInt: 10017], @"x-mac-ukrainian",
                  [NSNumber numberWithInt: 10021], @"x-mac-thai",
                  [NSNumber numberWithInt: 10029], @"x-mac-ce",
                  [NSNumber numberWithInt: 10079], @"x-mac-icelandic",
                  [NSNumber numberWithInt: 10081], @"x-mac-turkish",
                  [NSNumber numberWithInt: 10082], @"x-mac-croatian",
                  [NSNumber numberWithInt: 12000], @"utf-32",
                  [NSNumber numberWithInt: 12001], @"utf-32be",
                  [NSNumber numberWithInt: 20000], @"x-chinese-cns",
                  [NSNumber numberWithInt: 20001], @"x-cp20001",
                  [NSNumber numberWithInt: 20002], @"x-chinese-eten",
                  [NSNumber numberWithInt: 20003], @"x-cp20003",
                  [NSNumber numberWithInt: 20004], @"x-cp20004",
                  [NSNumber numberWithInt: 20005], @"x-cp20005",
                  [NSNumber numberWithInt: 20105], @"x-ia5",
                  [NSNumber numberWithInt: 20106], @"x-ia5-german",
                  [NSNumber numberWithInt: 20107], @"x-ia5-swedish",
                  [NSNumber numberWithInt: 20108], @"x-ia5-norwegian",
                  [NSNumber numberWithInt: 20127], @"us-ascii",
                  [NSNumber numberWithInt: 20261], @"x-cp20261",
                  [NSNumber numberWithInt: 20269], @"x-cp20269",
                  [NSNumber numberWithInt: 20273], @"ibm273",
                  [NSNumber numberWithInt: 20277], @"ibm277",
                  [NSNumber numberWithInt: 20278], @"ibm278",
                  [NSNumber numberWithInt: 20280], @"ibm280",
                  [NSNumber numberWithInt: 20284], @"ibm284",
                  [NSNumber numberWithInt: 20285], @"ibm285",
                  [NSNumber numberWithInt: 20290], @"ibm290",
                  [NSNumber numberWithInt: 20297], @"ibm297",
                  [NSNumber numberWithInt: 20420], @"ibm420",
                  [NSNumber numberWithInt: 20423], @"ibm423",
                  [NSNumber numberWithInt: 20424], @"ibm424",
                  [NSNumber numberWithInt: 20833], @"x-ebcdic-koreanextended",
                  [NSNumber numberWithInt: 20838], @"ibm-thai",
                  [NSNumber numberWithInt: 20866], @"koi8-r",
                  [NSNumber numberWithInt: 20871], @"ibm871",
                  [NSNumber numberWithInt: 20880], @"ibm880",
                  [NSNumber numberWithInt: 20905], @"ibm905",
                  [NSNumber numberWithInt: 20924], @"ibm00924",
                  [NSNumber numberWithInt: 20932], @"euc-jp",
                  [NSNumber numberWithInt: 20936], @"x-cp20936",
                  [NSNumber numberWithInt: 20949], @"x-cp20949",
                  [NSNumber numberWithInt: 21025], @"cp1025",
                  [NSNumber numberWithInt: 21866], @"koi8-u",
                  [NSNumber numberWithInt: 28591], @"iso-8859-1",
                  [NSNumber numberWithInt: 28592], @"iso-8859-2",
                  [NSNumber numberWithInt: 28593], @"iso-8859-3",
                  [NSNumber numberWithInt: 28594], @"iso-8859-4",
                  [NSNumber numberWithInt: 28595], @"iso-8859-5",
                  [NSNumber numberWithInt: 28596], @"iso-8859-6",
                  [NSNumber numberWithInt: 28597], @"iso-8859-7",
                  [NSNumber numberWithInt: 28598], @"iso-8859-8",
                  [NSNumber numberWithInt: 28599], @"iso-8859-9",
                  [NSNumber numberWithInt: 28603], @"iso-8859-13",
                  [NSNumber numberWithInt: 28605], @"iso-8859-15",
                  [NSNumber numberWithInt: 29001], @"x-europa",
                  [NSNumber numberWithInt: 38598], @"iso-8859-8-i",
                  [NSNumber numberWithInt: 50220], @"iso-2022-jp",
                  [NSNumber numberWithInt: 50221], @"csiso2022jp",
                  [NSNumber numberWithInt: 50222], @"iso-2022-jp",
                  [NSNumber numberWithInt: 50225], @"iso-2022-kr",
                  [NSNumber numberWithInt: 50227], @"x-cp50227",
                  [NSNumber numberWithInt: 51932], @"euc-jp",
                  [NSNumber numberWithInt: 51936], @"euc-cn",
                  [NSNumber numberWithInt: 51949], @"euc-kr",
                  [NSNumber numberWithInt: 52936], @"hz-gb-2312",
                  [NSNumber numberWithInt: 54936], @"gb18030",
                  [NSNumber numberWithInt: 57002], @"x-iscii-de",
                  [NSNumber numberWithInt: 57003], @"x-iscii-be",
                  [NSNumber numberWithInt: 57004], @"x-iscii-ta",
                  [NSNumber numberWithInt: 57005], @"x-iscii-te",
                  [NSNumber numberWithInt: 57006], @"x-iscii-as",
                  [NSNumber numberWithInt: 57007], @"x-iscii-or",
                  [NSNumber numberWithInt: 57008], @"x-iscii-ka",
                  [NSNumber numberWithInt: 57009], @"x-iscii-ma",
                  [NSNumber numberWithInt: 57010], @"x-iscii-gu",
                  [NSNumber numberWithInt: 57011], @"x-iscii-pa",
                  [NSNumber numberWithInt: 65000], @"utf-7",
                  [NSNumber numberWithInt: 65001], @"utf-8",
                  nil] retain];
      }
    return table;
}

+ (NSDictionary *) getReverseCodepagesTable
{
  static NSDictionary *table = nil;

  if (table == nil)
    {
      NSDictionary *codepages_table;
      NSEnumerator *enumerator;
      NSMutableArray *codepages, *names;
      id key;
      // Build reverse table: (NSNumber) codepage -> (NSString) encoding name
      codepages_table = [self getCodepagesTable];
      codepages = [NSMutableArray arrayWithCapacity: [codepages_table count]];
      names = [NSMutableArray arrayWithCapacity: [codepages_table count]];
      enumerator = [codepages_table keyEnumerator];
      while ((key = [enumerator nextObject]))
        {
          [names addObject: key];
          [codepages addObject: [codepages_table objectForKey: key]];
        }
      table = [[NSDictionary dictionaryWithObjects: names forKeys: codepages] retain];
    }
  return table;
}

+ (NSNumber *) getCodepageFromName: (NSString *) name
{
  return [[self getCodepagesTable] objectForKey: [name lowercaseString]];
}

+ (NSString *) getNameFromCodepage: (NSNumber *) codepage
{
  return [[self getReverseCodepagesTable] objectForKey: codepage];
}

@end
