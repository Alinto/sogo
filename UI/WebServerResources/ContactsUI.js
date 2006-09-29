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

var cachedContacts = new Array();
var currentContactFolder = '';
/* mail list */

function openContactWindow(sender, url) {
  log ("message window at url: " + url);
  var msgWin = window.open(url, null,
			   "width=544,height=525,resizable=1,scrollbars=1,toolbar=0,"
			   + "location=0,directories=0,status=0,menubar=0,copyhistory=0");
  msgWin.focus();
}

function clickedUid(sender, contactuid) {
  resetSelection(window);
  openContactWindow(sender, contactuid,
                    ApplicationBaseURL + currentContactFolder
                    + "/" + contactuid + "/edit");
  return true;
}

function doubleClickedUid(sender, contactuid) {
  alert("DOUBLE Clicked " + contactuid);

  return false;
}

function toggleMailSelect(sender) {
  var row;
  row = $(sender.name);
  row.className = sender.checked ? "tableview_selected" : "tableview";
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

function onContactsFolderTreeItemClick(element)
{
  var topNode = $('d');
  var contactsFolder = element.parentNode.getAttribute("dataname");

  if (topNode.selectedEntry)
    deselectNode(topNode.selectedEntry);
  selectNode(element);
  topNode.selectedEntry = element;

  openContactsFolder(contactsFolder);
}

function openContactsFolder(contactsFolder, params)
{
  if (contactsFolder != currentContactFolder || params) {
    if (contactsFolder == currentContactFolder)
      selection = $("contactsList").getSelectedRowsId();
    else
      selection = null;

    currentContactFolder = contactsFolder;
    var url = ApplicationBaseURL + contactsFolder + "/view?noframe=1&sort=cn&desc=0";
    if (params)
      url += '&' + params;

    log ("reload url = '" + url + "'");
    var selection;
    if (document.contactsListAjaxRequest) {
      document.contactsListAjaxRequest.aborted = true;
      document.contactsListAjaxRequest.abort();
    }
    document.contactsListAjaxRequest
      = triggerAjaxRequest(url, contactsListCallback, selection);
  }
}

function openContactsFolderAtIndex(element) {
  var idx = element.getAttribute("idx");
  var url = ApplicationBaseURL + currentContactFolder + "/view?noframe=1&idx=" + idx;

  if (document.contactsListAjaxRequest) {
    document.contactsListAjaxRequest.aborted = true;
    document.contactsListAjaxRequest.abort();
  }
  document.contactsListAjaxRequest
    = triggerAjaxRequest(url, contactsListCallback);
}

function contactsListCallback(http)
{
  var div = $('contactsListContent');

  if (http.readyState == 4
      && http.status == 200) {
    document.contactsListAjaxRequest = null;
    div.innerHTML = http.responseText;
    var selected = http.callbackData;
    if (selected) {
      for (var i = 0; i < selected.length; i++)
        selectNode($(selected[i]));
    }
  }
  else
    log ("ajax fuckage");
}

function onContactContextMenu(event, element)
{
  var menu = $('contactMenu');
  menu.addEventListener("hideMenu", onContactContextMenuHide, false);
  onMenuClick(event, 'contactMenu');

  var topNode = $('contactsList');
  var selectedNodes = topNode.getSelectedRows();
  topNode.menuSelectedRows = selectedNodes;
  for (var i = 0; i < selectedNodes.length; i++)
    deselectNode(selectedNodes[i]);
  topNode.menuSelectedEntry = element;
  selectNode(element);
}

function onContactContextMenuHide(event)
{
  var topNode = $('contactsList');

  if (topNode.menuSelectedEntry) {
    deselectNode(topNode.menuSelectedEntry);
    topNode.menuSelectedEntry = null;
  }
  if (topNode.menuSelectedRows) {
    var nodes = topNode.menuSelectedRows;
    for (var i = 0; i < nodes.length; i++)
      selectNode (nodes[i]);
    topNode.menuSelectedRows = null;
  }
}

function onFolderMenuHide(event)
{
  var topNode = $('d');

  if (topNode.menuSelectedEntry) {
    deselectNode(topNode.menuSelectedEntry);
    topNode.menuSelectedEntry = null;
  }
  if (topNode.selectedEntry)
    selectNode(topNode.selectedEntry);
}

function loadContact(idx)
{
  if (document.contactAjaxRequest) {
    document.contactAjaxRequest.aborted = true;
    document.contactAjaxRequest.abort();
  }

  if (cachedContacts[currentContactFolder + "/" + idx]) {
    var div = $('contactView');
    div.innerHTML = cachedContacts[currentContactFolder + "/" + idx];
  }
  else {
    var url = (ApplicationBaseURL + currentContactFolder + "/"
               + idx + "/view?noframe=1");
    document.contactAjaxRequest
      = triggerAjaxRequest(url, contactLoadCallback, idx);
  }
}

function contactLoadCallback(http)
{
  var div = $('contactView');

  if (http.readyState == 4
      && http.status == 200) {
    document.contactAjaxRequest = null;
    var content = http.responseText;
    cachedContacts[currentContactFolder + "/" + http.callbackData] = content;
    div.innerHTML = content;
  }
  else
    log ("ajax fuckage");
}

var rowSelectionCount = 0;

validateControls();

function showElement(e, shouldShow) {
  e.style.display = shouldShow ? "" : "none";
}

function enableElement(e, shouldEnable) {
  if(!e)
    return;
  if(shouldEnable) {
    if(e.hasAttribute("disabled"))
      e.removeAttribute("disabled");
  }
  else {
    e.setAttribute("disabled", "1");
  }
}

function validateControls() {
  var e = $("moveto");
  this.enableElement(e, rowSelectionCount > 0);
}

function moveTo(uri) {
  alert("MoveTo: " + uri);
}

/* contact menu entries */
function onContactRowClick(event, node)
{
  var contactId = node.getAttribute('id');

  loadContact(contactId);
  log ("clicked contact: " + contactId);
//   changeCalendarDisplay(day);
//   changeDateSelectorDisplay(day);

  return onRowClick(event);
}

function onContactRowDblClick(event, node)
{
  var contactId = node.getAttribute('id');

  openContactWindow(null,
                    ApplicationBaseURL + currentContactFolder
                    + "/" + contactId + "/edit");

  return false;
}

function onMenuEditContact(event, node)
{
  var node = getParentMenu(node).menuTarget.parentNode;
  var contactId = node.getAttribute('id');

  openContactWindow(null,
                    ApplicationBaseURL + currentContactFolder
                    + "/" + contactId + "/edit");

  return false;
}

function onMenuWriteToContact(event, node)
{
  var node = getParentMenu(node).menuTarget.parentNode;
  var contactId = node.getAttribute('id');

  openContactWindow(null,
                    ApplicationBaseURL + currentContactFolder
                    + "/" + contactId + "/write");

  return false;
}

function onMenuDeleteContact(event, node)
{
  uixDeleteSelectedContacts(node);

  return false;
}

function onToolbarEditSelectedContacts(event)
{
  var contactsList = $('contactsList');
  var rows = contactsList.getSelectedRowsId();

  for (var i = 0; i < rows.length; i++) {
    openContactWindow(null,
                      ApplicationBaseURL + currentContactFolder
                      + "/" + rows[i] + "/edit");
  }

  return false;
}

function onToolbarWriteToSelectedContacts(event)
{
  var contactsList = $('contactsList');
  var rows = contactsList.getSelectedRowsId();

  for (var i = 0; i < rows.length; i++) {
    openContactWindow(null,
                      ApplicationBaseURL + currentContactFolder
                      + "/" + rows[i] + "/write");
  }

  return false;
}

function uixDeleteSelectedContacts(sender)
{
  var failCount = 0;
  var contactsList = $('contactsList');
  var rows = contactsList.getSelectedRowsId();

  var contactView = $('contactView');
  contactView.innerHTML = '';

  for (var i = 0; i < rows.length; i++) {
    var url, http, rowElem;
    
    /* send AJAX request (synchronously) */
    
    url = (ApplicationBaseURL + currentContactFolder + "/"
           + rows[i] + "/delete");
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
    rowElem = $(rows[i]);
    rowElem.parentNode.removeChild(rowElem);
  }

  if (failCount > 0)
    alert("Could not delete " + failCount + " messages!");
  
  return false;
}

function newEmailTo(sender) {
  var mailto = sanitizeMailTo(sender.parentNode.parentNode.menuTarget.innerHTML);

  if (mailto.length > 0)
    {
      w = window.open("compose?mailto=" + mailto,
		      "SOGo_compose",
		      "width=680,height=520,resizable=1,scrollbars=1,toolbar=0," +
		      "location=0,directories=0,status=0,menubar=0,copyhistory=0");
      w.focus();
    }

  return false; /* stop following the link */
}

function onHeaderClick(node)
{
  var href = node.getAttribute("href");

  if (document.contactsListAjaxRequest) {
    document.contactsListAjaxRequest.aborted = true;
    document.contactsListAjaxRequest.abort();
  }
  url = ApplicationBaseURL + currentContactFolder + "/" + href;
  if (!href.match(/noframe=/))
    url += "&noframe=1";
  log ("url: " + url);
  document.contactsListAjaxRequest
    = triggerAjaxRequest(url, contactsListCallback);

  return false;
}

function registerDraggableMessageNodes()
{
  log ("can we drag...");
}

function newContact(sender) {
  openContactWindow(sender,
                    ApplicationBaseURL + currentContactFolder + "/new");

  return false; /* stop following the link */
}

function onFolderSelectionChange()
{
  var folderList = $("contactFolders");
  var nodes = folderList.getSelectedNodes();
  var newFolder = nodes[0].getAttribute("id");

  $('contactView').innerHTML = '';

  openContactsFolder(newFolder);
}

function onSearchFormSubmit()
{
  var searchValue = $("searchValue");

  openContactsFolder(currentContactFolder, "search=" + searchValue.value);

  return false;
}

function onConfirmContactSelection()
{
  var folderLi = $(currentContactFolder);
  var currentContactFolderName = folderLi.innerHTML;

  var contactsList = $('contactsList');
  var rows = contactsList.getSelectedRows();
  for (i = 0; i < rows.length; i++)
    {
      var cid = rows[i].getAttribute("contactid");
      if (cid)
        {
          var cname = '' + rows[i].getAttribute("contactname");
          log('cid = ' + cid + '; cname = ' + cname );
          if (cid.length > 0)
            opener.window.addContact(contactSelectorId,
                                     cid,
                                     currentContactFolderName + '/' + cname);
        }
    }

  return false;
}

function onContactMailTo(node) {
  return openMailTo(node.innerHTML);
}

function refreshContacts(contactId) {
  openContactsFolder(currentContactFolder, "reload=true");
  cachedContacts[currentContactFolder + "/" + contactId] = null;
  loadContact(contactId);

  return false;
}
