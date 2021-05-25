/*
  Copyright (C) 2005-2012 Inverse inc.

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>

//
//
//
@class RTFFontTable;

@interface RTFHandler : NSObject
{
  NSMapTable *_charsets;
  NSMutableData *_html;
  NSData *_data;

  const char *_bytes;
  int _current_pos;
  int _len;
}

- (id) initWithData: (NSData *) theData;
- (NSMutableData *) parse;

- (RTFFontTable *) parseFontTable;
- (void) mangleInternalStateWithBytesPtr: (const char*) newBytes
                          andCurrentPos: (int) newCurrentPos;

@end

//
//
//
@interface RTFStack: NSObject
{
  NSMutableArray *a;
}
- (void) push: (id) theObject;
- (id) pop;
@end

//
//
//
@interface RTFFormattingOptions : NSObject
{
@public
  BOOL bold;
  BOOL italic;
  BOOL underline;
  BOOL strikethrough;
  int font_index;
  int color_index;
  int start_pos;
  const unsigned short *charset;
}
@end

//
//
//
@interface RTFFontInfo : NSObject
{
@public
  NSString *family;
  unsigned char charset;
  NSString *name;
  unsigned int pitch;
  unsigned int index;
}

- (NSString *) description;
@end

//
// \fX - font, index in font table
//
@interface RTFFontTable : NSObject
{
  @public
  NSMapTable *fontInfos;
}

- (void) addFontInfo: (RTFFontInfo *) theFontInfo
             atIndex: (unsigned int ) theIndex;
- (RTFFontInfo *) fontInfoAtIndex: (unsigned int ) theIndex;
- (NSString *) description;

@end

//
//
//
@interface RTFColorDef : NSObject
{
@public
  unsigned char red;
  unsigned char green;
  unsigned char blue;
}

@end

//
// {\colortbl\red0\green0\blue0;\red128\green0\blue0;\red255\green0\blue0;}
//
// \cfX - color/foreground - index
// \cbX - color/background - index
//
//
@interface RTFColorTable : NSObject
{
  @public
  NSMutableArray *colorDefs;
}

- (void) addColorDef: (RTFColorDef *) theColorDef;

@end
