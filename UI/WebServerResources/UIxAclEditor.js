/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var contactSelectorAction = 'acls-contacts';
var defaultUserID = '';
var AclEditor = {
    userRightsHeight: null,
    userRightsWidth: null
};

var usersToSubscribe = [];

function addUser(userName, userID, type) {
    var result = false;
    if (!$(userID)) {
        var ul = $("userList");
        var lis = ul.childNodesWithTag("li");
        var newNode = nodeForUser(userName, userID, canSubscribeUsers);
        newNode.addClassName("normal-" + type);

        var count = lis.length - 1;
        var inserted = false;
        while (count > -1 && !inserted) {
            if ($(lis[count]).hasClassName("normal-user")) {
                if ((count+1) < lis.length)
                    ul.insertBefore(newNode, lis[count+1]);
                else
                    ul.appendChild(newNode);
                inserted = true;
            }
            else {
                count--;
            }
        }
        if (!inserted) {
            if (lis.length > 0)
                ul.insertBefore(newNode, lis[0]);
            else
                ul.appendChild(newNode);
        }

        var url = window.location.href;
        var elements = url.split("/");
        elements[elements.length-1] = ("addUserInAcls?uid="
                                       + userID);
        triggerAjaxRequest(elements.join("/"), addUserCallback, newNode);
        result = true;
    }
    return result;
}

function addUserCallback(http) {
    if (http.readyState == 4) {
        if (!isHttpStatus204(http.status)) {
            var node = http.callbackData;
            node.parentNode.removeChild(node);
        }
    }
}

function setEventsOnUserNode(node) {
    var n = $(node);
    n.observe("mousedown", listRowMouseDownHandler);
    n.observe("selectstart", listRowMouseDownHandler);
    n.observe("dblclick", onOpenUserRights);
    n.observe("click", onRowClick);

    var cbParents = n.childNodesWithTag("label");
    if (cbParents && cbParents.length) {
        var cbParent = $(cbParents[0]);
        var checkbox = cbParent.childNodesWithTag("input")[0];
        $(checkbox).observe("change", onSubscriptionChange);
    }
}

function onSubscriptionChange(event) {
    var li = this.parentNode.parentNode;
    var username = li.getAttribute("id");
    var idx = usersToSubscribe.indexOf(username);
    if (this.checked) {
        if (idx < 0)
            usersToSubscribe.push(username);
    } else {
        if (idx > -1)
            usersToSubscribe.splice(idx, 1);
    }
}

function nodeForUser(userName, userId, canSubscribe) {
    var node = createElement("li");
    node.id = userId;

    var span = createElement("span");
    span.addClassName("userFullName");
    span.appendChild(document.createTextNode(" " + userName));
    node.appendChild(span);

    if (canSubscribe) {
        var label = createElement("label");
        label.addClassName("subscriptionArea");
        var cb = createElement("input");
        cb.type = "checkbox";
        label.appendChild(cb);
        label.appendChild(document.createTextNode(_("Subscribe User")));
        node.appendChild(label);
    }

    setEventsOnUserNode(node);

    return node;
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
        var userId = nodes[i].id;
        if (userId != defaultUserID && userId != "anonymous") {
            triggerAjaxRequest(baseURL + userId, removeUserCallback,
                               nodes[i]);
        }
    }
    preventDefault(event);
}

function subscribeToFolder(refreshCallback, refreshCallbackData) {
    var result = true;
    if (UserLogin != refreshCallbackData["folder"]) {
        result = addUser(refreshCallbackData["folderName"],
                         refreshCallbackData["folder"],
                         refreshCallbackData["type"]);
    }
    else
        refreshCallbackData["window"].alert(_("You cannot subscribe to a folder that you own!"));
    return result;
}

function openRightsForUserID(userID) {
    var url = window.location.href;
    var elements = url.split("/");
    elements[elements.length-1] = "userRights?uid=" + userID;

    var height = AclEditor.userRightsHeight;
    if (userID == "anonymous") {
        height -= 42;
        if (CurrentModule() == "Contacts") {
            height -= 21;
        }
    }
    window.open(elements.join("/"), "",
                "width=" + AclEditor.userRightsWidth
                + ",height=" + height
                + ",resizable=0,scrollbars=0,toolbar=0,"
                + "location=0,directories=0,status=0,menubar=0,copyhistory=0");
}

function openRightsForUser(button) {
    var nodes = $("userList").getSelectedRows();
    if (nodes.length > 0)
        openRightsForUserID(nodes[0].getAttribute("id"));

    return false;
}

function onOpenUserRights(event) {
    openRightsForUser();
    preventDefault(event);
}

function onAclLoadHandler() {
    var ul = $("userList");
    var lis = ul.childNodesWithTag("li");
    for (var i = 0; i < lis.length; i++)
        setEventsOnUserNode(lis[i]);

    var input = $("defaultUserID");
    if (input) {
        defaultUserID = $("defaultUserID").value;
        var userNode = nodeForUser(_("Any Authenticated User"),
                                   defaultUserID);
        userNode.addClassName("any-user");
        userNode.setAttribute("title",
                              _("Any user not listed above"));
        ul.appendChild(userNode);
    }
    if (isPublicAccessEnabled && CurrentModule() != "Mail") {
        userNode = nodeForUser(_("Public Access"), "anonymous");
        userNode.addClassName("anonymous-user");
        userNode.setAttribute("title",
                              _("Anybody accessing this resource from the public area"));
        ul.appendChild(userNode);
    }
    
    var buttonArea = $("userSelectorButtons");
    if (buttonArea) {
        var buttons = buttonArea.childNodesWithTag("a");
        $("aclAddUser").stopObserving ("click");
        $("aclDeleteUser").stopObserving ("click");
        $("aclAddUser").observe("mousedown", onUserAdd);
        $("aclDeleteUser").observe("mousedown", onUserRemove);
    }

    AclEditor['userRightsHeight'] = window.opener.getUsersRightsWindowHeight();
    AclEditor['userRightsWidth'] = window.opener.getUsersRightsWindowWidth();

    Event.observe(window, "unload", onAclCloseHandler);
}

function onAclCloseHandler(event) {
    if (usersToSubscribe.length) {
        var url = (URLForFolderID($("folderID").value)
                   + "/subscribeUsers?uids=" + usersToSubscribe.join(","));
        new Ajax.Request(url, {
            asynchronous: false,
            method: 'get',
            onFailure: function(transport) {
                    log("Can't subscribe users: " + transport.status);
                }
        });
    }

    return true;
}

document.observe("dom:loaded", onAclLoadHandler);
