/* -*- Mode: java; tab-width: 2; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/* Cyrus: comparator-i;ascii-numeric fileinto reject vacation imapflags
   notify envelope relational regex subaddress copy */
var sieveCapabilities = [];

var filter;

var selectedRuleDiv = null;
var selectedActionDiv = null;

var fieldLabels;
var methodLabels;
var operatorLabels;
var operatorRequirements;
var methodRequirements;
var flagLabels;

var mailboxes = [];

function onLoadHandler() {
    setupConstants();
    setupEventHandlers();

    if (window.opener)
        sieveCapabilities = window.opener.getSieveCapabilitiesFromEditor();
    if (!window.opener || filterId == "new") {
        setupNewFilterData();
    } else {
        filter = window.opener.getFilterFromEditor(filterId).evalJSON();
    }

    if (!window.opener || window.opener.userMailboxes) {
        setupFilterViews();
    } else {
        loadMailboxes();
    }
}

function loadMailboxes() {
    var url = ApplicationBaseURL + "Mail/0/mailboxes";
    triggerAjaxRequest(url, onLoadMailboxesCallback);
}

function onLoadMailboxesCallback(http) {
    if (http.readyState == 4) {
        // log("http.status: " + http.status);
        if (http.status == 200) {
            checkAjaxRequestsState();
            if (http.responseText.length > 0) {
                var jsonResponse = http.responseText.evalJSON(true);
                window.opener.setupMailboxesFromJSON(jsonResponse);
            }
        }
        setupFilterViews();
    }
}

function setupConstants() {
    fieldLabels = { "subject": _("Subject"),
                    "from": _("From"),
                    "to": _("To"),
                    "cc": _("Cc"),
                    "to_or_cc": _("To or Cc"),
                    "size": _("Size (Kb)"),
                    "header": _("Header") };
    methodLabels = { "addflag": _("Flag the message with:"),                         
                     "discard": _("Discard the message"),
                     "fileinto": _("File the message in:"),
                     "keep": _("Keep the message"),
                     "redirect": _("Forward the message to:"),
                     "reject": _("Send a reject message:"),
                     "vacation": _("Send a vacation message"),
                     "stop": _("Stop processing filter rules") };

    operatorLabels = { "under": _("is under"),
                       "over": _("is over"),
                       "is": _("is"),
                       "is_not": _("is not"),
                       "contains": _("contains"),
                       "contains_not": _("does not contain"),
                       "matches": _("matches"),
                       "matches_not": _("does not match"),
                       "regex": _("matches regex"),
                       "regex_not": _("does not match regex") };

    flagLabels = { "seen": _("Seen"),
                   "deleted": _("Deleted"),
                   "answered": _("Answered"),
                   "flagged": _("Flagged"),
                   "junk": _("Junk"),
                   "not_junk": _("Not Junk") };
    for (var i = 1; i < 6; i++) {
        var key = "label" + i;
        flagLabels[key] = _("Label " + i);
    }
}

function setupEventHandlers() {
    var filterName = $($("mainForm").filterName);
    if (filterName) {
        var boundCB = onFilterNameChange
                      .bindAsEventListener(filterName);
        filterName.observe("change", boundCB);
    }
    var matchTypeSelect = $("matchType");
    if (matchTypeSelect) {
        var boundCB = onMatchTypeChange
                      .bindAsEventListener(matchTypeSelect);
        matchTypeSelect.observe("change", boundCB);
    }

    var filterRules = $("filterRules");
    var boundCB = onFilterRulesDivClick
        .bindAsEventListener(filterRules);
    filterRules.observe("click", boundCB);
    var ruleAdd = $("ruleAdd");
    if (ruleAdd) {
        var boundCB = onRuleAddClick.bindAsEventListener(ruleAdd);
        ruleAdd.observe("click", boundCB);
    }
    var ruleDelete = $("ruleDelete");
    if (ruleDelete) {
        var boundCB = onRuleDeleteClick.bindAsEventListener(ruleDelete);
        ruleDelete.observe("click", boundCB);
    }

    var filterActions = $("filterActions");
    var boundCB = onFilterActionsDivClick
        .bindAsEventListener(filterActions);
    filterActions.observe("click", boundCB);
    var actionAdd = $("actionAdd");
    if (actionAdd) {
        var boundCB = onActionAddClick.bindAsEventListener(actionAdd);
        actionAdd.observe("click", boundCB);
    }
    var actionDelete = $("actionDelete");
    if (actionDelete) {
        var boundCB = onActionDeleteClick
            .bindAsEventListener(actionDelete);
        actionDelete.observe("click", boundCB);
    }
}

