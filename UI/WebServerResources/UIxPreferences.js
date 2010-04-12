/* -*- Mode: java; tab-width: 2; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var isSieveScriptsEnabled = false;
var filters = [];

function savePreferences(sender) {
    var sendForm = true;

    var sigList = $("signaturePlacementList");
    if (sigList)
        sigList.disabled = false;

    if ($("categoriesList")) {
        serializeCategories(null);
    }

    if ($("dayStartTime")) {
        var start = $("dayStartTime");
        var selectedStart = parseInt(start.options[start.selectedIndex].value);
        var end = $("dayEndTime");
        var selectedEnd = parseInt(end.options[end.selectedIndex].value);
        if (selectedStart >= selectedEnd) {
            alert (getLabel ("Day start time must be prior to day end time."));
            sendForm = false;
        }
    }

    if ($("enableVacation") && $("enableVacation").checked) {
        if ($("autoReplyText").value.strip().length == 0
            || $("autoReplyEmailAddresses").value.strip().length == 0) {
            alert(getLabel("Please specify your message and your email addresses for which you want to enable auto reply."));
            sendForm = false;
        }
    }

    if ($("enableForward") && $("enableForward").checked) {
        if ($("forwardAddress").value.strip().length == 0) {
            alert(getLabel("Please specify an address to which you want to forward your messages."));
            sendForm = false;
        }
    }

    if (isSieveScriptsEnabled) {
        var jsonFilters = prototypeIfyFilters();
        $("sieveFilters").setValue(jsonFilters.toJSON());
    }

    if (sendForm)
        $("mainForm").submit();

    return false;
}

function prototypeIfyFilters() {
    var newFilters = $([]);
    for (var i = 0; i < filters.length; i++) {
        var filter = filters[i];
        var newFilter = $({});
        newFilter.name = filter.name;
        newFilter.match = filter.match;
        newFilter.active = filter.active;

        if (filter.rules) {
            newFilter.rules = $([]);
            for (var j = 0; j < filter.rules.length; j++) {
                newFilter.rules.push($(filter.rules[j]));
            }
        }

        newFilter.actions = $([]);
        for (var j = 0; j < filter.actions.length; j++) {
            newFilter.actions.push($(filter.actions[j]));
        }
        newFilters.push(newFilter);
    }

    return newFilters;
}

function _setupEvents(enable) {
    var widgets = [ "timezone", "shortDateFormat", "longDateFormat",
                    "timeFormat", "weekStartDay", "dayStartTime", "dayEndTime",
                    "firstWeek", "messageCheck", "subscribedFoldersOnly",
                    "language"];
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

    var categoriesValue = $("categoriesValue");
    if (categoriesValue)
        categoriesValue.value = "";
}

function onChoiceChanged(event) {
    var hasChanged = $("hasChanged");
    hasChanged.value = "1";

    _setupEvents(false);
}

function addDefaultEmailAddresses(event) {
    var defaultAddresses = $("defaultEmailAddresses").value.split(/, */);
    var addresses = $("autoReplyEmailAddresses").value.trim();
    
    if (addresses) addresses = addresses.split(/, */);
    else addresses = new Array();

    defaultAddresses.each(function(adr) {
            for (var i = 0; i < addresses.length; i++)
                if (adr == addresses[i])
                    break;
            if (i == addresses.length)
                addresses.push(adr);
        });
    
    $("autoReplyEmailAddresses").value = addresses.join(", ");

    event.stop();
}

function initPreferences() {
    var tabsContainer = $("preferencesTabs");
    var controller = new SOGoTabsController();
    controller.attachToTabsContainer(tabsContainer);

    var filtersListWrapper = $("filtersListWrapper");
    if (filtersListWrapper) {
        isSieveScriptsEnabled = true;
    }
    _setupEvents(true);
    if (typeof (initAdditionalPreferences) != "undefined")
        initAdditionalPreferences();

    if ($("signature")) {
        onComposeMessagesTypeChange();
    }

    var table = $("categoriesList");
    if (table) {
        resetCategoriesColors(null);
        var r = $$("TABLE#categoriesList tbody tr");
        for (var i= 0; i < r.length; i++)
            r[i].identify();
        table.multiselect = true;
        resetTableActions();
        $("categoryAdd").observe("click", onCategoryAdd);
        $("categoryDelete").observe("click", onCategoryDelete);
    }

    // Disable placement (after) if composing in HTML
    if ($("composeMessagesType")) {
        if ($("composeMessagesType").value == 1) {
            $("replyPlacementList").selectedIndex = 0;
            $("replyPlacementList").disabled = 1;
        }
        onReplyPlacementListChange ();
    }

    var button = $("addDefaultEmailAddresses");
    if (button)
        button.observe("click", addDefaultEmailAddresses);

    var button = $("changePasswordBtn");
    if (button)
        button.observe("click", onChangePasswordClick);

    initSieveFilters();
}

