/*
  Copyright (C) 2005-2013 Inverse inc.

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

#include "RTFHandler.h"
#include <Foundation/NSValue.h>
#include <Foundation/NSException.h>

//
// Useful macros
//
#define ADVANCE self->_bytes++; self->_current_pos++;
#define ADVANCE_N(N) self->_bytes += (N); self->_current_pos += (N);
#define REWIND self->_bytes--; self->_current_pos--;

#define DEFAULT_CHARSET 1
#define FONTNAME_LEN_MAX 100

//
// Charset definitions. See http://msdn.microsoft.com/en-us/goglobal/bb964654 for all details.
//
const unsigned short ansicpg1250[256] = {
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
    0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017, 0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
    0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
    0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f,
    0x20ac, 0x0000, 0x201a, 0x0000, 0x201e, 0x2026, 0x2020, 0x2021, 0x0000, 0x2030, 0x0160, 0x2039, 0x015a, 0x0164, 0x017d, 0x0179,
    0x0000, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x0000, 0x2122, 0x0161, 0x203a, 0x015b, 0x0165, 0x017e, 0x017a,
    0x00a0, 0x02c7, 0x02d8, 0x0141, 0x00a4, 0x0104, 0x00a6, 0x00a7, 0x00a8, 0x00a9, 0x015e, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x017b,
    0x00b0, 0x00b1, 0x02db, 0x0142, 0x00b4, 0x00b5, 0x00b6, 0x00b7, 0x00b8, 0x0105, 0x015f, 0x00bb, 0x013d, 0x02dd, 0x013e, 0x017c,
    0x0154, 0x00c1, 0x00c2, 0x0102, 0x00c4, 0x0139, 0x0106, 0x00c7, 0x010c, 0x00c9, 0x0118, 0x00cb, 0x011a, 0x00cd, 0x00ce, 0x010e,
    0x0110, 0x0143, 0x0147, 0x00d3, 0x00d4, 0x0150, 0x00d6, 0x00d7, 0x0158, 0x016e, 0x00da, 0x0170, 0x00dc, 0x00dd, 0x0162, 0x00df,
    0x0155, 0x00e1, 0x00e2, 0x0103, 0x00e4, 0x013a, 0x0107, 0x00e7, 0x010d, 0x00e9, 0x0119, 0x00eb, 0x011b, 0x00ed, 0x00ee, 0x010f,
    0x0111, 0x0144, 0x0148, 0x00f3, 0x00f4, 0x0151, 0x00f6, 0x00f7, 0x0159, 0x016f, 0x00fa, 0x0171, 0x00fc, 0x00fd, 0x0163, 0x02d9 };

const unsigned short ansicpg1251[256] = {
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
    0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017, 0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
    0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
    0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f,
    0x0402, 0x0403, 0x201a, 0x0453, 0x201e, 0x2026, 0x2020, 0x2021, 0x20ac, 0x2030, 0x0409, 0x2039, 0x040a, 0x040c, 0x040b, 0x040f,
    0x0452, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x0000, 0x2122, 0x0459, 0x203a, 0x045a, 0x045c, 0x045b, 0x045f,
    0x00a0, 0x040e, 0x045e, 0x0408, 0x00a4, 0x0490, 0x00a6, 0x00a7, 0x0401, 0x00a9, 0x0404, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x0407,
    0x00b0, 0x00b1, 0x0406, 0x0456, 0x0491, 0x00b5, 0x00b6, 0x00b7, 0x0451, 0x2116, 0x0454, 0x00bb, 0x0458, 0x0405, 0x0455, 0x0457,
    0x0410, 0x0411, 0x0412, 0x0413, 0x0414, 0x0415, 0x0416, 0x0417, 0x0418, 0x0419, 0x041a, 0x041b, 0x041c, 0x041d, 0x041e, 0x041f,
    0x0420, 0x0421, 0x0422, 0x0423, 0x0424, 0x0425, 0x0426, 0x0427, 0x0428, 0x0429, 0x042a, 0x042b, 0x042c, 0x042d, 0x042e, 0x042f,
    0x0430, 0x0431, 0x0432, 0x0433, 0x0434, 0x0435, 0x0436, 0x0437, 0x0438, 0x0439, 0x043a, 0x043b, 0x043c, 0x043d, 0x043e, 0x043f,
    0x0440, 0x0441, 0x0442, 0x0443, 0x0444, 0x0445, 0x0446, 0x0447, 0x0448, 0x0449, 0x044a, 0x044b, 0x044c, 0x044d, 0x044e, 0x044f };

const unsigned short ansicpg1252[256] = {
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
    0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017, 0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
    0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
    0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f,
    0x20ac, 0x0000, 0x201a, 0x0192, 0x201e, 0x2026, 0x2020, 0x2021, 0x02c6, 0x2030, 0x0160, 0x2039, 0x0152, 0x0000, 0x017d, 0x0000,
    0x0000, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x02dc, 0x2122, 0x0161, 0x203a, 0x0153, 0x0000, 0x017e, 0x0178,
    0x00a0, 0x00a1, 0x00a2, 0x00a3, 0x00a4, 0x00a5, 0x00a6, 0x00a7, 0x00a8, 0x00a9, 0x00aa, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x00af,
    0x00b0, 0x00b1, 0x00b2, 0x00b3, 0x00b4, 0x00b5, 0x00b6, 0x00b7, 0x00b8, 0x00b9, 0x00ba, 0x00bb, 0x00bc, 0x00bd, 0x00be, 0x00bf,
    0x00c0, 0x00c1, 0x00c2, 0x00c3, 0x00c4, 0x00c5, 0x00c6, 0x00c7, 0x00c8, 0x00c9, 0x00ca, 0x00cb, 0x00cc, 0x00cd, 0x00ce, 0x00cf,
    0x00d0, 0x00d1, 0x00d2, 0x00d3, 0x00d4, 0x00d5, 0x00d6, 0x00d7, 0x00d8, 0x00d9, 0x00da, 0x00db, 0x00dc, 0x00dd, 0x00de, 0x00df,
    0x00e0, 0x00e1, 0x00e2, 0x00e3, 0x00e4, 0x00e5, 0x00e6, 0x00e7, 0x00e8, 0x00e9, 0x00ea, 0x00eb, 0x00ec, 0x00ed, 0x00ee, 0x00ef,
    0x00f0, 0x00f1, 0x00f2, 0x00f3, 0x00f4, 0x00f5, 0x00f6, 0x00f7, 0x00f8, 0x00f9, 0x00fa, 0x00fb, 0x00fc, 0x00fd, 0x00fe, 0x00ff };

const unsigned short ansicpg1253[256] = {
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
    0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017, 0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
    0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
    0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f,
    0x20ac, 0x0000, 0x201a, 0x0192, 0x201e, 0x2026, 0x2020, 0x2021, 0x0000, 0x2030, 0x0000, 0x2039, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x0000, 0x2122, 0x0000, 0x203a, 0x0000, 0x0000, 0x0000, 0x0000,
    0x00a0, 0x0385, 0x0386, 0x00a3, 0x00a4, 0x00a5, 0x00a6, 0x00a7, 0x00a8, 0x00a9, 0x0000, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x2015,
    0x00b0, 0x00b1, 0x00b2, 0x00b3, 0x0384, 0x00b5, 0x00b6, 0x00b7, 0x0388, 0x0389, 0x038a, 0x00bb, 0x038c, 0x00bd, 0x038e, 0x038f,
    0x0390, 0x0391, 0x0392, 0x0393, 0x0394, 0x0395, 0x0396, 0x0397, 0x0398, 0x0399, 0x039a, 0x039b, 0x039c, 0x039d, 0x039e, 0x039f,
    0x03a0, 0x03a1, 0x0000, 0x03a3, 0x03a4, 0x03a5, 0x03a6, 0x03a7, 0x03a8, 0x03a9, 0x03aa, 0x03ab, 0x03ac, 0x03ad, 0x03ae, 0x03af,
    0x03b0, 0x03b1, 0x03b2, 0x03b3, 0x03b4, 0x03b5, 0x03b6, 0x03b7, 0x03b8, 0x03b9, 0x03ba, 0x03bb, 0x03bc, 0x03bd, 0x03be, 0x03bf,
    0x03c0, 0x03c1, 0x03c2, 0x03c3, 0x03c4, 0x03c5, 0x03c6, 0x03c7, 0x03c8, 0x03c9, 0x03ca, 0x03cb, 0x03cc, 0x03cd, 0x03ce, 0x0000 };

const unsigned short ansicpg1254[256] = {
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
    0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017, 0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
    0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
    0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f,
    0x20ac, 0x0000, 0x201a, 0x0192, 0x201e, 0x2026, 0x2020, 0x2021, 0x02c6, 0x2030, 0x0160, 0x2039, 0x0152, 0x0000, 0x0000, 0x0000,
    0x0000, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x02dc, 0x2122, 0x0161, 0x203a, 0x0153, 0x0000, 0x0000, 0x0178,
    0x00a0, 0x00a1, 0x00a2, 0x00a3, 0x00a4, 0x00a5, 0x00a6, 0x00a7, 0x00a8, 0x00a9, 0x00aa, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x00af,
    0x00b0, 0x00b1, 0x00b2, 0x00b3, 0x00b4, 0x00b5, 0x00b6, 0x00b7, 0x00b8, 0x00b9, 0x00ba, 0x00bb, 0x00bc, 0x00bd, 0x00be, 0x00bf,
    0x00c0, 0x00c1, 0x00c2, 0x00c3, 0x00c4, 0x00c5, 0x00c6, 0x00c7, 0x00c8, 0x00c9, 0x00ca, 0x00cb, 0x00cc, 0x00cd, 0x00ce, 0x00cf,
    0x011e, 0x00d1, 0x00d2, 0x00d3, 0x00d4, 0x00d5, 0x00d6, 0x00d7, 0x00d8, 0x00d9, 0x00da, 0x00db, 0x00dc, 0x0130, 0x015e, 0x00df,
    0x00e0, 0x00e1, 0x00e2, 0x00e3, 0x00e4, 0x00e5, 0x00e6, 0x00e7, 0x00e8, 0x00e9, 0x00ea, 0x00eb, 0x00ec, 0x00ed, 0x00ee, 0x00ef,
    0x011f, 0x00f1, 0x00f2, 0x00f3, 0x00f4, 0x00f5, 0x00f6, 0x00f7, 0x00f8, 0x00f9, 0x00fa, 0x00fb, 0x00fc, 0x0131, 0x015f, 0x00ff };

const unsigned short ansicpg1255[256] = {
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
    0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017, 0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
    0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
    0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f,
    0x20ac, 0x0000, 0x201a, 0x0192, 0x201e, 0x2026, 0x2020, 0x2021, 0x02c6, 0x2030, 0x0000, 0x2039, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x02dc, 0x2122, 0x0000, 0x203a, 0x0000, 0x0000, 0x0000, 0x0000,
    0x00a0, 0x00a1, 0x00a2, 0x00a3, 0x20aa, 0x00a5, 0x00a6, 0x00a7, 0x00a8, 0x00a9, 0x00d7, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x00af,
    0x00b0, 0x00b1, 0x00b2, 0x00b3, 0x00b4, 0x00b5, 0x00b6, 0x00b7, 0x00b8, 0x00b9, 0x00f7, 0x00bb, 0x00bc, 0x00bd, 0x00be, 0x00bf,
    0x05b0, 0x05b1, 0x05b2, 0x05b3, 0x05b4, 0x05b5, 0x05b6, 0x05b7, 0x05b8, 0x05b9, 0x0000, 0x05bb, 0x05bc, 0x05bd, 0x05be, 0x05bf,
    0x05c0, 0x05c1, 0x05c2, 0x05c3, 0x05f0, 0x05f1, 0x05f2, 0x05f3, 0x05f4, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x05d0, 0x05d1, 0x05d2, 0x05d3, 0x05d4, 0x05d5, 0x05d6, 0x05d7, 0x05d8, 0x05d9, 0x05da, 0x05db, 0x05dc, 0x05dd, 0x05de, 0x05df,
    0x05e0, 0x05e1, 0x05e2, 0x05e3, 0x05e4, 0x05e5, 0x05e6, 0x05e7, 0x05e8, 0x05e9, 0x05ea, 0x0000, 0x0000, 0x200e, 0x200f, 0x0000 };

const unsigned short ansicpg1256[256] = {
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
    0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017, 0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
    0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
    0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f,
    0x20ac, 0x067e, 0x201a, 0x0192, 0x201e, 0x2026, 0x2020, 0x2021, 0x02c6, 0x2030, 0x0679, 0x2039, 0x0152, 0x0686, 0x0698, 0x0688,
    0x06af, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x06a9, 0x2122, 0x0691, 0x203a, 0x0153, 0x200c, 0x200d, 0x06ba,
    0x00a0, 0x060c, 0x00a2, 0x00a3, 0x00a4, 0x00a5, 0x00a6, 0x00a7, 0x00a8, 0x00a9, 0x06be, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x00af,
    0x00b0, 0x00b1, 0x00b2, 0x00b3, 0x00b4, 0x00b5, 0x00b6, 0x00b7, 0x00b8, 0x00b9, 0x061b, 0x00bb, 0x00bc, 0x00bd, 0x00be, 0x061f,
    0x06c1, 0x0621, 0x0622, 0x0623, 0x0624, 0x0625, 0x0626, 0x0627, 0x0628, 0x0629, 0x062a, 0x062b, 0x062c, 0x062d, 0x062e, 0x062f,
    0x0630, 0x0631, 0x0632, 0x0633, 0x0634, 0x0635, 0x0636, 0x00d7, 0x0637, 0x0638, 0x0639, 0x063a, 0x0640, 0x0641, 0x0642, 0x0643,
    0x00e0, 0x0644, 0x00e2, 0x0645, 0x0646, 0x0647, 0x0648, 0x00e7, 0x00e8, 0x00e9, 0x00ea, 0x00eb, 0x0649, 0x064a, 0x00ee, 0x00ef,
    0x064b, 0x064c, 0x064d, 0x064e, 0x00f4, 0x064f, 0x0650, 0x00f7, 0x0651, 0x00f9, 0x0652, 0x00fb, 0x00fc, 0x200e, 0x200f, 0x06d2 };

const unsigned short ansicpg1257[256] = {
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
    0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017, 0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
    0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
    0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f,
    0x20ac, 0x0000, 0x201a, 0x0000, 0x201e, 0x2026, 0x2020, 0x2021, 0x0000, 0x2030, 0x0000, 0x2039, 0x0000, 0x00a8, 0x02c7, 0x00b8,
    0x0000, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x0000, 0x2122, 0x0000, 0x203a, 0x0000, 0x00af, 0x02db, 0x0000,
    0x00a0, 0x0000, 0x00a2, 0x00a3, 0x00a4, 0x0000, 0x00a6, 0x00a7, 0x00d8, 0x00a9, 0x0156, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x00c6,
    0x00b0, 0x00b1, 0x00b2, 0x00b3, 0x00b4, 0x00b5, 0x00b6, 0x00b7, 0x00f8, 0x00b9, 0x0157, 0x00bb, 0x00bc, 0x00bd, 0x00be, 0x00e6,
    0x0104, 0x012e, 0x0100, 0x0106, 0x00c4, 0x00c5, 0x0118, 0x0112, 0x010c, 0x00c9, 0x0179, 0x0116, 0x0122, 0x0136, 0x012a, 0x013b,
    0x0160, 0x0143, 0x0145, 0x00d3, 0x014c, 0x00d5, 0x00d6, 0x00d7, 0x0172, 0x0141, 0x015a, 0x016a, 0x00dc, 0x017b, 0x017d, 0x00df,
    0x0105, 0x012f, 0x0101, 0x0107, 0x00e4, 0x00e5, 0x0119, 0x0113, 0x010d, 0x00e9, 0x017a, 0x0117, 0x0123, 0x0137, 0x012b, 0x013c,
    0x0161, 0x0144, 0x0146, 0x00f3, 0x014d, 0x00f5, 0x00f6, 0x00f7, 0x0173, 0x0142, 0x015b, 0x016b, 0x00fc, 0x017c, 0x017e, 0x02d9 };

const unsigned short ansicpg1258[256] = {
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
    0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017, 0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
    0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
    0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f,
    0x20ac, 0x0000, 0x201a, 0x0192, 0x201e, 0x2026, 0x2020, 0x2021, 0x02c6, 0x2030, 0x0000, 0x2039, 0x0152, 0x0000, 0x0000, 0x0000,
    0x0000, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x02dc, 0x2122, 0x0000, 0x203a, 0x0153, 0x0000, 0x0000, 0x0178,
    0x00a0, 0x00a1, 0x00a2, 0x00a3, 0x00a4, 0x00a5, 0x00a6, 0x00a7, 0x00a8, 0x00a9, 0x00aa, 0x00ab, 0x00ac, 0x00ad, 0x00ae, 0x00af,
    0x00b0, 0x00b1, 0x00b2, 0x00b3, 0x00b4, 0x00b5, 0x00b6, 0x00b7, 0x00b8, 0x00b9, 0x00ba, 0x00bb, 0x00bc, 0x00bd, 0x00be, 0x00bf,
    0x00c0, 0x00c1, 0x00c2, 0x0102, 0x00c4, 0x00c5, 0x00c6, 0x00c7, 0x00c8, 0x00c9, 0x00ca, 0x00cb, 0x0300, 0x00cd, 0x00ce, 0x00cf,
    0x0110, 0x00d1, 0x0309, 0x00d3, 0x00d4, 0x01a0, 0x00d6, 0x00d7, 0x00d8, 0x00d9, 0x00da, 0x00db, 0x00dc, 0x01af, 0x0303, 0x00df,
    0x00e0, 0x00e1, 0x00e2, 0x0103, 0x00e4, 0x00e5, 0x00e6, 0x00e7, 0x00e8, 0x00e9, 0x00ea, 0x00eb, 0x0301, 0x00ed, 0x00ee, 0x00ef,
    0x0111, 0x00f1, 0x0323, 0x00f3, 0x00f4, 0x01a1, 0x00f6, 0x00f7, 0x00f8, 0x00f9, 0x00fa, 0x00fb, 0x00fc, 0x01b0, 0x20ab, 0x00ff };

const unsigned short ansicpg874[256] = {
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000a, 0x000b, 0x000c, 0x000d, 0x000e, 0x000f,
    0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017, 0x0018, 0x0019, 0x001a, 0x001b, 0x001c, 0x001d, 0x001e, 0x001f,
    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
    0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
    0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f,
    0x20ac, 0x0000, 0x0000, 0x0000, 0x0000, 0x2026, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x00a0, 0x0e01, 0x0e02, 0x0e03, 0x0e04, 0x0e05, 0x0e06, 0x0e07, 0x0e08, 0x0e09, 0x0e0a, 0x0e0b, 0x0e0c, 0x0e0d, 0x0e0e, 0x0e0f,
    0x0e10, 0x0e11, 0x0e12, 0x0e13, 0x0e14, 0x0e15, 0x0e16, 0x0e17, 0x0e18, 0x0e19, 0x0e1a, 0x0e1b, 0x0e1c, 0x0e1d, 0x0e1e, 0x0e1f,
    0x0e20, 0x0e21, 0x0e22, 0x0e23, 0x0e24, 0x0e25, 0x0e26, 0x0e27, 0x0e28, 0x0e29, 0x0e2a, 0x0e2b, 0x0e2c, 0x0e2d, 0x0e2e, 0x0e2f,
    0x0e30, 0x0e31, 0x0e32, 0x0e33, 0x0e34, 0x0e35, 0x0e36, 0x0e37, 0x0e38, 0x0e39, 0x0e3a, 0x0000, 0x0000, 0x0000, 0x0000, 0x0e3f,
    0x0e40, 0x0e41, 0x0e42, 0x0e43, 0x0e44, 0x0e45, 0x0e46, 0x0e47, 0x0e48, 0x0e49, 0x0e4a, 0x0e4b, 0x0e4c, 0x0e4d, 0x0e4e, 0x0e4f,
    0x0e50, 0x0e51, 0x0e52, 0x0e53, 0x0e54, 0x0e55, 0x0e56, 0x0e57, 0x0e58, 0x0e59, 0x0e5a, 0x0e5b, 0x0000, 0x0000, 0x0000, 0x0000 };

//
//
//
@implementation RTFStack

- (id) init
{
  if ((self = [super init]))
    {
      a = [[NSMutableArray alloc] init];
    }
  return self;
}

- (void) dealloc
{
  [a release];
  [super dealloc];
}

- (void) push: (id) theObject
{
  [a addObject: theObject];
}

- (id) pop
{
  id o = nil;

  if ([a count])
    {
      o = [[[a lastObject] retain] autorelease];
      [a removeLastObject];
    }

  return o;
}

- (id) top
{
  id o = nil;

  if ([a count])
    {
      o = [[[a lastObject] retain] autorelease];
    }

  return o;
}

@end

//
//
//
@implementation RTFFormattingOptions
@end

//
//
//
@implementation RTFFontInfo

- (id) init
{
  if ((self = [super init]))
    {

    }

  charset = DEFAULT_CHARSET;
  return self;
}

- (void) dealloc
{
  [family release];
  [name release];
  [super dealloc];
}

- (NSString *) description
{
  NSString *description;
  description = [NSString stringWithFormat:
                          @"%u name=%@ family=%@ charset=%u pitch=%u",
                          index, name, family, charset, pitch
                 ];
  return description;
}

@end

//
//
//
@implementation RTFFontTable

- (id) init
{
  if ((self = [super init]))
    {
      fontInfos = NSCreateMapTable(NSObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 128);
    }
  return self;
}

- (void) dealloc
{
  NSFreeMapTable(fontInfos);
  [super dealloc];
}

- (void) addFontInfo: (RTFFontInfo *) theFontInfo
             atIndex: (unsigned int) theIndex
{
  NSNumber *key;

  key = [NSNumber numberWithInt: theIndex];
  NSMapInsert(fontInfos, key, (void*) theFontInfo);
}

- (RTFFontInfo *) fontInfoAtIndex: (unsigned int) theIndex
{
  NSNumber *key;

  key = [NSNumber numberWithInt: theIndex];
  return NSMapGet(fontInfos, key);
}

- (NSString *) description
{
  NSMutableString *description;
  NSEnumerator *enumerator;
  RTFFontInfo *fontInfo;

  description = [NSMutableString stringWithFormat: @"Number of fonts: %u\n", [fontInfos count]];

  enumerator = [fontInfos objectEnumerator];
  while ((fontInfo = [enumerator nextObject]))
    {
      [description appendString: [fontInfo description]];
      [description appendString: @"\n"];
    }

  return description;
}

@end

//
//
//
@implementation RTFColorDef

@end

//
//
//
@implementation RTFColorTable

- (id) init
{
  if ((self = [super init]))
    {
      colorDefs = [[NSMutableArray alloc] init];
    }
  return self;
}

- (void) dealloc
{
  [colorDefs release];
  [super dealloc];
}

- (void) addColorDef: (RTFColorDef *) theColorDef
{
  [colorDefs addObject: theColorDef];
}

- (RTFColorDef *) colorDefAtIndex: (unsigned int) theIndex
{
  return [colorDefs objectAtIndex: theIndex];
}

@end

//
//
//
@implementation RTFHandler

static NSMapTable *_charsets = nil;
static NSMapTable *_cws = nil;
typedef enum {
  CW_UNKNOWN = 0,
  CW_ANSICPG,
  CW_B,
  CW_CF,
  CW_COLORTBL,
  CW_F,
  CW_FONTTBL,
  CW_I,
  CW_PAR,
  CW_PICT,
  CW_SOFTLINE,
  CW_STRIKE,
  CW_STYLESHEET,
  CW_TAB,
  CW_U,
  CW_UL,
  CW_ULNONE
} commandWordId;

static NSMapTable *_fontCws = nil;
typedef enum {
  FONTCW_UNKNOWN = 0,
  FONTCW_F,
  FONTCW_FBIDI,
  FONTCW_FCHARSET,
  FONTCW_FDECOR,
  FONTCW_FMODERN,
  FONTCW_FNIL,
  FONTCW_FPRQ,
  FONTCW_FROMAN,
  FONTCW_FSCRIPT,
  FONTCW_FSWISS,
  FONTCW_FTECH
} fontCommandWordId;

static void _init_charsets_table()
{
      _charsets = NSCreateMapTable(NSObjectMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 23);
      // 238 — Eastern European - cpg1250
      NSMapInsert(_charsets, @"ansicpg1250", ansicpg1250);
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 238], ansicpg1250);
      // 204 — Russian - cpg1251
      NSMapInsert(_charsets, @"ansicpg1251", ansicpg1251);
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 204], ansicpg1251);
      //  0 - Latin 1 - cpg1252 - also know as ANSI
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 0], ansicpg1252);
      NSMapInsert(_charsets, @"ansicpg1252", ansicpg1252);
      // 161 - Greek  cpg1253
      NSMapInsert(_charsets, @"ansicpg1253", ansicpg1253);
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 161], ansicpg1253);
      // 162 — Turkish - cpg1254
      NSMapInsert(_charsets, @"ansicpg1254", ansicpg1254);
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 162], ansicpg1254);
      // 177 — Hebrew Traditional - cpg1255
      // also 181 - Hebrew user
      NSMapInsert(_charsets, @"ansicpg1255", ansicpg1255);
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 177], ansicpg1255);
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 181], ansicpg1255);
      // 178 — Arabic  - cpg1256
      // also 179 - Arabic traditional
      // also 180 - Arabic User
      NSMapInsert(_charsets, @"ansicpg1256", ansicpg1256);
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 178], ansicpg1256);
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 179], ansicpg1256);
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 180], ansicpg1256);
      // 186 — Baltic - pg 1257
      NSMapInsert(_charsets, @"ansicpg1257", ansicpg1257);
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 186], ansicpg1257);
      // 163 — Vietnamese - pg1259
      NSMapInsert(_charsets, @"ansicpg1258", ansicpg1258);
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 163], ansicpg1258);
      // 222 — Thai - cpg874
      NSMapInsert(_charsets, @"ansicpg874", ansicpg874);
      NSMapInsert(_charsets, [NSNumber numberWithUnsignedChar: 222], ansicpg874);

      // TODO: check differences between traditional/user/no-qualified for Arabic and Hebrew
      // TODO: missing codepage for the following codes:
      // 2 — Symbol
      // 3 — Invalid
      // 77 — Mac
      // 128 — Shift Jis
      // 129 — Hangul
      // 130 — Johab
      // 134 — GB2312
      // 136 — Big5
      // 254 — PC 437
      // 255 — OEM
}

static void _init_cws_table()
{
  _cws = NSCreateMapTable(NSObjectMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 16);
  NSMapInsert(_cws, @"ansicpg", (void *) CW_ANSICPG);
  NSMapInsert(_cws, @"b", (void *) CW_B);
  NSMapInsert(_cws, @"cf", (void *) CW_CF);
  NSMapInsert(_cws, @"colortbl", (void *) CW_COLORTBL);
  NSMapInsert(_cws, @"f", (void *) CW_F);
  NSMapInsert(_cws, @"fonttbl", (void *) CW_FONTTBL);
  NSMapInsert(_cws, @"i", (void *) CW_I);
  NSMapInsert(_cws, @"par", (void *) CW_PAR);
  NSMapInsert(_cws, @"pict", (void *) CW_PICT);
  NSMapInsert(_cws, @"softline", (void *) CW_SOFTLINE);
  NSMapInsert(_cws, @"strike", (void *) CW_STRIKE);
  NSMapInsert(_cws, @"stylesheet", (void *) CW_STYLESHEET);
  NSMapInsert(_cws, @"tab", (void *) CW_TAB);
  NSMapInsert(_cws, @"u", (void *) CW_U);
  NSMapInsert(_cws, @"ul", (void *) CW_UL);
  NSMapInsert(_cws, @"ulnone", (void *) CW_ULNONE);
}

static void _init_fontCws_table()
{
  _fontCws = NSCreateMapTable(NSObjectMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 23);
  NSMapInsert(_fontCws, @"f", (void *) FONTCW_F);
  NSMapInsert(_fontCws, @"fbidi", (void *) FONTCW_FBIDI);
  NSMapInsert(_fontCws, @"fcharset", (void *) FONTCW_FCHARSET);
  NSMapInsert(_fontCws, @"fdecor", (void *) FONTCW_FDECOR);
  NSMapInsert(_fontCws, @"fmodern", (void *) FONTCW_FMODERN);
  NSMapInsert(_fontCws, @"fnil", (void *) FONTCW_FNIL);
  NSMapInsert(_fontCws, @"fprq", (void *) FONTCW_FPRQ);
  NSMapInsert(_fontCws, @"froman", (void *) FONTCW_FROMAN);
  NSMapInsert(_fontCws, @"fscript", (void *) FONTCW_FSCRIPT);
  NSMapInsert(_fontCws, @"fswiss", (void *) FONTCW_FSWISS);
  NSMapInsert(_fontCws, @"ftech", (void *) FONTCW_FTECH);
}

- (id) initWithData: (NSData *) theData
{
  if ((self = [super init]))
    {
      ASSIGN(_data, theData);
      _bytes = (char *)[_data bytes];
      _len = [_data length];
      _current_pos = 0;
      if (_charsets == nil)
          _init_charsets_table();
      if (_cws == nil)
        _init_cws_table();
      if (_fontCws == nil)
        _init_fontCws_table();
    }

  return self;
}

- (void) dealloc
{
  NSFreeMapTable(_charsets);
  [_data release];
  [super dealloc];
}

/*
  Returns pointer to the control word and in len pointer its length including numeric argument
*/
- (const char *) parseControlWord: (unsigned int *) len
{
  const char *start, *end;

  start = ADVANCE;

  /*
    A control word is defined by:

    \<ASCII Letter Sequence><Delimiter>
  */
  while (isalpha(*_bytes))
    {
      ADVANCE;
    }

  /*
    The <Delimiter> can be one of the following:

     - A space. This serves only to delimit a control word and is
       ignored in subsequent processing.

     - A numeric digit or an ASCII minus sign (-), which indicates
       that a numeric parameter is associated with the control word.
       Only this case requires to include it in the control word.

     - Any character other than a letter or a digit
  */
  if (*_bytes == '-' || isdigit(*_bytes))
    {
      ADVANCE;
      while (isdigit(*_bytes))  // TODO: Allow up to 10 digits
        {
          ADVANCE;
        }
    }
  /* In this case, the delimiting character terminates the control
     word and is not part of the control word. */

  end = _bytes;
  *len = end-start-1;

  return start+1;
}

