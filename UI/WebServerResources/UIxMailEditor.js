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

var autoSaveTimer;

function refreshDraftsFolder() {
    if (window.opener && window.opener.getUnseenCountForFolder) {
        var nodes = window.opener.$("mailboxTree").select("DIV[datatype=draft]");
        window.opener.getUnseenCountForFolder(nodes[0].readAttribute("dataname"));
    }
}

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

function updateWindowTitleFromSubject(event) {
    if (this.value) {
        document.title = this.value;
    }else{
        document.title = '(' + _("Untitled") + ')';
    }
}

/* mail editor */

function onValidate(onSuccess) {
    if (document.pageform.action != "send") {
        
        if (!hasRecipients()) {
            showAlertDialog(_("error_missingrecipients"));
        }
        else if (document.pageform.subject.value == "") {
            showConfirmDialog(_("Warning"), _("error_missingsubject"), onValidateDone.bind(this, onSuccess), null, _("Send Anyway"), _("Cancel"));
        }
        else {
            onValidateDone(onSuccess);
        }
    }
}

function onValidateDone(onSuccess) {
    // Create "blocking" div to avoid double-clicking on send button
    var safetyNet = createElement("div", "javascriptSafetyNet");
    $('pageContent').insert({top: safetyNet});

    if (!document.busyAnim) {
        var toolbar = document.getElementById("toolbar");
        document.busyAnim = startAnimation(toolbar);
    }

    var lastRow = $("lastRow");
    lastRow.down("select").name = "popup_last";

    window.shouldPreserve = true;

    document.pageform.action = "send";

    if (typeof onSuccess == 'function')
        onSuccess();

    disposeDialog();

    return true;
}

function onPostComplete(http) {
    var response = http.responseText;
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
                                 jsonResponse["sourceMessageID"]);
            
            refreshDraftsFolder();
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
            // Remove "blocking" div
            onFinalLoadHandler(); // from generic.js
        }
    }
    else {
        onCloseButtonClick();
    }
}

function clickedEditorSend() {
    onValidate(function() {
            if (CKEDITOR.instances.text) CKEDITOR.instances.text.updateElement();
            triggerAjaxRequest(document.pageform.action,
                               onPostComplete,
                               null,
                               Form.serialize(document.pageform), // excludes the file input
                               { "Content-type": "application/x-www-form-urlencoded" });
        });

    return false;
}

function formatBytes(bytes, si) {
    var thresh = si ? 1000 : 1024;
    if (bytes < thresh) return bytes + ' B';
    var units = si ? ['KiB','MiB','GiB'] : ['KB','MB','GB'];
    var u = -1;
    do {
        bytes /= thresh;
        ++u;
    } while (bytes >= thresh);
    return bytes.toFixed(1) + ' ' + units[u];
}

function createAttachment(file) {
    var list = $('attachments');
    var attachment;
    if (list.select('[data-filename="'+file.name+'"]').length == 0) {
        // File is not already uploaded
        var attachment = createElement('li', null, ['muted progress0'], null, { 'data-filename': file.name }, list);
        attachment.appendChild(new Element('i', { 'class': 'icon-attachment' }));
        var a = createElement('a', null, null, null, {'href': '#', 'target': '_new' }, attachment);

        a.appendChild(document.createTextNode(file.name));
        if (file.size)
            attachment.appendChild(new Element('span', { 'class': 'muted' }).update('(' + formatBytes(file.size, true) + ')'));
    }

    return attachment;
}

function clickedEditorSave() {
    var lastRow = $("lastRow");
    lastRow.down("select").name = "popup_last";

    window.shouldPreserve = true;
    document.pageform.action = "save";
    if (CKEDITOR.instances.text) CKEDITOR.instances.text.updateElement();

    triggerAjaxRequest(document.pageform.action, function (http) {
            if (http.readyState == 4) {
                if (http.status == 200) {
                    refreshDraftsFolder();
                }
                else {
                    var response = http.responseText.evalJSON(true);
                    showAlertDialog(_("Error while saving the draft:") + " " + response.textStatus);
                }
            }
        },
        null,
        Form.serialize(document.pageform), // excludes the file input
        { "Content-type": "application/x-www-form-urlencoded" });

    return false;
}

/**
 * On first focus of textarea, position the caret with respect to user's preferences
 */
function onTextFocus(event) {
    if (MailEditor.textFirstFocus) {
        var content = this.getValue();
        var replyPlacement = UserDefaults["SOGoMailReplyPlacement"];
        if (replyPlacement == "above" || !mailIsReply) {
            // For forwards, place caret at top unconditionally
            this.setCaretTo(0);
        }
        else {
            var caretPosition = this.getValue().length - MailEditor.signatureLength;
            caretPosition = adjustOffset(this, caretPosition);
            if (hasSignature())
                caretPosition -= 2;
            this.setCaretTo(caretPosition);
        }
        MailEditor.textFirstFocus = false;
    }
}

