function onSearchFormSubmit() {
  var searchValue = $("searchValue");

  var url = (ApplicationBaseURL
	     + "/foldersSearch?ldap-only=YES&search=" + searchValue.value
	     + "&type=" + window.userFolderType);
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
   if (window.userFolderType == "user"
       || nodes.length > 1) {
      var parentNode = nodes[0];
      var userInfos = parentNode.split(":");
      var email = userInfos[1] + " &lt;" + userInfos[2] + ">";
      tree.add(parent, 0, email, 0, '#', userInfos[0], 'person',
	       '', '',
	       ResourcesURL + '/abcard.gif',
	       ResourcesURL + '/abcard.gif');
      for (var i = 1; i < nodes.length; i++) {
	 var folderInfos = nodes[i].split(":");
	 var icon = ResourcesURL + '/';
	 if (folderInfos[2] == 'contact')
	    icon += 'tb-mail-addressbook-flat-16x16.png';
	 else
	    icon += 'calendar-folder-16x16.png';
	 var folderId = userInfos[0] + ":" + folderInfos[1];
	 tree.add(parent + i, parent, folderInfos[0], 0, '#', folderId,
		  folderInfos[2] + '-folder', '', '', icon, icon);
      }
      offset = nodes.length - 1;
   }
   else
      window.alert("nope:" + window.userFolderType);

   return offset;
}

function buildTree(response) { 
   d = new dTree("d");
   d.config.folderLlinks = true;
   d.config.hideRoot = true;
   d.icon.root = ResourcesURL + '/tbtv_account_17x17.gif';
   d.icon.folder = ResourcesURL + '/tbtv_leaf_corner_17x17.gif';
   d.icon.folderOpen = ResourcesURL + '/tbtv_leaf_corner_17x17.gif';
   d.icon.node = ResourcesURL + '/tbtv_leaf_corner_17x17.gif';
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
   this.select();
   topNode.selectedEntry = this;
}

function userFoldersCallback(http) {
   if (http.readyState == 4) {
      document.userFoldersRequest = null;
      if (http.status == 200) {
	 var div = $("folders");
	 var response = http.responseText;
	 div.innerHTML = buildTree(http.responseText);
	 var nodes = document.getElementsByClassName("node", $("d"));
	 for (i = 0; i < nodes.length; i++)
	    nodes[i].addEventListener("click",
				      onFolderTreeItemClick, false);
      }
   }
}

function onConfirmFolderSelection(event) {
   var topNode = $("d");
   if (topNode.selectedEntry) {
      var node = topNode.selectedEntry.parentNode;
      var folder = node.getAttribute("dataname");
      var folderName;
      if (window.userFolderType == "user") {
	 var spans = document.getElementsByClassName("nodeName",
						     topNode.selectedEntry);
	 var email = spans[0].innerHTML;
	 email = email.replace("&lt;", "<");
	 email = email.replace("&gt;", ">");
	 folderName = email;
      }
      else {
	 var spans1 = document.getElementsByClassName("nodeName",
						   node);
	 var spans2 = document.getElementsByClassName("nodeName",
						      node.parentNode.previousSibling);
	 var email = spans2[0].innerHTML;
	 email = email.replace("&lt;", "<");
	 email = email.replace("&gt;", ">");
	 folderName = spans1[0].innerHTML + ' (' + email + ')';
      }
      var data = { folderName: folderName, folder: folder };
      window.opener.subscribeToFolder(window.userFolderCallback, data);
   }
}

function initUserFoldersWindow() {
   configureSearchField();
   $("addButton").addEventListener("click", onConfirmFolderSelection, false);
}

window.addEventListener("load", initUserFoldersWindow, false);
