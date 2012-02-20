/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var ComponentEditor = {
    attendeesWindow: null,
    recurrenceWindow: null,
    reminderWindow: null
};

function getOwnerLogin() {
    return ownerLogin;
}

function getCalendarOwner() {
    var ownerProfile;

    if (typeof organizer == "undefined") {
        var calendarIndex = $("calendarList").value;
        var ownersList = owners[0];
        var profiles = owners[1];
        var ownerUid = ownersList[calendarIndex];
        ownerProfile = profiles[ownerUid];
        ownerProfile["uid"] = ownerUid;
    }
    else {
        ownerProfile = organizer;
    }
    
    return ownerProfile;
}

function onPopupAttendeesWindow(event) {
    if (event)
        preventDefault(event);
    if (ComponentEditor.attendeesWindow && ComponentEditor.attendeesWindow.open && !ComponentEditor.attendeesWindow.closed)
        ComponentEditor.attendeesWindow.focus();
    else
        ComponentEditor.attendeesWindow = window.open(ApplicationBaseURL + "/editAttendees",
                                                      sanitizeWindowName(activeCalendar + activeComponent + "Attendees"),
                                                      "width=900,height=573");
    
    return false;
}

function onSelectClassification(event) {
    if (event.button == 0 || (isWebKit() && event.button == 1)) {
        var node = getTarget(event);
        if (node.tagName != 'A')
            node = $(node).up("A");
        popupToolbarMenu(node, "classification-menu");
        Event.stop(event);
    }
}

function onPopupAttachWindow(event) {
    if (event)
        preventDefault(event);

    var attachInput = $("attach");
    var newAttach = window.prompt(_("Target:"), attachInput.value || "http://");
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

    var classificationInput = $("classification");
    classificationInput.value = classification;
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

function initializeClassificationMenu() {
    if ($("classification-menu")) {
        var classification = $("classification").value.toUpperCase();
        var classificationMenu = $("classification-menu").childNodesWithTag("ul")[0];
        var menuEntries = $(classificationMenu).childNodesWithTag("li");
        var chosenNode;
        if (classification == "CONFIDENTIAL")
            chosenNode = menuEntries[1];
        else if (classification == "PRIVATE")
            chosenNode = menuEntries[2];
        else
            chosenNode = menuEntries[0];
        classificationMenu.chosenNode = chosenNode;
        $(chosenNode).addClassName("_chosen");
    }
}

function findAttendeeWithFieldValue(field, fieldValue) {
    var foundAttendee = null;

    var attendeesKeys = attendees.keys();
    for (var i = 0; !foundAttendee && i < attendeesKeys.length; i++) {
        var attendee = attendees.get(attendeesKeys[i]);
        if (attendee[field] == fieldValue) {
            foundAttendee = attendee;
        }
    }

    return foundAttendee;
}

function findDelegateAddress() {
    var delegateAddress = null;

    var ownerAttendee = findAttendeeWithFieldValue("uid", ownerLogin);
    if (ownerAttendee && ownerAttendee["delegated-to"]) {
        var delegateAttendee
            = findAttendeeWithFieldValue("email",
                                         ownerAttendee["delegated-to"]);
        if (delegateAttendee) {
            if (delegateAttendee["name"]) {
                delegateAddress = (delegateAttendee["name"]
                                   + " <" + delegateAttendee["email"] + ">");
            }
            else {
                delegateAddress = delegateAttendee["email"];
            }
        }
    }

    return delegateAddress;
}

function onComponentEditorLoad(event) {
    initializeDocumentHref();
    initializeClassificationMenu();
    var list = $("calendarList");
    if (list) {
        list.observe("change", onChangeCalendar, false);
        list.fire("mousedown");
    }
    
    var tmp = $("itemClassificationList");
    if (tmp) {
        var menuItems = tmp.childNodesWithTag("li");
        for (var i = 0; i < menuItems.length; i++)
            menuItems[i].observe("mousedown",
                                 onMenuSetClassification.bindAsEventListener(menuItems[i]),
                                 false);
    }

    tmp = $("replyList");
    if (tmp) {
        tmp.observe("change", onReplyChange);
        var isDelegated = (tmp.value == 4);
        tmp = $("delegatedTo");
        tmp.addInterface(SOGoAutoCompletionInterface);
        tmp.uidField = "c_mail";
        tmp.excludeGroups = true;
        var delegateEditor = $("delegateEditor");
        tmp.animationParent = delegateEditor;
        if (isDelegated) {
            var delegateAddress = findDelegateAddress();
            if (delegateAddress) {
                tmp.value = delegateAddress;
            }
            delegateEditor.show();
        }
     }

    tmp = $("repeatHref");
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
    Event.observe(window, "beforeunload", onComponentEditorClose);
    
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
}

function onSummaryChange (e) {
    if ($("summary"))
        document.title = $("summary").value;
}

function onReplyChange(event) {
    var delegateEditor = $("delegateEditor");
    if (this.value == 4) {
        // Delegated
        delegateEditor.show();
        $("delegatedTo").focus();
    }
    else {
        delegateEditor.hide();
    }
    onWindowResize(null);

    return true;
}

function onComponentEditorClose(event) {
    if (ComponentEditor.attendeesWindow && ComponentEditor.attendeesWindow.open && !ComponentEditor.attendeesWindow.closed)
        ComponentEditor.attendeesWindow.close();
    if (ComponentEditor.recurrenceWindow && ComponentEditor.recurrenceWindow.open && !ComponentEditor.recurrenceWindow.closed)
        ComponentEditor.recurrenceWindow.close();
    if (ComponentEditor.reminderWindow && ComponentEditor.reminderWindow.open && !ComponentEditor.reminderWindow.closed)
        ComponentEditor.reminderWindow.close();
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
        // Custom repeat rule
        repeatHref.show();
        if (event) {
            if (ComponentEditor.recurrenceWindow && ComponentEditor.recurrenceWindow.open && !ComponentEditor.recurrenceWindow.closed)
                ComponentEditor.recurrenceWindow.focus();
            else
                ComponentEditor.recurrenceWindow = window.open(ApplicationBaseURL + "editRecurrence",
                                                               sanitizeWindowName(activeCalendar + activeComponent + "Recurrence"),
                                                               "width=500,height=400");
        }
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
        if (event) {
            if (ComponentEditor.reminderWindow && ComponentEditor.reminderWindow.open && !ComponentEditor.reminderWindow.closed)
                ComponentEditor.reminderWindow.focus();
            else {
                var height = (emailAlarmsEnabled ? 215 : 150);
                ComponentEditor.reminderWindow
                    = window.open(ApplicationBaseURL + "editReminder",
                                  sanitizeWindowName(activeCalendar + activeComponent + "Reminder"),
                                  "width=255,height=" + height);
            }
        }
    }
    else if (reminderHref)
        reminderHref.hide();

    return false;
}

function onOkButtonClick (e) {
    var item = $("replyList");
    var value = parseInt(item.options[item.selectedIndex].value);
    var action = "";
    var parameters = "";
  
    if (value == 0)
        action = 'accept';
    else if (value == 1)
        action = 'decline';
    else if (value == 2)
        action = 'needsaction';
    else if (value == 3)
        action = 'tentative';
    else if (value == 4) {
        var url = ApplicationBaseURL + activeCalendar + '/' + activeComponent;
        delegateInvitation(url, modifyEventCallback);
    }

    if (action != "")
        modifyEvent (item, action, parameters);
}

function onCancelButtonClick (e) {
    window.close ();
}

document.observe("dom:loaded", onComponentEditorLoad);
