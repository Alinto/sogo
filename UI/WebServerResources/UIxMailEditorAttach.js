/*
 Copyright (C) 2005 SKYRIX Software AG
 
 This file is part of OpenGroupware.org.
 
 OGo is free software; you can redistribute it and/or modify it under
 the terms of the GNU Lesser General Public License as published by the
 Free Software Foundation; either version 2, or (at your option) any
 later version.
 
 OGo is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 License for more details.
 
 You should have received a copy of the GNU Lesser General Public
 License along with OGo; see the file COPYING.  If not, write to the
 Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
 02111-1307, USA.
*/

function updateAttachmentListInEditorWindow(sender) {
  var attachments;
  
  attachments = this.getAttachmentNames();
  window.opener.updateInlineAttachmentList(this, attachments);
}

function getAttachmentNames() {
  var e, s, names;

  e = document.getElementById('attachmentList');
  s = e.innerHTML;
  /* remove trailing delimiter */
  s = s.substr(0, s.length - 1);
  if (s == '') return null;

  /* probably no OS allows '/' in a file name */
  names = s.split('/');
  return names;
}