- (const char *) parseControlWordAndSetLenIn: (unsigned int *) len
                         setHasIntArgumentIn: (BOOL *) hasArg
                            setIntArgumentIn: (int *) arg
{
  const char *start;
  const char *end = NULL;
  const char *startArg = NULL;
  const char *endArg = NULL;

  ADVANCE;
  start = _bytes;

  /*
    A control word is defined by:

    \<ASCII Letter Sequence><Delimiter>
  */
  while (isalpha(*_bytes))
    {
      end = _bytes;
      ADVANCE;
    }

  if (end == NULL)
    {
      return NULL;
    }

  /*
    The <Delimiter> can be one of the following:

     - A space. This serves only to delimit a control word and is
       ignored in subsequent processing.

     - A numeric digit or an ASCII minus sign (-), which indicates
       that a numeric parameter is associated with the control word.
       Only this case requires to include it in the control word.

     - Any character other than a letter or a digit
  */

  if (*_bytes == '-' || isdigit(*_bytes))
    {
      startArg = _bytes;
      endArg = _bytes;
      ADVANCE;
      while (isdigit(*_bytes))
        {
          endArg = _bytes;
          ADVANCE;
        }
    }

  *hasArg = NO;
  *arg = 0;
  if (startArg)
    {
      NSString *s;
      unsigned int argLength = endArg - startArg + 1;
      // the next guard is to protect against a single '-'
      if (argLength > 1 || (*startArg != '-'))
        {
          s = [[NSString alloc] initWithBytesNoCopy: (void *) startArg
                                             length: argLength
                                           encoding: NSASCIIStringEncoding
                                       freeWhenDone: NO];
          [s autorelease];
          *hasArg = YES;
          *arg = [s intValue]; // Warning: it does not detect conversion errors
        }
    }


  /* In other cases, the delimiting character terminates the control
     word and is not part of the control word. */
  *len = end - start + 1;
  return start;
}

