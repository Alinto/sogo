/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function onLoadContactFolderProperties() {
    var tabsContainer = $("propertiesTabs");
    var controller = new SOGoTabsController();
    controller.attachToTabsContainer(tabsContainer);
    
    var okButton = $("okButton");
    okButton.observe("click", onOKClick);
  
    var cancelButton = $("cancelButton");
    cancelButton.observe("click", onCancelClick);
  
    Event.observe(document, "keydown", onDocumentKeydown);
}

function onOKClick(event) {
    var AddressBookName = $("addressBookName");
    var folders = parent$("contactFolders");
    var selected = folders.getSelectedNodes()[0];

    if (!AddressBookName.value.blank()) {
        var newName = AddressBookName.value;
        var currentName = AddressBookName.defaultValue;
        if (newName && newName.length > 0 && newName != currentName) {
            if (selected.getAttribute("owner") != "nobody") {
                var url = (URLForFolderID(selected.getAttribute("id")) + "/renameFolder?name=" + escape(newName.utf8encode()));
                triggerAjaxRequest(url, folderRenameCallback, {node: selected, name: newName});
        
            }
            else {
                alert_("You do not own this address book");
            }
        }
        else
            window.close();
    }
    else
        alert(_("Please specify an address book name."));
    Event.stop(event);
}

function folderRenameCallback(http) {
    if (http.readyState == 4) {
        if (isHttpStatus204(http.status)) {
            var dict = http.callbackData;
            dict["node"].childNodesWithTag("span")[0].innerHTML = dict["name"];
            window.close();
        }
    }
}

function onCancelClick(event) {
    window.close();
}

function onDocumentKeydown(event) {
    var target = Event.element(event);
    if (target.tagName == "INPUT" || target.tagName == "SELECT") {
        if (event.keyCode == Event.KEY_RETURN) {
            onOKClick(event);
        }
    }
    if (event.keyCode == Event.KEY_ESC) {
        onCancelClick();
    }
}

document.observe("dom:loaded", onLoadContactFolderProperties);