function onFilterNameChange(event) {
    filter.name = this.value;
}

function onMatchTypeChange() {
    var matchType = this.value;
    filter.match = matchType;
    var container = $("filterRulesContainer");
    var otherContainer = $("filterActionsContainer");
    var otherContainerTop;
    if (matchType == "allmessages") {
        container.hide();
        otherContainerTop = 130;
    } else {
        container.show();
        otherContainerTop = 240;
    }
    otherContainer.setStyle({ top: otherContainerTop + "px" });
}

function onFilterRulesDivClick(event) {
    setSelectedRuleDiv(null);
    Event.stop(event);
}

function onFilterActionsDivClick(event) {
    setSelectedActionDiv(null);
    Event.stop(event);
}

function createFilterRule() {
    return { field: "subject", operator: "contains", value: "" };
}

function createFilterAction() {
    return { method: "fileinto", argument: "INBOX" };
}

function setupNewFilterData() {
    var newFilterTemplate = $({ name: _("Untitled Filter"),
                                match: "any",
                                active: true });
    newFilterTemplate.rules = $([ createFilterRule() ]);
    newFilterTemplate.actions = $([ createFilterAction() ]);

    filter = newFilterTemplate;
}

function setupFilterViews() {
    var filterName = $("mainForm").filterName;
    if (filterName) {
        filterName.value = filter.name;
        if (filterId == "new") {
            filterName.focus();
            $(filterName).selectText(0, filterName.value.length);
        }
    }

    var matchTypeSelect = $("matchType");
    if (matchTypeSelect) {
        matchTypeSelect.value = filter.match;
    }
    if (filter.match != "allmessages") {
        var filterRules = $("filterRules");
        if (filterRules && filter.rules) {
            for (var i = 0; i < filter.rules.length; i++) {
                appendRule(filterRules, filter.rules[i]);
            }
        }
    }
    onMatchTypeChange.apply(matchTypeSelect);

    var filterActions = $("filterActions");
    if (filterActions && filter.actions) {
        for (var i = 0; i < filter.actions.length; i++) {
            appendAction(filterActions, filter.actions[i]);
        }
    }
}

function appendRule(container, rule) {
    var ruleDiv = createElement("div", null, "rule",
                                { rule: rule }, null,
                                container);
    var boundCB = onRuleDivClick.bindAsEventListener(ruleDiv);
    ruleDiv.observe("click", boundCB);
    ensureRuleRepresentation(ruleDiv);

    return ruleDiv;
}

function onRuleDivClick(event) {
    setSelectedRuleDiv(this);
    Event.stop(event);
}

function setSelectedRuleDiv(newDiv) {
    if (selectedRuleDiv) {
        selectedRuleDiv.removeClassName("_selected");
    }
    selectedRuleDiv = newDiv;
    if (selectedRuleDiv) {
        selectedRuleDiv.addClassName("_selected");
    }
}

function ensureRuleRepresentation(container) {
    ensureFieldRepresentation(container);
    ensureOperatorRepresentation(container);
    ensureValueRepresentation(container);
}

function ensureFieldRepresentation(container) {
    var fieldSpans = container.select("SPAN.fieldContainer");
    var fieldSpan;
    if (fieldSpans.length)
        fieldSpan = fieldSpans[0];
    else {
        while (container.firstChild) {
            container.removeChild(container.firstChild);
        }
        fieldSpan = createElement("span", null, "fieldContainer",
                                  null, null, container);
    }
    ensureFieldSelectRepresentation(container, fieldSpan);
    ensureFieldCustomHeaderRepresentation(container, fieldSpan);
}

