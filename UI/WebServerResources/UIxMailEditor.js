/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var contactSelectorAction = 'mailer-contacts';
var attachmentCount = 0;
var MailEditor = {
    currentField: null,
    selectedIndex: -1,
    delay: 750,
    delayedSearch: false,
    signatureLength: 0,
    textFirstFocus: true
};

function onContactAdd(button) {
    var div = $("contacts");
    if (div.visible()) {
        div.hide();
        $("rightPanel").setStyle({ left: "0px" });
        $(button).removeClassName("active");
    }
    else {
        $("rightPanel").setStyle({ left: $("leftPanel").getStyle("width") });
        div.show();
        $(button).addClassName("active");
    }

    $("hiddenDragHandle").adjust();
    onWindowResize(null);
}

function addContact(tag, fullContactName, contactId, contactName, contactEmail) {
    if (!mailIsRecipient(contactEmail)) {
        var neededOptionValue = 0;
        if (tag == "cc")
            neededOptionValue = 1;
        else if (tag == "bcc")
            neededOptionValue = 2;

        var stop = false;
        var counter = 0;
        var currentRow = $('row_' + counter);
        while (currentRow && !stop) {
            var currentValue = $(currentRow.childNodesWithTag("td")[1]).childNodesWithTag("input")[0].value;
            if (currentValue == neededOptionValue) {
                stop = true;
                insertContact($("addr_" + counter), contactName, contactEmail);
            }
            counter++;
            currentRow = $('row_' + counter);
        }

        if (!stop) {
            fancyAddRow("");
            var row = $("row_" + currentIndex);
            var td = $(row.childNodesWithTag("td")[0]);
            var select = $(td.childNodesWithTag("select")[0]);
            select.value = neededOptionValue;
            insertContact($("addr_" + currentIndex), contactName, contactEmail);
            onWindowResize(null);
        }
    }
}

function onContactFolderChange(event) {
    initCriteria();
    openContactsFolder(this.value);
}

function mailIsRecipient(mailto) {
    var isRecipient = false;

    var counter = 0;
    var currentRow = $('row_' + counter);

    var email = extractEmailAddress(mailto).toUpperCase();

    while (currentRow && !isRecipient) {
        var currentValue = $("addr_"+counter).value.toUpperCase();
        if (currentValue.indexOf(email) > -1)
            isRecipient = true;
        else
            {
                counter++;
                currentRow = $('row_' + counter);
            }
    }

    return isRecipient;
}

function insertContact(inputNode, contactName, contactEmail) {
    var value = '' + inputNode.value;

    var newContact = contactName;
    if (newContact.length > 0)
        newContact += ' <' + contactEmail + '>';
    else
        newContact = contactEmail;

    if (value.length > 0)
        value += ", ";
    value += newContact;

    inputNode.value = value;
}


/* mail editor */

function validateEditorInput() {
    var errortext = "";
    var field;
   
    field = document.pageform.subject;
    if (field.value == "")
        errortext = errortext + _("error_missingsubject") + "\n";

    if (!hasRecipients())
        errortext = errortext + _("error_missingrecipients") + "\n";
   
    if (errortext.length > 0) {
        alert(_("error_validationfailed") + ":\n" + errortext);
        return false;
    }

    return true;
}

function onValidate(event) {
    var rc = false;

    if (document.pageform.action != "send"
        && validateEditorInput()) {
        var input = currentAttachmentInput();
        if (input)
            input.parentNode.removeChild(input);

        var toolbar = document.getElementById("toolbar");
        if (!document.busyAnim)
            document.busyAnim = startAnimation(toolbar);
  
        var lastRow = $("lastRow");
        lastRow.down("select").name = "popup_last";
    
        window.shouldPreserve = true;

        document.pageform.action = "send";

        AIM.submit($(document.pageform), {'onComplete' : onPostComplete});

        rc = true;
    }

    return rc;
}

