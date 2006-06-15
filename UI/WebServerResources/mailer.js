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
/* JavaScript for SOGo Mailer */

/*
  DOM ids available in mail list view:
    row_$msgid
    div_$msgid
    readdiv_$msgid
    unreaddiv_$msgid

  Window Properties:
    width, height
    bool: resizable, scrollbars, toolbar, location, directories, status,
          menubar, copyhistory
*/

/* mail list */

function openMessageWindow(sender, msguid, url) {
  return window.open(url, "SOGo_msg_" + msguid,
	   "width=640,height=480,resizable=1,scrollbars=1,toolbar=0," +
	   "location=0,directories=0,status=0,menubar=0,copyhistory=0")
}

function clickedUid(sender, msguid) {
  resetSelection(window);
  openMessageWindow(sender, msguid, msguid + "/view");
  return true;
}
function doubleClickedUid(sender, msguid) {
  alert("DOUBLE Clicked " + msguid);

  return false;
}

function toggleMailSelect(sender) {
  var row;
  row = document.getElementById(sender.name);
  row.className = sender.checked ? "tableview_selected" : "tableview";
}
function collectSelectedRows() {
  var pageform = document.forms['pageform'];
  var rows = new Array();

  for (key in pageform) {
    if (key.indexOf("row_") != 0)
      continue;

    if (!pageform[key].checked)
      continue;
    
    rows[rows.length] = key.substring(4, key.length);
  }
  return rows;
}

function clearSearch(sender) {
  var searchField = window.document.getElementById("search");
  if (searchField) searchField.value="";
  return true;
}

/* compose support */

function clickedCompose(sender) {
  var urlstr;
  
  urlstr = "compose";
  window.open(urlstr, "SOGo_compose",
	      "width=680,height=520,resizable=1,scrollbars=1,toolbar=0," +
	      "location=0,directories=0,status=0,menubar=0,copyhistory=0");
  return false; /* stop following the link */
}

/* mail editor */

function validateEditorInput(sender) {
  var errortext = "";
  var field;
  
  field = document.pageform.subject;
  if (field.value == "")
    errortext = errortext + labels.error_missingsubject + "\n";

  if (!UIxRecipientSelectorHasRecipients())
    errortext = errortext + labels.error_missingrecipients + "\n";
  
  if (errortext.length > 0) {
    alert(labels.error_validationfailed + ":\n" + errortext);
    return false;
  }
  return true;
}

function clickedEditorSend(sender) {
  if (!validateEditorInput(sender))
    return false;

  document.pageform.action="send";
  document.pageform.submit();
  // if everything is ok, close the window
  return true;
}

function clickedEditorAttach(sender) {
  var urlstr;
  
  urlstr = "viewAttachments";
  window.open(urlstr, "SOGo_attach",
	      "width=320,height=320,resizable=1,scrollbars=1,toolbar=0," +
	      "location=0,directories=0,status=0,menubar=0,copyhistory=0");
  return false; /* stop following the link */
}

function clickedEditorSave(sender) {
  document.pageform.action="save";
  document.pageform.submit();
  refreshOpener();
  return true;
}

function clickedEditorDelete(sender) {
  document.pageform.action="delete";
  document.pageform.submit();
  refreshOpener();
  window.close();
  return true;
}

function showInlineAttachmentList(sender) {
  var r, l;
  
  r = document.getElementById('compose_rightside');
  r.style.display = 'block';
  l = document.getElementById('compose_leftside');
  l.style.width = "67%";
  this.adjustInlineAttachmentListHeight(sender);
}

function updateInlineAttachmentList(sender, attachments) {
  if (!attachments || (attachments.length == 0)) {
    this.hideInlineAttachmentList(sender);
    return;
  }
  var e, i, count, text;
  
  count = attachments.length;
  text  = "";
  for (i = 0; i < count; i++) {
    text = text + attachments[i];
    text = text + '<br />';
  }

  e = document.getElementById('compose_attachments_list');
  e.innerHTML = text;
  this.showInlineAttachmentList(sender);
}

function adjustInlineAttachmentListHeight(sender) {
  var e;
  
  e = document.getElementById('compose_rightside');
  if (e.style.display == 'none') return;

  /* need to lower left size first, because left auto-adjusts to right! */
  xHeight('compose_attachments_list', 10);

  var leftHeight, rightHeaderHeight;
  leftHeight        = xHeight('compose_leftside');
  rightHeaderHeight = xHeight('compose_attachments_header');
  xHeight('compose_attachments_list', (leftHeight - rightHeaderHeight) - 16);
}

function hideInlineAttachmentList(sender) {
  var e;
  
//  xVisibility('compose_rightside', false);
  e = document.getElementById('compose_rightside');
  e.style.display = 'none';
  e = document.getElementById('compose_leftside');
  e.style.width = "100%";
}

/* addressbook helpers */

function openAnais(sender) {
  var urlstr;

  urlstr = "anais";
  var w = window.open(urlstr, "Anais",
                      "width=350,height=600,left=10,top=10,toolbar=no," +
                      "dependent=yes,menubar=no,location=no,resizable=yes," +
                      "scrollbars=yes,directories=no,status=no");
  w.focus();
}

function openAddressbook(sender) {
  var urlstr;
  
  urlstr = "addressbook";
  var w = window.open(urlstr, "Addressbook",
                      "width=600,height=400,left=10,top=10,toolbar=no," +
                      "dependent=yes,menubar=no,location=no,resizable=yes," +
                      "scrollbars=yes,directories=no,status=no");
  w.focus();
}