function initSieveFilters() {
    var table = $("filtersList");
    if (table) {
        var filtersValue = $("sieveFilters").getValue();
        if (filtersValue && filtersValue.length) {
            filters = $(filtersValue.evalJSON(false));
            for (var i = 0; i < filters.length; i++) {
                appendSieveFilterRow(table, i, filters[i]);
            }
        }
        $("filterAdd").observe("click", onFilterAdd);
        $("filterDelete").observe("click", onFilterDelete);
        $("filterMoveUp").observe("click", onFilterMoveUp);
        $("filterMoveDown").observe("click", onFilterMoveDown);
    }
}

function appendSieveFilterRow(filterTable, number, filter) {
    var row = createElement("tr");
    row.observe("mousedown", onRowClick);
    row.observe("dblclick", onFilterEdit.bindAsEventListener(row));

    var nameColumn = createElement("td");
    nameColumn.appendChild(document.createTextNode(filter["name"]));
    row.appendChild(nameColumn);

    var activeColumn = createElement("td", null, "activeColumn");
    var cb = createElement("input", null, "checkBox",
                           { checked: filter.active,
                             type: "checkbox" },
                           null, activeColumn);
    var bound = onScriptActiveCheck.bindAsEventListener(cb);
    cb.observe("change", bound);
    row.appendChild(activeColumn);

    filterTable.tBodies[0].appendChild(row);
}

function onScriptActiveCheck(event) {
    var index = this.parentNode.parentNode.rowIndex - 1;
    filters[index].active = this.checked;
}

function updateSieveFilterRow(filterTable, number, filter) {
    var row = $(filterTable.tBodies[0].rows[number]);
    var columns = row.childNodesWithTag("td");
    var nameColumn = columns[0];
    while (nameColumn.firstChild) {
        nameColumn.removeChild(nameColumn.firstChild);
    }
    nameColumn.appendChild(document.createTextNode(filter.name));

    var activeColumn = columns[1];
    while (activeColumn.firstChild) {
        activeColumn.removeChild(activeColumn.firstChild);
    }
    createElement("input", null, "checkBox",
                  { checked: filter.active,
                       type: "checkbox" },
                  null, activeColumn);
}

function _editFilter(filterId) {
    var urlstr = ApplicationBaseURL + "editFilter?filter=" + filterId;
    var win = window.open(urlstr, "sieve_filter_" + filterId,
                          "width=560,height=380,resizable=0");
    if (win)
        win.focus();
}

function onFilterAdd(event) {
    log("onFilterAdd");
    _editFilter("new");
    event.stop();
}

function onFilterDelete(event) {
    var filtersList = $("filtersList").tBodies[0];
    var nodes = filtersList.getSelectedNodes();
    if (nodes.length > 0) {
        var deletedFilters = [];
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            deletedFilters.push(node.rowIndex - 1);
        }
        deletedFilters = deletedFilters.sort(function (x,y) { return x-y; });
        var rows = filtersList.rows;
        for (var i = 0; i < deletedFilters.length; i++) {
            var filterNbr = deletedFilters[i];
            filters.splice(filterNbr, 1);
            var row = rows[filterNbr];
            row.parentNode.removeChild(row);
        }
    }
    event.stop();
}

function onFilterMoveUp(event) {
    var filtersList = $("filtersList").tBodies[0];
    var nodes = filtersList.getSelectedNodes();
    if (nodes.length > 0) {
        var node = nodes[0];
        var previous = node.previous();
        if (previous) {
            var count = node.rowIndex - 1;
            node.parentNode.removeChild(node);
            filtersList.insertBefore(node, previous);
            var swapFilter = filters[count];
            filters[count] = filters[count - 1];
            filters[count - 1] = swapFilter;
        }
    }
    event.stop();
}

