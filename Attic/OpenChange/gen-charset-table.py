#!/usr/bin/python

import getopt
import os
import re
import string
import sys

h_template = """unsigned short %(charsetName)s[%(len)d] = { %(values)s };"""
CHAR_UNDEF = "0x0000"
MAP_LEN = 256
itemsPerLine = 16

def usage():
    usageMsg = """
Usage: %s -f inputFile
""" % (os.path.basename(sys.argv[0]))
    sys.stderr.write(usageMsg)

def parseCharsetFile(file = None):
  if file is None:
    return None

  charmap = [CHAR_UNDEF] * MAP_LEN

  # Sample line:
  # FD = U+200E : LEFT-TO-RIGHT MARK
  for line in file.xreadlines():
    m = re.search("(\w{2}) = U\+(\w{4}) :", line)
    if not m:
      sys.stderr.write("Skipping weird line: %s" % line)
      continue

    ind = int(m.group(1), base=16)
    unicodeValue = str(m.group(2)).lower()

    charmap[ind] = "0x%s" % (unicodeValue)

  return charmap


def formatCharacterMap(charmap = None):
  if not charmap:
    return None

  value = ""
  for i in xrange(0,MAP_LEN-1):
    char = charmap[i]
    if i % itemsPerLine == 0:
      value += "\n    "
    value += "%s, " % (char)
    i += 1
  value += charmap[MAP_LEN-1]

  return value

if __name__ == '__main__':
  inputFile = None

  try:
    opts, args = getopt.getopt(sys.argv[1:], "f:")
  except getopt.GetoptError, err:
    sys.stderr.write(str(err))
    usage()
    sys.exit(2)

  for o, a in opts:
    if o == "-f":
        inputFile = a
    else:
        assert False, "unhandled option"

  if not inputFile:
    usage()
    sys.exit(1)


  f = open(inputFile, "r", 1)

  charsetMap = parseCharsetFile(f)
  charsetValues = formatCharacterMap(charsetMap)
  print h_template % {"len": len(charsetMap),
                      "charsetName": os.path.basename(inputFile),
                      "values": charsetValues}
