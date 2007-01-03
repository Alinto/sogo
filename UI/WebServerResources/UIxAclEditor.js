/* test */

var contactSelectorAction = 'acls-contacts';

function addContact(tag, fullContactName, contactId, contactName,
                    contactEmail) {
   if (tag == "assistant")
      addUser(contactName, contactId, false);
   else if (tag == "delegate")
      addUser(contactName, contactId, true);
}

function addUser(userName, userId, delegate) {
   var uidList = $("uixselector-userRoles-uidList");
   var uids;

   if (uidList.value.length > 0) {
      uids = uidList.value.split(",");
   } else {
      uids = new Array();
   }

   if (uids.indexOf(userId) < 0) {
      uids.push(userId);
      var ul = $("uixselector-userRoles-display");
      ul.appendChild(nodeForUser(userName, userId));
      uidList.value = uids.join(",");
      var roleList;
      if (delegate)
        roleList = $("delegates");
      else
        roleList = $("assistants");
      if (roleList.value.length > 0) {
        uids = roleList.value.split(",");
        uids.push(userId);
        roleList.value = uids.join(",");
      }
      else
        roleList.value = userId;
   }
}

function nodeForUser(userName, userId) {
   var node = document.createElement("li");
   node.setAttribute("uid", userId);
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
    var uid = selected.getAttribute("uid");
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

function onUsersChange(type) {
  var select = $("userRoleDropDown");
  if (type == "removal") {
    var list;
    if (select.selectedIndex == 0)
      list = $("assistants");
    else
      list = $("delegates");

    var uids = $("uixselector-userRoles-uidList");
    var listArray = list.value.split(",");
    var newListArray = new Array();
    for (var i = 0; i < listArray.length; i++) {
      var regexp = new RegExp("(^|,)" + listArray[i] + "($|,)");
      if (regexp.test(uids.value))
        newListArray.push(listArray[i]);
    }
    if (newListArray.length > 0)
      list.value = newListArray.join(",");
    else
      list.value = "";
  }

  updateSelectedRole($("uixselector-userRoles-display"));
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

  var uid = $("uixselector-userRoles-display").getSelectedRows()[0].getAttribute("uid");
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

function onAclLoadHandler() {
  $("userRoles").changeNotification = onUsersChange;

  var ul = $("uixselector-userRoles-display");
  ul.addEventListener("selectionchange",
                      onAclSelectionChange, false);
  var select = $("userRoleDropDown");
  select.addEventListener("change", onUserRoleDropDownChange, false);
}

window.addEventListener("load", onAclLoadHandler, false);