/**
 * Change behavior of tab key in textarea (plain-text mail)
 */
function onTextKeyDown(event) {
    if (event.keyCode == Event.KEY_TAB) {
        if (event.shiftKey) {
            // Shift-tab goes back to subject field
            var subjectField = $$("div#subjectRow input").first();
            subjectField.focus();
            subjectField.selectText(0, subjectField.value.length);
            preventDefault(event);
        }
        else {
            if (!(event.shiftKey || event.metaKey || event.ctrlKey)) {
                // Convert a tab to 4 spaces
                if (typeof(this.selectionStart) != "undefined") { // Mozilla and Safari
                    var cursor = this.selectionStart;
                    var startText = ((cursor > 0)
                                     ? this.value.substr(0, cursor)
                                     : "");
                    var endText = this.value.substr(cursor);
                    var newText = startText + "    " + endText;
                    this.value = newText;
                    cursor += 4;
                    this.setSelectionRange(cursor, cursor);
                }
                else if (this.selectionRange) // IE
                    this.selectionRange.text = "    ";
                preventDefault(event);
            }
        }
    }
}

function onTextIEUpdateCursorPos(event) {
    this.selectionRange = document.selection.createRange().duplicate();
}

function onHTMLFocus(event) {
    if (MailEditor.textFirstFocus) {
        var s = event.editor.getSelection();
        var selected_ranges = s.getRanges();
        var children = event.editor.document.getBody().getChildren();
        var node;
        var caretAtTop = (UserDefaults["SOGoMailReplyPlacement"] == "above")
            || !mailIsReply; // for forwards, place caret at top unconditionally

        if (caretAtTop) {
            node = children.getItem(0);
        }
        else {
            // Search for signature starting from bottom
            node = children.getItem(children.count() - 1);
            while (true) {
                var x = node.getPrevious();
                if (x == null) {
                    break;
                }
                if (x.getText() == '--') {
                    node = x.getPrevious().getPrevious();
                    break;
                }
                node = x;
            }
        }

        s.selectElement(node);

        // Place the caret
        if (caretAtTop)
            s.scrollIntoView(); // top
        selected_ranges = s.getRanges();
        selected_ranges[0].collapse(true);
        s.selectRanges(selected_ranges);
        if (!caretAtTop)
            s.scrollIntoView(); // bottom

        MailEditor.textFirstFocus = false;
    }
}