//
// {\colortbl\red0\green0\blue0;\red128\green0\blue0;\red255\green0\blue0;}
//
- (RTFColorTable *) parseColorTable
{
  RTFColorTable *colorTable;
  RTFColorDef *colorDef;

  colorTable = [[[RTFColorTable alloc] init] autorelease];
  colorDef = [[[RTFColorDef alloc] init] autorelease];

  while (*_bytes != '}')
    {
      if (*_bytes == ';')
        {
          [colorTable addColorDef: colorDef];
          colorDef = [[[RTFColorDef alloc] init] autorelease];
          ADVANCE;
        }
      else if (*_bytes == '\\')
        {
          const char *cw;
          unsigned int len;
          NSString *s;

          cw = [self parseControlWord: &len];

          // Skip our control word
          //if (strncmp(start+1, "colortbl", len) == 0)
          //  continue;

          s = [[NSString alloc] initWithBytesNoCopy: (void *)cw
                                             length: len
                                           encoding: NSASCIIStringEncoding
                                       freeWhenDone: NO];
          [s autorelease];

          if ([s hasPrefix: @"red"])
            {
              colorDef->red = [[s substringFromIndex: 3] intValue];
            }
          else if ([s hasPrefix: @"green"])
            {
              colorDef->green = [[s substringFromIndex: 4] intValue];
            }
          else
            {
              colorDef->blue = [[s substringFromIndex: 4] intValue];
            }
        }
      else
        {
          ADVANCE;
        }

    }

  return colorTable;
}

