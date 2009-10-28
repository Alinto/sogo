/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
function validateListEditor () {
    return serializeReferences();
}

function makeEditable (element) {
    element.addClassName("editing");
    element.removeClassName("referenceListCell");

    var span = element.down("SPAN");
    span.update();

    var textField = element.down("INPUT");
    textField.show();
    textField.focus();
    textField.select();
    
    return true;
}

function endEditable(event, textField) {
    if (!textField)
        textField = this;
 
    var uid = textField.readAttribute("uid");
    var cell = textField.up("TD");
    var textSpan = cell.down("SPAN");
    
    cell.removeClassName("editing");
    cell.addClassName("referenceListCell");
    textField.hide();

    if (uid) {
        var tmp = textField.value;
        tmp = tmp.replace (/</, "&lt;");
        tmp = tmp.replace (/>/, "&gt;");
        textSpan.update(tmp);
    }
    else {
        cell.up("TR").remove();
    }

    if (event)
        Event.stop(event);
    
    return false;
}

function endAllEditables (e) {
    var r = $$("TABLE#referenceList TBODY TR TD");
    for (var i = 0; i < r.length; i++) {
        var element = $(r[i]);
        if (r[i] != this && element.hasClassName("editing"))
            endEditable(null, element.down("INPUT"));
    }
}

function onNameEdit (e) {
    endAllEditables();
    if (!this.hasClassName("editing")) {
        makeEditable (this);
    }
}

function onReferenceAdd (e) {
    var tablebody = $("referenceList").tBodies[0];
    var row = new Element("tr");
    var td = new Element("td");
    var textField = new Element("input");
    var span = new Element("span");

    row.addClassName ("referenceListRow");
    row.observe("mousedown", onRowClick);
    td.addClassName ("referenceListCell");
    td.observe("mousedown", endAllEditables);
    td.observe("dblclick", onNameEdit);
    textField.addInterface(SOGoAutoCompletionInterface);
    textField.addressBook = activeAddressBook;
    textField.excludeLists = true;
    textField.observe("autocompletion:changed", endEditable);

    td.appendChild(textField);
    td.appendChild(span);
    row.appendChild (td);
    tablebody.appendChild(row);
    tablebody.deselectAll();
    row.selectElement();

    makeEditable(td);
}

function onReferenceDelete(e) {
    var list = $('referenceList').down("TBODY");;
    var rows = list.getSelectedNodes();
    var count = rows.length;

    for (var i = 0; i < count; i++) {
        rows[i].remove();
    }
}

function serializeReferences(e) {
    var r = $$("TABLE#referenceList TBODY TR INPUT");
    var cards = new Array();
    for (var i = 0; i < r.length; i++) {
        var uid = $(r[i]).readAttribute("uid");
        if (uid)
            cards.push(uid);
    }
    $("referencesValue").value = cards.join(",");
    return true;
}

function resetTableActions() {
    var r = $$("TABLE#referenceList TBODY TR");
    for (var i = 0; i < r.length; i++) {
        var row = $(r[i]);
        row.observe("mousedown", onRowClick);
        var td = row.down("TD");
        td.observe("mousedown", endAllEditables);
        td.observe("dblclick", onNameEdit);
        var textField = td.down("INPUT");
        textField.addInterface(SOGoAutoCompletionInterface);
        textField.addressBook = activeAddressBook;
        textField.excludeLists = true;
        textField.confirmedValue = textField.value;
        textField.observe("autocompletion:changed", endEditable);
    }
}

function onEditorCancelClick(event) {
    preventDefault(event);
    window.close();
}

function initListEditor() {
    var table = $("referenceList");
    table.multiselect = true;
    resetTableActions();
    $("referenceAdd").observe("click", onReferenceAdd);
    $("referenceDelete").observe("click", onReferenceDelete);
    $("cancelButton").observe("click", onEditorCancelClick);
}

document.observe("dom:loaded", initListEditor);
