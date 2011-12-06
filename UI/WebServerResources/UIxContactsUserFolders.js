/* -*- Mode: java; tab-width: 2; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var d;

function onSearchFormSubmit() {
    startAnimation($("pageContent"), $("filterPanel"));

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
    var div = $("folders");
    if (http.status == 200) {
        var response = http.responseText.evalJSON();
        buildUsersTree(div, response);
    }
    else if (http.status == 404)
        div.update();
}

function addUserLineToTree(tree, parent, line) {
    // line[0] = uid
    // line[1] = cn
    // line[2] = email
    // line[3] = 1 if it's a group
    // line[4] = contact info
    var icon = ResourcesURL + '/busy.gif';

    var email = line[1] + " &lt;" + line[2] + "&gt;";
    if (line[4] && !line[4].empty())
        email += ", " + line[4].split("\n").join("; "); // extra contact info
    var icon_card = 'abcard.png';
    var datatype = 'person';
    if (line[3]) {
        icon_card = 'ablist.png';
        datatype = 'group';
    }
    tree.add(parent, 0, email, 0, '#', line[0], datatype,
             '', '',
             ResourcesURL + '/' + icon_card,
             ResourcesURL + '/' + icon_card);
    if (window.opener.userFolderType != "user") {
        tree.add(parent + 1, parent, _("Please wait..."), 0, '#', null,
                 null, '', '', icon, icon);
    }
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

    var isUserDialog = (window.opener.userFolderType == "user");
    var multiplier = ((isUserDialog) ? 1 : 2);

    if (response.length > 0) {
        for (var i = 0; i < response.length; i++)
            addUserLineToTree(d, 1 + i * multiplier, response[i]);
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
    else {
        $("searchValue").addClassName("notfound");
    }
}

function onUserNodeToggle(event) {
    this.stopObserving("click", onUserNodeToggle);

    var person = this.parentNode.getAttribute("dataname");

    var url = (UserFolderURLForUser(person) + "foldersSearch"
               + "?type=" + window.opener.userFolderType);
    var nodeId = this.getAttribute("id").substr(3);
    triggerAjaxRequest(url, foldersSearchCallback,
                       { nodeId: nodeId, user: person });
}

function onTreeItemClick(event) {
    preventDefault(event);

    var topNode = $("d");
    if (topNode.selectedEntry)
        topNode.selectedEntry.deselect();
    this.selectElement();
    topNode.selectedEntry = this;

    if (window.opener.userFolderType == "user")
        $("addButton").removeClassName("disabled");
    else {
        var dataname = this.parentNode.getAttribute("dataname");
        if (!dataname)
            dataname = "";
        if (dataname.indexOf(":") == -1)
            $("addButton").addClassName("disabled");
        else
            $("addButton").removeClassName("disabled");
    };
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
                dd.appendChild (addFolderBranchToTree (d, user, folders[i], nodeId, i, false));
            dd.appendChild (addFolderBranchToTree (d, user, folders[folders.length-1], nodeId,
                                                   (folders.length - 1), true));
            //dd.update(str);
            for (var i = 1; i < folders.length; i++) {
                var sd = $("sd" + (nodeId + i));
                sd.observe("click", onTreeItemClick);
            }
        }
        else {
            dd.innerHTML = '';
            dd.appendChild(addFolderNotFoundNode (d, nodeId, null));
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
    return tree.node(node, (nodeId + 1));
}

function onConfirmFolderSelection(event) {
    if (!this.hasClassName("disabled")) {
        var topNode = $("d");
        if (topNode && topNode.selectedEntry) {
            var node = topNode.selectedEntry.parentNode;
            var folder = node.getAttribute("dataname");
            var type = node.getAttribute("datatype");

            var folderName;
            if (window.opener.userFolderType == "user") {
                var span = $(topNode.selectedEntry).down("SPAN.nodeName");
                var email = (span.innerHTML
                             .replace("&lt;", "<", "g")
                             .replace("&gt;", ">", "g"));
                folderName = email.replace(/>,.*$/, ">", "g");
            }
            else {
                var resource = $(topNode.selectedEntry).down("SPAN.nodeName");
                var user = $(node.parentNode.previousSibling).down("SPAN.nodeName");
                var email = (user.innerHTML
                             .replace("&lt;", "<", "g")
                             .replace("&gt;", ">", "g"));
                folderName = resource.innerHTML + ' (' + email + ')';
                folderName = folderName.replace(/>,.*(\))?$/, ">)$1", "g");
            }

            var data = { folderName: folderName, folder: folder, type: type, window: window };
            if (parent$(accessToSubscribedFolder(folder)))
                window.alert(_("You have already subscribed to that folder!"));
            else
                window.opener.subscribeToFolder(window.opener.userFolderCallback, data);
            this.blur(); // required by IE
        }
    }
}

function onFolderSearchKeyDown(event) {
    if (event.keyCode == Event.KEY_BACKSPACE
        || IsCharacterKey(event.keyCode)) {
        $("searchValue").removeClassName("notfound");
        var div = $("folders");
        if (!div.clean) {
            var oldD = $("d"); // the folders tree
            if (oldD) {
                oldD.remove();
                delete d;
            }
            div.clean = true;
            $("addButton").addClassName("disabled");
        }
    }
}

function initUserFoldersWindow() {
    var searchValue = $("searchValue");
    searchValue.observe("keydown", onFolderSearchKeyDown);

    $("addButton").observe("click", onConfirmFolderSelection);
    $("doneButton").observe("click", onCloseButtonClick);

    searchValue.focus();
}

document.observe("dom:loaded", initUserFoldersWindow);