/* filters */

function clickedFilter(sender, scriptname) {
  var urlstr;
  
  urlstr = scriptname + "/edit";
  window.open(urlstr, "SOGo_filter_" + scriptname,
	      "width=640,height=480,resizable=1,scrollbars=1,toolbar=0," +
	      "location=0,directories=0,status=0,menubar=0,copyhistory=0")
  return true;
}

function clickedNewFilter(sender) {
  var urlstr;
  
  urlstr = "create";
  window.open(urlstr, "SOGo_filter",
	      "width=680,height=480,resizable=1,scrollbars=1,toolbar=0," +
	      "location=0,directories=0,status=0,menubar=0,copyhistory=0");
  return false; /* stop following the link */
}

/* mail list DOM changes */

function markMailInWindow(win, msguid, markread) {
  var msgDiv;

  msgDiv = win.document.getElementById("div_" + msguid);
  if (msgDiv) {
    if (markread) {
      msgDiv.className = "mailer_readmailsubject";
    
      msgDiv = win.document.getElementById("unreaddiv_" + msguid);
      if (msgDiv) msgDiv.style.display = "none";
      msgDiv = win.document.getElementById("readdiv_" + msguid);
      if (msgDiv) msgDiv.style.display = "block";
    }
    else {
      msgDiv.className = "mailer_unreadmailsubject";
    
      msgDiv = win.document.getElementById("readdiv_" + msguid);
      if (msgDiv) msgDiv.style.display = "none";
      msgDiv = win.document.getElementById("unreaddiv_" + msguid);
      if (msgDiv) msgDiv.style.display = "block";
    }
    return true;
  }
  else
    return false;
}
function markMailReadInWindow(win, msguid) {
  /* this is called by UIxMailView with window.opener */
  return markMailInWindow(win, msguid, true);
}

/* main window */

function reopenToRemoveLocationBar() {
  // we cannot really use this, see below at the close comment
  if (window.locationbar && window.locationbar.visible) {
    newwin = window.open(window.location.href, "SOGo",
			 "width=800,height=600,resizable=1,scrollbars=1," +
			 "toolbar=0,location=0,directories=0,status=0," + 
			 "menubar=0,copyhistory=0");
    if (newwin) {
      window.close(); // this does only work for windows opened by scripts!
      newwin.focus();
      return true;
    }
    return false;
  }
  return true;
}

/* mail list reply */

function openMessageWindowsForSelection(sender, action) {
  var rows  = collectSelectedRows();
  var idset = "";
  
  for (var i = 0; i < rows.length; i++) {
    win = openMessageWindow(sender, 
			    rows[i]                /* msguid */,
			    rows[i] + "/" + action /* url */);
  }
}

function mailListMarkMessage(sender, action, msguid, markread) {
  var url;
  var http = createHTTPClient();

  url = action + "?uid=" + msguid;

  if (http) {
    // TODO: add parameter to signal that we are only interested in OK
    http.open("POST", url + "&jsonly=1", false /* not async */);
    http.send("");
    if (http.status != 200) {
      // TODO: refresh page?
      alert("Message Mark Failed: " + http.statusText);
      window.location.reload();
    }
    else {
      markMailInWindow(window, msguid, markread);
    }
  }
  else {
    window.location.href = url;
  }
}

/* maillist row highlight */

var oldMaillistHighlight = null; // to remember deleted/selected style

function ml_highlight(sender) {
  oldMaillistHighlight = sender.className;
  if (oldMaillistHighlight == "tableview_highlight")
    oldMaillistHighlight = null;
  sender.className = "tableview_highlight";
}
function ml_lowlight(sender) {
  if (oldMaillistHighlight) {
    sender.className = oldMaillistHighlight;
    oldMaillistHighlight = null;
  }
  else
    sender.className = "tableview";
}


/* folder operations */

function ctxFolderAdd(sender) {
  var folderName;
  
  folderName = prompt("Foldername: ");
  if (folderName == undefined)
    return false;
  if (folderName == "")
    return false;
  
  // TODO: should use a form-POST or AJAX
  window.location.href = "createFolder?name=" + escape(folderName);
  return false;
}

function ctxFolderDelete(sender) {
  if (!confirm("Delete current folder?"))
    return false;
  
  // TODO: should use a form-POST or AJAX
  window.location.href = "deleteFolder";
  return false;
}

/* bulk delete of messages */

function uixDeleteSelectedMessages(sender) {
  var rows;
  var failCount = 0;
  
  rows = collectSelectedRows();
  for (var i = 0; i < rows.length; i++) {
    var url, http, rowElem;
    
    /* send AJAX request (synchronously) */
    
    url = "" + rows[i] + "/trash?jsonly=1";
    
    http = createHTTPClient();
    http.open("POST", url, false /* not async */);
    http.send("");
    if (http.status != 200) { /* request failed */
      failCount++;
      http = null;
      continue;
    }
    http = null;

    /* remove from page */

    /* line-through would be nicer, but hiding is OK too */
    rowElem = document.getElementById("row_" + rows[i]);
    rowElem.style.display = "none";
  }
  
  if (failCount > 0)
    alert("Could not delete " + failCount + " messages!");
  
  window.location.reload();
  return false;
}
