/* test */

var contactSelectorAction = 'acls-contacts';
var defaultUserID = '';
var userRightsHeight;
var userRightsWidth;

function addUser(userName, userID) {
   if (!$(userID)) {
      var ul = $("userList");
      ul.appendChild(nodeForUser(userName, userID));
      var url = window.location.href;
      var elements = url.split("/");
      elements[elements.length-1] = ("addUserInAcls?uid="
                                     + userID);
      triggerAjaxRequest(elements.join("/"), addUserCallback);
   }
}

function addUserCallback(http) {
}

function setEventsOnUserNode(node) {
   Event.observe(node, "mousedown", listRowMouseDownHandler);
   Event.observe(node, "selectstart", listRowMouseDownHandler);
   Event.observe(node, "dblclick", onOpenUserRights);
   Event.observe(node, "click", onRowClick);
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
      && http.status == 204)
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
   if (UserLogin != refreshCallbackData["folder"]) {
      addUser(refreshCallbackData["folderName"],
	      refreshCallbackData["folder"]);
   }
   else
      refreshCallbackData["window"].alert(clabels["You cannot subscribe to a folder that you own!"]);
}

function openRightsForUserID(userID) {
   var url = window.location.href;
   var elements = url.split("/");
   elements[elements.length-1] = "userRights?uid=" + userID;

   window.open(elements.join("/"), "",
	       "width=" + userRightsWidth
	       + ",height=" + userRightsHeight
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
      Event.observe(defaultRolesBtn, "click", openRightsForDefaultUser);
   var ul = $("userList");
   var lis = ul.childNodesWithTag("li");
   for (var i = 0; i < lis.length; i++)
      setEventsOnUserNode(lis[i]);

   var buttonArea = $("userSelectorButtons");
   if (buttonArea) {
      var buttons = buttonArea.childNodesWithTag("a");
      Event.observe(buttons[0], "click", onUserAdd);
      Event.observe(buttons[1], "click", onUserRemove);
   }

   userRightsHeight = window.opener.getUsersRightsWindowHeight();
   userRightsWidth = window.opener.getUsersRightsWindowWidth();
}

FastInit.addOnLoad(onAclLoadHandler);
