/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var d;
var usersRightsWindowHeight = 220;
var usersRightsWindowWidth = 450;

/* ACLs module */

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
	var response = http.responseText.evalJSON();
	buildUsersTree(div, response)
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
    d.icon.line = ResourcesURL + '/tbtv_line_17x22.png';
    d.icon.join = ResourcesURL + '/tbtv_junction_17x22.png';
    d.icon.joinBottom = ResourcesURL + '/tbtv_corner_17x22.png';
    d.icon.plus = ResourcesURL + '/tbtv_plus_17x22.png';
    d.icon.plusBottom = ResourcesURL + '/tbtv_corner_plus_17x22.png';
    d.icon.minus = ResourcesURL + '/tbtv_minus_17x22.png';
    d.icon.minusBottom = ResourcesURL + '/tbtv_corner_minus_17x22.png';
    d.icon.nlPlus = ResourcesURL + '/tbtv_corner_plus_17x22.png';
    d.icon.nlMinus = ResourcesURL + '/tbtv_corner_minus_17x22.png';
    d.icon.empty = ResourcesURL + '/empty.gif';
    d.preload ();
    d.add(0, -1, '');
    
    var isUserDialog = false;
    var multiplier = ((isUserDialog) ? 1 : 2);
    
    if (response.length > 0) {
        for (var i = 0; i < response.length; i++)
            addUserLineToTree(d, 1 + i * multiplier, response[i]);
        treeDiv.innerHTML = "";
        treeDiv.appendChild(d.domObject ());
        treeDiv.clean = false;
        for (var i = 0; i < response.length; i++) {
            if (!isUserDialog) {
                var toggle = $("tgd" + (1 + i * 2));
                toggle.observe ("click", onUserNodeToggle);
            }
            var sd = $("sd" + (1 + i * multiplier));
            sd.observe("click", onTreeItemClick);
        }
    }
}

function addUserLineToTree(tree, parent, line) {
    var icon = ResourcesURL + '/busy.gif';
    
    var email = line[1] + " &lt;" + line[2] + "&gt;";
    if (line[3] && !line[3].empty())
      email += ", " + line[3]; // extra contact info
    tree.add(parent, 0, email, 0, '#', line[0], 'person',
             '', '',
             ResourcesURL + '/abcard.png',
             ResourcesURL + '/abcard.png');
    tree.add(parent + 1, parent, _("Please wait..."), 0, '#', null,
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
	    for (var i = 1; i < folders.length - 1; i++)
                dd.appendChild(addFolderBranchToTree (d, user, folders[i], nodeId, i, false));
 	    dd.appendChild (addFolderBranchToTree (d, user, folders[folders.length-1], nodeId,
                                                   (folders.length - 1), true));
	    for (var i = 1; i < folders.length; i++) {
      		var sd = $("sd" + (nodeId + i));
      		sd.observe("click", onTreeItemClick);
      		sd.observe("dblclick", onFolderOpen);
	    }
	}
	else {
	    dd.innerHTML = '';
	    dd.appendChild (addFolderNotFoundNode (d, nodeId, null));
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
    var node = new Node(1, nodeId, _("No possible subscription"), 0, '#',
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

/* Common functions */

function configureDragHandles() {
    var handle = $("verticalDragHandle");
    if (handle) {
        handle.addInterface(SOGoDragHandlesInterface);
        handle.leftBlock = $("administrationModules");
        handle.rightBlock = $("rightPanel");
        handle.leftMargin = 100;
    }
}

function help() {
    var div = $("helpDialog");
    var title = div.select('H3').first();
    var description = div.select('DIV DIV')[0];
    var module = $$("#administrationModules LI._selected").first();

    var cellPosition = module.cumulativeOffset();
    var cellDimensions = module.getDimensions();
    var left = cellDimensions.width - 20;
    var top = cellPosition.top + 3;

    div.setStyle({ top: top + 'px',
                left: left + 'px' });
    title.update($("moduleTitle").innerHTML);
    description.update($("moduleDescription").innerHTML);

    div.show();
}

function initAdministration() {
    $("helpDialogClose").observe("click", function(event) {
            $("helpDialog").hide();
        });

    var searchValue = $("searchValue");
    searchValue.focus();
}

document.observe("dom:loaded", initAdministration);
