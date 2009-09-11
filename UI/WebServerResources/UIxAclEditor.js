/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/* test */

var contactSelectorAction = 'acls-contacts';
var defaultUserID = '';
var AclEditor = {
 userRightsHeight: null,
 userRightsWidth: null
};

function addUser(userName, userID) {
	var result = false;
	if (!$(userID)) {
		var ul = $("userList");
		ul.appendChild(nodeForUser(userName, userID));
		var url = window.location.href;
		var elements = url.split("/");
		elements[elements.length-1] = ("addUserInAcls?uid="
																	 + userID);
		triggerAjaxRequest(elements.join("/"), addUserCallback);
		result = true;
	}
	return result;
}

function addUserCallback(http) {
	// Ignore response
}

function setEventsOnUserNode(node) {
  var n = $(node);
  n.observe("mousedown", listRowMouseDownHandler);
  n.observe("selectstart", listRowMouseDownHandler);
  n.observe("dblclick", onOpenUserRights);
  n.observe("click", onRowClick);
}

function nodeForUser(userName, userId) {
	var node = document.createElement("li");
	node.setAttribute("id", userId);
	node.setAttribute("class", "");
	setEventsOnUserNode(node);

	var image = document.createElement("img");
	image.setAttribute("src", ResourcesURL + "/abcard.gif");

	node.appendChild(image);
	node.appendChild(document.createTextNode(" " + userName));

	return node;
}

function saveAcls() {
	var uidList = new Array();
	var users = $("userList").childNodesWithTag("li");
	for (var i = 0; i < users.length; i++)
		uidList.push(users[i].getAttribute("id"));
	$("userUIDS").value = uidList.join(",");
	$("aclForm").submit();

	return false;
}

function onUserAdd(event) {
	openUserFolderSelector(null, "user");

	preventDefault(event);
}

function removeUserCallback(http) {
	var node = http.callbackData;

  if (http.readyState == 4
      && isHttpStatus204(http.status))
		node.parentNode.removeChild(node);
  else
		log("error deleting user: " + node.getAttribute("id"));
}

function onUserRemove(event) {
	var userList = $("userList");
	var nodes = userList.getSelectedRows();

	var url = window.location.href;
	var elements = url.split("/");
	elements[elements.length-1] = "removeUserFromAcls?uid=";
	var baseURL = elements.join("/");

	for (var i = 0; i < nodes.length; i++) {
		var userId = nodes[i].getAttribute("id");
		triggerAjaxRequest(baseURL + userId, removeUserCallback, nodes[i]);
	}
	preventDefault(event);
}

function subscribeToFolder(refreshCallback, refreshCallbackData) {
	var result = true;
	if (UserLogin != refreshCallbackData["folder"]) {
		result = addUser(refreshCallbackData["folderName"],
										 refreshCallbackData["folder"]);
	}
	else
		refreshCallbackData["window"].alert(label ("You cannot subscribe to a folder that you own!"));
	return result;
}

function openRightsForUserID(userID) {
	var url = window.location.href;
	var elements = url.split("/");
	elements[elements.length-1] = "userRights?uid=" + userID;

	window.open(elements.join("/"), "",
							"width=" + AclEditor.userRightsWidth
							+ ",height=" + AclEditor.userRightsHeight
							+ ",resizable=0,scrollbars=0,toolbar=0,"
							+ "location=0,directories=0,status=0,menubar=0,copyhistory=0");
}

function openRightsForUser(button) {
  var nodes = $("userList").getSelectedRows();
  if (nodes.length > 0)
		openRightsForUserID(nodes[0].getAttribute("id"));

  return false;
}

function openRightsForDefaultUser(event) {
	openRightsForUserID(defaultUserID);
	preventDefault(event);
}

function onOpenUserRights(event) {
	openRightsForUser();
	preventDefault(event);
}

function onAclLoadHandler() {
	defaultUserID = $("defaultUserID").value;
	var defaultRolesBtn = $("defaultRolesBtn");
	if (defaultRolesBtn)
		defaultRolesBtn.observe("click", openRightsForDefaultUser);
	var ul = $("userList");
	var lis = ul.childNodesWithTag("li");
	for (var i = 0; i < lis.length; i++)
		setEventsOnUserNode(lis[i]);

	var buttonArea = $("userSelectorButtons");
	if (buttonArea) {
		var buttons = buttonArea.childNodesWithTag("a");
		buttons[0].observe("click", onUserAdd);
		buttons[1].observe("click", onUserRemove);
	}

	AclEditor['userRightsHeight'] = window.opener.getUsersRightsWindowHeight();
	AclEditor['userRightsWidth'] = window.opener.getUsersRightsWindowWidth();
}

document.observe("dom:loaded", onAclLoadHandler);