function onPostComplete(response) {
    if (response && response.length > 0) {
        var jsonResponse = response.evalJSON();
        if (jsonResponse["status"] == "success") {
            var p;
            if (window.frameElement && window.frameElement.id)
                p = parent;
            if (window.opener && window.opener.refreshMessage)
                p = window.opener;
            if (p && p.refreshMessage)
                p.refreshMessage(jsonResponse["sourceFolder"],
                                 jsonResponse["messageID"]);            
            onCloseButtonClick();
        }
        else {
            var message = jsonResponse["message"];
            document.pageform.action = "";
            var progressImage = $("progressIndicator");
            if (progressImage) {
                progressImage.parentNode.removeChild(progressImage);
            }
            showAlertDialog(jsonResponse["message"]);
        }
    }
    else {
        onCloseButtonClick();
    }
}

function clickedEditorSend() {
    if (onValidate()) {
        document.pageform.submit();
    }

    return false;
}

function currentAttachmentInput() {
    var input = null;

    var inputs = $("attachmentsArea").getElementsByTagName("input");
    var i = 0;
    while (!input && i < inputs.length)
        if ($(inputs[i]).hasClassName("currentAttachment"))
            input = inputs[i];
        else
            i++;

    return input;
}

function clickedEditorAttach() {
    var input = currentAttachmentInput();
    if (!input) {
        var area = $("attachmentsArea");

        if (!area.style.display) {
            area.setStyle({ display: "block" });
            onWindowResize(null);
        }
        var inputs = area.getElementsByTagName("input");
        var attachmentName = "attachment" + attachmentCount;
        var newAttachment = createElement("input", attachmentName,
                                          "currentAttachment", null,
                                          { type: "file",
                                            name: attachmentName },
                                          area);
        attachmentCount++;
        newAttachment.observe("change",
                              onAttachmentChange.bindAsEventListener(newAttachment));
    }

    return false;
}

function onAttachmentChange(event) {
    if (this.value == "")
        this.parentNode.removeChild(this);
    else {
        this.addClassName("attachment");
        this.removeClassName("currentAttachment");
        var list = $("attachments");
        createAttachment(this, list);
        clickedEditorAttach(null);
    }
}

function createAttachment(node, list) {
    var attachment = createElement("li", null, null, { node: node }, null, list);
    createElement("img", null, null, { src: ResourcesURL + "/attachment.gif" },
                  null, attachment);

    var filename = node.value;
    var separator;
    if (navigator.appVersion.indexOf("Windows") > -1)
        separator = "\\";
    else
        separator = "/";
    var fileArray = filename.split(separator);
    var attachmentName = document.createTextNode(fileArray[fileArray.length-1]);
    attachment.appendChild(attachmentName);
    attachment.writeAttribute("title", fileArray[fileArray.length-1]);
}

function clickedEditorSave() {
    var input = currentAttachmentInput();
    if (input)
        input.parentNode.removeChild(input);

    var lastRow = $("lastRow");
    lastRow.down("select").name = "popup_last";

    window.shouldPreserve = true;
    document.pageform.action = "save";
    document.pageform.submit();

    if (window.opener && window.opener.open && !window.opener.closed)
        window.opener.refreshFolderByType('draft');

    return false;
}

function onTextFocus(event) {
    if (MailEditor.textFirstFocus) {
        // On first focus, position the caret at the proper position
        var content = this.getValue();
        var replyPlacement = UserDefaults["SOGoMailReplyPlacement"];
        if (replyPlacement == "above" || !mailIsReply) { // for forwards, place caret at top unconditionally
            this.setCaretTo(0);
        }
        else {
            var caretPosition = this.getValue().length - MailEditor.signatureLength;
            if (Prototype.Browser.IE)
                caretPosition -= lineBreakCount(this.getValue().substring(0, caretPosition));
            if (hasSignature())
                caretPosition -= 2;
            this.setCaretTo(caretPosition);
        }
        MailEditor.textFirstFocus = false;
    }
	
    var input = currentAttachmentInput();
    if (input)
        input.parentNode.removeChild(input);
}

