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
    element.appendChild (textField);
    textField.addInterface (SOGoAutoCompletionInterface);
    textField.focus ();
    textField.select ();
    textField.excludeLists = 1;
    textField.menu = $("contactsMenu");
    textField.endEditable = endEditable;
    textField.addAnother = onReferenceAdd;
    textField.baseUrl = window.location.href + "/../../contactSearch?search=";
}

function endEditable (event, element) {
    var card;
    var name;
    var mail;

    if (element) {
      card = element.readAttribut("card");
      mail = element.readAttribute("mail");
      name = element.readAttribute("name");
    }
    else {
      if ($(this).tagName == "INPUT") {
          element = this.ancestors ().first ();
          card = this.readAttribute ("card");
          name = this.readAttribute ("name");
          mail = this.readAttribute ("mail");
      }
      else {
          element = this;
          card = element.childElements ().first ().readAttribute ("card");
          mail = element.childElements ().first ().readAttribute ("mail");
          name = element.childElements ().first ().readAttribute ("name");
      }
    }
    element.writeAttribute ("card", card);
    element.writeAttribute ("name", name);
    element.writeAttribute ("mail", mail);

    var tmp = "";
    if (card) {
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
            endEditable (null, $(r[i]));
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
