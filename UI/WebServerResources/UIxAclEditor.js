/* test */

var contactSelectorAction = 'acls-contacts';

function addContact(tag, fullContactName, contactId, contactName,
                    contactEmail) {
   if (tag == "assistant")
      addUser(contactName, contactId, false);
   else if (tag == "delegate")
      addUser(contactName, contactId, true);
}

function addUser(userName, userId, checked) {
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
      ul.appendChild(nodeForUser(userName, userId, checked));
      uidList.value = uids.join(",");
   }

   log("addUser: " + uidList.value);
}

function nodeForUser(userName, userId, checked) {
   var node = document.createElement("li");
   node.setAttribute("uid", userId);
   node.setAttribute("class", "");
   node.addEventListener("mousedown", listRowMouseDownHandler, true);
   node.addEventListener("click", onRowClick, true);

   var checkbox = document.createElement("input");
   checkbox.setAttribute("type", "checkbox");
   checkbox.setAttribute("class", "checkBox");
   checkbox.checked = checked;
   checkbox.addEventListener("change", updateAclStatus, true);

   node.appendChild(checkbox);
   node.appendChild(document.createTextNode(userName));

   return node;
}

function updateAclStatus() {
}

function saveAcls() {
   var form = $("aclForm");
   var lis = $("uixselector-userRoles-display").childNodesWithTag("li");

   var assistants = new Array();
   var delegates = new Array();
   for (var i = 0; i < lis.length; i++) {
      var uName = lis[i].getAttribute("uid");
      var cb = lis[i].childNodesWithTag("input")[0];
      if (cb.checked)
         delegates.push(uName);
      else
         assistants.push(uName);
   }
   $("assistants").value = assistants.join(",");
   $("delegates").value = delegates.join(",");

   form.submit();

   return false;
}
