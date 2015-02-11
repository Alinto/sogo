var filters = [];
var mailAccounts = null;
var dialogs = {};

function savePreferences(sender) {
    var sendForm = true;

    var sigList = $("signaturePlacementList");
    if (sigList)
        sigList.disabled = false;

    if ($("appointmentsWhiteListWrapper"))
        serializeAppointmentsWhiteList();

    if ($("calendarCategoriesListWrapper"))
        serializeCalendarCategories();

    if ($("contactsCategoriesListWrapper"))
        serializeContactsCategories();

    if ($("mailLabelsListWrapper"))
        serializeMailLabels();

    if (typeof mailCustomFromEnabled !== "undefined" && !emailRE.test($("email").value)) {
        showAlertDialog(_("Please specify a valid sender address."));
        sendForm = false;
    }

    if ($("replyTo")) {
        var replyTo = $("replyTo").value;
        if (!replyTo.blank() && !emailRE.test(replyTo)) {
            showAlertDialog(_("Please specify a valid reply-to address."));
            sendForm = false;
        }
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
        if ($("autoReplyText").value.strip().length == 0 || $("autoReplyEmailAddresses").value.strip().length == 0) {
            showAlertDialog(_("Please specify your message and your email addresses for which you want to enable auto reply."));
            sendForm = false;
        }

        if ($("autoReplyText").value.strip().endsWith('\n.')) {
            showAlertDialog(_("Your vacation message must not end with a single dot on a line."));
            sendForm = false;
        }

        if ($("enableVacationEndDate") && $("enableVacationEndDate").checked) {
            var e = $("vacationEndDate_date");
            var endDate = e.inputAsDate();
            var now = new Date();
            if (isNaN(endDate.getTime()) || endDate.getTime() < now.getTime()) {
                showAlertDialog(_("End date of your auto reply must be in the future."));
                sendForm = false;
            }
        }
    }

    if ($("enableForward") && $("enableForward").checked) {
        var addresses = $("forwardAddress").value.split(",");

        // We check if all addresses are valid
        for (var i = 0; i < addresses.length && sendForm; i++)
            if (!emailRE.test(addresses[i].strip())) {
                showAlertDialog(_("Please specify an address to which you want to forward your messages."));
                sendForm = false;
            }
       
        // We check if we can only to internal/external addresses.
        var constraints = parseInt(forwardConstraints);
        
        if (constraints > 0) {
            // We first extract the list of 'known domains' to SOGo
            var defaultAddresses = $("defaultEmailAddresses").value.split(/, */);
            var domains = new Array();
            
            defaultAddresses.each(function(adr) {
                var domain = adr.split("@")[1];
                if (domain) {
                    domains.push(domain.toLowerCase());
                }
            });

            // We check if we're allowed or not to forward based on the domain defaults
            for (var i = 0; i < addresses.length && sendForm; i++) {
                var domain = addresses[i].split("@")[1].toLowerCase();
                if (domains.indexOf(domain) < 0 && constraints == 1) {
                    showAlertDialog(_("You are not allowed to forward your messages to an external email address."));
                    sendForm = false;
                }
                else if (domains.indexOf(domain) >= 0 && constraints == 2) {
                    showAlertDialog(_("You are not allowed to forward your messages to an internal email address."));
                    sendForm = false;
                }
            }
        }
    }

    if (typeof sieveCapabilities != "undefined") {
        var jsonFilters = prototypeIfyFilters();
        $("sieveFilters").setValue(Object.toJSON(jsonFilters));
    }

    if (sendForm) {
        saveMailAccounts();

        triggerAjaxRequest($("mainForm").readAttribute("action"), function (http) {
            if (http.readyState == 4) {
                var response = http.responseText.evalJSON(true);
                if (http.status == 503) {
                    showAlertDialog(_(response.textStatus));
                }
                else if (http.status == 200) {
                    if (response.hasChanged == 1) {
                        window.opener.location.reload();
                        window.close();
                    }
                    else {
                        window.close();
                    }
                }
                else {
                    showAlertDialog(_(response.textStatus));
                }
            }
        },
                           null,
                           Form.serialize($("mainForm")), // excludes the file input
                           { "Content-type": "application/x-www-form-urlencoded"}
                          );
    }
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
                    "firstWeek", "refreshViewCheck", "sortByThreads", "displayRemoteInlineImages",
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
        $("replyPlacementList").on("change", onReplyPlacementListChange);

    if ($("composeMessagesType"))
        $("composeMessagesType").on("change", onComposeMessagesTypeChange);

    // Note: we also monitor changes to the calendar categories.
    // See functions endEditable and onColorPickerChoice.
    var valueInputs = [ "calendarCategoriesValue", "calendarCategoriesValue" ];
    for (var i = 0; i < valueInputs.length; i++) {
        var valueInput = $(valueInputs[i]);
        if (valueInput)
            valueInput.value = "";
    }
}

