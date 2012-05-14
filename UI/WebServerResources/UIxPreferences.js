var isSieveScriptsEnabled = false;
var filters = [];
var mailAccounts = null;
var dialogs = {};

function savePreferences(sender) {
    var sendForm = true;

    var sigList = $("signaturePlacementList");
    if (sigList)
        sigList.disabled = false;

    if ($("calendarCategoriesListWrapper")) {
        serializeCalendarCategories();
    }
    if ($("contactsCategoriesListWrapper")) {
        serializeContactsCategories();
    }

    if ($("dayStartTime")) {
        var start = $("dayStartTime");
        var selectedStart = parseInt(start.options[start.selectedIndex].value);
        var end = $("dayEndTime");
        var selectedEnd = parseInt(end.options[end.selectedIndex].value);
        if (selectedStart >= selectedEnd) {
            showAlertDialog (_("Day start time must be prior to day end time."));
            sendForm = false;
        }
    }

    if ($("enableVacation") && $("enableVacation").checked) {
        if ($("autoReplyText").value.strip().length == 0
            || $("autoReplyEmailAddresses").value.strip().length == 0) {
            showAlertDialog(_("Please specify your message and your email addresses for which you want to enable auto reply."));
            sendForm = false;
        }
	if ($("autoReplyText").value.strip().endsWith('\n.')) {
	  showAlertDialog(_("Your vacation message must not end with a single dot on a line."));
	  sendForm = false;
	}
        if ($("enableVacationEndDate") && $("enableVacationEndDate").checked) {
            var e = $("vacationEndDate_date");
            var endDate = e.calendar.prs_date(e.value);
            var now = new Date();
            if (endDate.getTime() < now.getTime()) {
                showAlertDialog(_("End date of your auto reply must be in the future."));
                sendForm = false;
            }
        }
    }

    if ($("enableForward") && $("enableForward").checked) {
        var addresses = $("forwardAddress").value.split(",");
        for (var i = 0; i < addresses.length && sendForm; i++)
            if (!emailRE.test(addresses[i].strip())) {
                showAlertDialog(_("Please specify an address to which you want to forward your messages."));
                sendForm = false;
            }
    }

    if (isSieveScriptsEnabled) {
        var jsonFilters = prototypeIfyFilters();
        $("sieveFilters").setValue(Object.toJSON(jsonFilters));
    }

    saveMailAccounts();

    if (sendForm)
        $("mainForm").submit();

    return false;
}

function onAdjustTime(event) {
    // unconditionally called from skycalendar.html
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

        if (filter.actions) {
            newFilter.actions = $([]);
            for (var j = 0; j < filter.actions.length; j++) {
                newFilter.actions.push($(filter.actions[j]));
            }
        }
        newFilters.push(newFilter);
    }

    return newFilters;
}

