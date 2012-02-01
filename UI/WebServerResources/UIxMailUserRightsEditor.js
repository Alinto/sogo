/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function onUpdateACL(event) {
    if ($('uid').value == 'anyone') {
        var inputs = $$('#userRightsForm input[type="checkbox"]');
        var enabled = false;
        for (var i = 0; i < inputs.length; i++) {
            if (inputs[i].checked) {
                enabled = true;
                break;
            }
        }
        if (enabled) {
            showConfirmDialog(_("Warning"), _("Any user with an account on this system will be able to access your mailbox \"%{0}\". Are you certain you trust them all?").formatted($("folderName").allTextContent()),
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
