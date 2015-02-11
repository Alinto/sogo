#ifndef AUTH_LMHASH_H
#define AUTH_LMHASH_H

typedef unsigned char uchar;

/* ========================================================================== **
 *
 *                                  LMhash.h
 *
 * Copyright:
 *  Copyright (C) 2004 by Christopher R. Hertel
 *
 * Email: crh@ubiqx.mn.org
 *
 * $Id: LMhash.h,v 0.1 2004/05/30 02:26:31 crh Exp $
 *
 * -------------------------------------------------------------------------- **
 *
 * Description:
 *
 *  Implemention of the LAN Manager hash (LM hash) and LM response
 *  algorithms.
 *
 * -------------------------------------------------------------------------- **
 *
 * License:
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * -------------------------------------------------------------------------- **
 *
 * Notes:
 *
 *  This module implements the LM hash.  The NT hash is simply the MD4() of
 *  the password, so we don't need a separate implementation of that.  This
 *  module also implements the LM response, which can be combined with the
 *  NT hash to produce the NTLM response.
 *
 *  This implementation was created based on the description in my own book.
 *  The book description was, in turn, written after studying many existing
 *  examples in various documentation.  Jeremy Allison and Andrew Tridgell
 *  deserve lots of credit for having figured out the secrets of Lan Manager
 *  authentication many years ago.
 *
 *  See:
 *    Implementing CIFS - the Common Internet File System
 *      by your truly.  ISBN 0-13-047116-X, Prentice Hall PTR., August 2003
 *    Section 15.3, in particular.
 *    (Online at: http://ubiqx.org/cifs/SMB.html#SMB.8.3)
 *
 * ========================================================================== **
 */

/* -------------------------------------------------------------------------- **
 * Functions:
 */

uchar *auth_LMhash( uchar *dst, const uchar *pwd, const int pwdlen );
  /* ------------------------------------------------------------------------ **
   * Generate an LM Hash from the input password.
   *
   *  Input:  dst     - Pointer to a location to which to write the LM Hash.
   *                    Requires 16 bytes minimum.
   *          pwd     - Source password.  Should be in OEM charset (extended
   *                    ASCII) format in all upper-case, but this
   *                    implementation doesn't really care.  See the notes
   *                    below.
   *          pwdlen  - Length, in bytes, of the password.  Normally, this
   *                    will be strlen( pwd ).
   *
   *  Output: Pointer to the resulting LM hash (same as <dst>).
   *
   *  Notes:  This function does not convert the input password to upper
   *          case.  The upper-case conversion should be done before the
   *          password gets this far.  DOS codepage handling and such
   *          should be taken into consideration.  Rather than attempt to
   *          work out all those details here, the function assumes that
   *          the password is in the correct form before it reaches this
   *          point.
   *
   * ------------------------------------------------------------------------ **
   */
#endif