function _setupEvents() {
    var widgets = [ "timezone", "shortDateFormat", "longDateFormat",
                    "timeFormat", "weekStartDay", "dayStartTime", "dayEndTime",
                    "firstWeek", "messageCheck", "sortByThreads",
                    "subscribedFoldersOnly", "language", "defaultCalendar",
                    "enableVacation" ];
    for (var i = 0; i < widgets.length; i++) {
        var widget = $(widgets[i]);
        if (widget) {
            widget.observe("change", onChoiceChanged);
        }
    }


    // We check for non-null elements as replyPlacementList and composeMessagesType
    // might not be present if ModulesConstraints disable those elements
    if ($("replyPlacementList"))
    	$("replyPlacementList").observe("change", onReplyPlacementListChange);

    if ($("composeMessagesType"))
    	$("composeMessagesType").observe("change", onComposeMessagesTypeChange);

    // Note: we also monitor changes to the calendar categories.
    // See functions endEditable and onColorPickerChoice.
    var valueInputs = [ "calendarCategoriesValue", "calendarCategoriesValue" ];
    for (var i = 0; i < valueInputs.length; i++) {
        var valueInput = $(valueInputs[i]);
        if (valueInput)
            valueInput.value = "";
    }
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

    var wrapper = $("calendarCategoriesListWrapper");
    if (wrapper) {
        var table = wrapper.childNodesWithTag("table")[0];
        resetCalendarCategoriesColors(null);
        var r = $$("#calendarCategoriesListWrapper tbody tr");
        for (var i= 0; i < r.length; i++)
            r[i].identify();
        table.multiselect = true;
        resetCalendarTableActions();
        $("calendarCategoryAdd").observe("click", onCalendarCategoryAdd);
        $("calendarCategoryDelete").observe("click", onCalendarCategoryDelete);
    }

    wrapper = $("contactsCategoriesListWrapper");
    if (wrapper) {
        var table = wrapper.childNodesWithTag("table")[0];
        var r = $$("#contactsCategoriesListWrapper tbody tr");
        for (var i= 0; i < r.length; i++)
            r[i].identify();
        table.multiselect = true;
        resetContactsTableActions();
        $("contactsCategoryAdd").observe("click", onContactsCategoryAdd);
        $("contactsCategoryDelete").observe("click", onContactsCategoryDelete);
    }

    // Disable placement (after) if composing in HTML
    var button = $("composeMessagesType");
    if (button) {
        if (button.value == 1) {
            $("replyPlacementList").value = 0;
            $("replyPlacementList").disabled = true;
        }
        onReplyPlacementListChange();
        button.on("change", function(event) {
            if (this.value == 0)
                $("replyPlacementList").disabled = false;
            else {
                $("replyPlacementList").value = 0;
                $("replyPlacementList").disabled = true;
            }
        });
    }

    button = $("addDefaultEmailAddresses");
    if (button)
        button.observe("click", addDefaultEmailAddresses);

    button = $("changePasswordBtn");
    if (button)
        button.observe("click", onChangePasswordClick);

    initSieveFilters();
    initMailAccounts();

    button = $("enableVacationEndDate");
    if (button) {
        assignCalendar('vacationEndDate_date');
        button.on("change", function(event) {
            if (this.checked)
                $("vacationEndDate_date").enable();
            else
                $("vacationEndDate_date").disable();
        });
    }
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
                           { type: "checkbox" },
                           null, activeColumn);
    cb.checked = filter.active;
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
    var cb = activeColumn.childNodesWithTag("input");
    cb[0].checked = filter.active;
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

    return false;
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
    var filter = copyFilter(filters[filterId]);
    return Object.toJSON(filter);
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

    var inputs = $$("#accountInfo input");
    for (var i = 0; i < inputs.length; i++) {
        $(inputs[i]).observe("change", onMailAccountInfoChange);
    }

    inputs = $$("#identityInfo input");
    for (var i = 0; i < inputs.length; i++) {
        $(inputs[i]).observe("change", onMailIdentityInfoChange);
    }
    $("actSignature").observe("click", onMailIdentitySignatureClick);
    displayMailAccount(mailAccounts[0], true);

    inputs = $$("#returnReceiptsInfo input");
    for (var i = 0; i < inputs.length; i++) {
        $(inputs[i]).observe("change", onMailReceiptInfoChange);
    }
    inputs = $$("#returnReceiptsInfo select");
    for (var i = 0; i < inputs.length; i++) {
        $(inputs[i]).observe("change", onMailReceiptActionChange);
    }
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

function onMailReceiptInfoChange(event) {
    if (!this.mailAccount["receipts"]) {
        this.mailAccount["receipts"] = {};
    }
    var keyName = this.name.cssIdToHungarianId();
    this.mailAccount["receipts"][keyName] = this.value;

    var popupIds = [ "receipt-non-recipient-action",
                     "receipt-outside-domain-action",
                     "receipt-any-action" ];
    var receiptActionsDisable = (this.value == "ignore");
    for (var i = 0; i < popupIds.length; i++) {
        var actionPopup = $(popupIds[i]);
        actionPopup.disabled = receiptActionsDisable;
    }
}

