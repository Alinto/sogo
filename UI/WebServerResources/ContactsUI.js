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
var currentFolderIsExternal = false;
var contactSelectorAction = 'addressbooks-contacts';

function openContactWindow(sender, url) {
  var msgWin = window.open(url, null, "width=545,height=545,resizable=0");
  msgWin.focus();
}

function clickedUid(sender, contactuid) {
  resetSelection(window);
  openContactWindow(sender, contactuid,
                    CurrentContactFolderURL()
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
    alert(labels.error_validationfailed.decodeEntities() + ":\n"
          + errortext.decodeEntities());
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

function CurrentContactFolderURL() {
  return ((currentFolderIsExternal)
          ? UserFolderURL + "../" + currentContactFolder + "/Contacts/personal"
          : ApplicationBaseURL + currentContactFolder);
}

function openContactsFolder(contactsFolder, params, external)
{
  if (contactsFolder != currentContactFolder || params) {
    if (contactsFolder == currentContactFolder)
      selection = $("contactsList").getSelectedRowsId();
    else
      selection = null;

    currentContactFolder = contactsFolder;
    if (external)
      currentFolderIsExternal = true;
    else
      currentFolderIsExternal = false;
    var url = CurrentContactFolderURL() + "/view?noframe=1&sort=cn&desc=0";
    if (params)
      url += '&' + params;

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
  var url = CurrentContactFolderURL() + "/view?noframe=1&idx=" + idx;

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
    var url = (CurrentContactFolderURL() + "/"
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
  loadContact(node.getAttribute('id'));

  return onRowClick(event);
}

function onContactRowDblClick(event, node)
{
  var contactId = node.getAttribute('id');

  openContactWindow(null,
                    CurrentContactFolderURL()
                    + "/" + contactId + "/edit");

  return false;
}

function onMenuEditContact(event, node)
{
  var node = getParentMenu(node).menuTarget.parentNode;
  var contactId = node.getAttribute('id');

  openContactWindow(null,
                    CurrentContactFolderURL()
                    + "/" + contactId + "/edit");

  return false;
}

function onMenuWriteToContact(event, node)
{
  var node = getParentMenu(node).menuTarget.parentNode;
  var contactId = node.getAttribute('id');

  openMailComposeWindow(CurrentContactFolderURL()
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
                      CurrentContactFolderURL()
                      + "/" + rows[i] + "/edit");
  }

  return false;
}

function onToolbarWriteToSelectedContacts(event)
{
  var contactsList = $('contactsList');
  var rows = contactsList.getSelectedRowsId();

  for (var i = 0; i < rows.length; i++)
    openMailComposeWindow(CurrentContactFolderURL()
                          + "/" + rows[i] + "/write");

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
    
    url = (CurrentContactFolderURL() + "/"
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
  url = CurrentContactFolderURL() + "/" + href;
  if (!href.match(/noframe=/))
    url += "&noframe=1";
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
                    CurrentContactFolderURL() + "/new");

  return false; /* stop following the link */
}

function onFolderSelectionChange()
{
  var folderList = $("contactFolders");
  var nodes = folderList.getSelectedNodes();
  var newFolder;
  var externalFolder = nodes[0].getAttribute("external-addressbook");
  if (externalFolder)
    newFolder = externalFolder;
  else
    newFolder = nodes[0].getAttribute("id");

  $('contactView').innerHTML = '';

  openContactsFolder(newFolder, null, externalFolder);
}

function onSearchFormSubmit()
{
  var searchValue = $("searchValue");

  openContactsFolder(currentContactFolder, "search=" + searchValue.value);

  return false;
}

function onConfirmContactSelection(tag)
{
  var folderLi = $(currentContactFolder);
  var currentContactFolderName = folderLi.innerHTML;
  var selectorList = null;
  var initialValues = null;

  if (selector)
    {
      var selectorId = selector.getAttribute("id");
      selectorList = opener.window.document.getElementById('uixselector-'
                                                           + selectorId
                                                           + '-uidList');
      initialValues = selectorList.value;
      log("values: " + initialValues);
    }

  var contactsList = $("contactsList");
  var rows = contactsList.getSelectedRows();
  for (i = 0; i < rows.length; i++)
    {
      var cid = rows[i].getAttribute("contactid");
      var cname = '' + rows[i].getAttribute("contactname");
      var email = '' + rows[i].cells[1].innerHTML;
      opener.window.addContact(tag, currentContactFolderName + '/' + cname,
                               cid, cname, email);
    }

  if (selector && selector.changeNotification
      && selectorList.value != initialValues)
    selector.changeNotification("addition");

  return false;
}

function onConfirmAddressBookSelection() {
  var folderLi = $(currentContactFolder);
  var currentContactFolderName = folderLi.innerHTML;

  var selector = window.opener.document.getElementById("contactFolders");
  var initialValues = selector.getAttribute("additional-addressbooks");
  if (!initialValues)
    initialValues = "";
  var newValues = initialValues;
  log("values: " + initialValues);

  var contactsList = $("contactsList");
  var rows = contactsList.getSelectedRows();
  for (i = 0; i < rows.length; i++) {
    var cid = rows[i].getAttribute("contactid");
    var cname = '' + rows[i].getAttribute("contactname");
    var email = '' + rows[i].cells[1].innerHTML;
    var re = new RegExp("(^|,)" + cid + "($|,)");
    if (!re.test(newValues)) {
      if (newValues.length)
        newValues += "," + cid;
      else
        newValues = cid;
    }
  }

  if (newValues != initialValues)
    window.opener.setTimeout("setAdditionalAddressBooks(\""
                             + newValues + "\");", 100);

  return false;
}

function setAdditionalAddressBooks(additionalAddressBooks) {
  var urlstr = (ApplicationBaseURL + "/updateAdditionalAddressBooks?ids="
                + additionalAddressBooks);
  if (document.addressBooksAjaxRequest) {
    document.addressBooksAjaxRequest.aborted = true;
    document.addressBooksAjaxRequest.abort();
  }
  document.addressBooksAjaxRequest
    = triggerAjaxRequest(urlstr,
                         addressBooksCallback, additionalAddressBooks);
}

function addressBooksCallback(http) {
  if (http.readyState == 4) {
    if (http.status == 200) {
      var ul = $("contactFolders");

      var children = ul.childNodesWithTag("li");
      for (var i = 0; i < children.length; i++)
        if (children[i].getAttribute("external-addressbook"))
          ul.removeChild(children[i]);

      ul.setAttribute("additional-addressbooks", http.callbackData);
      if (http.callbackData.length > 0) {
        var list = http.callbackData.split(",");
        var newCode = "";
        for (var i = 0; i < list.length; i++) {
          var username = list[i];
          newCode += ( "<li external-addressbook=\"" + username + "\""
                       + " onmousedown=\"return false;\""
                       + " onclick=\"return onRowClick(event);\""
                       + " oncontextmenu=\"return onContactFolderContextMenu(event);\">" );
          newCode += ( username + "</li>" );
        }
        ul.innerHTML += newCode;
      }
    }
    document.addressBooksAjaxRequest = null;
  }
  else
    log ("ajax fuckage");
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

function onAddressBookAdd(node) {
  var selector = $("contactFolders");
  var selectorUrl = '?popup=YES&selectorId=contactFolders';

  urlstr = ApplicationBaseURL;
  if (urlstr[urlstr.length-1] != '/')
    urlstr += '/';
  urlstr += ("../../" + UserLogin + "/Contacts/"
             + contactSelectorAction + selectorUrl);
//   log (urlstr);
  var w = window.open(urlstr, "Addressbook",
                      "width=640,height=400,resizable=1,scrollbars=0");
  w.selector = selector;
  w.opener = this;
  w.focus();

  return false;
}

function onAddressBookRemove(node) {
  var selector = $("contactFolders");
  var nodes = selector.getSelectedNodes();
  if (nodes.length > 0) {
    var cid = nodes[0].getAttribute("external-addressbook");
    if (cid) {
      var initialValues = selector.getAttribute("additional-addressbooks");
      var re = new RegExp("(^|,)" + cid + "($|,)");
      var newValues = initialValues.replace(re, "");
      if (initialValues != newValues)
        setAdditionalAddressBooks(newValues);
    }
  }

  return false;
}
