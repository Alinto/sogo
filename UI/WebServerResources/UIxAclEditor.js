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

function onUserRemove(event) {
   var userList = $("userList");
   var nodes = userList.getSelectedRows();
   for (var i = 0; i < nodes.length; i++)
      userList.removeChild(nodes[i]);
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
    window.open(elements.join("/"));
  }

  return false;
}

function onOpenUserRights(event) {
  window.alert("user: " + this.getAttribute("id"));
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
}

window.addEventListener("load", onAclLoadHandler, false);