function ensureFieldSelectRepresentation(container, fieldSpan) {
    var fields
        = [ "subject", "from", "to", "cc", "to_or_cc", "size", "header" ];
    var selects = fieldSpan.select("SELECT");
    var select;
    if (selects.length)
        select = selects[0];
    else {
        select = createElement("select");
        select.rule = container.rule;
        var boundCB = onFieldSelectChange.bindAsEventListener(select);
        select.observe("change", boundCB);
        for (var i = 0; i < fields.length; i++) {
            var field = fields[i];
            var fieldOption = createElement("option", null, null,
                                            { value: field }, null, select);
            fieldOption.appendChild(document
                                    .createTextNode(fieldLabels[field]));
        }
        fieldSpan.appendChild(select);
    }
    select.value = container.rule.field;
    container.rule.field = select.value;
}

function onFieldSelectChange(event) {
    this.rule.field = this.value;
    var fieldSpan = this.parentNode;
    var container = fieldSpan.parentNode;
    ensureFieldCustomHeaderRepresentation(container, fieldSpan);
    ensureOperatorRepresentation(container);
    ensureValueRepresentation(container);
}

function ensureFieldCustomHeaderRepresentation(container, fieldSpan) {
    var headerInputs = fieldSpan.select("INPUT");
    var headerInput = null;
    if (headerInputs.length) {
        headerInput = headerInputs[0];
    }
    if (container.rule.field == "header") {
        if (!headerInput) {
            headerInput = createElement("input", null, "textField",
                                        { type: "text" }, null, fieldSpan);
            headerInput.rule = container.rule;
            if (!container.rule.custom_header)
                container.rule.custom_header = "";
            headerInput.value = container.rule.custom_header;
            var boundCB
                = onFieldCustomHeaderChange.bindAsEventListener(headerInput);
            headerInput.observe("change", boundCB);
            headerInput.focus();
        }
    } else {
        if (headerInput) {
            if (container.rule.custom_header)
                container.rule.custom_header = null;
            fieldSpan.removeChild(headerInput);
        }
    }
}

function onFieldCustomHeaderChange(event) {
    this.rule.custom_header = this.value;
}

function ensureOperatorRepresentation(container) {
    var operatorSpans = container.select("SPAN.operatorContainer");
    var operatorSpan;
    if (operatorSpans.length)
        operatorSpan = operatorSpans[0];
    else
        operatorSpan = createElement("span", null, "operatorContainer",
                                     null, null, container);
    ensureOperatorSelectRepresentation(container, operatorSpan);
}

function ensureOperatorSelectRepresentation(container, operatorSpan) {
    var operators = determineOperators(container.rule.field);

    var ruleField = container.rule.field;
    var selects = operatorSpan.select("SELECT");
    var select = null;
    if (selects.length) {
        select = selects[0];
        if ((ruleField == "size" && !select.sizeOperator)
            || (ruleField != "size" && select.sizeOperator)) {
            operatorSpan.removeChild(select);
            select = null;
        }
    }
    if (!select) {    
        select = createElement("select");
        select.rule = container.rule;
        select.sizeOperator = (ruleField == "size");
        var boundCB = onOperatorSelectChange.bindAsEventListener(select);
        select.observe("change", boundCB);
        for (var i = 0; i < operators.length; i++) {
            var operator = operators[i];
            var operatorOption = createElement("option", null, null,
                                               { value: operator }, null,
                                               select);
            operatorOption.appendChild(document
                                       .createTextNode(operatorLabels[operator]));
        }
        operatorSpan.appendChild(select);
    }
    if (container.rule.operator
        && operators.indexOf(container.rule.operator) == -1) {
        container.rule.operator = operators[0];
    }
    select.value = container.rule.operator;
    container.rule.operator = select.value;
}

function onOperatorSelectChange(event) {
    this.rule.operator = this.value;
    var valueSpans = this.parentNode.parentNode.select("SPAN.valueContainer");
    if (valueSpans.length) {
        var valueInputs = valueSpans[0].select("INPUT");
        if (valueInputs.length) {
            valueInputs[0].focus();
        }
    }
}

