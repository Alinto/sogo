/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var d;
var usersRightsWindowHeight = 220;
var usersRightsWindowWidth = 450;

function onSearchFormSubmit() {
    var searchValue = $("searchValue");
    var encodedValue = encodeURI(searchValue.value);
    
    if (encodedValue.blank()) {
	checkAjaxRequestsState();
    }
    else {
	var url = (UserFolderURL
		   + "usersSearch?search=" + encodedValue);
	if (document.userFoldersRequest) {
	    document.userFoldersRequest.aborted = true;
	    document.userFoldersRequest.abort();
	}
	document.userFoldersRequest
	    = triggerAjaxRequest(url, usersSearchCallback);
    }
    
    return false;
}

function usersSearchCallback(http) {
    document.userFoldersRequest = null;
    var div = $("administrationContent");
    if (http.status == 200) {
	var response = http.responseText;
	buildUsersTree(div, http.responseText)
    }
    else if (http.status == 404)
	div.update();
}

function buildUsersTree(treeDiv, response) {
    d = new dTree("d");
    d.config.hideRoot = true;
    d.icon.root = ResourcesURL + '/tbtv_account_17x17.gif';
    d.icon.folder = ResourcesURL + '/tbtv_leaf_corner_17x17.png';
    d.icon.folderOpen = ResourcesURL + '/tbtv_leaf_corner_17x17.png';
    d.icon.node = ResourcesURL + '/tbtv_leaf_corner_17x17.png';
    d.icon.line = ResourcesURL + '/tbtv_line_17x17.gif';
    d.icon.join = ResourcesURL + '/tbtv_junction_17x17.gif';
    d.icon.joinBottom = ResourcesURL + '/tbtv_corner_17x17.gif';
    d.icon.plus = ResourcesURL + '/tbtv_plus_17x17.gif';
    d.icon.plusBottom = ResourcesURL + '/tbtv_corner_plus_17x17.gif';
    d.icon.minus = ResourcesURL + '/tbtv_minus_17x17.gif';
    d.icon.minusBottom = ResourcesURL + '/tbtv_corner_minus_17x17.gif';
    d.icon.nlPlus = ResourcesURL + '/tbtv_corner_plus_17x17.gif';
    d.icon.nlMinus = ResourcesURL + '/tbtv_corner_minus_17x17.gif';
    d.icon.empty = ResourcesURL + '/empty.gif';
    d.preload ();
    d.add(0, -1, '');
    
    var isUserDialog = false;
    var multiplier = ((isUserDialog) ? 1 : 2);
    
    if (response.length) {
	var lines = response.split("\n");
	for (var i = 0; i < lines.length; i++) {
	    if (lines[i].length > 0)
		addUserLineToTree(d, 1 + i * multiplier, lines[i]);
	}
	treeDiv.appendChild(d.domObject ());
	treeDiv.clean = false;
	for (var i = 0; i < lines.length - 1; i++) {
	    if (lines[i].length > 0) {
		if (!isUserDialog) {
		    var toggle = $("tgd" + (1 + i * 2));
		    toggle.observe ("click", onUserNodeToggle);
		}
		var sd = $("sd" + (1 + i * multiplier));
		sd.observe("click", onTreeItemClick);
	    }
	}
    }
}

function addUserLineToTree(tree, parent, line) {
    var icon = ResourcesURL + '/busy.gif';
    
    var userInfos = line.split(":");
    var email = userInfos[1] + " &lt;" + userInfos[2] + "&gt;";
    if (userInfos[3] && !userInfos[3].empty())
	email += ", " + userInfos[3]; // extra contact info
    tree.add(parent, 0, email, 0, '#', userInfos[0], 'person',
	     '', '',
	     ResourcesURL + '/abcard.gif',
	     ResourcesURL + '/abcard.gif');
    tree.add(parent + 1, parent, labels["Please wait..."], 0, '#', null,
	     null, '', '', icon, icon);
}

function onTreeItemClick(event) {
    preventDefault(event);
    
    var topNode = $("d");
    if (topNode.selectedEntry)
	topNode.selectedEntry.deselect();
    this.selectElement();
    topNode.selectedEntry = this;
}

function onUserNodeToggle(event) {
    this.stopObserving("click", onUserNodeToggle);
    
    var person = this.parentNode.getAttribute("dataname");
    var url = (UserFolderURLForUser(person) + "foldersSearch");
    var nodeId = this.getAttribute("id").substr(3);
    triggerAjaxRequest(url, foldersSearchCallback,
		       { nodeId: nodeId, user: person });
}

