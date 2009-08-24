function validateListEditor () {
    serializeReferences ();
    return true;
}

function makeEditable (element) {
    element.addClassName ("editing");
    element.removeClassName ("referenceListCell");
    var tmp = element.innerHTML;
    element.innerHTML = "";
    var textField = new Element ("input", {"type": "text", 
                                           "width": "90%"});
    textField.style.width = "90%";
    textField.value = tmp.trim ();
    textField.value = textField.value.replace (/&lt;/, "<");
    textField.value = textField.value.replace (/&gt;/, ">");
    textField.observe ("keydown", interceptEnter);
    element.appendChild (textField);
    textField.focus ();
    textField.select ();
}

function interceptEnter (e) {
    if (e.keyCode == Event.KEY_RETURN) {
        endAllEditables (null);
        preventDefault (e);
        return false;
    }
    else {
        onContactKeydown(e);
    }
}

function endEditable (element) {
    var tmp = "";
    if (element.readAttribute ("card")) {
        var tmp = element.childElements ().first ().value;
        tmp = tmp.replace (/</, "&lt;");
        tmp = tmp.replace (/>/, "&gt;");
        element.innerHTML = tmp;
        element.removeClassName ("editing");
        element.addClassName ("referenceListCell");
    }
    else {
        element.ancestors ().first ().remove ();
    }
}

function endAllEditables (e) {
    var r = $$("TABLE#referenceList tbody tr td");
    for (var i=0; i<r.length; i++) {
        if (r[i] != this && r[i].hasClassName ("editing"))
            endEditable ($(r[i]));
    }
}

function onNameEdit (e) {
    endAllEditables ();
    if (!this.hasClassName ("editing")) {
        makeEditable (this);
    }
}

function onReferenceAdd (e) {
    var row = new Element ("tr");
    var nametd = new Element ("td").update ("");

    row.addClassName ("referenceListRow");
    nametd.addClassName ("referenceListCell");

    row.appendChild (nametd);
    $("referenceList").tBodies[0].appendChild (row);
    makeEditable (nametd);

    resetTableActions ();
}

function onReferenceDelete (e) {
    var list = $('referenceList').down("TBODY");;
    var rows = list.getSelectedNodes();
    var count = rows.length;

    for (var i=0; i < count; i++) {
        rows[i].remove ();
    }
}

function serializeReferences (e) {
    var r = $$("TABLE#referenceList tbody tr");
    var cards = "{";

    for (var i = 0; i < r.length; i++) {
        var td = r[i].childElements ().first ();
        var card = td.readAttribute ("card");
        var name = td.readAttribute ("name");
        var mail = td.readAttribute ("mail");
        cards += "\"" + card + "\" = (\""+name+"\", \""+mail+"\");";
    }
    cards = cards + "}";

    $("referencesValue").value = cards;
}

function resetTableActions () {
    var r = $$("TABLE#referenceList tbody tr");
    for (var i = 0; i < r.length; i++) {
        var row = $(r[i]);
        row.observe("mousedown", onRowClick);
        var td = row.childElements().first ();
        td.observe("mousedown", endAllEditables);
        td.observe("dblclick", onNameEdit);
    }
}

function onEditorCancelClick(event) {
	preventDefault(event);
	window.close();
}

function initListEditor () {
    var table = $("referenceList");
    table.multiselect = true;
    resetTableActions ();
    $("referenceAdd").observe ("click", onReferenceAdd);
    $("referenceDelete").observe ("click", onReferenceDelete);
    $("cancelButton").observe("click", onEditorCancelClick);
}

document.observe("dom:loaded", initListEditor);
