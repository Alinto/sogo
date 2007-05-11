/* test */

var contactSelectorAction = 'acls-contacts';

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

function nodeForUser(userName, userId) {
   var node = document.createElement("li");
   node.setAttribute("id", userId);
   node.setAttribute("class", "");
   node.addEventListener("mousedown", listRowMouseDownHandler, true);
   node.addEventListener("click", onRowClick, true);

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

   event.preventDefault();
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
   event.preventDefault();
}

function subscribeToFolder(refreshCallback, refreshCallbackData) {
   addUser(refreshCallbackData["folderName"],
	   refreshCallbackData["folder"]);
}

function openRightsForUser(button) {
  var nodes = $("userList").getSelectedRows();
  if (nodes.length > 0) {
    var url = window.location.href;
    var elements = url.split("/");
    elements[elements.length-1] = ("userRights?uid="
                                   + nodes[0].getAttribute("id"));

    window.open(elements.join("/"), "",
		"width=" + this.userRightsWidth
		+ ",height=" + this.userRightsHeight
		+ ",resizable=0,scrollbars=0,toolbar=0,"
		+ "location=0,directories=0,status=0,menubar=0,copyhistory=0");
  }

  return false;
}

function onOpenUserRights(event) {
   openRightsForUser();
   event.preventDefault();
}

function onAclLoadHandler() {
  var ul = $("userList");
  var lis = ul.childNodesWithTag("li");
  for (var i = 0; i < lis.length; i++) {
     lis[i].addEventListener("mousedown", listRowMouseDownHandler, false);
     lis[i].addEventListener("dblclick", onOpenUserRights, false);
     lis[i].addEventListener("click", onRowClick, false);
  }

  var buttons = $("userSelectorButtons").childNodesWithTag("a");
  buttons[0].addEventListener("click", onUserAdd, false);
  buttons[1].addEventListener("click", onUserRemove, false);

  this.userRightsHeight = window.opener.getUsersRightsWindowHeight();
  this.userRightsWidth = window.opener.getUsersRightsWindowWidth();
}

window.addEventListener("load", onAclLoadHandler, false);
