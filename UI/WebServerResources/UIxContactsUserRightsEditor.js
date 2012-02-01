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
            if (uid == '<default>')
                showConfirmDialog(_("Warning"),
                                  _("Any user with an account on this system will be able to access your address book \"%{0}\". Are you certain you trust them all?").formatted($("folderName").allTextContent()),
                                  onUpdateACLConfirm, onUpdateACLCancel,
                                  "Give Access", "Keep Private");
            else
                showConfirmDialog(_("Warning"),
                                  _("Potentially anyone on the Internet will be able to access your address book \"%{0}\", even if they do not have an account on this system. Is this information suitable for the public Internet?").formatted($("folderName").allTextContent()),
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