function onTextKeyDown(event) {
    if (event.keyCode == Event.KEY_TAB) {
        // Change behavior of tab key in textarea
        if (event.shiftKey) {
            var subjectField = $$("div#subjectRow input").first();
            subjectField.focus();
            subjectField.selectText(0, subjectField.value.length);
            preventDefault(event);
        }
        else {
            if (!(event.shiftKey || event.metaKey || event.ctrlKey)) {
                if (typeof(this.selectionStart)
                    != "undefined") { // For Mozilla and Safari
                    var cursor = this.selectionStart;
                    var startText = ((cursor > 0)
                                     ? this.value.substr(0, cursor)
                                     : "");
                    var endText = this.value.substr(cursor);
                    var newText = startText + "   " + endText;
                    this.value = newText;
                    cursor += 3;
                    this.setSelectionRange(cursor, cursor);
                }
                else if (this.selectionRange) // IE
                    this.selectionRange.text = "   ";
                else { // others ?
                }
                preventDefault(event);
            }
        }
    }
}

function onTextIEUpdateCursorPos(event) {
    this.selectionRange = document.selection.createRange().duplicate();
}

function onTextMouseDown(event) {
    if (event.button == 0) {
        event.returnValue = false;
        event.cancelBubble = false;
    }
}

function initAddresses() {
    var addressList = $("addressList");
    var i = 1;
    addressList.select("input.textField").each(function (input) {
            if (!input.readAttribute("readonly")) {
                input.addInterface(SOGoAutoCompletionInterface);
                input.uidField = "c_name";
                input.on("focus", addressFieldGotFocus.bind(input));
                input.on("blur", addressFieldLostFocus.bind(input));
                input.on("autocompletion:changedlist", expandContactList);
                input.on("autocompletion:changed", addressFieldChanged.bind(input));
                //input.onListAdded = expandContactList;
            }
        });
}

/* Overwrite function of MailerUI.js */
function configureDragHandle() {
    var handle = $("hiddenDragHandle");
    if (handle) {
        handle.addInterface(SOGoDragHandlesInterface);
        handle.leftMargin = 135; // minimum width
        handle.leftBlock = $("leftPanel");
        handle.rightBlock = $("rightPanel");
        handle.enableRightSafety();
        handle.observe("handle:dragged", onWindowResize);
    }
}

function initMailEditor() {
    if (composeMode != "html" && $("text"))
        $("text").style.display = "block";

    var list = $("attachments");
    if (!list) return;
    list.multiselect = true;
    list.on("click", onRowClick);
    list.attachMenu("attachmentsMenu");
    var elements = $(list).childNodesWithTag("li");
    if (elements.length > 0)
        $("attachmentsArea").setStyle({ display: "block" });

    var textarea = $("text");
  
    var textContent = textarea.getValue();
    if (hasSignature()) {
        var sigLimit = textContent.lastIndexOf("--");
        if (sigLimit > -1)
            MailEditor.signatureLength = (textContent.length - sigLimit);
    }
    if (UserDefaults["SOGoMailReplyPlacement"] != "above") {
        textarea.scrollTop = textarea.scrollHeight;
    }
    textarea.observe("focus", onTextFocus);
    //textarea.observe("mousedown", onTextMouseDown);
    textarea.observe("keydown", onTextKeyDown);

    if (Prototype.Browser.IE) {
        var ieEvents = [ "click", "select", "keyup" ];
        for (var i = 0; i < ieEvents.length; i++)
            textarea.observe(ieEvents[i], onTextIEUpdateCursorPos, false);
    }

    initAddresses();

    var focusField = (mailIsReply ? textarea : $("addr_0"));
    focusField.focus();

    initializePriorityMenu();

    configureDragHandle();

    var composeMode = UserDefaults["SOGoMailComposeMessageType"];
    if (composeMode == "html") {
        CKEDITOR.replace('text',
                         {
                             toolbar :
                             [['Bold', 'Italic', '-', 'NumberedList', 
                               'BulletedList', '-', 'Link', 'Unlink', 'Image', 
                               'JustifyLeft','JustifyCenter','JustifyRight',
                               'JustifyBlock','Font','FontSize','-','TextColor',
                               'BGColor','-','SpellChecker','Scayt']
                             ],
                             language : localeCode,
			     scayt_sLang : localeCode
                          }
                         );
        if (focusField == textarea)
            focusCKEditor();
    }

    $("contactFolder").observe("change", onContactFolderChange);
    
    Event.observe(window, "resize", onWindowResize);
    Event.observe(window, "beforeunload", onMailEditorClose);
    
    onWindowResize.defer();
}

