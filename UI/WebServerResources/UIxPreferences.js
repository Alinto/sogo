/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function savePreferences(sender) {
    var sigList = $("signaturePlacementList");
    if (sigList)
        sigList.disabled=false;

    serializeCategories (null);

    $("mainForm").submit();
    
    return false;
}

function _setupEvents(enable) {
    var widgets = [ "timezone", "shortDateFormat", "longDateFormat",
                    "timeFormat", "weekStartDay", "dayStartTime", "dayEndTime",
                    "firstWeek", "messageCheck", "subscribedFoldersOnly" ];
    for (var i = 0; i < widgets.length; i++) {
        var widget = $(widgets[i]);
        if (widget) {
            if (enable)
                widget.observe("change", onChoiceChanged);
            else
                widget.stopObserving("change", onChoiceChanged);
        }
    }

    $("replyPlacementList").observe ("change", onReplyPlacementListChange);
    $("composeMessagesType").observe ("change", onComposeMessagesTypeChange);
    $("categoriesValue").value = "";
}

function onChoiceChanged(event) {
    var hasChanged = $("hasChanged");
    hasChanged.value = "1";

    _setupEvents(false);
}

function initPreferences() {
    _setupEvents(true);
    if (typeof (initAdditionalPreferences) != "undefined")
        initAdditionalPreferences();

    if ($("signature")) {
        onComposeMessagesTypeChange ();
    }

    resetCategoriesColors (null);
    var table = $("categoriesList");
    var r = $$("TABLE#categoriesList tbody tr");
    for (var i=0; i<r.length; i++)
        r[i].identify ();
    table.multiselect = true;
    resetTableActions ();
    $("categoryAdd").observe ("click", onCategoryAdd);
    $("categoryDelete").observe ("click", onCategoryDelete);
}

function resetTableActions() {
    var r = $$("TABLE#categoriesList tbody tr");
    for (var i = 0; i < r.length; i++) {
        var row = $(r[i]);
        row.observe("mousedown", onRowClick);
        var tds = row.childElements();
        tds[0].observe("mousedown", endAllEditables);
        tds[0].observe("dblclick", onNameEdit);
        tds[1].observe("mousedown", endAllEditables);
        tds[1].childElements()[0].observe ("dblclick", onColorEdit);
    }
}

function makeEditable (element) {
    element.addClassName ("editing");
    element.removeClassName ("categoryListCell");
    var tmp = element.innerHTML;
    element.innerHTML = "";
    var textField = new Element ("input", {"type": "text", 
                                           "width": "100%"});
    textField.value = tmp;
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
}

function endEditable (element) {
    var tmp = element.childElements ().first ().value;
    element.innerHTML = tmp;
    element.removeClassName ("editing");
    element.addClassName ("categoryListCell");
}

function endAllEditables (e) {
    var r = $$("TABLE#categoriesList tbody tr td");
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

function onColorEdit (e) {
    var r = $$("TABLE#categoriesList tbody tr td div.colorEditing");
    for (var i=0; i<r.length; i++)
        r[i].removeClassName ("colorEditing");

    this.addClassName ("colorEditing");
    var cPicker = window.open(ApplicationBaseURL + "../" + UserLogin 
                              + "/Calendar/colorPicker", "colorPicker",
                              "width=250,height=200,resizable=0,scrollbars=0"
                              + "toolbar=0,location=0,directories=0,status=0,"
                              + "menubar=0,copyhistory=0", "test"
                              );
    cPicker.focus();

    preventDefault(e);
}

function onColorPickerChoice (newColor) {
    var div = $$("TABLE#categoriesList tbody tr td div.colorEditing").first ();
    //  div.removeClassName ("colorEditing");
    div.showColor = newColor;
    div.style.background = newColor;
}


function onCategoryAdd (e) {
    var row = new Element ("tr");
    var nametd = new Element ("td").update ("");
    var colortd = new Element ("td");
    var colordiv = new Element ("div", {"class": "colorBox"});

    row.identify ();
    row.addClassName ("categoryListRow");

    nametd.addClassName ("categoryListCell");

    colortd.addClassName ("categoryListCell");
    colordiv.innerHTML = "&nbsp;";
    colordiv.showColor = "#F0F0F0";
    colordiv.style.background = colordiv.showColor;

    colortd.appendChild (colordiv);
    row.appendChild (nametd);
    row.appendChild (colortd);
    $("categoriesList").tBodies[0].appendChild (row);
    makeEditable (nametd);

    resetTableActions ();
}

function onCategoryDelete (e) {
    var list = $('categoriesList').down("TBODY");;
    var rows = list.getSelectedNodes();
    var count = rows.length;

    for (var i=0; i < count; i++) {
        rows[i].remove ();
    }

}

function serializeCategories (e) {
    var r = $$("TABLE#categoriesList tbody tr");
    var names = "(";
    var colors = "(";

    for (var i = 0; i < r.length; i++) {
        var tds = r[i].childElements ();
        var name  = $(tds.first ()).innerHTML;
        var color = $(tds.last ().childElements ().first ()).showColor;

        names += "\"" + name + "\", ";
        colors += "\"" + color + "\", ";
    }
    names = names.substr (0, names.length - 1) + ")";
    colors = colors.substr (0, colors.length - 1) + ")";

    $("categoriesValue").value = "(" + names + ", " + colors + ")";
}


function resetCategoriesColors (e) {
    var divs = $$("TABLE#categoriesList DIV.colorBox");

    for (var i = 0; i < divs.length; i++) {
        var d = divs[i];
        var color = d.innerHTML;
        d.showColor = color;
        if (color != "undefined")
            d.setStyle({ backgroundColor: color });
        d.update("&nbsp;");
    }
}

function onReplyPlacementListChange() {
    // above = 0
    if ($("replyPlacementList").value == 0) {
        $("signaturePlacementList").disabled=false;
    }
    else {
        $("signaturePlacementList").value=1;
        $("signaturePlacementList").disabled=true;
    }
}

function onComposeMessagesTypeChange(event) {
    var textArea = $('signature');
    
    if (event) {
        // Due to a limitation of CKEDITOR, we reload the page when the user
        // changes the composition mode to avoid Javascript errors.
        var saveAndReload = confirm(labels["composeMessageChanged"]);
        if (saveAndReload)
            return savePreferences();
        else {
            // Restore previous value of composeMessagesType
             $("composeMessagesType").stopObserving("change", onComposeMessagesTypeChange);
            $("composeMessagesType").value = ((Event.element(event).value == 1)?"0":"1");
            Event.element(event).blur();
            $("composeMessagesType").observe("change", onComposeMessagesTypeChange);
            return false;
        }
    }

    if ($("composeMessagesType").value == 1) {
        // HTML mode
        CKEDITOR.replace('signature',
                         {
                           height: "290px",
                           toolbar :
                             [['Bold', 'Italic', '-', 'Link', 
                               'Font','FontSize','-','TextColor',
                               'BGColor']
                              ] 
                          }
                         );
    }
}

document.observe("dom:loaded", initPreferences);
