/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function onUpdateACL(event) {
    var uid = $('uid').value;
    if (uid == '<default>' || uid == 'anonymous') {
        var selects = $$('#userRightsForm select');
        var enabled = false;
        for (var i = 0; i < selects.length; i++) {
            if (selects[i].value != 'None') {
                enabled = true;
                break;
            }
        }
        if (!enabled) {
            var inputs = $$('#userRightsForm input[type="checkbox"]');
            for (var i = 0; i < inputs.length; i++) {
                if (inputs[i].checked) {
                    enabled = true;
                    break;
                }
            }
        }
        if (enabled) {
            if (uid == '<default>')
                showConfirmDialog(_("Warning"),
                                  _("Any user with an account on this system will be able to access your calendar \"%{0}\". Are you certain you trust them all?").formatted($("folderName").allTextContent()),
                                  onUpdateACLConfirm, onUpdateACLCancel,
                                  "Give Access", "Keep Private");
            else
                showConfirmDialog(_("Warning"),
                                  _("Potentially anyone on the Internet will be able to access your calendar \"%{0}\", even if they do not have an account on this system. Is this information suitable for the public Internet?").formatted($("folderName").allTextContent()),
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
    var options = $$('#userRightsForm option');
    for (var i = 0; i < options.length; i++)
        options[i].selected = (options[i].value == 'None');
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
