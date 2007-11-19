/* JavaScript for SOGoContacts */

var cachedContacts = new Array();
var currentContactFolder = null;

var usersRightsWindowHeight = 200;
var usersRightsWindowWidth = 450;

function validateEditorInput(sender) {
  var errortext = "";
  var field;
  
  field = document.pageform.subject;
  if (field.value == "")
    errortext = errortext + labels.error_missingsubject + "\n";

  if (!hasRecipients())
    errortext = errortext + labels.error_missingrecipients + "\n";
  
  if (errortext.length > 0) {
    alert(labels.error_validationfailed + ":\n"
          + errortext);
    return false;
  }
  return true;
}

function openContactsFolder(contactsFolder, reload, idx) {
  if ((contactsFolder && contactsFolder != currentContactFolder)
      || reload) {
     currentContactFolder = contactsFolder;
     var url = URLForFolderID(currentContactFolder) +
	"/view?noframe=1";

     var searchValue = search["value"];
     if (searchValue && searchValue.length > 0)
	url += ("&search=" + search["criteria"]
		+ "&value=" + escape(searchValue.utf8encode()));
     var sortAttribute = sorting["attribute"];
     if (sortAttribute && sortAttribute.length > 0)
	url += ("&sort=" + sorting["attribute"]
		+ "&asc=" + sorting["ascending"]);

     var selection;
     if (contactsFolder == currentContactFolder) {
        var contactsList = $("contactsList");
        if (contactsList)
           selection = contactsList.getSelectedRowsId();
//        else
//           window.alert("no contactsList");
     }
     else
	selection = null;

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
  if (http.readyState == 4
      && http.status == 200) {
    document.contactsListAjaxRequest = null;

    var table = $("contactsList");
    if (table) {
      // Update table
      var data = http.responseText;
      var html = data.replace(/^(.*\n)*.*(<table(.*\n)*)$/, "$2");
      var tbody = table.tBodies[0]; 
      var tmp = document.createElement('div');
      $(tmp).update(html);
      table.replaceChild(tmp.firstChild.tBodies[0], tbody);
    }
    else {
      // Add table (doesn't happen .. yet)
      var div = $("contactsListContent");
      div.update(http.responseText);
      table = $("contactsList");
      configureSortableTableHeaders(table);
      TableKit.Resizable.init(table, {'trueResize' : true, 'keepWidth' : true});
    }
    
    if (sorting["attribute"] && sorting["attribute"].length > 0) {
       var sortHeader;
       if (sorting["attribute"] == "displayName")
	  sortHeader = $("nameHeader");
       else if (sorting["attribute"] == "mail")
	  sortHeader = $("mailHeader");
       else if (sorting["attribute"] == "screenName")
	  sortHeader = $("screenNameHeader");
       else if (sorting["attribute"] == "org")
	  sortHeader = $("orgHeader");
       else if (sorting["attribute"] == "phone")
	  sortHeader = $("phoneHeader");
       else
	  sortHeader = null;
       
       if (sortHeader) {
	  var sortImages = $(table.tHead).getElementsByClassName("sortImage");
	  $(sortImages).each(function(item) {
	      item.remove();
	    });

	  var sortImage = createElement("img", "messageSortImage", "sortImage");
	  sortHeader.insertBefore(sortImage, sortHeader.firstChild);
	  if (sorting["ascending"])
	     sortImage.src = ResourcesURL + "/title_sortdown_12x12.png";
	  else
	     sortImage.src = ResourcesURL + "/title_sortup_12x12.png";
       }
    }

    var selected = http.callbackData;
    if (selected) {
       for (var i = 0; i < selected.length; i++) {
	  var row = $(selected[i]);
	  if (row)
	     row.select();
       }
    }
  }
  else
    log ("ajax problem 1: status = " + http.status);
}

function onContactFoldersContextMenu(event) {
  var menu = $("contactFoldersMenu");
  //Event.observe(menu, "hideMenu", onContactFoldersContextMenuHide, false);
  Event.observe(menu, "mousedown", onContactFoldersContextMenuHide, false);
  popupMenu(event, "contactFoldersMenu", this);

  var topNode = $("contactFolders");
  var selectedNodes = topNode.getSelectedRows();
  topNode.menuSelectedRows = selectedNodes;
  for (var i = 0; i < selectedNodes.length; i++)
    $(selectedNodes[i]).deselect();
  topNode.menuSelectedEntry = this;
  $(this).select();
}

function onContactContextMenu(event, element) { log ("onContactContextMenu");
  var menu = $("contactMenu");

  Event.observe(menu, "mousedown", onContactContextMenuHide, false);
  popupMenu(event, "contactMenu", element);

  var topNode = $("contactsList");
  var selectedNodes = topNode.getSelectedRows();
  topNode.menuSelectedRows = selectedNodes;
  for (var i = 0; i < selectedNodes.length; i++)
    $(selectedNodes[i]).deselect();
  topNode.menuSelectedEntry = element;
  $(element).select();
}

function onContactContextMenuHide(event) {
  var topNode = $("contactsList");

  if (topNode.menuSelectedEntry) {
    $(topNode.menuSelectedEntry).deselect();
    topNode.menuSelectedEntry = null;
  }
  if (topNode.menuSelectedRows) {
    var nodes = topNode.menuSelectedRows;
    for (var i = 0; i < nodes.length; i++)
      $(nodes[i]).select();
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
    log ("ajax problem 2: " + http.status);
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

  openContactWindow(URLForFolderID(currentContactFolder)
                    + "/" + contactId + "/edit", contactId);

  return false;
}

function onMenuEditContact(event) {
  var contactId = document.menuTarget.getAttribute('id');

  openContactWindow(URLForFolderID(currentContactFolder)
                    + "/" + contactId + "/edit", contactId);
}

function onMenuWriteToContact(event) {
   var contactId = document.menuTarget.getAttribute('id');
   var contactRow = $(contactId);
   var emailCell = contactRow.down('td', 1);

   if (!emailCell.firstChild) { // .nodeValue is the contact email address
     window.alert(labels["The selected contact has no email address."]);
     return false;
   }

   openMailComposeWindow(ApplicationBaseURL + currentContactFolder
			 + "/" + contactId + "/write");

   if (document.body.hasClassName("popup"))
     window.close();
}

function onMenuDeleteContact(event) {
  uixDeleteSelectedContacts(this);
}

function onToolbarEditSelectedContacts(event) {
  var contactsList = $('contactsList');
  var rows = contactsList.getSelectedRowsId();

  for (var i = 0; i < rows.length; i++) {
    openContactWindow(URLForFolderID(currentContactFolder)
                      + "/" + rows[i] + "/edit", rows[i]);
  }

  return false;
}

function onToolbarWriteToSelectedContacts(event) {
  var contactsList = $('contactsList');
  var rows = contactsList.getSelectedRowsId();
  var rowsWithEmail = 0;

  if (rows.length == 0)
    return false;

  for (var i = 0; i < rows.length; i++) {
    var emailCell = $(rows[i]).down('td', 1);
    if (emailCell.firstChild) { // .nodeValue is the contact email address
      rowsWithEmail++;
      openMailComposeWindow(ApplicationBaseURL + currentContactFolder
			    + "/" + rows[i] + "/write");
    }
  }

  if (rowsWithEmail == 0) {
    window.alert(labels["The selected contact has no email address."]);
  }
  else if (document.body.hasClassName("popup"))
    window.close();

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
    openMailComposeWindow("compose?mailto=" + mailto);

  return false; /* stop following the link */
}

function onHeaderClick(event) {
   var headerId = this.getAttribute("id");
   var newSortAttribute;
   if (headerId == "nameHeader")
      newSortAttribute = "displayName";
   else if (headerId == "mailHeader")
      newSortAttribute = "mail";
   else if (headerId == "screenNameHeader")
      newSortAttribute = "screenName";
   else if (headerId == "orgHeader")
      newSortAttribute = "org";
   else if (headerId == "phoneHeader")
      newSortAttribute = "phone";

   if (sorting["attribute"] == newSortAttribute)
      sorting["ascending"] = !sorting["ascending"];
   else {
      sorting["attribute"] = newSortAttribute;
      sorting["ascending"] = true;
   }

   refreshCurrentFolder();

   Event.stop(event);
}

function newContact(sender) {
  openContactWindow(URLForFolderID(currentContactFolder) + "/new");

  return false; /* stop following the link */
}

function onFolderSelectionChange() {
   var folderList = $("contactFolders");
   var nodes = folderList.getSelectedNodes();
   $("contactView").innerHTML = '';
  
   if (nodes[0].hasClassName("denied")) {
      var div = $("contactsListContent");
      div.update();
   }
   else {
      search = {};
      sorting = {};
      $("searchValue").value = "";
      initCriteria();
      openContactsFolder(nodes[0].getAttribute("id"));
   }
}

function refreshCurrentFolder() {
   openContactsFolder(currentContactFolder, true);
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

   preventDefault(event);
}

function onContactMailTo(node) {
  return openMailTo(node.innerHTML);
}

function refreshContacts(contactId) {
   refreshCurrentFolder();
   cachedContacts[currentContactFolder + "/" + contactId] = null;
   loadContact(contactId);

   return false;
}

function onAddressBookNew(event) {
  createFolder(window.prompt(labels["Name of the Address Book"]),
	       appendAddressBook);
  preventDefault(event);
}

function appendAddressBook(name, folder) {
  if (folder)
    folder = accessToSubscribedFolder(folder);
  else
    folder = "/" + name;
  if ($(folder))
    window.alert(clabels["You have already subscribed to that folder!"]);
  else {
    var li = document.createElement("li");
    $("contactFolders").appendChild(li);
    li.setAttribute("id", folder);
    li.appendChild(document.createTextNode(name));
    setEventsOnContactFolder(li);
  }
}

function newFolderCallback(http) {
  if (http.readyState == 4
      && http.status == 201) {
     var name = http.callbackData;
     appendAddressBook(name, "/" + name);
  }
  else
    log ("ajax problem 4:" + http.status);
}

function newUserFolderCallback(folderData) {
   var folder = $(folderData["folder"]);
   if (!folder)
      appendAddressBook(folderData["folderName"], folderData["folder"]);
}

function onAddressBookAdd(event) {
   openUserFolderSelector(newUserFolderCallback, "contact");

   preventDefault(event);
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
    var folderIdElements = folderId.split("_");
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

  preventDefault(event);
}

function deletePersonalAddressBook(folderId) {
  var label
    = labels["Are you sure you want to delete the selected address book?"];
  if (window.confirm(label)) {
    if (document.deletePersonalABAjaxRequest) {
      document.deletePersonalABAjaxRequest.aborted = true;
      document.deletePersonalABAjaxRequest.abort();
    }
    var url = ApplicationBaseURL + "/" + folderId + "/deleteFolder";
    document.deletePersonalABAjaxRequest
      = triggerAjaxRequest(url, deletePersonalAddressBookCallback,
			   folderId);
  }
}

function deletePersonalAddressBookCallback(http) {
  if (http.readyState == 4) {
    if (isHttpStatus204(http.status)) {
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
    log ("ajax problem 5: " + http.status);
}

function configureDragHandles() {
  var handle = $("dragHandle");
  if (handle) {
    handle.addInterface(SOGoDragHandlesInterface);
    handle.leftBlock=$("contactFoldersList");
    handle.rightBlock=$("rightPanel");
    handle.leftMargin = 100;
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
      var denied = ! isHttpStatus204(http.status);
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
  Event.observe(links[0], "click", onAddressBookNew, false);
  Event.observe(links[1], "click", onAddressBookAdd, false);
  Event.observe(links[2], "click", onAddressBookRemove, false);
}

function configureContactFolders() {
  var contactFolders = $("contactFolders");
  if (contactFolders) {
    Event.observe(contactFolders, "mousedown", listRowMouseDownHandler);
    Event.observe(contactFolders, "click", onFolderSelectionChange);
    var lis = contactFolders.childNodesWithTag("li");
    for (var i = 0; i < lis.length; i++)
      setEventsOnContactFolder(lis[i]);

    lookupDeniedFolders();

    var personalFolder = $("/personal");
    personalFolder.select();
    openContactsFolder("/personal");
  }
}

function setEventsOnContactFolder(node) {
   Event.observe(node, "mousedown", listRowMouseDownHandler, false);
   Event.observe(node, "click", onRowClick, false);
   Event.observe(node, "contextmenu",
		 onContactFoldersContextMenu.bindAsEventListener(node), false);
}

function onMenuModify(event) {
  var folders = $("contactFolders");
  var selected = folders.getSelectedNodes()[0];

  if (UserLogin == selected.getAttribute("owner")) {
    var currentName = selected.innerHTML;
    var newName = window.prompt(labels["Address Book Name"],
				currentName);
    if (newName && newName.length > 0
	&& newName != currentName) {
      var url = (URLForFolderID(selected.getAttribute("id"))
		 + "/renameFolder?name=" + escape(newName.utf8encode()));
      triggerAjaxRequest(url, folderRenameCallback,
			 {node: selected, name: newName});
    }
  } else
    window.alert(clabels["Unable to rename that folder!"]);
}

function folderRenameCallback(http) {
  if (http.readyState == 4) {
    if (isHttpStatus204(http.status)) {
      var dict = http.callbackData;
      dict["node"].innerHTML = dict["name"];
    }
  }
}

function onMenuSharing(event) {
  if ($(this).hasClassName("disabled"))
    return;

   var folders = $("contactFolders");
   var selected = folders.getSelectedNodes()[0];
   var owner = selected.getAttribute("owner");
   if (owner == "nobody")
     window.alert(clabels["The user rights cannot be"
			  + " edited for this object!"]);
   else {
     var title = this.innerHTML;
     var url = URLForFolderID(selected.getAttribute("id"));

     openAclWindow(url + "/acls", title);
   }
}

function onContactFoldersMenuPrepareVisibility() {
  var folders = $("contactFolders");
  var selected = folders.getSelectedNodes();  

  if (selected.length > 0) {
    var folderOwner = selected[0].getAttribute("owner");
    var sharingOption = $(this).down("ul").childElements().last();
    // Disable the "Sharing" option when address book is not owned by user
    if (folderOwner == UserLogin || IsSuperUser)
      sharingOption.removeClassName("disabled");
    else
      sharingOption.addClassName("disabled");
  }
}

function getMenus() {
   var menus = {};
   menus["contactFoldersMenu"] = new Array(onMenuModify, "-", null,
					   null, "-", null, "-",
					   onMenuSharing);
   menus["contactMenu"] = new Array(onMenuEditContact, "-",
				    onMenuWriteToContact, null, "-",
				    onMenuDeleteContact);
   menus["searchMenu"] = new Array(setSearchCriteria);
   
   var contactFoldersMenu = $("contactFoldersMenu");
   if (contactFoldersMenu)
     contactFoldersMenu.prepareVisibility = onContactFoldersMenuPrepareVisibility;
   
   return menus;
}

function configureSelectionButtons() {
   var container = $("contactSelectionButtons");
   if (container) {
      var buttons = container.childNodesWithTag("input");
      for (var i = 0; i < buttons.length; i++)
	Event.observe(buttons[i], "click",
		      onConfirmContactSelection.bindAsEventListener(buttons[i]));
   }
}

function initContacts(event) {
   if (!document.body.hasClassName("popup")) {
     configureAbToolbar();
   }
   else
     configureSelectionButtons();
   configureContactFolders();
//     initDnd();

   var table = $("contactsList");
   if (table) {
     // Initialize contacts table
     table.multiselect = true;
     configureSortableTableHeaders(table);
     TableKit.Resizable.init(table, {'trueResize' : true, 'keepWidth' : true});
   }
}

FastInit.addOnLoad(initContacts);
