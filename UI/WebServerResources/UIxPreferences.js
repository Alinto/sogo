var isSieveScriptsEnabled = false;
var filters = [];
var mailAccounts = null;
var dialogs = {};

function savePreferences(sender) {
    var sendForm = true;

    var sigList = $("signaturePlacementList");
    if (sigList)
        sigList.disabled = false;

    if ($("categoriesList")) {
        serializeCategories();
    }

    if ($("dayStartTime")) {
        var start = $("dayStartTime");
        var selectedStart = parseInt(start.options[start.selectedIndex].value);
        var end = $("dayEndTime");
        var selectedEnd = parseInt(end.options[end.selectedIndex].value);
        if (selectedStart >= selectedEnd) {
            alert (_("Day start time must be prior to day end time."));
            sendForm = false;
        }
    }

    if ($("enableVacation") && $("enableVacation").checked) {
        if ($("autoReplyText").value.strip().length == 0
            || $("autoReplyEmailAddresses").value.strip().length == 0) {
            alert(_("Please specify your message and your email addresses for which you want to enable auto reply."));
            sendForm = false;
        }
    }

    if ($("enableForward") && $("enableForward").checked) {
        if (!emailRE.test($("forwardAddress").value)) {
            alert(_("Please specify an address to which you want to forward your messages."));
            sendForm = false;
        }
    }

    if (isSieveScriptsEnabled) {
        var jsonFilters = prototypeIfyFilters();
        $("sieveFilters").setValue(jsonFilters.toJSON());
    }

    saveMailAccounts();

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

function _setupEvents() {
    var widgets = [ "timezone", "shortDateFormat", "longDateFormat",
                    "timeFormat", "weekStartDay", "dayStartTime", "dayEndTime",
                    "firstWeek", "messageCheck", "subscribedFoldersOnly",
                    "language" ];
    for (var i = 0; i < widgets.length; i++) {
        var widget = $(widgets[i]);
        if (widget) {
            widget.observe("change", onChoiceChanged);
        }
    }

    // Note: we also monitor changes to the calendar categories.
    // See functions endEditable and onColorPickerChoice.

    $("replyPlacementList").observe ("change", onReplyPlacementListChange);
    $("composeMessagesType").observe ("change", onComposeMessagesTypeChange);

    var categoriesValue = $("categoriesValue");
    if (categoriesValue)
        categoriesValue.value = "";
}

function onChoiceChanged(event) {
    var hasChanged = $("hasChanged");
    hasChanged.value = "1";
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
    _setupEvents();
    if (typeof (initAdditionalPreferences) != "undefined")
        initAdditionalPreferences();

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

    button = $("changePasswordBtn");
    if (button)
        button.observe("click", onChangePasswordClick);

    initSieveFilters();
    initMailAccounts();
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
    cb.observe("click", bound);
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

function setupMailboxesFromJSON(jsonResponse) {
    var responseMboxes = jsonResponse.mailboxes;
    userMailboxes = $([]);
    for (var i = 0; i < responseMboxes.length; i++) {
        var name = responseMboxes[i].path.substr(1);
        userMailboxes.push(name);
    }
}

function updateFilterFromEditor(filterId, filterJSON) {
    var filter = filterJSON.evalJSON();
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

/* mail accounts */
function initMailAccounts() {
    var mailAccountsJSON = $("mailAccountsJSON");
    mailAccounts = mailAccountsJSON.value.evalJSON();

    var mailAccountsList = $("mailAccountsList");
    if (mailAccountsList) {
        var li = createMailAccountLI(mailAccounts[0], true);
        mailAccountsList.appendChild(li);
        for (var i = 1; i < mailAccounts.length; i++) {
            li = createMailAccountLI(mailAccounts[i]);
            mailAccountsList.appendChild(li);
        }
        var lis = mailAccountsList.childNodesWithTag("li");
        lis[0].readOnly = true;
        lis[0].selectElement();

        var button = $("mailAccountAdd");
        if (button) {
            button.observe("click", onMailAccountAdd);
        }
        button = $("mailAccountDelete");
        if (button) {
            button.observe("click", onMailAccountDelete);
        }
    }

    var info = $("accountInfo");
    var inputs = info.getElementsByTagName("input");
    for (var i = 0; i < inputs.length; i++) {
        $(inputs[i]).observe("change", onMailAccountInfoChange);
    }

    info = $("identityInfo");
    inputs = info.getElementsByTagName("input");
    for (var i = 0; i < inputs.length; i++) {
        $(inputs[i]).observe("change", onMailIdentityInfoChange);
    }
    $("actSignature").observe("click", onMailIdentitySignatureClick);
    displayMailAccount(mailAccounts[0], true);
}

function onMailAccountInfoChange(event) {
    this.mailAccount[this.name] = this.value;
    var hasChanged = $("hasChanged");
    hasChanged.value = "1";
}

function onMailIdentityInfoChange(event) {
    if (!this.mailAccount["identities"]) {
        this.mailAccount["identities"] = [{}];
    }
    var identity = this.mailAccount["identities"][0];
    identity[this.name] = this.value;
    var hasChanged = $("hasChanged");
    hasChanged.value = "1";
}

function onMailIdentitySignatureClick(event) {
    if (!this.readOnly) {
        var dialogId = "signatureDialog";
        var dialog = dialogs[dialogId];
        if (!dialog) {
            var label = _("Please enter your signature below:");
            var fields = createElement("p");
            fields.appendChild(createElement("textarea", "signature"));
            fields.appendChild(createElement("br"));
            fields.appendChild(createButton("okBtn", _("OK"),
                                            onMailIdentitySignatureOK));
            fields.appendChild(createButton("cancelBtn", _("Cancel"),
                                            disposeDialog.bind(document.body, dialogId)));
            var dialog = createDialog(dialogId,
                                      _("Signature"),
                                      label,
                                      fields,
                                      "none");
            document.body.appendChild(dialog);
            dialog.show();
            dialogs[dialogId] = dialog;

            if ($("composeMessagesType").value != 0) {
                CKEDITOR.replace('signature',
                                 { height: "70px",
                                   toolbar: [['Bold', 'Italic', '-', 'Link',
                                              'Font','FontSize','-','TextColor',
                                              'BGColor']
                                            ],
                                   language: localeCode,
                                   scayt_sLang: localeCode });
            }
        }
        dialog.mailAccount = this.mailAccount;
        if (!this.mailAccount["identities"]) {
            this.mailAccount["identities"] = [{}];
        }
        var identity = this.mailAccount["identities"][0];
        var area = $("signature");
        area.value = identity["signature"];
        dialog.show();
        $("bgDialogDiv").show();
        if (!CKEDITOR.instances["signature"])
            area.focus();
        event.stop();
    }
}

function onMailIdentitySignatureOK(event) {
    var dialog = $("signatureDialog");
    var mailAccount = dialog.mailAccount;
    if (!mailAccount["identities"]) {
        mailAccount["identities"] = [{}];
    }
    var identity = mailAccount["identities"][0];

    var content = (CKEDITOR.instances["signature"]
                   ? CKEDITOR.instances["signature"].getData()
                   : $("signature").value);
    identity["signature"] = content;
    displayAccountSignature(mailAccount);
    dialog.hide();
    $("bgDialogDiv").hide();
    dialog.mailAccount = null;
    var hasChanged = $("hasChanged");
    hasChanged.value = "1";
}

function createMailAccountLI(mailAccount, readOnly) {
    var li = createElement("li");
    li.appendChild(document.createTextNode(mailAccount["name"]));
    li.observe("click", onMailAccountEntryClick);
    li.observe("mousedown", onRowClick);
    if (readOnly) {
        li.addClassName("readonly");
    }
    else {
        var editionCtlr = new RowEditionController();
        editionCtlr.attachToRowElement(li);
        editionCtlr.notifyNewValueCallback = function(ignore, newValue) {
            mailAccount["name"] = newValue;
        };
        li.editionController = editionCtlr;
    }
    li.mailAccount = mailAccount;

    return li;
}

function onMailAccountEntryClick(event) {
    displayMailAccount(this.mailAccount, this.readOnly);
}

function displayMailAccount(mailAccount, readOnly) {
    var editor = $("mailAccountEditor");
    var inputs = editor.getElementsByTagName("input");
    for (var i = 0; i < inputs.length; i++) {
        inputs[i].disabled = readOnly;
        inputs[i].mailAccount = mailAccount;
    }

    var encryption = "none";

    var encRadioValues = [ "none", "ssl", "tls" ];
    if (mailAccount["encryption"]) {
        encryption = mailAccount["encryption"];
    }
    var form = $("mainForm");
    form.setRadioValue("encryption", encRadioValues.indexOf(encryption));

    var port;
    if (mailAccount["port"]) {
        port = mailAccount["port"];
    }
    else {
        if (encryption == "ssl") {
            port = 993;
        }
        else {
            port = 143;
        }
    }
    $("port").value = port;

    $("serverName").value = mailAccount["serverName"];
    $("userName").value = mailAccount["userName"];
    $("password").value = mailAccount["password"];

    var identity = (mailAccount["identities"]
                    ? mailAccount["identities"][0]
                    : {} );
    $("fullName").value = identity["fullName"] || "";
    $("email").value = identity["email"] || "";

    displayAccountSignature(mailAccount);
}

function displayAccountSignature(mailAccount) {
    var actSignature = $("actSignature");
    actSignature.mailAccount = mailAccount;

    var actSignatureValue;
    var identity = (mailAccount["identities"]
                    ? mailAccount["identities"][0]
                    : {} );
    var value = identity["signature"];
    if (value && value.length > 0) {
        if (value.length < 30) {
            actSignatureValue = value;
        }
        else {
            actSignatureValue = value.substr(0, 30) + "...";
        }
    }
    else {
        actSignatureValue = _("(Click to create)");
    }
    while (actSignature.firstChild) {
        actSignature.removeChild(actSignature.firstChild);
    }
    actSignature.appendChild(document.createTextNode(actSignatureValue));
}

function createMailAccount() {
    var firstIdentity = mailAccounts[0]["identities"][0];
    var newIdentity = {};
    for (var k in firstIdentity) {
        newIdentity[k] = firstIdentity[k];
    }
    delete newIdentity["isDefault"];

    var newMailAccount = { name: _("New Mail Account"),
                           serverName: "mailserver",
                           userName: UserLogin,
                           password: "",
                           identities: [ newIdentity ] };

    return newMailAccount;
}

function onMailAccountAdd(event) {
    var newMailAccount = createMailAccount();
    mailAccounts.push(newMailAccount);
    var li = createMailAccountLI(newMailAccount);
    var mailAccountsList = $("mailAccountsList");
    mailAccountsList.appendChild(li);
    var selection = mailAccountsList.getSelectedNodes();
    for (var i = 0; i < selection.length; i++) {
        selection[i].deselect();
    }
    displayMailAccount(newMailAccount, false);
    li.selectElement();
    li.editionController.startEditing();

    var hasChanged = $("hasChanged");
    hasChanged.value = "1";

    event.stop();
}

function onMailAccountDelete(event) {
    var mailAccountsList = $("mailAccountsList");
    var selection = mailAccountsList.getSelectedNodes();
    if (selection.length > 0) {
        var li = selection[0];
        if (!li.readOnly) {
            li.deselect();
            li.editionController = null;
            var next = li.next();
            if (!next) {
                next = li.previous();
            }
            mailAccountsList.removeChild(li);
            var index = mailAccounts.indexOf(li.mailAccount);
            mailAccounts.splice(index, 1);
            next.selectElement();
            displayMailAccount(next.mailAccount, next.readOnly);

            var hasChanged = $("hasChanged");
            hasChanged.value = "1";
        }
    }
    event.stop();
}

function saveMailAccounts() {
    /* This removal enables us to avoid a few warning from SOPE for the inputs
     that were created dynamically. */
    var editor = $("mailAccountEditor");
    editor.parentNode.removeChild(editor);

    compactMailAccounts();
    var mailAccountsJSON = $("mailAccountsJSON");
    mailAccountsJSON.value = mailAccounts.toJSON();
}

function compactMailAccounts() {
    for (var i = 1; i < mailAccounts.length; i++) {
        var account = mailAccounts[i];
        var encryption = account["encryption"];
        if (encryption) {
            if (encryption == "none") {
                delete account["encryption"];
            }
        }
        else {
            encryption = "none";
        }
        var port = account["port"];
        if (port) {
            if ((encryption == "ssl" && port == 993)
                || port == 143) {
                delete account["port"];
            }
        }
    }
}

/* categories */
function resetTableActions() {
    var r = $$("TABLE#categoriesList tbody tr");
    for (var i = 0; i < r.length; i++) {
        var row = $(r[i]);
        row.observe("mousedown", onRowClick);
        var tds = row.childElements();
        var editionCtlr = new RowEditionController();
        editionCtlr.attachToRowElement(tds[0]);
        tds[1].childElements()[0].observe("dblclick", onColorEdit);
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
    if (parseInt($("hasChanged").value) == 0) {
        var hasChanged = $("hasChanged");
        hasChanged.value = "1";
    }
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

    resetTableActions ();
    nametd.editionController.startEditing();
}

function onCategoryDelete (e) {
    var list = $('categoriesList').down("TBODY");;
    var rows = list.getSelectedNodes();
    var count = rows.length;

    for (var i=0; i < count; i++) {
        rows[i].editionController = null;
        rows[i].remove ();
    }
}

function serializeCategories() {
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

    if (this.value == 0) /* text */ {
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
        if ($("signature") && !CKEDITOR.instances["signature"]) {
            CKEDITOR.replace('signature',
                             {
                                 height: "70px",
                                 toolbar: [['Bold', 'Italic', '-', 'Link',
                                            'Font','FontSize','-','TextColor',
                                            'BGColor']
                                          ],
                                 language: localeCode,
                                 scayt_sLang: localeCode
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