//
// Possible formats:
//
// {\fonttbl\f0\fswiss Helvetica;}
// {\fonttbl{\f0\froman\fcharset0\fprq2 Arial;}{\f1\fswiss\fprq2\fcharset0 Arial;}}
//
// FIXME: Complex ones not handled right now:
//
// {\fonttbl{\f2\fnil\fcharset256\fprq2{\*\panose 00020703090202050204}Courier New;}{...
// {\fonttbl{\f31\fnil\fcharset0\fprq0 Times New Roman Monotype{\*\falt Times New Roman};}{...
//
// We receive the full string.
//
- (RTFFontTable *) parseFontTable
{
  RTFFontTable *fontTable;
  RTFFontInfo *fontInfo;

  unsigned int level;

  fontTable = [[[RTFFontTable alloc] init] autorelease];
  fontInfo = nil;
  level = 0;

  do
    {
      if (*_bytes == '{')
        {
          if (fontTable && level == 1)
            {
              fontInfo = [[[RTFFontInfo alloc] init] autorelease];
            }
          ADVANCE;
          level++;
        }
      else if (*_bytes == '}')
        {
          if (fontTable && level == 2) //&& ![NSAllMapTableValues(fontTable->fontInfos) containsObject: fontInfo])
            {
              [fontTable addFontInfo: fontInfo  atIndex: fontInfo->index];
            }
          ADVANCE;
          level--;
        }
      else if (*_bytes == '\\')
        {
          const char *cw;
          unsigned int len;
          BOOL hasArg;
          int arg;
          NSString *cwKey;
          fontCommandWordId cwId;

          cw = [self parseControlWordAndSetLenIn: &len
                             setHasIntArgumentIn: &hasArg
                                setIntArgumentIn: &arg];
          if (level != 2)
            continue;
          else if (cw == NULL)
            continue;

          cwKey= [[NSString alloc] initWithBytesNoCopy: (void *)cw
                                                 length: len
                                               encoding: NSASCIIStringEncoding
                                           freeWhenDone: NO];
          [cwKey autorelease];

          cwId = (fontCommandWordId) NSMapGet(_fontCws, cwKey);
          switch (cwId)
            {
            case FONTCW_F:
              if (hasArg)
                fontInfo->index = arg;
              break;
            case FONTCW_FBIDI:
              fontInfo->family = @"bidi";
              break;
            case FONTCW_FCHARSET:
              if (hasArg)
                fontInfo->charset = arg;
              break;
            case FONTCW_FDECOR:
              fontInfo->family = @"decor";
              break;
            case FONTCW_FMODERN:
              fontInfo->family = @"modern";
              break;
            case FONTCW_FNIL:
              fontInfo->family = @"nil";
              break;
            case FONTCW_FPRQ:
              if (hasArg)
                fontInfo->pitch = arg;
              break;
            case FONTCW_FROMAN:
              fontInfo->family = @"roman";
              break;
            case FONTCW_FSCRIPT:
              fontInfo->family = @"script";
              break;
            case FONTCW_FSWISS:
              fontInfo->family = @"swiss";
              break;
            case FONTCW_FTECH:
              fontInfo->family = @"tech";
              break;
            case FONTCW_UNKNOWN:
            default:
              // do nothing
              break;
            }
        }
      else // no char
        {
          if (level == 2 && isalnum(*_bytes))
            {
              // we assume this is the fontname
              unsigned int fontnameLen;
              const char *delim = strpbrk(_bytes, ";{}\\");
              if (delim == NULL)
                {
                  // no delimiter found, we skip to next characters
                  ADVANCE;
                  continue;
                }
              fontnameLen = delim - _bytes;
              // only valid if the delimiter is a correct ';'
              if (*delim == ';')
                {
                  // there is no explicit limit length but we took 100
                  // as protection
                  if (delim && fontnameLen <= FONTNAME_LEN_MAX)
                    {
                      fontInfo->name = [[NSString alloc] initWithBytesNoCopy: (char *) _bytes
                                                                      length: fontnameLen
                                                                    encoding: NSASCIIStringEncoding
                                                                freeWhenDone: NO];
                      ADVANCE_N(fontnameLen);
                    }
                }
              else {
                // advance just before the special character
                ADVANCE_N(fontnameLen - 1);
              }
            }
          ADVANCE;
        }

    } while (level > 0);

  return fontTable;
}