function focusCKEditor(event) {
    if (CKEDITOR.status != 'basic_ready')
        setTimeout("focusCKEditor()", 100);
    else
        // CKEditor reports being ready but it's still not focusable;
        // we wait for a few more milliseconds
        setTimeout("CKEDITOR.instances.text.focus()", 500);
}

function initializePriorityMenu() {
    var priority = $("priority").value.toUpperCase();
    var priorityMenu = $("priorityMenu").childNodesWithTag("ul")[0];
    var menuEntries = $(priorityMenu).childNodesWithTag("li");
    var chosenNode;
    if (priority == "HIGHEST")
        chosenNode = menuEntries[0];
    else if (priority == "HIGH")
        chosenNode = menuEntries[1];
    else if (priority == "LOW")
        chosenNode = menuEntries[3];
    else if (priority == "LOWEST")
        chosenNode = menuEntries[4];
    else
        chosenNode = menuEntries[2];
    priorityMenu.chosenNode = chosenNode;
    $(chosenNode).addClassName("_chosen");
}

function onMenuCheckReturnReceipt(event) {
    event.cancelBubble = true;

    this.enabled = !this.enabled;
    var enabled = this.enabled;
    if (enabled) {
        this.addClassName("_chosen");
    }
    else {
        this.removeClassName("_chosen");
    }
    var receiptInput = $("receipt");
    receiptInput.value = (enabled ? "true" : "false") ;
}

function getMenus() {
    return {
            "attachmentsMenu": [ null, onRemoveAttachments,
                                 onSelectAllAttachments,
                                 "-",
                                 clickedEditorAttach, null],
            "optionsMenu": [ onMenuCheckReturnReceipt,
                             "-",
                             "priorityMenu" ],
            "priorityMenu": [ onMenuSetPriority,
                              onMenuSetPriority,
                              onMenuSetPriority,
                              onMenuSetPriority,
                              onMenuSetPriority ]
            };
}

function onRemoveAttachments() {
    var list = $("attachments");
    var nodes = list.getSelectedNodes();
    for (var i = nodes.length-1; i > -1; i--) {
        var input = $(nodes[i]).node;
        if (input) {
            input.parentNode.removeChild(input);
            list.removeChild(nodes[i]);
        }
        else {
            var filename = nodes[i].title;
            var url = "" + window.location;
            var parts = url.split("/");
            parts[parts.length-1] = "deleteAttachment?filename=" + encodeURIComponent(filename);
            url = parts.join("/");
            triggerAjaxRequest(url, attachmentDeleteCallback,
                               nodes[i]);
        }
    }
}

function attachmentDeleteCallback(http) {
    if (http.readyState == 4) {
        if (isHttpStatus204(http.status)) {
            var node = http.callbackData;
            node.parentNode.removeChild(node);
        }
        else
            log("attachmentDeleteCallback: an error occured: " + http.responseText);
    }
}

function lineBreakCount(str){
    /* counts \n */
    try {
        return((str.match(/[^\n]*\n[^\n]*/gi).length));
    } catch(e) {
        return 0;
    }
}