function determineOperators(field) {
    var operators;
    if (field == "size") {
        operators = [ "under", "over" ];
    } else {
        var baseOperators = [ "is", "contains", "matches" ];
        if (sieveCapabilities.indexOf("regex") > -1) {
            baseOperators.push("regex");
        }
        operators = [];
        for (var i = 0; i < baseOperators.length; i++) {
            operators.push(baseOperators[i]);
            operators.push(baseOperators[i] + "_not");
        }
    }

    return operators;
}

function ensureValueRepresentation(container) {
    var valueSpans = container.select("SPAN.valueContainer");
    var valueSpan;
    if (valueSpans.length)
        valueSpan = valueSpans[0];
    else
        valueSpan = createElement("span", null, "valueContainer",
                                  null, null, container);
    ensureValueInputRepresentation(container, valueSpan);
}

function ensureValueInputRepresentation(container, valueSpan) {
    var inputs = valueSpan.select("INPUT");
    var input;
    if (inputs.length) {
        input = inputs[0];
    }
    else {
        input = createElement("input", null, "textField");
        input.rule = container.rule;
        var boundCB = onValueInputChange.bindAsEventListener(input);
        input.observe("change", boundCB);
        valueSpan.appendChild(input);
    }
    input.value = container.rule.value;
    ensureFieldValidity(input);
}

function ensureFieldValidity(input) {
    var valid = ensureFieldIsNotEmpty(input);
    if (valid && input.rule.field == "size") {
        valid = ensureFieldIsNumerical(input);
    }

    return valid;
}

function onValueInputChange(event) {
    if (ensureFieldValidity(this))
        this.rule.value = this.value;
    else
        this.rule.value = "";
}

function ensureFieldIsNumerical(input) {
    var valid = !isNaN(input.value);
    if (valid) {
        input.removeClassName("_invalid");
    } else {
        input.addClassName("_invalid");
    }

    return valid;
}

function ensureFieldIsNotEmpty(input) {
    var valid = !input.value.blank();
    if (valid) {
        input.removeClassName("_invalid");
    } else {
        input.addClassName("_invalid");
    }

    return valid;
}

function appendAction(container, action) {
    var actionDiv = createElement("div", null, "action",
                                  { action: action }, null,
                                  container);
    var boundCB = onActionDivClick.bindAsEventListener(actionDiv);
    actionDiv.observe("click", boundCB);
    ensureActionRepresentation(actionDiv);

    return actionDiv;
}

function onActionDivClick(event) {
    setSelectedActionDiv(this);
    Event.stop(event);
}

function setSelectedActionDiv(newSpan) {
    if (selectedActionDiv) {
        selectedActionDiv.removeClassName("_selected");
    }
    selectedActionDiv = newSpan;
    if (selectedActionDiv) {
        selectedActionDiv.addClassName("_selected");
    }
}

function ensureActionRepresentation(container) {
    ensureMethodRepresentation(container);
    ensureArgumentRepresentation(container);
}

function ensureMethodRepresentation(container) {
    var methodSpans = container.select("SPAN.methodContainer");
    var methodSpan;
    if (methodSpans.length)
        methodSpan = methodSpans[0];
    else {
        while (container.firstChild) {
            container.removeChild(container.firstChild);
        }
        methodSpan = createElement("span", null, "methodContainer",
                                   null, null, container);
    }
    ensureMethodSelectRepresentation(container, methodSpan);
}

function ensureMethodSelectRepresentation(container, methodSpan) {
    var methods = [ "redirect", "discard", "keep" ];
    if (sieveCapabilities.indexOf("reject") > -1) {
        methods.push("reject");
    }
    if (sieveCapabilities.indexOf("fileinto") > -1) {
        methods.push("fileinto");
    }
    if (sieveCapabilities.indexOf("imapflags") > -1) {
        methods.push("addflag");
    }
    methods.push("stop");
    /* TODO: those are currently unimplemented */
    // if (sieveCapabilities.indexOf("notify") > -1) {
    //     methods.push("notify");
    // }
    // if (sieveCapabilities.indexOf("vacation") > -1) {
    //     methods.push("vacation");
    // }

    var selects = methodSpan.select("SELECT");
    var select;
    if (selects.length)
        select = selects[0];
    else {
        select = createElement("select");
        select.action = container.action;
        var boundCB = onMethodSelectChange.bindAsEventListener(select);
        select.observe("change", boundCB);
        for (var i = 0; i < methods.length; i++) {
            var method = methods[i];
            var methodOption = createElement("option", null, null,
                                             { value: method }, null, select);
            methodOption.appendChild(document
                                     .createTextNode(methodLabels[method]));
        }
        methodSpan.appendChild(select);
    }
    select.value = container.action.method;
}