//
//
//
- (void) parseStyleSheet
{
  unsigned int count;

  count = 0;

  do
   {
     if (*_bytes == '{')
        {
           count++;
        }
     else if (*_bytes == '}')
        {
           count--;
        }
     ADVANCE;

   } while (count != 0);
}

- (void) parseIgnoringEverything
{
  unsigned int count = 1;
  // Ignore everything. But we cannot parse it blindly because it could have
  // binary data with '}' and '{' bytes, so disasters can happen and they will
  do
    {
      if (*_bytes == '\\')
        {
          unsigned int binary_size, len = 0, cw_len;
          const char *cw = [self parseControlWord: &len];
          cw_len = strlen("bin");
          if (strncmp(cw, "bin", cw_len) == 0 && len > cw_len)
            {
              NSString *s;
              s = [[NSString alloc] initWithBytesNoCopy: (void *) cw + cw_len
                                                 length: len - cw_len
                                               encoding: NSASCIIStringEncoding
                                           freeWhenDone: NO];
              [s autorelease];
              binary_size = [s intValue];
              ADVANCE_N(binary_size);
            }
        }

      if (*_bytes == '{') count++;
      if (*_bytes == '}') count--;
      ADVANCE;
    }
  while (count > 0);
}

//
//
//
- (void) parsePicture
{
  [self parseIgnoringEverything];
}


