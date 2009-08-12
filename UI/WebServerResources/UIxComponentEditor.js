/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function onPopupAttendeesWindow(event) {
    if (event)
        preventDefault(event);
    window.open(ApplicationBaseURL + "/editAttendees", null, 
                "width=803,height=573");

    return false;
}

function onSelectPrivacy(event) {
    if (event.button == 0 || (isSafari() && event.button == 1)) {
        var node = getTarget(event);
        if (node.tagName != 'BUTTON')
            node = $(node).up("button");
        popupToolbarMenu(node, "privacy-menu");
        Event.stop(event);
        //       preventDefault(event);
    }
}

function onPopupAttachWindow(event) {
    if (event)
        preventDefault(event);

    var attachInput = document.getElementById("attach");
    var newAttach = window.prompt(labels["Target:"], attachInput.value || "http://");
    if (newAttach != null) {
        var documentHref = $("documentHref");
        var documentLabel = $("documentLabel");
        if (documentHref.childNodes.length > 0) {
            documentHref.childNodes[0].nodeValue = newAttach;
            if (newAttach.length > 0)
                documentLabel.setStyle({ display: "block" });
            else
                documentLabel.setStyle({ display: "none" });
        }
        else {
            documentHref.appendChild(document.createTextNode(newAttach)); 
            if (newAttach.length > 0)
                documentLabel.setStyle({ display: "block" });
        }
        attachInput.value = newAttach;
    }
    onWindowResize(event);
  
    return false;
}

function onPopupDocumentWindow(event) {
    var documentUrl = $("attach");

    preventDefault(event);
    window.open(documentUrl.value, "SOGo_Document");

    return false;
}

function onMenuSetClassification(event) {
    event.cancelBubble = true;

    var classification = this.getAttribute("classification");
    if (this.parentNode.chosenNode)
        this.parentNode.chosenNode.removeClassName("_chosen");
    this.addClassName("_chosen");
    this.parentNode.chosenNode = this;

    var privacyInput = $("privacy");
    privacyInput.value = classification;
}

function onChangeCalendar(event) {
    var calendars = $("calendarFoldersList").value.split(",");
    var form = document.forms["editform"];
    var urlElems = form.getAttribute("action").split("?");
    var choice = calendars[this.value];
    var urlParam = "moveToCalendar=" + choice;
    if (urlElems.length == 1)
        urlElems.push(urlParam);
    else
        urlElems[2] = urlParam;

    while (urlElems.length > 2)
        urlElems.pop();

    form.setAttribute("action", urlElems.join("?"));
}

function initializeDocumentHref() {
    var documentHref = $("documentHref");
    var documentLabel = $("documentLabel");
    var documentUrl = $("attach");

    documentHref.observe("click", onPopupDocumentWindow, false);
    documentHref.setStyle({ textDecoration: "underline", color: "#00f" });
    if (documentUrl.value.length > 0) {
        documentHref.appendChild(document.createTextNode(documentUrl.value));
        documentLabel.setStyle({ display: "block" });
    }

    var changeUrlButton = $("changeAttachButton");
    if (changeUrlButton)
        changeUrlButton.observe("click", onPopupAttachWindow, false);
}

function initializePrivacyMenu() {
    if ($("privacy-menu")) {
        var privacy = $("privacy").value.toUpperCase();
        var privacyMenu = $("privacy-menu").childNodesWithTag("ul")[0];
        var menuEntries = $(privacyMenu).childNodesWithTag("li");
        var chosenNode;
        if (privacy == "CONFIDENTIAL")
            chosenNode = menuEntries[1];
        else if (privacy == "PRIVATE")
            chosenNode = menuEntries[2];
        else
            chosenNode = menuEntries[0];
        privacyMenu.chosenNode = chosenNode;
        $(chosenNode).addClassName("_chosen");
    }
}