function onFilterMoveDown(event) {
    var filtersList = $("filtersList").tBodies[0];
    var nodes = filtersList.getSelectedNodes();
    if (nodes.length > 0) {
        var node = nodes[0];
        var next = node.next();
        if (next) {
            var count = node.rowIndex - 1;
            filtersList.removeChild(next);
            filtersList.insertBefore(next, node);
            var swapFilter = filters[count];
            filters[count] = filters[count + 1];
            filters[count + 1] = swapFilter;
        }
    }
    event.stop();
}

function onFilterEdit(event) {
    _editFilter(this.rowIndex - 1);
    event.stop();
}

function copyFilter(originalFilter) {
    var newFilter = {};

    newFilter.name = originalFilter.name;
    newFilter.match = originalFilter.match;
    newFilter.active = originalFilter.active;
    if (originalFilter.rules) {
        newFilter.rules = [];
        for (var i = 0; i < originalFilter.rules.length; i++) {
            newFilter.rules.push(_copyFilterElement(originalFilter.rules[i]));
        }
    }
    newFilter.actions = [];
    for (var i = 0; i < originalFilter.actions.length; i++) {
        newFilter.actions.push(_copyFilterElement(originalFilter.actions[i]));
    }

    return newFilter;
}

function _copyFilterElement(filterElement) { /* element = rule or action */
    var newElement = {};
    for (var k in filterElement) {
        var value = filterElement[k];
        if (typeof(value) == "string" || typeof(value) == "number") {
            newElement[k] = value; 
        }
    }

    return newElement;
}

function getSieveCapabilitiesFromEditor() {
    return sieveCapabilities;
}

function getFilterFromEditor(filterId) {
    return copyFilter(filters[filterId]);
}

function updateFilterFromEditor(filterId, filter) {
    var sanitized = {};
    for (var k in filter) {
        if (!(k == "rules" && filter.match == "allmessages")) {
            sanitized[k] = filter[k];
        }
    }

    var table = $("filtersList");
    if (filterId == "new") {
        var newNumber = filters.length;
        filters.push(sanitized);
        appendSieveFilterRow(table, newNumber, sanitized);
    } else {
        filters[filterId] = sanitized;
        updateSieveFilterRow(table, filterId, sanitized);
    }
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
    var textField = new Element ("input", {"type": "text"});
    textField.value = tmp;
    textField.setStyle({ width: '98%' });
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

    var values = [];
    for (var i = 0; i < r.length; i++) {
        var tds = r[i].childElements ();
        var name  = $(tds.first ()).innerHTML;
        var color = $(tds.last ().childElements ().first ()).showColor;
        values.push("\"" + name + "\": \"" + color + "\"");
    }

    $("categoriesValue").value = "{ " + values.join(",\n") + "}";
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
    // var textArea = $('signature');

    if ($("composeMessagesType").value == 0) /* text */ {
        if (CKEDITOR.instances["signature"]) {
            var content = CKEDITOR.instances["signature"].getData();
            var htmlEditorWidget = $('cke_signature');
            htmlEditorWidget.parentNode.removeChild(htmlEditorWidget);
            delete CKEDITOR.instances["signature"];
            var textArea = $("signature");
            textArea.value = content;
            textArea.style.display = "";
            textArea.style.visibility = "";
        }
    } else {
        if (!CKEDITOR.instances["signature"]) {
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
}

function onChangePasswordClick(event) {
    var field = $("newPasswordField");
    var confirmationField = $("newPasswordConfirmationField");
    if (field && confirmationField) {
        var password = field.value;
        if (password == confirmationField.value) {
            if (password.length > 0) {
                var loginValues = readLoginCookie();
                var policy = new PasswordPolicy(loginValues[0],
                                                loginValues[1]);
                policy.setCallbacks(onPasswordChangeSuccess,
                                    onPasswordChangeFailure);
                policy.changePassword(password);
            }
            else
                SetLogMessage("passwordError", _("Password must not be empty."),
                                    "error");
        }
        else {
            SetLogMessage("passwordError", _("The passwords do not match."
                                  + " Please try again."),
                                "error");
            field.focus();
            field.select();
        }
    }
    event.stop();
}

function onPasswordChangeSuccess(message) {
    SetLogMessage("passwordError", message, "info");
}

function onPasswordChangeFailure(code, message) {
    SetLogMessage("passwordError", message, "error");
}

document.observe("dom:loaded", initPreferences);