function onMethodSelectChange(event) {
    this.action.method = this.value;
    var methodSpan = this.parentNode;
    var container = methodSpan.parentNode;
    ensureArgumentRepresentation(container);
}

function ensureArgumentRepresentation(container) {
    var argumentWidgetMethods
        = { "addflag": ensureFlagArgRepresentation,
            "fileinto": ensureMailboxArgRepresentation,
            "redirect": ensureRedirectArgRepresentation,
            "reject": ensureRejectArgRepresentation,
            "vacation": ensureVacationArgRepresentation };

    var widgetMethod = argumentWidgetMethods[container.action.method];
    var spanClass = container.action.method + "Argument";

    var argumentSpans = container.select("SPAN.argumentContainer");
    var argumentSpan;
    if (argumentSpans.length) {
        argumentSpan = argumentSpans[0];
        if (argumentSpan
            && (!widgetMethod || !argumentSpan.hasClassName(spanClass))) {
            container.removeChild(argumentSpan);
            container.action.argument = null;
            argumentSpan = null;
        }
    }
    else
        argumentSpan = null;

    if (!argumentSpan && widgetMethod) {
        argumentSpan = createElement("span", null,
                                     ["argumentContainer", spanClass],
                                     null, null, container);
        widgetMethod(container, argumentSpan);
    }
}

function ensureFlagArgRepresentation(container, argumentSpan) {
    var flags = [ "seen", "deleted", "answered", "flagged", "junk",
                  "not_junk" ];
    for (var i = 1; i < 6; i++) {
        flags.push("label" + i);
    }

    var selects = argumentSpan.select("SELECT");
    var select;
    if (selects.length)
        select = selects[0];
    else {
        select = createElement("select");
        select.action = container.action;
        var boundCB = onFlagArgumentSelectChange.bindAsEventListener(select);
        select.observe("change", boundCB);
        for (var i = 0; i < flags.length; i++) {
            var flag = flags[i];
            var flagOption = createElement("option", null, null,
                                           { value: flag }, null, select);
            var label = flagLabels[flag];
            flagOption.appendChild(document.createTextNode(label));
        }
        argumentSpan.appendChild(select);
    }
    /* 1) initialize the value if null
       2) set the SELECT to the corresponding value
       3) if value was not null in 1, we must ensure the SELECT contains it */
    if (!container.action.argument)
        container.action.argument = "seen";
    select.value = container.action.argument;
    container.action.argument = select.value;
}

function onFlagArgumentSelectChange(event) {
    this.action.argument = this.value;
}

function ensureMailboxArgRepresentation(container, argumentSpan) {
    var selects = argumentSpan.select("SELECT");
    var select;
    if (selects.length)
        select = selects[0];
    else {
        select = createElement("select");
        select.action = container.action;
        if (!container.action.argument)
            container.action.argument = "INBOX";
        var boundCB = onMailboxArgumentSelectChange.bindAsEventListener(select);
        select.observe("change", boundCB);
        var mailboxes = (window.opener
                         ? window.opener.userMailboxes
                         : ["INBOX" ]);
        for (var i = 0; i < mailboxes.length; i++) {
            var mailbox = mailboxes[i];
            var mboxOption = createElement("option", null, null,
                                           { value: mailbox }, null, select);
            mboxOption.appendChild(document.createTextNode(mailbox));
        }
        argumentSpan.appendChild(select);
    }
    select.value = container.action.argument;
    container.action.argument = select.value;
}

function onMailboxArgumentSelectChange(event) {
    this.action.argument = this.value;
}