// todo:  This keyword is only valid in the RTF header section right after the \ansi, \mac, \pc or \pca keyword.
inline static void parseAnsicpg (BOOL hasArg, int arg, const unsigned short **out_default_char)
{
  NSString *key;
  const unsigned short *res;

  if (!hasArg)
    return;
  key = [NSString stringWithFormat: @"anscicpg%i", arg];
  res =  NSMapGet(_charsets, key);
  if (res)
    *out_default_char = res;
}

inline static void parseB(RTFHandler *self, BOOL hasArg, int arg, RTFFormattingOptions *formattingOptions)
{
  if (!formattingOptions)
    return;
  if (hasArg && arg == 0)
    {
      [self->_html appendBytes: "</b>"  length: 4];
      formattingOptions->bold = NO;
    }
  else
    {
      [self->_html appendBytes: "<b>"  length: 3];
      formattingOptions->bold = YES;
    }
}

inline static void parseCf(RTFHandler *self, BOOL hasArg, int arg, RTFFormattingOptions *formattingOptions, RTFColorTable *colorTable)
{
  RTFColorDef *colorDef;
  char *v;

  if (!hasArg)
    return;
  if (!formattingOptions)
    return;

  colorDef = [colorTable colorDefAtIndex: arg];
  if (!colorDef)
    return;

  if (formattingOptions->color_index >= 0)
    {
      [self->_html appendBytes: "</font>"  length: 7];
    }

  formattingOptions->color_index = arg;

  v = calloc(23, sizeof(char));
  sprintf(v, "<font color=\"#%02x%02x%02x\">", colorDef->red, colorDef->green, colorDef->blue);
  [self->_html appendBytes: v  length: strlen(v)];
  free(v);
}


