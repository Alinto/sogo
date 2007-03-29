/* test */

var contactSelectorAction = 'acls-contacts';

function addUser(userName, userID) {
   if (!$(userID)) {
      var ul = $("userList");
      ul.appendChild(nodeForUser(userName, userID));
      var roleList = $("assistants");
      if (roleList.value.length > 0) {
	 var uids = roleList.value.split(",");
	 uids.push(userID);
	 roleList.value = uids.join(",");
      }
      else
	 roleList.value = userID;
   }
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
  $("aclForm").submit();

  return false;
}

function updateSelectedRole(list) {
  var select = $("userRoleDropDown");
  var selection = list.getSelectedRows(); 
  if (selection.length > 0) {
    select.style.visibility = "visible;";
    var selected = selection[0];
    var assistantsValue = $("assistants");
    var uid = selected.getAttribute("id");
    var regexp = new RegExp("(^|,)" + uid + "(,|$)","i");
    if (regexp.test(assistantsValue.value))
      select.selectedIndex = 0;
    else
      select.selectedIndex = 1;
  }
  else
    select.style.visibility = "hidden;";
}

function onAclSelectionChange() {
  log("selectionchange");
  updateSelectedRole(this);
}

function onUserRoleDropDownChange() {
  var oldList;
  var newList;

  if (this.selectedIndex == 0) {
    oldList = $("delegates");
    newList = $("assistants");
  } else {
    oldList = $("assistants");
    newList = $("delegates");
  }

  var uid = $("userList").getSelectedRows()[0].getAttribute("id");
  var newListArray;
  if (newList.value.length > 0) {
    newListArray = newList.value.split(",");
    newListArray.push(uid);
  }
  else
    newListArray = new Array(uid);
  newList.value = newListArray.join(",");

  var oldListArray = oldList.value.split(",").without(uid);
  if (oldListArray.length > 0)
    oldList.value = oldListArray.join(",");
  else
    oldList.value = "";

  log("assistants: " + $("assistants").value);
  log("delegates: " + $("delegates").value);
}

function onUserAdd(event) {
   openUserFolderSelector(null, "user");

   event.preventDefault();
}

function onUserRemove(event) {
   var userlist = $("userList");
   var node = userlist.getSelectedRows()[0];
   var uid = node.getAttribute("id");
   var regexp = new RegExp("(^|,)" + uid + "($|,)");
   var uids = $("assistants");
   if (!regexp.test(uids.value))
      uids = $("delegates");
   if (regexp.test(uids.value)) {
      var list = uids.value.split(",");
      var newList = new Array();
      for (var i = 0; i < list.length; i++) {
	 if (list[i] != uid)
	    newList.push(list[i]);
      }
      uids.value = newList.join(",");
      node.parentNode.removeChild(node);
   }
   updateSelectedRole(userlist);
   event.preventDefault();
}

function subscribeToFolder(refreshCallback, refreshCallbackData) {
   addUser(refreshCallbackData["folderName"],
	   refreshCallbackData["folder"]);
}

function onAclLoadHandler() {
  var ul = $("userList");
  ul.addEventListener("selectionchange",
                      onAclSelectionChange, false);
  var lis = ul.childNodesWithTag("li");
  for (var i = 0; i < lis.length; i++) {
     lis[i].addEventListener("mousedown", listRowMouseDownHandler, false);
     lis[i].addEventListener("click", onRowClick, false);
  }

  var select = $("userRoleDropDown");
  select.addEventListener("change", onUserRoleDropDownChange, false);

  var buttons = $("userSelectorButtons").childNodesWithTag("a");
  buttons[0].addEventListener("click", onUserAdd, false);
  buttons[1].addEventListener("click", onUserRemove, false);
}

window.addEventListener("load", onAclLoadHandler, false);
