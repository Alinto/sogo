function initializeWindowButtons() {
    var okButton = $("okButton");
    var cancelButton = $("cancelButton");

    okButton.observe("click", onEditorOkClick, false);
    cancelButton.observe("click", onEditorCancelClick, false);
}

function initializeFormValues() {
    if (parent$("reminderUnit").value.length > 0) {
        $("quantityField").value = parent$("reminderQuantity").value;
        $("unitsList").value = parent$("reminderUnit").value;
        $("relationsList").value = parent$("reminderRelation").value;
        $("referencesList").value = parent$("reminderReference").value;
    }

    var actionList = $("actionList");
    if (actionList) {
        actionList.observe("change", onActionListChange);
        var action = parent$("reminderAction").value;
        if (!action)
            action = "display";
        actionList.value = action;
        if (action == "email") {
            $("emailOrganizer").checked = (parent$("reminderEmailOrganizer").value
                                           == "true");
            $("emailAttendees").checked = (parent$("reminderEmailAttendees").value
                                           == "true");
        }
        updateActionCheckboxes(actionList);
    }
}

function onActionListChange() {
    updateActionCheckboxes(this);
}

function updateActionCheckboxes(list) {
    var disabled = (list.value != "email");

    $("emailOrganizer").disabled = disabled;
    $("emailAttendees").disabled = disabled;
}

function onEditorOkClick(event) {
    preventDefault(event);
    if (parseInt($("quantityField").value) > 0) {
        parent$("reminderQuantity").value = parseInt($("quantityField").value);
        parent$("reminderUnit").value = $("unitsList").value;
        parent$("reminderRelation").value = $("relationsList").value;
        parent$("reminderReference").value = $("referencesList").value;

        var actionList = $("actionList");
        var action;
        if (actionList) {
            action = $("actionList").value;
            parent$("reminderEmailOrganizer").value = ($("emailOrganizer").checked
                                                       ? "true"
                                                       : "false");

            parent$("reminderEmailAttendees").value = ($("emailAttendees").checked
                                                       ? "true"
                                                       : "false");
        }
        else {
            action = "display";
        }
        parent$("reminderAction").value = action;
        window.close();
    }
    else
        alert("heu");
}

function onEditorCancelClick(event) {
    preventDefault(event);
    window.close();
}

function onRecurrenceLoadHandler() {
    initializeFormValues();
    initializeWindowButtons();
}

document.observe("dom:loaded", onRecurrenceLoadHandler);