function foldersSearchCallback(http) {
    if (http.status == 200) {
	var response = http.responseText;
 	var nodeId = parseInt(http.callbackData["nodeId"]);
	
	var dd = $("dd" + (nodeId + 2));
	var indentValue = (dd ? 1 : 0);
	d.aIndent.push(indentValue);
	
	var dd = $("dd" + nodeId);
	if (response.length) {
	    var folders = response.split(";");
	    var user = http.callbackData["user"];
	    
	    dd.innerHTML = '';
	    for (var i = 1; i < folders.length - 1; i++) {
		      dd.appendChild(addFolderBranchToTree (d, user, folders[i], nodeId, i, false));
      		log (i + " = " + folders[i]);
	    }
	    dd.appendChild (addFolderBranchToTree (d, user, folders[folders.length-1], nodeId,
					  (folders.length - 1), true));
	    log ((folders.length - 1) + " = " + folders[folders.length-1]);
	    for (var i = 1; i < folders.length; i++) {
      		var sd = $("sd" + (nodeId + i));
      		sd.observe("click", onTreeItemClick);
      		sd.observe("dblclick", onFolderOpen);
	    }
	}
	else {
	    dd.appendChild (addFolderNotFoundNode (d, nodeId));
	    var sd = $("sd" + (nodeId + 1));
	    sd.observe("click", onTreeItemClick);
	}
	
	d.aIndent.pop();
    }
}

function addFolderBranchToTree(tree, user, folder, nodeId, subId, isLast) {
    var folderInfos = folder.split(":");
    var icon = ResourcesURL + '/';
    if (folderInfos[2] == 'Contact')
	icon += 'tb-mail-addressbook-flat-16x16.png';
    else
	icon += 'calendar-folder-16x16.png';
    var folderId = user + ":" + folderInfos[1];
    var name = folderInfos[0]; // name has the format "Folername (Firstname Lastname <email>)"
    var pos = name.lastIndexOf(' (');
    if (pos > -1)
	name = name.substring(0, pos); // strip the part with fullname and email
    var node = new Node(subId, nodeId, name, 0, '#', folderId,
			folderInfos[2] + '-folder', '', '', icon, icon);
    node._ls = isLast;
    var content = tree.node(node, (nodeId + subId), null);
    
    return content;
}

function addFolderNotFoundNode (tree, nodeId) {
    var icon = ResourcesURL + '/icon_unread.gif';
    var node = new Node(1, nodeId, labels["No possible subscription"], 0, '#',
			null, null, '', '', icon, icon);
    node._ls = true;
    return tree.node(node, (nodeId + 1), null);
}

function onFolderOpen(event) {
    var obj = Event.element(event);
    var node = obj.up("div.dTreeNode");
    var folderID = node.readAttribute("dataname");
    var urlstr = URLForFolderID(folderID) + "/acls";
    openAclWindow(urlstr);
}

function toggleDisplay(elementID) {
    var e = $(elementID);
    if (e) {
	e.toggle();
    }
}

function configureDragHandles() {
    var handle = $("verticalDragHandle");
    if (handle) {
        handle.addInterface(SOGoDragHandlesInterface);
        handle.leftBlock = $("administrationModules");
        handle.rightBlock = $("rightPanel");
        handle.leftMargin = 100;
	document.observe("handle:dragged", onWindowResize);
    }
}

function onToggleDescription(event) {
    var desc = this.up().next("div");
    var span = this.up("span");
    var h1 = this.up("h1");
    var filter = $("filterPanel");
    
    var div = $("administrationContent");
    var img = span.down("img");
    if (event) {
	// Toggle only if user clicks on the link
	if (desc.visible()) {
	    desc.hide();
	    img.src = ResourcesURL + "/arrow-rit-sharp.gif";
            filter.setStyle({ float: "right", clear: "none" });
	}
	else {
	    desc.show();
	    img.src = ResourcesURL + "/arrow-dwn.gif"; 
            filter.setStyle({ float: "none", clear: "left" });
	}
    }
    div.setStyle({ top: (filter.cumulativeOffset().top + 10) + "px" });
}

function onWindowResize(event) {
    var f = onToggleDescription.bind($("moduleDescription"));
    f(null);
}

function initAdministration() {
    var searchValue = $("searchValue");
    searchValue.focus();

    $("moduleDescription").observe("click", onToggleDescription);

    Event.observe(window, "resize", onWindowResize);
}

document.observe("dom:loaded", initAdministration);