function onMailReceiptActionChange(event) {
    if (!this.mailAccount["receipts"]) {
        this.mailAccount["receipts"] = {};
    }
    var keyName = this.name.cssIdToHungarianId();
    this.mailAccount["receipts"][keyName] = this.value;
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
            if (Prototype.Browser.IE)
                // Overwrite some fixes from iefixes.css
                dialog.setStyle({ width: 'auto', marginLeft: 'auto' });

            document.body.appendChild(dialog);
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
        if (typeof(identity["signature"]) != "undefined")
            area.value = identity["signature"];
        else
            area.value = "";


        dialog.show();
        $("bgDialogDiv").show();
        if (CKEDITOR.instances["signature"])
                focusCKEditor();
        else
            area.focus();
        Event.stop(event);
    }
}

function focusCKEditor() {
    if (CKEDITOR.status != 'basic_ready')
        setTimeout("focusCKEditor()", 100);
    else
        // CKEditor reports being ready but it's still not focusable;
        // we wait for a few more milliseconds
        setTimeout("CKEDITOR.instances.signature.focus()", 500);
}

function hideSignature() {
    if (CKEDITOR.status != 'basic_ready')
        setTimeout("hideSignature()", 100);
    else
        // CKEditor reports being ready but it's not;
        // we wait for a few more milliseconds
        setTimeout('disposeDialog("signatureDialog")', 200);
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
    hideSignature();
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
    var inputs = $$("#accountInfo input");
    inputs.each(function (i) { i.disabled = readOnly;
                               i.mailAccount = mailAccount; });

    inputs = $$("#identityInfo input");
    inputs.each(function (i) { i.mailAccount = mailAccount; });
    if (!mailCustomFromEnabled) {
        for (var i = 0; i < 2; i++) {
            inputs[i].disabled = readOnly;
        }
    }

    var form = $("mainForm");

    var encryption = "none";
    var encRadioValues = [ "none", "ssl", "tls" ];
    if (mailAccount["encryption"]) {
        encryption = mailAccount["encryption"];
    }
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
    $("replyTo").value = identity["replyTo"] || "";

    displayAccountSignature(mailAccount);

    var receiptAction = "ignore";
    var receiptActionValues = [ "ignore", "allow" ];
    if (mailAccount["receipts"] &&  mailAccount["receipts"]["receiptAction"]) {
        receiptAction = mailAccount["receipts"]["receiptAction"];
    }
    for (var i = 0; i < receiptActionValues.length; i++) {
        var keyName = "receipt-action-" + receiptActionValues[i];
        var input = $(keyName);
        input.mailAccount = mailAccount;
    }
    form.setRadioValue("receipt-action",
                       receiptActionValues.indexOf(receiptAction));
    var popupIds = [ "receipt-non-recipient-action",
                     "receipt-outside-domain-action",
                     "receipt-any-action" ];
    var receiptActionsDisable = (receiptAction == "ignore");
    for (var i = 0; i < popupIds.length; i++) {
        var actionPopup = $(popupIds[i]);
        actionPopup.disabled = receiptActionsDisable;
        var settingValue = "ignore";
        var settingName = popupIds[i].cssIdToHungarianId();
        if (mailAccount["receipts"] && mailAccount["receipts"][settingName]) {
            settingValue = mailAccount["receipts"][settingName];
        }
        actionPopup.value = settingValue;
        actionPopup.mailAccount = mailAccount;
    }
}

function displayAccountSignature(mailAccount) {
    var actSignature = $("actSignature");
    actSignature.mailAccount = mailAccount;

    var actSignatureValue;
    var identity = (mailAccount["identities"]
                    ? mailAccount["identities"][0]
                    : {} );
    var value = identity["signature"];
    if (value && value.length > 0)
        value = value.stripTags().unescapeHTML().replace(/^[ \n\r]*/, "");
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
    actSignature.update(actSignatureValue);
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

    // Could be null if ModuleConstraints disables email access
    if (editor)
    	editor.parentNode.removeChild(editor);

    compactMailAccounts();
    var mailAccountsJSON = $("mailAccountsJSON");

    if (mailAccountsJSON)
        mailAccountsJSON.value = Object.toJSON(mailAccounts);
}

