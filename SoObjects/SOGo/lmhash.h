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

uchar *auth_DESkey8to7( uchar *dst, const uchar *key );
  /* ------------------------------------------------------------------------ **
   * Compress an 8-byte DES key to its 7-byte form.
   *
   *  Input:  dst - Pointer to a memory location (minimum 7 bytes) to accept
   *                the compressed key.
   *          key - Pointer to an 8-byte DES key.  See the notes below.
   *
   *  Output: A pointer to the compressed key (same as <dst>) or NULL if
   *          either <src> or <dst> were NULL.
   *
   *  Notes:  There are no checks done to ensure that <dst> and <key> point
   *          to sufficient space.  Please be carefull.
   *
   *          The two pointers, <dst> and <key> may point to the same
   *          memory location.  Internally, a temporary buffer is used and
   *          the results are copied back to <dst>.
   *
   *          The DES algorithm uses 8 byte keys by definition.  The first
   *          step in the algorithm, however, involves removing every eigth
   *          bit to produce a 56-bit key (seven bytes).  SMB authentication
   *          skips this step and uses 7-byte keys.  The <auth_DEShash()>
   *          algorithm in this module expects 7-byte keys.  This function
   *          is used to convert an 8-byte DES key into a 7-byte SMB DES key.
   *
   * ------------------------------------------------------------------------ **
   */

uchar *auth_DEShash( uchar *dst, const uchar *key, const uchar *src );
  /* ------------------------------------------------------------------------ **
   * DES encryption of the input data using the input key.
   *
   *  Input:  dst - Destination buffer.  It *must* be at least eight bytes
   *                in length, to receive the encrypted result.
   *          key - Encryption key.  Exactly seven bytes will be used.
   *                If your key is shorter, ensure that you pad it to seven
   *                bytes.
   *          src - Source data to be encrypted.  Exactly eight bytes will
   *                be used.  If your source data is shorter, ensure that
   *                you pad it to eight bytes.
   *
   *  Output: A pointer to the encrpyted data (same as <dst>).
   *
   *  Notes:  In SMB, the DES function is used as a hashing function rather
   *          than an encryption/decryption tool.  When used for generating
   *          the LM hash the <src> input is the known value "KGS!@#$%" and
   *          the key is derived from the password entered by the user.
   *          When used to generate the LM or NTLM response, the <key> is
   *          derived from the LM or NTLM hash, and the challenge is used
   *          as the <src> input.
   *          See: http://ubiqx.org/cifs/SMB.html#SMB.8.3
   *
   *        - This function is called "DEShash" rather than just "DES"
   *          because it is only used for creating LM hashes and the
   *          LM/NTLM responses.  For all practical purposes, however, it
   *          is a full DES encryption implementation.
   *
   *        - This DES implementation does not need to be fast, nor is a
   *          DES decryption function needed.  The goal is to keep the
   *          code small, simple, and well documented.
   *
   *        - The input values are copied and refiddled within the module
   *          and the result is not written to <dst> until the very last
   *          step, so it's okay if <dst> points to the same memory as
   *          <key> or <src>.
   *
   * ------------------------------------------------------------------------ **
   */
#endif