function onBodyClickHandler(event) {
    var target = getTarget(event);
    if (!target.hasClassName('colorBox'))
        $("colorPickerDialog").hide();
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

    // Inner tabs on the mail module tab
    tabsContainer = $('mailOptionsTabs');
    if (tabsContainer) {
        var mailController = new SOGoTabsController();
        mailController.attachToTabsContainer(tabsContainer);
    }

    // Inner tabs on the calendar module tab
    tabsContainer = $('calendarOptionsTabs');
    if (tabsContainer) {
        var mailController = new SOGoTabsController();
        mailController.attachToTabsContainer(tabsContainer);
    }

    _setupEvents();

    // Optional function called when initializing the preferences
    // Typically defined inline in the UIxAdditionalPreferences.wox template
    if (typeof (initAdditionalPreferences) != "undefined")
        initAdditionalPreferences();

    // Color picker
    $('colorPickerDialog').on('click', 'span', onColorPickerChoice);
    $(document.body).on("click", onBodyClickHandler);

    // Calendar whiteList
    var whiteList = $("appointmentsWhiteListWrapper");
    if (whiteList) {
        var whiteListString = $("whiteList").getValue();
        var whiteListObject = {};
        // This condition is a backward compatibility where the strings looks like : "sogo1=John DOE <sogo1@example.com>"
        if (whiteListString.search("=") != -1) {
            var split = whiteListString.split("=");
            whiteListObject[split[0]] = split[1];
            
        }
        else if (whiteListString != "") {
            whiteListObject = JSON.parse(whiteListString);
        }
        var allKeys = Object.keys(whiteListObject);
        var allValues = Object.values(whiteListObject);
        var tablebody = $("appointmentsWhiteListWrapper").childNodesWithTag("table")[0].tBodies[0];
        for (i = 0; i < allKeys.length; i++) {
            var row = new Element("tr");
            var td = new Element("td").update("");
            var textField = new Element("input");
            var span = new Element("span");
            
            row.addClassName("whiteListRow");
            row.observe("mousedown", onRowClick);
            td.addClassName ("whiteListCell");
            td.observe("mousedown", endAllEditables);
            td.observe("dblclick", onNameEdit);
            textField.addInterface(SOGoAutoCompletionInterface);
            textField.SOGoUsersSearch = true;
            textField.observe("autocompletion:changed", endEditable);
            textField.addClassName("textField");
            textField.value = allValues[i];
            textField.setAttribute("uid", allKeys[i]);
            textField.hide();
            span.innerText = allValues[i];
            
            td.appendChild(textField);
            td.appendChild(span);
            row.appendChild (td);
            tablebody.appendChild(row);
            $(tablebody).deselectAll();
            
        }
        
        var table = whiteList.childNodesWithTag("table")[0];
        table.multiselect = true;
        $("appointmentsWhiteListAdd").observe("click", onAppointmentsWhiteListAdd);
        $("appointmentsWhiteListDelete").observe("click", onAppointmentsWhiteListDelete);
    }

    // Calender categories
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
        wrapper.observe("scroll", onBodyClickHandler);
    }

    // Mail labels/tags
    var wrapper = $("mailLabelsListWrapper");
    if (wrapper) {
        var table = wrapper.childNodesWithTag("table")[0];
        resetMailLabelsColors(null);
        var r = $$("#mailLabelsListWrapper tbody tr");
        for (var i= 0; i < r.length; i++)
            r[i].identify();
        table.multiselect = true;
        resetMailTableActions();
        $("mailLabelAdd").observe("click", onMailLabelAdd);
        $("mailLabelDelete").observe("click", onMailLabelDelete);
    }

    // Contact categories
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

    if ($("replyPlacementList"))
        onReplyPlacementListChange();

    var button = $("addDefaultEmailAddresses");
    if (button)
        button.observe("click", addDefaultEmailAddresses);

    button = $("changePasswordBtn");
    if (button)
        button.observe("click", onChangePasswordClick);

    initSieveFilters();

    initMailAccounts();

    button = $("enableVacationEndDate");
    if (button) {
        jQuery("#vacationEndDate_date").closest(".date").datepicker({ autoclose: true, position: 'above', weekStart: $('weekStartDay').getValue() });
        button.on("click", function(event) {
            if (this.checked)
                $("vacationEndDate_date").enable();
            else
                $("vacationEndDate_date").disable();
        });
    }
    onAddOutgoingAddressesCheck();
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
    var urlstr = ApplicationBaseURL + "/editFilter?filter=" + filterId;
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
        deletedFilters = deletedFilters.sort(function(x,y) { return x-y; });
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
        var mbox = { 'displayName': responseMboxes[i].displayName.substr(1),
                     'path': responseMboxes[i].path.substr(1) };
        userMailboxes.push(mbox);
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
    if (mailAccountsJSON) {
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
            fields.appendChild(createButton("okBtn", _("OK"),
                                            onMailIdentitySignatureOK));
            fields.appendChild(createButton("cancelBtn", _("Cancel"),
                                            disposeDialog));
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
                                 { height: "150px",
                                   toolbar: [['Bold', 'Italic', '-', 'Link',
                                              'Font','FontSize','-','TextColor',
                                              'BGColor'], ['Source']
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

        $("bgDialogDiv").show();
        if (Prototype.Browser.IE)
            jQuery('#bgDialogDiv').css('opacity', 0.4);
        jQuery(dialog).fadeIn('fast', function() {
            if (CKEDITOR.instances["signature"])
                focusCKEditor();
            else
                area.focus();
        });
        Event.stop(event);
    }
}

function focusCKEditor() {
    if (CKEDITOR.status != 'loaded')
        setTimeout("focusCKEditor()", 100);
    else
        CKEDITOR.instances.signature.focus()
}

function hideSignature() {
    if (CKEDITOR.status != 'loaded')
        setTimeout("hideSignature()", 100);
    else
        disposeDialog("signatureDialog");
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
    inputs.each(function(i) {
        i.disabled = readOnly;
        i.mailAccount = mailAccount;
    });

    inputs = $$("#identityInfo input");
    inputs.each(function(i) { i.mailAccount = mailAccount; });
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
        //Instead of removing the modules, we disable it. This will prevent the window to crash if we have a connection error.
        editor.select('input, select').each(function(i) { i.disable(); })

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

/* common function between calendar categories and mail labels */
function onColorEdit(e, target) {
    var view = $(target);

    view.select('div.colorEditing').each(function(box) {
        box.removeClassName('colorEditing');
    });
    this.addClassName("colorEditing");

    var cellPosition = this.cumulativeOffset();
    var cellDimensions = this.getDimensions();
    var div = $('colorPickerDialog');
    var divDimensions = div.getDimensions();
    var left = cellPosition[0] - divDimensions["width"];
    var top = cellPosition[1] - 165 - view.scrollTop;
    div.setStyle({ left: left + "px", top: top + "px" });
    div.writeAttribute('data-target', target);
    div.show();
}

function onColorPickerChoice(event) {
    var span = getTarget(event);
    var dialog = span.up('.dialog');
    var target = dialog.readAttribute('data-target');
    var newColor = "#" + span.className.substr(4);

    var wrapper = $(target);
    var div = wrapper.select("div.colorEditing").first();

    div.writeAttribute('data-color', newColor);
    div.style.background = newColor;
    if (parseInt($("hasChanged").value) == 0) {
        var hasChanged = $("hasChanged");
        hasChanged.value = "1";
    }

    dialog.hide();
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
        tds[1].childElements()[0].observe("click", onCalendarColorEdit);
    }
}

function onCalendarColorEdit(e) {
    var onCCE = onColorEdit.bind(this);
    onCCE(e, "calendarCategoriesListWrapper");
}

function makeEditable (element) {
    element.addClassName("editing");
    element.removeClassName("whiteListCell");

    var span = element.down("SPAN");
    span.update();

    var textField = element.down("INPUT");
    textField.show();
    textField.focus();
    textField.select();

    return true;
}

function endAllEditables (e) {
    var r = $$("TABLE#tableViewWhiteList TBODY TR TD");
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

function endEditable(event, textField) {
    if (!textField)
        textField = this;

    var uid = textField.readAttribute("uid");
    var cell = textField.up("TD");
    var textSpan = cell.down("SPAN");

    cell.removeClassName("editing");
    cell.addClassName("whiteListCell");
    textField.hide();

    var tmp = textField.value;
    tmp = tmp.replace (/</, "&lt;");
    tmp = tmp.replace (/>/, "&gt;");
    if (!uid)
        cell.up("TR").addClassName("notfound");
    if (tmp)
        textSpan.update(tmp);
    else
        cell.up("TR").remove();

    if (event)
        Event.stop(event);

    return false;
}

function onAppointmentsWhiteListAdd(e) {
    var tablebody = $("appointmentsWhiteListWrapper").childNodesWithTag("table")[0].tBodies[0];
    var row = new Element("tr");
    var td = new Element("td").update("");
    var textField = new Element("input");
    var span = new Element("span");

    row.addClassName("whiteListRow");
    row.observe("mousedown", onRowClick);
    td.addClassName ("whiteListCell");
    td.observe("mousedown", endAllEditables);
    td.observe("dblclick", onNameEdit);
    textField.addInterface(SOGoAutoCompletionInterface);
    textField.SOGoUsersSearch = true;
    textField.observe("autocompletion:changed", endEditable);
    textField.addClassName("textField");

    td.appendChild(textField);
    td.appendChild(span);
    row.appendChild (td);
    tablebody.appendChild(row);
    $(tablebody).deselectAll();
    row.selectElement();

    makeEditable(td);

}

function onAppointmentsWhiteListDelete(e) {
    var list = $('appointmentsWhiteListWrapper').down("TABLE").down("TBODY");
    var rows = list.getSelectedNodes();
    var count = rows.length;

    for (var i=0; i < count; i++) {
        rows[i].editionController = null;
        rows[i].remove();
    }
}

function serializeAppointmentsWhiteList() {
    var r = $$("#appointmentsWhiteListWrapper TBODY TR");

    var users = {};
    for (var i = 0; i < r.length; i++) {
        var tds = r[i].childElements().first().down("INPUT");
        var uid  = tds.getAttribute("uid");
        var value = tds.getValue();
        if (uid != null)
            users[uid] = value;
    }
    $("whiteList").value = Object.toJSON(users);
}

function onCalendarCategoryAdd(e) {
    var row = new Element("tr");
    var nametd = new Element("td").update("");
    var colortd = new Element("td");
    var colordiv = new Element("div", {"class": "colorBox", dataColor: "#F0F0F0"});

    row.identify();
    row.addClassName("categoryListRow");

    nametd.addClassName("categoryListCell");
    colortd.addClassName("categoryListCell");
    colordiv.setStyle({backgroundColor: "#F0F0F0"});

    colortd.appendChild(colordiv);
    row.appendChild(nametd);
    row.appendChild(colortd);
    $("calendarCategoriesListWrapper").childNodesWithTag("table")[0].tBodies[0].appendChild(row);

    resetCalendarTableActions();
    nametd.editionController.startEditing();
}

function onCalendarCategoryDelete(e) {
    var list = $('calendarCategoriesListWrapper').down("TABLE").down("TBODY");
    var rows = list.getSelectedNodes();
    var count = rows.length;

    for (var i=0; i < count; i++) {
        rows[i].editionController = null;
        rows[i].remove();
    }
}

function serializeCalendarCategories() {
    var r = $$("#calendarCategoriesListWrapper TBODY TR");

    var values = [];
    for (var i = 0; i < r.length; i++) {
        var tds = r[i].childElements();
        var name  = $(tds.first()).innerHTML.trim();
        var color = $(tds.last().childElements().first()).readAttribute('data-color');
        values.push("\"" + name + "\": \"" + color + "\"");
    }

    $("calendarCategoriesValue").value = "{ " + values.join(",\n") + "}";
}

function resetCalendarCategoriesColors(e) {
    var divs = $$("#calendarCategoriesListWrapper DIV.colorBox");
    for (var i = 0; i < divs.length; i++) {
        var d = divs[i];
        var color = d.readAttribute("data-color");
        if (color != "undefined")
            d.setStyle({ backgroundColor: color });
    }
}

/* /calendar categories */

/* mail label/tags */
function resetMailTableActions() {
    var r = $$("#mailLabelsListWrapper tbody tr");
    for (var i = 0; i < r.length; i++) {
        var row = $(r[i]);
        row.observe("mousedown", onRowClick);
        var tds = row.childElements();
        var editionCtlr = new RowEditionController();
        editionCtlr.attachToRowElement(tds[0]);
        tds[1].childElements()[0].observe("click", onMailColorEdit);
    }
}

function onMailColorEdit(e) {
    var onMCE = onColorEdit.bind(this);
    onMCE(e, "mailLabelsListWrapper");
}

function onMailLabelAdd(e) {
    var row = new Element("tr");
    var nametd = new Element("td").update("");
    var colortd = new Element("td");
    var colordiv = new Element("div", {"class": "colorBox", dataColor: "#F0F0F0"});

    row.identify();
    row.addClassName("labelListRow");

    nametd.addClassName("labelListCell");
    colortd.addClassName("labelListCell");
    colordiv.setStyle({backgroundColor: "#F0F0F0"});

    colortd.appendChild(colordiv);
    row.appendChild(nametd);
    row.appendChild(colortd);
    $("mailLabelsListWrapper").childNodesWithTag("table")[0].tBodies[0].appendChild(row);

    resetMailTableActions();
    nametd.editionController.startEditing();
}

function onMailLabelDelete(e) {
    var list = $('mailLabelsListWrapper').down("TABLE").down("TBODY");
    var rows = list.getSelectedNodes();
    var count = rows.length;

    for (var i=0; i < count; i++) {
        rows[i].editionController = null;
        rows[i].remove();
    }
}

function resetMailLabelsColors(e) {
    var divs = $$("#mailLabelsListWrapper DIV.colorBox");
    for (var i = 0; i < divs.length; i++) {
        var d = divs[i];
        var color = d.readAttribute('data-color');
        if (color != "undefined")
            d.setStyle({ backgroundColor: color });
    }
}

function serializeMailLabels() {
    var r = $$("#mailLabelsListWrapper TBODY TR");

    var values = [];
    for (var i = 0; i < r.length; i++) {
        var tds = r[i].childElements();
        var name = r[i].readAttribute("data-name"); 
        var label  = $(tds.first()).innerHTML;
        var color = $(tds.last().childElements().first()).readAttribute('data-color');

        /* if name is null, that's because we've just added a new tag */
        if (!name) {
            name = label.replace(/[ \(\)\/\{%\*<>\\\"]/g, "_");
        }

        values.push("\"" + name + "\": [\"" + label + "\", \"" + color + "\"]");
    }

    $("mailLabelsValue").value = "{ " + values.join(",\n") + "}";
}

/* /mail label/tags */


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

    resetContactsTableActions();
    nametd.editionController.startEditing();
}

function onContactsCategoryDelete(e) {
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

function onAddOutgoingAddressesCheck(checkBox) {
    if (!checkBox) {
        checkBox = $("addOutgoingAddresses");
    }
    $("addressBookList").disabled = !checkBox.checked;
}

function onReplyPlacementListChange() {
    if ($("replyPlacementList").value == 0) {
        // Reply placement is above quote, signature can be place before of after quote
        $("signaturePlacementList").disabled = false;
    }
    else {
        // Reply placement is bellow quote, signature is unconditionally placed after quote
        $("signaturePlacementList").value = 1;
        $("signaturePlacementList").disabled = true;
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
                SetLogMessage("passwordError", _("Password must not be empty."), "error");
        }
        else {
            SetLogMessage("passwordError", _("The passwords do not match. Please try again."), "error");
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