function initAddresses() {
    var addressList = $("addressList");
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

function initAutoSaveTimer() {
    var autoSave = UserDefaults["SOGoMailAutoSave"];

    if (autoSave) {
        var interval;

        interval = parseInt(autoSave) * 60;
            
        autoSaveTimer = window.setInterval(onAutoSaveCallback,
                                           interval * 1000);
    }
}

function onAutoSaveCallback(event) {
    clickedEditorSave();
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

function configureAttachments() {
    var list = $("attachments");

    if (!list) return;

    list.on('click', 'a', function (event, element) {
            // Don't follow links of attachments not yet uploaded
            if (!element.up('li').hasClassName('progressDone')) {
                Event.stop(event);
                return false;
            }
        });

    list.on('click', 'i.icon-attachment', function (event, element) {
            // Delete attachment when clicking on small icon
            var item = element.up('li');
            if (item.hasClassName('progressDone')) {
                var filename = item.readAttribute('data-filename');
                var url = "" + window.location;
                var parts = url.split("/");
                parts[parts.length-1] = "deleteAttachment?filename=" + encodeURIComponent(filename);
                url = parts.join("/");
                triggerAjaxRequest(url, attachmentDeleteCallback, item);
            }
        });

    var dropzone = jQuery('#dropZone');
    jQuery('#fileUpload').fileupload({
            // With singleFileUploads option enabled, the 'add' and 'done' (or 'fail') callbacks
            // are called once for each file in the selection for XHR file uploads
            singleFileUploads: true,
            pasteZone: null,
            dataType: 'json',
            add: function (e, data) {
                var file = data.files[0];
                var attachment = createAttachment(file);
                if (attachment) {
                    file.attachment = attachment;
                    // Update the text field when using HTML mode
                    if (CKEDITOR.instances.text) CKEDITOR.instances.text.updateElement();
                    data.submit();
                }
                if (dropzone.is(":visible"))
                    dropzone.fadeOut('fast');
            },
            done: function (e, data) {
                var attachment = data.files[0].attachment;
                var attrs = data.result[data.result.length-1];
                attachment.className = 'progressDone';
                attachment.down('a').setAttribute('href', attrs.url);
                if (window.opener && window.opener.open && !window.opener.closed)
                    window.opener.refreshFolderByType('draft');
            },
            fail: function (e, data) {
                var attachment = data.files[0].attachment;
                var filename = data.files[0].name;
                var textStatus;
                try {
                    var response = data.xhr().response.evalJSON();
                    textStatus = response.textStatus;
                } catch (e) {}
                if (!textStatus)
                    textStatus = _("Can't contact server");
                showAlertDialog(_("Error while uploading the file \"%{0}\":").formatted(filename) + " " + textStatus);
                attachment.remove();
            },
            dragover: function (e, data) {
                if (!dropzone.is(":visible"))
                    dropzone.show();
            },
            progress: function (e, data) {
                var progress = parseInt(data.loaded / data.total * 4, 10);
                var attachment = data.files[0].attachment;
                attachment.className = 'muted progress' + progress;
            }
        });

    dropzone.on('dragleave', function (e) {
            dropzone.fadeOut('fast');
    });
}

function initMailEditor() {
    var textarea = $("text");

    if (composeMode != "html" && $("text"))
        textarea.show();

    configureAttachments();
  
    initAddresses();
    initAutoSaveTimer();
    
    var focusField = textarea;
    if (!mailIsReply) {
        focusField = $("addr_0");
        focusField.focus();
    }

    initializePriorityMenu();
    initializeReturnReceiptMenu();

    configureDragHandle();

    // Set current subject as window title if not set, use '(Untitled)'
    if (document.pageform.subject.value == "")
        document.title = '(' + _("Untitled") + ')';
    else
        document.title = _(document.pageform.subject.value);

    // Change the window title when typing the subject
    $$("div#subjectRow input").first().on("keyup", updateWindowTitleFromSubject);

    var composeMode = UserDefaults["SOGoMailComposeMessageType"];
    if (composeMode == "html") {
        // HTML mode
        CKEDITOR.replace('text',
                         {
                             language : localeCode,
			     scayt_sLang : localeCode
                          }
                         );
        CKEDITOR.on('instanceReady', function(event) {
                if (focusField == textarea)
                    // CKEditor reports being ready but it's still not focusable;
                    // we wait for a few more milliseconds
                    setTimeout("CKEDITOR.instances.text.focus()", 500);
            });
        CKEDITOR.instances.text.on('focus', onHTMLFocus);
    }
    else {
        // Plain text mode
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
        textarea.observe("keydown", onTextKeyDown);

        if (Prototype.Browser.IE) {
            // Hack to allow to replace the tab by spaces in IE < 9
            var ieEvents = [ "click", "select", "keyup" ];
            for (var i = 0; i < ieEvents.length; i++)
                textarea.observe(ieEvents[i], onTextIEUpdateCursorPos, false);
        }

        if (focusField == textarea)
            textarea.focus();
    }

    $("contactFolder").observe("change", onContactFolderChange);
    
    Event.observe(window, "beforeunload", onMailEditorClose);
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

function initializeReturnReceiptMenu() {
    var receipt = $("receipt").value.toLowerCase();
    if (receipt == "true")
        $("optionsMenu").down('li').addClassName("_chosen");
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

/**
 * Adjust offset when the browser uses two characters for line feeds.
 */
function adjustOffset(element, offset) {
    var val = element.value, newOffset = offset;
    if (val.indexOf("\r\n") > -1) {
        var matches = val.replace(/\r\n/g, "\n").slice(0, offset).match(/\n/g);
        newOffset -= matches ? matches.length - 1 : 0;
    }
    return newOffset;
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

function onSelectOptions(event) {
    if (event.button == 0 || (isWebKit() && event.button == 1)) {
        var node = getTarget(event);
        if (node.tagName != 'A')
            node = $(node).up("A");
        popupToolbarMenu(node, "optionsMenu");
        Event.stop(event);
    }
}

/**
 * Overwrite definition of MailerUI.js
 */
function onWindowResize(event) {
    if (!document.pageform)
      return;
    var textarea = document.pageform.text;
    var rowheight = (Element.getHeight(textarea) / textarea.rows);
    var headerarea = $("headerArea");
    var totalwidth = $("rightPanel").getWidth();
  
    var subjectfield = headerarea.down("div#subjectRow span.headerField");
    var subjectinput = headerarea.down("div#subjectRow input.textField");
  
    // Resize subject field
    subjectinput.setStyle({ width: (totalwidth
                                    - $(subjectfield).getWidth()
                                    - 17) + 'px' });
    // Resize from field
    $("fromSelect").setStyle({ width: (totalwidth
                                       - $("fromField").getWidth()
                                       - 15) + 'px' });

    // Resize address fields
//    var addresslist = $('addressList');
//    addresslist.setStyle({ width: (totalwidth - 10) + 'px' });

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
    var e = event || window.event;

    if (window.shouldPreserve) {
        window.shouldPreserve = false;
        if (jQuery('#fileUpload').fileupload('active') > 0) {
            var msg = _("There is an active file upload. Closing the window will interrupt it.");
            if (e) {
                e.returnValue = msg;
            }
            return msg;
        }
    }
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
