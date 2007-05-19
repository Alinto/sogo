/* JavaScript for SOGoContacts */

var cachedContacts = new Array();
var currentContactFolder = '/personal';

var usersRightsWindowHeight = 180;
var usersRightsWindowWidth = 450;

function openContactWindow(sender, url) {
  var msgWin = window.open(url, null, "width=450,height=600,resizable=0");
  msgWin.focus();
}

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

function openContactsFolder(contactsFolder, params) {
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
    var url = URLForFolderID(currentContactFolder) +
       "/view?noframe=1&sort=cn&desc=0";
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
  var url = URLForFolderID(currentContactFolder) + "/view?noframe=1&idx=" + idx;

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
    var url = (URLForFolderID(currentContactFolder)
	       + "/" + idx + "/view?noframe=1");
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
    log ("ajax fuckage 2: " + http.status);
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
                    URLForFolderID(currentContactFolder)
                    + "/" + contactId + "/edit");

  return false;
}

function onMenuEditContact(event, node) {
  var node = getParentMenu(node).menuTarget.parentNode;
  var contactId = node.getAttribute('id');

  openContactWindow(null,
                    URLForFolderID(currentContactFolder)
                    + "/" + contactId + "/edit");

  return false;
}

function onMenuWriteToContact(event, node) {
  var node = getParentMenu(node).menuTarget.parentNode;
  var contactId = node.getAttribute('id');

  openMailComposeWindow(ApplicationBaseURL + currentContactFolder
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
		      URLForFolderID(currentContactFolder)
                      + "/" + rows[i] + "/edit");
  }

  return false;
}

function onToolbarWriteToSelectedContacts(event) {
  var contactsList = $('contactsList');
  var rows = contactsList.getSelectedRowsId();

  for (var i = 0; i < rows.length; i++)
    openMailComposeWindow(ApplicationBaseURL + currentContactFolder
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
    
    url = (URLForFolderID(currentContactFolder) + "/"
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
    alert("Could not delete the selected contacts!");
  
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
  url = URLForFolderID(currentContactFolder) + "/" + this.link;
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
                    URLForFolderID(currentContactFolder) + "/new");

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
   else
      openContactsFolder(nodes[0].getAttribute("id"), null);
}

function onSearchFormSubmit() {
  var searchValue = $("searchValue");

  openContactsFolder(currentContactFolder,
		     "search=" + searchValue.value);

  return false;
}

function onConfirmContactSelection(event) {
   var tag = this.getAttribute("name");
   var folderLi = $(currentContactFolder);
   var currentContactFolderName = folderLi.innerHTML;
   var selectorList = null;
   var initialValues = null;

   if (selector) {
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

   event.preventDefault();
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

function appendAddressBook(name, folder) {
   var li = document.createElement("li");
   li.setAttribute("id", folder);
   li.appendChild(document.createTextNode(name));
   li.addEventListener("mousedown", listRowMouseDownHandler, false);
   li.addEventListener("click", onRowClick, false);
   li.addEventListener("contextmenu", onContactFoldersContextMenu, false);
   $("contactFolders").appendChild(li);
}

function newAbCallback(http) {
  if (http.readyState == 4
      && http.status == 201) {
     var name = http.callbackData;
     appendAddressBook(name, "/" + name);
  }
  else
    log ("ajax fuckage 4:" + http.status);
}

function newUserFolderCallback(folderData) {
   var folder = $(folderData["folder"]);
   if (!folder)
      appendAddressBook(folderData["folderName"], folderData["folder"]);
}

function onAddressBookAdd(event) {
   openUserFolderSelector(newUserFolderCallback, "contact");

   event.preventDefault();
}

function onFolderUnsubscribeCB(folderId) {
   var node = $(folderId);
   node.parentNode.removeChild(node);
   var personal = $("/personal");
   personal.select();
   onFolderSelectionChange();
}

function onAddressBookRemove(event) {
  var selector = $("contactFolders");
  var nodes = selector.getSelectedNodes();
  if (nodes.length > 0) { 
     nodes[0].deselect();
     var folderId = nodes[0].getAttribute("id");
     var folderIdElements = folderId.split(":");
     if (folderIdElements.length > 1)
	unsubscribeFromFolder(folderId, onFolderUnsubscribeCB, folderId);
     else {
	var abId = folderIdElements[0].substr(1);
	deletePersonalAddressBook(abId);
	var personal = $("/personal");
	personal.select();
	onFolderSelectionChange();
     }
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
  var list = $("contactFolders").childNodesWithTag("li");
  for (var i = 0; i < list.length; i++) {
     var folderID = list[i].getAttribute("id");
     var url = URLForFolderID(folderID) + "/canAccessContent";
     triggerAjaxRequest(url, deniedFoldersLookupCallback, folderID);
  }
}

function deniedFoldersLookupCallback(http) {
   if (http.readyState == 4) { 
      var denied = true;

      if (http.status == 200)
         denied = (http.responseText == "0");
      var entry = $(http.callbackData);
      if (denied)
	 entry.addClassName("denied");
      else
	 entry.removeClassName("denied");
   }
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

    lookupDeniedFolders();
    contactFolders.style.visibility = "visible;";

    var personalFolder = $("/personal");
    personalFolder.select();
  }
}

function onMenuSharing(event) {
   var folders = $("contactFolders");
   var selected = folders.getSelectedNodes()[0];
   var title = this.innerHTML;
   var url = URLForFolderID(selected.getAttribute("id"));

   openAclWindow(url + "/acls", title);
}

function initializeMenus() {
//   var menus = new Array("contactFoldersMenu", "contactMenu", "searchMenu");
//   initMenusNamed(menus);

//   var menuEntry = $("accessRightsMenuEntry");
//   menuEntry.addEventListener("mouseup", onMenuSharing, false);
}

function configureSearchField() {
   var searchValue = $("searchValue");

   searchValue.addEventListener("mousedown", onSearchMouseDown, false);
   searchValue.addEventListener("click", popupSearchMenu, false);
   searchValue.addEventListener("blur", onSearchBlur, false);
   searchValue.addEventListener("focus", onSearchFocus, false);
   searchValue.addEventListener("keydown", onSearchKeyDown, false);
}

function configureSelectionButtons() {
   var container = $("contactSelectionButtons");
   if (container) {
      var buttons = container.childNodesWithTag("input");
      for (var i = 0; i < buttons.length; i++)
	 buttons[i].addEventListener("click", onConfirmContactSelection,
				     false);
   }
}

var initContacts = {
  handleEvent: function (event) {
    if (!document.body.hasClassName("popup")) {
      configureAbToolbar();
      configureSearchField();
    }
    else
      configureSelectionButtons();
    configureContactFolders();
//     initDnd();
  }
}

window.addEventListener("load", initContacts, false);