inline static void parseColorTableWrapper(RTFHandler *self, RTFColorTable **colorTable)
{
  *colorTable = [self parseColorTable];
}

inline static void parseF(RTFHandler *self, BOOL hasArg, int arg, RTFFormattingOptions *formattingOptions, RTFFontTable *fontTable)
{
  RTFFontInfo *fontInfo;

  if (!hasArg)
    return;
  if (!formattingOptions)
    return;

  if (formattingOptions->font_index >= 0 && arg != formattingOptions->font_index)
    {
      [self->_html appendBytes: "</font>"  length: 7];
    }

  formattingOptions->font_index = arg;

  fontInfo = [fontTable fontInfoAtIndex: arg];
  char *v = NULL;
  if (fontInfo && fontInfo->name)
    {
      if ([fontInfo->name length] < 128)
        {
          int tag_size = 15 + [fontInfo->name length];
          v = calloc(tag_size, sizeof(char));
          snprintf(v, tag_size, "<font face=\"%s\">", [fontInfo->name UTF8String]);
        }
      else
        {
          NSLog(@"RTFHandler: Font %u has %d chars length, parse error? "
                "Ignored", arg, [fontInfo->name length]);
          v = calloc(7, sizeof(char));
          sprintf(v, "<font>");
        }
    }
  else
    {
      // RTF badformed? We don't know about that font (arg index not found).
      // Anyhow, we still open the html tag because in the future
      // we will close it (e.g. when new font is used).
      v = calloc(7, sizeof(char));
      sprintf(v, "<font>");
    }

  if (fontInfo && fontInfo->charset)
    {
      if (fontInfo->charset == DEFAULT_CHARSET)
        /* charset 1 is default charset */
        formattingOptions->charset = NULL;
      else {
        NSNumber *key = [NSNumber numberWithUnsignedChar: fontInfo->charset];
        formattingOptions->charset =  NSMapGet(_charsets, key);
      }
    }

  [self->_html appendBytes: v  length: strlen(v)];
  free(v);
}

inline static void parseFontTableWrapper(RTFHandler *self, const char * cw, RTFFontTable **fontTable)
{
  // We rewind our buffer so we start at the beginning of {\fonttbl...
  self->_bytes = cw-2;
  self->_current_pos -= 9;  // Length: {\fonttbl
  *fontTable = [self parseFontTable];

  // We go back 1 byte in order to end our section properly ('}' character)
  REWIND;
}

inline static void parseI(RTFHandler *self, BOOL hasArg, int arg, RTFFormattingOptions *formattingOptions)
{
  if (!formattingOptions)
    return;
  if (hasArg && arg == 0)
    {
      [self->_html appendBytes: "</i>"  length: 4];
      formattingOptions->italic = NO;
    }
  else
    {
      [self->_html appendBytes: "<i>"  length: 3];
      formattingOptions->italic = YES;
    }
}

inline static void parsePar(RTFHandler *self)
{
  [self->_html appendBytes: "<br>"  length: 4];
}

inline static void parsePictureWrapper(RTFHandler *self, const char * cw)
{
  self->_bytes = cw-2;
  self->_current_pos -= 6;  // Length: {\pict
  [self parsePicture];
  REWIND;
}

// same implementation that /par
inline static void parseSoftline(RTFHandler *self)
{
  [self->_html appendBytes: "<br>"  length: 4];
}

inline static void parseStrike(RTFHandler *self, BOOL hasArg, int arg, RTFFormattingOptions *formattingOptions)
{
  if (!formattingOptions)
    return;
  if (hasArg && arg == 0)
    {
      [self->_html appendBytes: "</strike>"  length: 9];
      formattingOptions->strikethrough = NO;
    }
  else
    {
      [self->_html appendBytes: "<strike>"  length: 8];
      formattingOptions->strikethrough = YES;
    }
}

inline static void parseStyleSheetWrapper(RTFHandler *self, const char * cw)
{
  self->_bytes = cw-2;
  self->_current_pos -= 12;  // Length: {\stylesheet
  [self parseStyleSheet];
  REWIND;
}

inline static void parseTab(RTFHandler *self)
{
  [self->_html appendBytes: "&nbsp;&nbsp;"  length: 12];
}

inline static void parseU(RTFHandler *self, BOOL hasArg, int arg)
{
  unichar uch;
  NSString *s;
  NSData *d;

  if (!hasArg)
    return;
  if (arg < 0)
    // a negative value means a value greater than 32767
    arg = 32767 - arg;

  uch = (unichar) arg;
  s = [NSString stringWithCharacters: &uch length: 1];
  d = [s dataUsingEncoding: NSUTF8StringEncoding];
  [self->_html appendData: d];
}

inline static void parseUl(RTFHandler *self, BOOL hasArg, int arg, RTFFormattingOptions *formattingOptions)
{
  if (!formattingOptions)
    return;
  if (hasArg && arg ==0)
    {
      [self->_html appendBytes: "</u>"  length: 4];
      formattingOptions->underline = NO;
    }
  else
    {
      [self->_html appendBytes: "<u>"  length: 3];
      formattingOptions->underline = YES;
    }
}