function hasSignature() {
    try {
        return(UserDefaults["SOGoMailSignature"].length > 0);
    } catch(e) {
        return false;
    }
}

function onMenuSetPriority(event) {
    event.cancelBubble = true;

    var priority = this.getAttribute("priority");
    if (this.parentNode.chosenNode)
        this.parentNode.chosenNode.removeClassName("_chosen");
    this.addClassName("_chosen");
    this.parentNode.chosenNode = this;

    var priorityInput = $("priority");
    priorityInput.value = priority;
}

function onSelectAllAttachments() {
    $("attachments").selectAll();
}

function onSelectOptions(event) {
    if (event.button == 0 || (isWebKit() && event.button == 1)) {
        var node = getTarget(event);
        if (node.tagName != 'A')
            node = $(node).up("A");
        popupToolbarMenu(node, "optionsMenu");
        Event.stop(event);
    }
}

function onWindowResize(event) {
    if (!document.pageform)
      return;
    var textarea = document.pageform.text;
    var rowheight = (Element.getHeight(textarea) / textarea.rows);
    var headerarea = $("headerArea");
    var totalwidth = $("rightPanel").getWidth();
  
    var attachmentsarea = $("attachmentsArea");
    var attachmentswidth = 0;
    var subjectfield = headerarea.down("div#subjectRow span.headerField");
    var subjectinput = headerarea.down("div#subjectRow input.textField");
    if (attachmentsarea.style.display) {
        // Resize attachments list
        attachmentswidth = attachmentsarea.getWidth();
        fromfield = $(document).getElementsByClassName('headerField', headerarea)[0];
        var height = headerarea.getHeight() - fromfield.getHeight() - subjectfield.getHeight() - 10;
        if (Prototype.Browser.IE)
            $("attachments").setStyle({ height: (height - 13) + 'px' });
        else
            $("attachments").setStyle({ height: height + 'px' });
    }
  
    // Resize subject field
    subjectinput.setStyle({ width: (totalwidth
                                    - $(subjectfield).getWidth()
                                    - attachmentswidth
                                    - 17) + 'px' });
    // Resize from field
    $("fromSelect").setStyle({ width: (totalwidth
                                       - $("fromField").getWidth()
                                       - attachmentswidth
                                       - 15) + 'px' });

    // Resize address fields
    var addresslist = $('addressList');
    addresslist.setStyle({ width: ($(window).width() - attachmentswidth - 10) + 'px' });

    // Set textarea position
    var hr = headerarea.select("hr").first();
    textarea.setStyle({ 'top': hr.offsetTop + 'px' });

    // Resize the textarea (message content)
    var offsetTop = $('rightPanel').offsetTop + headerarea.getHeight();
    var composeMode = UserDefaults["SOGoMailComposeMessageType"];
    if (composeMode == "html") {
        var editor = $('cke_text');
        if (editor == null) {
            onWindowResize.defer();
            return;
        }
        var height = window.height() - offsetTop;
        CKEDITOR.instances["text"].resize('100%', height);
    }
    else
        textarea.rows = Math.floor((window.height() - offsetTop) / rowheight);

    // Resize search contacts addressbook selector
    if ($("contacts").visible())
        $("contactFolder").setStyle({ width: ($("contactsSearch").getWidth() - 10) + "px" });
}

function onMailEditorClose(event) {
    if (window.shouldPreserve)
        window.shouldPreserve = false;
    else {
        var url = "" + window.location;
        var parts = url.split("/");
        parts[parts.length-1] = "delete";
        url = parts.join("/");
        if (window.frameElement && window.frameElement.id)
            parent.deleteDraft(url);
        else if (window.opener && window.opener.open && !window.opener.closed)
            window.opener.deleteDraft(url);
    }

    Event.stopObserving(window, "beforeunload", onMailEditorClose);
}

document.observe("dom:loaded", initMailEditor);