function ensureRedirectArgRepresentation(container, argumentSpan) {
    var emailInputs = argumentSpan.select("INPUT");
    var emailInput = null;
    if (emailInputs.length) {
        emailInput = emailInputs[0];
    }
    if (!emailInput) {
        emailInput = createElement("input", null, "textField",
                                   { type: "text" }, null, argumentSpan);
        emailInput.action = container.action;
        if (!container.action.argument)
            container.action.argument = "";
        var boundCB
            = onEmailArgumentChange.bindAsEventListener(emailInput);
        emailInput.observe("change", boundCB);
        emailInput.focus();
    }
    emailInput.value = container.action.argument;
}

function onEmailArgumentChange(event) {
    this.action.argument = this.value;
}

function ensureRejectArgRepresentation(container, argumentSpan) {
    var msgAreas = argumentSpan.select("TEXTAREA");
    var msgArea = null;
    if (msgAreas.length) {
        msgArea = msgAreas[0];
    }
    if (!msgArea) {
        msgArea = createElement("textarea", null, null,
                                { action: container.action }, null,
                                argumentSpan);
        if (!container.action.argument)
            container.action.argument = "";
        var boundCB
            = onMsgArgumentChange.bindAsEventListener(msgArea);
        msgArea.observe("change", boundCB);
        msgArea.focus();
    }
    msgArea.value = container.action.argument;
}

function onMsgArgumentChange(event) {
    this.action.argument = this.value;
}

function ensureVacationArgRepresentation(container, argumentSpan) {
    
}

function onRuleAddClick(event) {
    var filterRules = $("filterRules");
    if (filterRules) {
        var newRule = createFilterRule();
        if (!filter.rules)
            filter.rules = [];
        filter.rules.push(newRule);
        var newRuleDiv = appendRule(filterRules, newRule);
        setSelectedRuleDiv(newRuleDiv);
        filterRules.scrollTop = newRuleDiv.offsetTop;
    }
    Event.stop(event);
}

function onRuleDeleteClick(event) {
    if (selectedRuleDiv) {
        var ruleIndex = filter.rules.indexOf(selectedRuleDiv.rule);
        filter.rules.splice(ruleIndex, 1);
        var nextSelected = selectedRuleDiv.next();
        if (!nextSelected)
            nextSelected = selectedRuleDiv.previous();
        selectedRuleDiv.parentNode.removeChild(selectedRuleDiv);
        setSelectedRuleDiv(nextSelected);
    }

    Event.stop(event);
}

function onActionAddClick(event) {
    var filterActions = $("filterActions");
    if (filterActions) {
        var newAction = createFilterAction();
        filter.actions.push(newAction);
        var newActionDiv = appendAction(filterActions, newAction);
        setSelectedActionDiv(newActionDiv);
        filterActions.scrollTop = newActionDiv.offsetTop;
    }
    Event.stop(event);
}

function onActionDeleteClick(event) {
    if (selectedActionDiv) {
        var actionIndex = filter.actions.indexOf(selectedActionDiv.action);
        filter.actions.splice(actionIndex, 1);
        var nextSelected = selectedActionDiv.next();
        if (!nextSelected)
            nextSelected = selectedActionDiv.previous();
        selectedActionDiv.parentNode.removeChild(selectedActionDiv);
        setSelectedActionDiv(nextSelected);
    }

    Event.stop(event);
}

function savePreferences(event) {
    var valid = true;

    var rules = $$("DIV#filterRules DIV.rule");
    if (rules.length == 0) {
        onRuleAddClick(event);
        valid = false;
    }

    var actions = $$("DIV#filterActions DIV.action");
    if (actions.length == 0) {
        onActionAddClick(event);        
        valid = false;
    }

    if (valid) {
        var inputs = $$("DIV#filterRules input");
        inputs.each(function(input) {
                if (input.hasClassName("_invalid"))
                    valid = false;
            });
    }

    if (valid) {
        if (window.opener) {
            window.opener.updateFilterFromEditor(filterId, Object.toJSON(filter));
        }
        window.close();
    }
    
    return false;
}

// function configureDragHandles() {
//     var handle = $("splitter");
//     if (handle) {
//         handle.addInterface(SOGoDragHandlesInterface);
//         handle.upperBlock = $("filterRulesContainer");
//         handle.lowerBlock = $("filterActionsContainer");
//     }
// }

document.observe("dom:loaded", onLoadHandler);