- (NSMutableData *) parse
{
  RTFFormattingOptions *formattingOptions;
  RTFColorTable *colorTable;
  RTFFontTable *fontTable;
  RTFStack *stack;

  const unsigned short *defaultCharset;

  // convenience variables for parsing
  unsigned char c;
  NSData *d;
  NSString *s;

  stack = [[RTFStack alloc] init];
  fontTable = nil;
  colorTable = nil;
  defaultCharset = ansicpg1252;
  formattingOptions = nil;

  _html = [[[NSMutableData alloc] init] autorelease];
  [_html appendBytes: "<html><meta charset='utf-8'><body>"  length: 34];


  // Check if we got RTF data
  // this does not allow \s\n before '}' neither newline before control command
  if (_len > 4 && strncmp((const char*)_bytes, "{\\rtf", 4) != 0)
    return nil;

  while (_current_pos < _len)
    {
      c = *_bytes;

      // RTF control code
      if (c == '\\')
        {
          unsigned int len;
          const char *cw;
          BOOL hasArg;
          int arg;
          NSString *cwKey;
          commandWordId cwId;
          char nextByte = *(_bytes+1);

          if (nextByte == '\'')
            {
              // A hexadecimal value, based on the specified character set (may be used to identify 8-bit values).
              const char *b1, *b2;
              short index;
              short tmp;

              const unsigned short * active_charset;
              if (formattingOptions && formattingOptions->charset)
                active_charset = formattingOptions->charset;
              else
                active_charset = defaultCharset;


              ADVANCE;
              ADVANCE;

              b1 = ADVANCE;
              b2 = ADVANCE;

              tmp = (isdigit(*b1) ? *b1 - 48 : toupper(*b1) - 55);
              if (tmp < 0 || tmp > 16)
                {
                  // Incorrect first hexadecimal character. Skipping.
                  continue;
                }
              index = tmp*16;

              tmp = (isdigit(*b2) ? *b2 - 48 : toupper(*b2) - 55);
              if (tmp < 0 || tmp > 16)
                {
                  // Incorrect second hexadecimal character. Skipping.
                  continue;
                }
              index += tmp;

              s = [NSString stringWithCharacters: &(active_charset[index])  length: 1];
              d = [s dataUsingEncoding: NSUTF8StringEncoding];
              [_html appendData: d];
              continue;
            }
          else if (nextByte == '*')
            {
              [self parseIgnoringEverything];
              continue;
            }
          else if (!isalpha(nextByte))
            {
              // escape + character
              ADVANCE_N(2);
              // check for special escapes for the no-implemented features
              // for control of word breaking
              if (nextByte == '~')
                // no breaking space
                nextByte = ' ';
              else if (nextByte == '-')
                // optional hyphen; we skip it
                continue;
              else if  (nextByte == '_')
                // no breaking hyphen, treat it as a normal hyphen
                nextByte = '-';

              [_html appendBytes: &nextByte length: 1];
              continue;
            }


          cw = [self parseControlWordAndSetLenIn: &len
                             setHasIntArgumentIn: &hasArg
                                setIntArgumentIn: &arg];
          if (cw == NULL)
            continue;

          cwKey= [[NSString alloc] initWithBytesNoCopy: (void *)cw
                                                 length: len
                                               encoding: NSASCIIStringEncoding
                                           freeWhenDone: NO];
          [cwKey autorelease];

          cwId = (commandWordId) NSMapGet(_cws, cwKey);
          switch (cwId)
            {
            case CW_ANSICPG:
              parseAnsicpg(hasArg, arg, &defaultCharset);
              break;
            case CW_B:
              parseB(self, hasArg, arg, formattingOptions);
              break;
            case CW_CF:
              parseCf(self, hasArg, arg, formattingOptions, colorTable);
              break;
            case CW_COLORTBL:
              parseColorTableWrapper(self, &colorTable);
              break;
            case CW_F:
              parseF(self, hasArg, arg, formattingOptions, fontTable);
              break;
            case CW_FONTTBL:
              parseFontTableWrapper(self, cw, &fontTable);
              break;
            case CW_I:
              parseI(self, hasArg, arg, formattingOptions);
              break;
            case CW_PAR:
              parsePar(self);
              break;
            case CW_PICT:
              parsePictureWrapper(self, cw);
              break;
            case CW_SOFTLINE:
              parseSoftline(self);
              break;
            case CW_STRIKE:
              parseStrike(self, hasArg, arg, formattingOptions);
              break;
            case CW_STYLESHEET:
              parseStyleSheetWrapper(self, cw);
              break;
            case CW_TAB:
              parseTab(self);
              break;
            case CW_U:
              parseU(self, hasArg, arg);
              break;
            case CW_UL:
              parseUl(self, hasArg, arg, formattingOptions);
              break;
            case CW_ULNONE:
              parseUl(self, YES, 0, formattingOptions);
              break;
            case CW_UNKNOWN:
            default:
              // do nothing
              break;
            }

          // If a space delimits the control word, the space does not appear in the document.
          // Any characters following the delimiter, including spaces, will appear in the document. (except newline!)
          if (*_bytes == ' ')
            {
              ADVANCE;
            }
        }
      else if (c == '{')
        {
          formattingOptions = [[[RTFFormattingOptions alloc] init] autorelease];

          formattingOptions->bold = NO;
          formattingOptions->italic = NO;
          formattingOptions->strikethrough = NO;
          formattingOptions->underline = NO;
          formattingOptions->font_index = -1;
          formattingOptions->color_index = -1;
          formattingOptions->start_pos = [_html length];
          formattingOptions->charset = defaultCharset;
          [stack push: formattingOptions];
          ADVANCE;
        }
      else if (c == '}')
        {
          formattingOptions = [stack pop];

          if (formattingOptions)
            {
              // Handle {\b bold} vs. \b bold \b0
              if (formattingOptions->bold)
                {
                  [_html appendBytes: "</b>"  length: 4];
                }

              if (formattingOptions->italic)
                {
                  [_html appendBytes: "</i>"  length: 4];
                }

              if (formattingOptions->strikethrough)
                {
                  [_html appendBytes: "</strike>"  length: 9];
                }

              if (formattingOptions->underline)
                {
                  [_html appendBytes: "</u>"  length: 4];
                }

              if (formattingOptions->font_index >= 0)
                {
                  [_html appendBytes: "</font>"  length: 7];
                }

              if (formattingOptions->color_index >= 0)
                {
                  [_html appendBytes: "</font>"  length: 7];
                }
            }

          formattingOptions = [stack top];
          ADVANCE;
        }
      else
        {
          c = *_bytes;
          // We avoid appending NULL bytes or endlines
          if (c && (c != '\n') && (c != '\r'))
            {
              const unsigned short * active_charset;
              if (formattingOptions && formattingOptions->charset)
                active_charset = formattingOptions->charset;
              else
                active_charset = defaultCharset;

              s = [NSString stringWithCharacters: &(active_charset[c])  length: 1];
              d = [s dataUsingEncoding: NSUTF8StringEncoding];
              [_html appendData: d];
            }
          ADVANCE;
        }
    }

  [_html appendBytes: "</body></html>"  length: 14];

  [stack release];
  return _html;
}

/* This method is for ease of testing and should not be used in normal operations */
- (void) mangleInternalStateWithBytesPtr: (const char*) newBytes
                           andCurrentPos: (int) newCurrentPos
{
  _bytes = newBytes;
  _current_pos = newCurrentPos;
}

@end
