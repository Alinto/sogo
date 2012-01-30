/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function onUpdateACL(event) {
    var uid = $('uid').value;
    if (uid == '<default>' || uid == 'anonymous') {
        var inputs = $$('#userRightsForm input[type="checkbox"]');
        var enabled = false;
        for (var i = 0; i < inputs.length; i++) {
            if (inputs[i].checked) {
                enabled = true;
                break;
            }
        }
        if (enabled) {
            showConfirmDialog(_("Confirmation"), _("Are you sure you want to give rights to " + ((uid == "<default>")?"all authenticated users":"everybody") + "?"),
                              onUpdateACLConfirm, onUpdateACLCancel,
                              "Give Access", "Keep Private");
            return false;
        }
    }

    return onUpdateACLConfirm(event);
}

function onUpdateACLConfirm(event) {
    disposeDialog();

    $('userRightsForm').submit();
    Event.stop(event);

    return false;
}

function onUpdateACLCancel(event) {
    var inputs = $$('#userRightsForm input[type="checkbox"]');
    for (var i = 0; i < inputs.length; i++)
        if (inputs[i].checked)
            inputs[i].checked = false;

    disposeDialog();
}

function onCancelACL(event) {
    window.close();
}

function initACLButtons() {
    $("updateButton").observe("click", onUpdateACL);
    $("cancelButton").observe("click", onCancelACL);
}

document.observe("dom:loaded", initACLButtons);