function onComponentEditorLoad(event) {
    initializeDocumentHref();
    initializePrivacyMenu();
    var list = $("calendarList");
    if (list) {
        list.observe("change", onChangeCalendar, false);
        list.fire("mousedown");
    }
    
    if ($("itemPrivacyList")) {
        var menuItems = $("itemPrivacyList").childNodesWithTag("li");
        for (var i = 0; i < menuItems.length; i++)
            menuItems[i].observe("mousedown",
                                 onMenuSetClassification.bindAsEventListener(menuItems[i]),
                                 false);
    }
    
    var tmp = $("repeatHref");
    if (tmp)
        tmp.observe("click", onPopupRecurrenceWindow);
    tmp = $("repeatList");
    if (tmp)
        tmp.observe("change", onPopupRecurrenceWindow);
    tmp = $("reminderHref");
    if (tmp)
        tmp.observe("click", onPopupReminderWindow);
    tmp = $("reminderList");
    if (tmp)
        tmp.observe("change", onPopupReminderWindow);
    tmp = $("summary");
    if (tmp)
        tmp.observe("keyup", onSummaryChange);
    
    Event.observe(window, "resize", onWindowResize);
    
    onPopupRecurrenceWindow(null);
    onPopupReminderWindow(null);
    onSummaryChange (null);
    
    var summary = $("summary");
    if (summary) {
  	summary.focus();
        summary.selectText(0, summary.value.length);
    }
    
    tmp = $("okButton");
    if (tmp)
        tmp.observe ("click", onOkButtonClick);
    tmp = $("cancelButton");
    if (tmp)
        tmp.observe ("click", onCancelButtonClick);
    
    if (tmp)
        window.resizeTo(430,540);
}

function onSummaryChange (e) {
    if ($("summary"))
        document.title = $("summary").value;
}

function onWindowResize(event) {
    var comment = $("commentArea");
    if (comment) {
        // Resize comment area of read-write component
        var document = $("documentLabel");
        var area = comment.select("textarea").first();
        var offset = 6;
        var height;
        
        height = window.height() - comment.cumulativeOffset().top - offset;
        
        if (document.visible()) {
            // Component has an attachment
            if ($("changeAttachButton"))
                height -= $("changeAttachButton").getHeight();
            else
                height -= $("documentHref").getHeight();
        }
        
        if (area)
            area.setStyle({ height: (height - offset*2) + "px" });

        comment.setStyle({ height: (height - offset) + "px" });
    }
    else {
        // Resize attendees area of a read-only component
        $("eventView").style.height = window.height () + "px";
        var height = window.height() - 120;
        var tmp = $("generalDiv");
        if (tmp)
            height -= tmp.offsetHeight;
        tmp = $("descriptionDiv");
        if (tmp)
            height -= tmp.offsetHeight;
        
        tmp = $("attendeesDiv");
        if (tmp) {
            tmp.style.height = height + "px";
            $("attendeesMenu").style.height = (height - 20) + "px";
        }
    }
    
    return true;
}

function onPopupRecurrenceWindow(event) {
    if (event)
        preventDefault(event);
    
    var repeatHref = $("repeatHref");
    
    var repeatList = $("repeatList");
    if (repeatList && repeatList.value == 7) {
        repeatHref.show();
        if (event)
            window.open(ApplicationBaseURL + "editRecurrence", null, 
                        "width=500,height=400");
    }
    else if (repeatHref)
        repeatHref.hide();
    
    return false;
}

function onPopupReminderWindow(event) {
    if (event)
        preventDefault(event);

    var reminderHref = $("reminderHref");

    var reminderList = $("reminderList");
    if (reminderList && reminderList.value == 15) {
        reminderHref.show();
        if (event)
            window.open(ApplicationBaseURL + "editReminder", null, 
                        "width=250,height=150");
    }
    else if (reminderHref)
        reminderHref.hide();

    return false;
}

function onOkButtonClick (e) {
    var item = $("replyList");
    var value = parseInt(item.options[item.selectedIndex].value);
    var action = "";
  
    if (value == 0)
        action = 'accept';
    else if (value == 1)
        action = 'decline';

    if (action != "")
        modifyEvent (item, action);
}

function onCancelButtonClick (e) {
    window.close ();
}

document.observe("dom:loaded", onComponentEditorLoad);
