var contactSelectorAction = 'delegation-contacts';

function addDelegate(delegateName, delegateID) {
   var result = false;
    if (!$(delegateID)) {
        var ul = $("delegateList");
        var newNode = nodeForDelegate(delegateName, delegateID);
        ul.appendChild(newNode);

        var url = window.location.href;
        var elements = url.split("/");
        elements[elements.length-1] = ("addDelegate?uid="
                                       + delegateID);
        triggerAjaxRequest(elements.join("/"), addDelegateCallback, newNode);
        result = true;
    }
    return result;
}

function addDelegateCallback(http) {
    if (http.readyState == 4) {
        if (!isHttpStatus204(http.status)) {
            var node = http.callbackData;
            node.parentNode.removeChild(node);
        }
    }
}

function setEventsOnDelegateNode(node) {
    node.observe("mousedown", listRowMouseDownHandler);
    node.observe("selectstart", listRowMouseDownHandler);
    node.observe("click", onRowClick);
}

function nodeForDelegate(delegateName, delegateId) {
    var node = createElement("li");
    node.id = delegateId;

    var span = createElement("span");
    span.addClassName("userFullName");
    span.appendChild(document.createTextNode(" " + delegateName));
    node.appendChild(span);

    setEventsOnDelegateNode(node);

    return node;
}

function onDelegateAdd(event) {
    openUserFolderSelector(null, "user");

    preventDefault(event);
}

function removeDelegateCallback(http) {
    var node = http.callbackData;

    if (http.readyState == 4
        && isHttpStatus204(http.status))
        node.parentNode.removeChild(node);
    else
        log("error deleting delegate: " + node.getAttribute("id"));
}

function onDelegateRemove(event) {
    var delegateList = $("delegateList");
    var nodes = delegateList.getSelectedRows();

    var url = window.location.href;
    var elements = url.split("/");
    elements[elements.length-1] = "removeDelegate?uid=";
    var baseURL = elements.join("/");

    for (var i = 0; i < nodes.length; i++) {
        var delegateId = nodes[i].id;
        triggerAjaxRequest(baseURL + delegateId, removeDelegateCallback,
                           nodes[i]);
    }
    preventDefault(event);
}

function subscribeToFolder(refreshCallback, refreshCallbackData) {
    var result = true;
    if (UserLogin != refreshCallbackData["folder"]) {
        result = addDelegate(refreshCallbackData["folderName"],
                             refreshCallbackData["folder"]);
    }
    else
        refreshCallbackData["window"].alert(_("You cannot subscribe to a folder that you own!"));
    return result;
}

function onDelegationLoadHandler() {
    var ul = $("delegateList");
    var lis = ul.childNodesWithTag("li");
    for (var i = 0; i < lis.length; i++)
        setEventsOnDelegateNode(lis[i]);

    var buttonArea = $("delegateSelectorButtons");
    if (buttonArea) {
        var buttons = buttonArea.childNodesWithTag("a");
        $("addDelegate").stopObserving ("click");
        $("deleteDelegate").stopObserving ("click");
        $("addDelegate").observe("mousedown", onDelegateAdd);
        $("deleteDelegate").observe("mousedown", onDelegateRemove);
    }
}

document.observe("dom:loaded", onDelegationLoadHandler);