function compactMailAccounts() {

    if (!mailAccounts)
        return;

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

/* calendar categories */
function resetCalendarTableActions() {
    var r = $$("#calendarCategoriesListWrapper tbody tr");
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
    var r = $$("#calendarCategoriesListWrapper div.colorEditing");
    for (var i=0; i<r.length; i++)
        r[i].removeClassName("colorEditing");

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
    var div = $$("#calendarCategoriesListWrapper div.colorEditing").first ();
    //  div.removeClassName ("colorEditing");
    div.showColor = newColor;
    div.style.background = newColor;
    if (parseInt($("hasChanged").value) == 0) {
        var hasChanged = $("hasChanged");
        hasChanged.value = "1";
    }
}

function onCalendarCategoryAdd (e) {
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
    $("calendarCategoriesListWrapper").childNodesWithTag("table")[0].tBodies[0].appendChild (row);

    resetCalendarTableActions ();
    nametd.editionController.startEditing();
}

function onCalendarCategoryDelete (e) {
    var list = $('calendarCategoriesListWrapper').down("TABLE").down("TBODY");
    var rows = list.getSelectedNodes();
    var count = rows.length;

    for (var i=0; i < count; i++) {
        rows[i].editionController = null;
        rows[i].remove ();
    }
}

function serializeCalendarCategories() {
    var r = $$("#calendarCategoriesListWrapper TBODY TR");

    var values = [];
    for (var i = 0; i < r.length; i++) {
        var tds = r[i].childElements ();
        var name  = $(tds.first ()).innerHTML;
        var color = $(tds.last ().childElements ().first ()).showColor;
        values.push("\"" + name + "\": \"" + color + "\"");
    }

    $("calendarCategoriesValue").value = "{ " + values.join(",\n") + "}";
}

function resetCalendarCategoriesColors (e) {
    var divs = $$("#calendarCategoriesListWrapper DIV.colorBox");
    for (var i = 0; i < divs.length; i++) {
        var d = divs[i];
        var color = d.innerHTML;
        d.showColor = color;
        if (color != "undefined")
            d.setStyle({ backgroundColor: color });
        d.update("&nbsp;");
    }
}

/* /calendar categories */

/* contacts categories */
function resetContactsTableActions() {
    var r = $$("#contactsCategoriesListWrapper tbody tr");
    for (var i = 0; i < r.length; i++) {
        var row = $(r[i]);
        row.observe("mousedown", onRowClick);
        var tds = row.childElements();
        var editionCtlr = new RowEditionController();
        editionCtlr.attachToRowElement(tds[0]);
    }
}

function onContactsCategoryAdd(e) {
    var row = new Element("tr");
    row.identify();
    row.addClassName("categoryListRow");

    var nametd = new Element("td").update("");
    nametd.addClassName("categoryListCell");
    row.appendChild(nametd);
    var list = $('contactsCategoriesListWrapper').down("TABLE").down("TBODY");
    list.appendChild(row);

    resetContactsTableActions ();
    nametd.editionController.startEditing();
}

function onContactsCategoryDelete (e) {
    var list = $('contactsCategoriesListWrapper').down("TABLE").down("TBODY");
    var rows = list.getSelectedNodes();
    var count = rows.length;

    for (var i = 0; i < count; i++) {
        rows[i].editionController = null;
        rows[i].remove();
    }
}

function serializeContactsCategories() {
    var values = [];

    var tds = $$("#contactsCategoriesListWrapper TBODY TD");

    for (var i = 0; i < tds.length; i++) {
        var td = $(tds[i]);
        values.push(td.allTextContent());
    }

    $("contactsCategoriesValue").value = Object.toJSON(values);
}

/* / contact categories */


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
