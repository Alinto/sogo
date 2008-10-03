/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

function onSearchFormSubmit() {
  var searchValue = $("searchValue");

  var url = (UserFolderURL
						 + "foldersSearch?search=" + escape(searchValue.value)
						 + "&type=" + window.opener.userFolderType);
  if (document.userFoldersRequest) {
		document.userFoldersRequest.aborted = true;
		document.userFoldersRequest.abort();
  }
  document.userFoldersRequest
		= triggerAjaxRequest(url, userFoldersCallback);

  return false;
}

function addLineToTree(tree, parent, line) {
	var offset = 0;

	var nodes = line.split(";");
	if (window.opener.userFolderType == "user"
			|| nodes.length > 1) {
		var parentNode = nodes[0];
		var userInfos = parentNode.split(":");
		var email = userInfos[1] + " &lt;" + userInfos[2] + "&gt;";
		if (!userInfos[3].empty())
			email += " (" + userInfos[3] + ")"; // extra contact info
		tree.add(parent, 0, email, 0, '#', userInfos[0], 'person',
						 '', '',
						 ResourcesURL + '/abcard.gif',
						 ResourcesURL + '/abcard.gif');
		for (var i = 1; i < nodes.length; i++) {
			var folderInfos = nodes[i].split(":");
			var icon = ResourcesURL + '/';
			if (folderInfos[2] == 'Contact')
				icon += 'tb-mail-addressbook-flat-16x16.png';
			else
				icon += 'calendar-folder-16x16.png';
			var folderId = userInfos[0] + ":" + folderInfos[1];
			var name = folderInfos[0]; // name has the format "Folername (Firstname Lastname <email>)"
			var pos = name.lastIndexOf(' (')
				if (pos != -1)
					name = name.substring(0, pos); // strip the part with fullname and email
			tree.add(parent + i, parent, name, 0, '#', folderId,
							 folderInfos[2] + '-folder', '', '', icon, icon);
		}
		offset = nodes.length - 1;
	}
	//    else
	//       window.alert("nope:" + window.opener.userFolderType);

	return offset;
}

function buildTree(response) { 
	d = new dTree("d");
	d.config.folderLlinks = true;
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
	d.add(0, -1, '');

	var lines = response.split("\n");
	var offset = 0;
	for (var i = 0; i < lines.length; i++) {
		if (lines[i].length > 0)
			offset += addLineToTree(d, i + 1 + offset, lines[i]);
	}

	return d;
}

function onFolderTreeItemClick(event) {
	preventDefault(event);

	var topNode = $("d");
	if (topNode.selectedEntry)
		topNode.selectedEntry.deselect();
	this.selectElement();
	topNode.selectedEntry = this;

	if (window.opener.userFolderType == "user")
		$("addButton").disabled = false;
	else {
		var dataname = this.parentNode.getAttribute("dataname");
		$("addButton").disabled = (dataname.indexOf(":") == -1);
	};
}

function userFoldersCallback(http) {
  document.userFoldersRequest = null;
  var div = $("folders");
  if (http.status == 200) {
    var response = http.responseText;
    div.update(buildTree(http.responseText));
    div.clean = false;
    var nodes = document.getElementsByClassName("node", $("d"));
    for (i = 0; i < nodes.length; i++)
      $(nodes[i]).observe("click", onFolderTreeItemClick);
  }
  else if (http.status == 404)
    div.update();
}

function onConfirmFolderSelection(event) {
  var topNode = $("d");
  if (topNode && topNode.selectedEntry) {
    var node = topNode.selectedEntry.parentNode;
    var folder = node.getAttribute("dataname");

    var folderName;
    if (window.opener.userFolderType == "user") {
			var span = $(topNode.selectedEntry).down("SPAN.nodeName");
			var email = (span.innerHTML
									 .replace("&lt;", "<", "g")
									 .replace("&gt;", ">", "g"));
      folderName = email;
    }
    else {
			var resource = $(topNode.selectedEntry).down("SPAN.nodeName");
			var user = $(node.parentNode.previousSibling).down("SPAN.nodeName");
			var email = (user.innerHTML
									 .replace("&lt;", "<", "g")
									 .replace("&gt;", ">", "g"));
			folderName = resource.innerHTML + ' (' + email + ')';
    }

    var data = { folderName: folderName, folder: folder, window: window };
    if (parent$(accessToSubscribedFolder(folder)))
      window.alert(clabels["You have already subscribed to that folder!"]);
    else
      window.opener.subscribeToFolder(window.opener.userFolderCallback, data);
  }
}

function onFolderSearchKeyDown(event) {
  var div = $("folders");
  if (!div.clean) {
    div.update();
    div.clean = true;
		$("addButton").disabled = true;
  }
}

function initUserFoldersWindow() {
  var searchValue = $("searchValue");
  searchValue.observe("keydown", onFolderSearchKeyDown);
  var addButton = $("addButton");
  addButton.observe("click", onConfirmFolderSelection);
  searchValue.focus();
}

FastInit.addOnLoad(initUserFoldersWindow);
