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

function onContactsFolderTreeItemClick(element) {
  var topNode = $('d');
  var contactsFolder = element.parentNode.getAttribute("dataname");

  if (topNode.selectedEntry)
    topNode.selectedEntry.deselect();
  element.select();
  topNode.selectedEntry = element;

  openContactsFolder(contactsFolder);
}

function CurrentContactFolderURL() {
  return ((currentFolderIsExternal)
          ? UserFolderURL + "../" + currentContactFolder + "/Contacts/personal"
          : ApplicationBaseURL + currentContactFolder);
}

function openContactsFolder(contactsFolder, params, external) {
  if (contactsFolder != currentContactFolder || params) {
     if (contactsFolder == currentContactFolder) {
        var contactsList = $("contactsList");
        if (contactsList)
           selection = contactsList.getSelectedRowsId();
        else
           window.alert("no contactsList");
     }
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

function contactsListCallback(http) {
  var div = $("contactsListContent");

  if (http.readyState == 4
      && http.status == 200) {
    document.contactsListAjaxRequest = null;
    div.innerHTML = http.responseText;
    var selected = http.callbackData;
    if (selected) {
        for (var i = 0; i < selected.length; i++)
          $(selected[i]).select();
    }
    configureSortableTableHeaders();
  }
  else
    log ("ajax fuckage 1");
}

function onContactFoldersContextMenu(event) {
  var menu = $("contactFoldersMenu");
  menu.addEventListener("hideMenu", onContactFoldersContextMenuHide, false);
  onMenuClick(event, "contactFoldersMenu");

  var topNode = $("contactFolders");
  var selectedNodes = topNode.getSelectedRows();
  topNode.menuSelectedRows = selectedNodes;
  for (var i = 0; i < selectedNodes.length; i++)
    selectedNodes[i].deselect();
  topNode.menuSelectedEntry = this;
  this.select();
}

function onContactContextMenu(event, element) {
  var menu = $("contactMenu");
  menu.addEventListener("hideMenu", onContactContextMenuHide, false);
  onMenuClick(event, "contactMenu");

  var topNode = $("contactsList");
  var selectedNodes = topNode.getSelectedRows();
  topNode.menuSelectedRows = selectedNodes;
  for (var i = 0; i < selectedNodes.length; i++)
    selectedNodes[i].deselect();
  topNode.menuSelectedEntry = element;
  element.select();
}

function onContactContextMenuHide(event) {
  var topNode = $("contactsList");

  if (topNode.menuSelectedEntry) {
    topNode.menuSelectedEntry.deselect();
    topNode.menuSelectedEntry = null;
  }
  if (topNode.menuSelectedRows) {
    var nodes = topNode.menuSelectedRows;
    for (var i = 0; i < nodes.length; i++)
      nodes[i].select();
    topNode.menuSelectedRows = null;
  }
}

function onContactFoldersContextMenuHide(event) {
  var topNode = $("contactFolders");

  if (topNode.menuSelectedEntry) {
    topNode.menuSelectedEntry.deselect();
    topNode.menuSelectedEntry = null;
  }
  if (topNode.menuSelectedRows) {
    var nodes = topNode.menuSelectedRows;
    for (var i = 0; i < nodes.length; i++)
      nodes[i].select();
    topNode.menuSelectedRows = null;
  }
}

function onFolderMenuHide(event) {
  var topNode = $('d');

  if (topNode.menuSelectedEntry) {
    topNode.menuSelectedEntry.deselect();
    topNode.menuSelectedEntry = null;
  }
  if (topNode.selectedEntry)
    topNode.selectedEntry.select();
}

function loadContact(idx) {
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

function contactLoadCallback(http) {
  var div = $('contactView');

  if (http.readyState == 4
      && http.status == 200) {
    document.contactAjaxRequest = null;
    var content = http.responseText;
    cachedContacts[currentContactFolder + "/" + http.callbackData] = content;
    div.innerHTML = content;
  }
  else
    log ("ajax fuckage 2");
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
function onContactRowClick(event, node) {
  loadContact(node.getAttribute('id'));

  return onRowClick(event);
}

function onContactRowDblClick(event, node) {
  var contactId = node.getAttribute('id');

  openContactWindow(null,
                    CurrentContactFolderURL()
                    + "/" + contactId + "/edit");

  return false;
}

function onMenuEditContact(event, node) {
  var node = getParentMenu(node).menuTarget.parentNode;
  var contactId = node.getAttribute('id');

  openContactWindow(null,
                    CurrentContactFolderURL()
                    + "/" + contactId + "/edit");

  return false;
}

function onMenuWriteToContact(event, node) {
  var node = getParentMenu(node).menuTarget.parentNode;
  var contactId = node.getAttribute('id');

  openMailComposeWindow(CurrentContactFolderURL()
                        + "/" + contactId + "/write");

  return false;
}

function onMenuDeleteContact(event, node) {
  uixDeleteSelectedContacts(node);

  return false;
}

function onToolbarEditSelectedContacts(event) {
  var contactsList = $('contactsList');
  var rows = contactsList.getSelectedRowsId();

  for (var i = 0; i < rows.length; i++) {
    openContactWindow(null,
                      CurrentContactFolderURL()
                      + "/" + rows[i] + "/edit");
  }

  return false;
}

function onToolbarWriteToSelectedContacts(event) {
  var contactsList = $('contactsList');
  var rows = contactsList.getSelectedRowsId();

  for (var i = 0; i < rows.length; i++)
    openMailComposeWindow(CurrentContactFolderURL()
                          + "/" + rows[i] + "/write");

  return false;
}

function uixDeleteSelectedContacts(sender) {
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

function onHeaderClick(event) {
  if (document.contactsListAjaxRequest) {
    document.contactsListAjaxRequest.aborted = true;
    document.contactsListAjaxRequest.abort();
  }
  url = CurrentContactFolderURL() + "/" + this.link;
  if (!this.link.match(/noframe=/))
    url += "&noframe=1";
  document.contactsListAjaxRequest
    = triggerAjaxRequest(url, contactsListCallback);

  event.preventDefault();
}

function registerDraggableMessageNodes() {
  log ("can we drag...");
}

function newContact(sender) {
  openContactWindow(sender,
                    CurrentContactFolderURL() + "/new");

  return false; /* stop following the link */
}

function onFolderSelectionChange() {
  var folderList = $("contactFolders");
  var nodes = folderList.getSelectedNodes();
  $("contactView").innerHTML = '';

  if (nodes[0].hasClassName("denied")) {
    var div = $("contactsListContent");
    div.innerHTML = "";
  }
  else {
    var newFolder;
    var externalFolder = nodes[0].getAttribute("external-addressbook");
    if (externalFolder)
      newFolder = externalFolder;
    else
      newFolder = nodes[0].getAttribute("id");

    openContactsFolder(newFolder, null, externalFolder);
  }
}

function onSearchFormSubmit() {
  var searchValue = $("searchValue");

  openContactsFolder(currentContactFolder, "search=" + searchValue.value);

  return false;
}

function onConfirmContactSelection(tag) {
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
    }

  var contactsList = $("contactsList");
  var rows = contactsList.getSelectedRows();
  for (i = 0; i < rows.length; i++) {
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
    log ("ajax fuckage 3");
}

function onContactMailTo(node) {
  return openMailTo(node.innerHTML);
}

function refreshContacts(contactId) {
  openContactsFolder(currentContactFolder, "reload=true", currentFolderIsExternal);
  cachedContacts[currentContactFolder + "/" + contactId] = null;
  loadContact(contactId);

  return false;
}

function onAddressBookNew(event) {
  var name = window.prompt(labels["Name of the Address Book"].decodeEntities());
  if (name) {
    if (document.newAbAjaxRequest) {
      document.newAbAjaxRequest.aborted = true;
      document.newAbAjaxRequest.abort();
    }
    var url = ApplicationBaseURL + "/newAb?name=" + name;
    document.newAbAjaxRequest
       = triggerAjaxRequest(url, newAbCallback, name);
  }
  event.preventDefault();
}

function newAbCallback(http) {
  if (http.readyState == 4
      && http.status == 201) {
     var ul = $("contactFolders");
     var name = http.callbackData;
     var li = document.createElement("li");
     li.setAttribute("id", "/" + name);
     li.appendChild(document.createTextNode(name));
     li.addEventListener("mousedown", listRowMouseDownHandler, false);
     li.addEventListener("click", onRowClick, false);
     li.addEventListener("contextmenu", onContactFoldersContextMenu, false);
     ul.appendChild(li);
  }
  else
    log ("ajax fuckage 4:" + http.status);
}

function onAddressBookAdd(event) {
  var selector = $("contactFolders");
  var selectorURL = '?popup=YES&selectorId=contactFolders';

  urlstr = ApplicationBaseURL;
  if (urlstr[urlstr.length-1] != '/')
    urlstr += '/';
  urlstr += ("../../" + UserLogin + "/Contacts/"
             + contactSelectorAction + selectorURL);
//   log (urlstr);
  var w = window.open(urlstr, "Addressbook",
                      "width=640,height=400,resizable=1,scrollbars=0");
  w.selector = selector;
  w.opener = window;
  w.focus();

  event.preventDefault();
}

function onAddressBookRemove(event) {
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
    else {
       nodes[0].deselect();
       var folderId = nodes[0].getAttribute("id").substr(1);
       deletePersonalAddressBook(folderId);
    }

    var personal = $("/personal");
    personal.select();
    onFolderSelectionChange();
  }

  event.preventDefault();
}

function deletePersonalAddressBook(folderId) {
   var label
      = labels["Are you sure you want to delete the selected address book?"];
   if (window.confirm(label.decodeEntities())) {
      if (document.deletePersonalABAjaxRequest) {
	 document.deletePersonalABAjaxRequest.aborted = true;
	 document.deletePersonalABAjaxRequest.abort();
      }
      var url = ApplicationBaseURL + "/" + folderId + "/delete";
      document.deletePersonalABAjaxRequest
	 = triggerAjaxRequest(url, deletePersonalAddressBookCallback,
			      folderId);
   }
}

function deletePersonalAddressBookCallback(http) {
  if (http.readyState == 4) {
     if (http.status == 200) {
	var ul = $("contactFolders");
	
	var children = ul.childNodesWithTag("li");
	var i = 0;
	var done = false;
	while (!done && i < children.length) {
	   var currentFolderId = children[i].getAttribute("id").substr(1);
	   if (currentFolderId == http.callbackData) {
	      ul.removeChild(children[i]);
	      done = true;
	   }
	   else
	      i++;
	}
     }
     document.deletePersonalABAjaxRequest = null;
  }
  else
     log ("ajax fuckage");
}

function configureDragHandles() {
  var handle = $("dragHandle");
  if (handle) {
    handle.addInterface(SOGoDragHandlesInterface);
    handle.leftBlock=$("contactFoldersList");
    handle.rightBlock=$("rightPanel");
  }

  handle = $("rightDragHandle");
  if (handle) {
    handle.addInterface(SOGoDragHandlesInterface);
    handle.upperBlock=$("contactsListContent");
    handle.lowerBlock=$("contactView");
  }
}

function lookupDeniedFolders() {
  var rights;
  var http = createHTTPClient();
  if (http) {
    http.url = ApplicationBaseURL + "/checkRights";
    http.open("GET", http.url, false /* not async */);
    http.send("");
    if (http.status == 200
        && http.responseText.length > 0) {
      rights = http.responseText.split(",");
    }
  }

  return rights;
}

function configureAbToolbar() {
  var toolbar = $("abToolbar");
  var links = toolbar.childNodesWithTag("a");
  links[0].addEventListener("click", onAddressBookNew, false);
  links[1].addEventListener("click", onAddressBookAdd, false);
  links[2].addEventListener("click", onAddressBookRemove, false);
}

function configureContactFolders() {
  var contactFolders = $("contactFolders");
  if (contactFolders) {
    contactFolders.addEventListener("selectionchange",
                                    onFolderSelectionChange, false);
    var lis = contactFolders.childNodesWithTag("li");
    for (var i = 0; i < lis.length; i++) {
      lis[i].addEventListener("mousedown", listRowMouseDownHandler, false);
      lis[i].addEventListener("click", onRowClick, false);
      lis[i].addEventListener("contextmenu", onContactFoldersContextMenu, false);
    }

    var denieds = lookupDeniedFolders();
    if (denieds) {
      var start = (lis.length - denieds.length);
      for (var i = start; i < lis.length; i++) {
        if (denieds[i-start] == "1")
          lis[i].removeClassName("denied");
        else
          lis[i].addClassName("denied");
      }
    }
    contactFolders.style.visibility = "visible;";
  }
}

function onAccessRightsMenuEntryMouseUp(event) {
  var folders = $("contactFolders");
  var selected = folders.getSelectedNodes()[0];
  var external = selected.getAttribute("external-addressbook");
  var title = this.innerHTML;
  if (external)
    url = UserFolderURL + "../" + external + "/Contacts/personal/acls";
  else
    url = ApplicationBaseURL + selected.getAttribute("id") + "/acls";

  openAclWindow(url, title);
}

function initializeMenus() {
  var menus = new Array("contactFoldersMenu", "contactMenu", "searchMenu");
  initMenusNamed(menus);

  var menuEntry = $("accessRightsMenuEntry");
  menuEntry.addEventListener("mouseup", onAccessRightsMenuEntryMouseUp, false);
}

var initContacts = {
  handleEvent: function (event) {
    if (!document.body.hasClassName("popup")) {
      configureAbToolbar();
    }
    configureContactFolders();
//     initDnd();
  }
}

window.addEventListener("load", initContacts, false);
