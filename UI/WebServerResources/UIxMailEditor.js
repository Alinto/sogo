/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

var contactSelectorAction = 'mailer-contacts';
var signatureLength = 0;

var attachmentCount = 0;
var MailEditor = {
 addressBook: null,
 currentField: null,
 selectedIndex: -1,
 delay: 750,
 delayedSearch: false
};

function onContactAdd() {
	var selector = null;
	var selectorURL = '?popup=YES&selectorId=mailer-contacts';
 
	if (MailEditor.addressBook && MailEditor.addressBook.open && !MailEditor.addressBook.closed)
		MailEditor.addressBook.focus();
	else {
		var urlstr = ApplicationBaseURL 
			+ "../Contacts/"
			+ contactSelectorAction + selectorURL;
		MailEditor.addressBook = window.open(urlstr, "_blank",
																				 "width=640,height=400,resizable=1,scrollbars=0");
		MailEditor.addressBook.selector = selector;
		MailEditor.addressBook.opener = self;
		MailEditor.addressBook.focus();
	}
  
	return false;
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
			fancyAddRow(false, "");
			$($("row_" + counter).childNodesWithTag("td")[0]).childNodesWithTag("select")[0].value
				= neededOptionValue;
			insertContact($("addr_" + counter), contactName, contactEmail);
			onWindowResize(null);
		}
	}
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

function toggleAttachments() {
	var div = $("attachmentsArea");
	var style = "" + div.getStyle("display");
	if (style.length)
		div.setStyle({ display: "" });
	else
		div.setStyle({ display: "block" });

	return false;
}

function updateInlineAttachmentList(sender, attachments) {
	var count = 0;

	var div = $("attachmentsArea");
	if (attachments)
		count = attachments.length;

	if (count) {
		var text  = "";
		for (var i = 0; i < count; i++) {
			text = text + attachments[i];
			text = text + '<br />';
		}

		var e = $('compose_attachments_list');
		e.innerHTML = text;
		var style = "" + div.getStyle("display");
		if (!style.length)
			div.setStyle({display: "block"});
	}
	else
		div.setStyle({display: ""});
}
/* mail editor */

function validateEditorInput(sender) {
	var errortext = "";
	var field;
   
	field = document.pageform.subject;
	if (field.value == "")
		errortext = errortext + labels["error_missingsubject"] + "\n";

	if (!hasRecipients())
		errortext = errortext + labels["error_missingrecipients"] + "\n";
   
	if (errortext.length > 0) {
		alert(labels["error_validationfailed"] + ":\n" + errortext);
		return false;
	}

	return true;
}

function clickedEditorSend(sender) {
	if (!validateEditorInput(sender))
		return false;

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
	document.pageform.submit();
  
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

function clickedEditorAttach(sender) {
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

function onAddAttachment() {
	return clickedEditorAttach(null);
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
	attachment.observe("click", onRowClick);

	var filename = node.value;
	var separator;
	if (navigator.appVersion.indexOf("Windows") > -1)
		separator = "\\";
	else
		separator = "/";
	var fileArray = filename.split(separator);
	var attachmentName = document.createTextNode(fileArray[fileArray.length-1]);
	attachment.appendChild(attachmentName);
}

function clickedEditorSave(sender) {
	var input = currentAttachmentInput();
	if (input)
		input.parentNode.removeChild(input);

	var lastRow = $("lastRow");
	lastRow.down("select").name = "popup_last";

	window.shouldPreserve = true;
	document.pageform.action = "save";
	document.pageform.submit();

	if (window.opener && window.open && !window.closed)
		window.opener.refreshFolderByType('draft');
	return false;
}

function onTextFocus() {
	var input = currentAttachmentInput();
	if (input)
		input.parentNode.removeChild(input);
}

function onTextKeyDown(event) {
	if (event.keyCode == Event.KEY_TAB) {
		if (event.shiftKey) {
			var nodes = $("subjectRow").childNodesWithTag("input");
			var objectInput = $(nodes[0]);
			objectInput.focus();
			objectInput.selectText(0, objectInput.value.length);
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

function onTextFirstFocus() {
	var content = this.getValue();
	if (content.lastIndexOf("--") == 0) {
		this.insertBefore(document.createTextNode("\r"),
											this.lastChild);
	}
	if (signatureLength > 0) {
		var length = this.getValue().length - signatureLength - 2;
		this.setCaretTo(length);
	}
	Event.stopObserving(this, "focus", onTextFirstFocus);
}

function onTextContextMenu(event) {
	event.returnValue = true;
	event.cancelBubble = true;
}

function onTextMouseDown(event) {
	if (event.button == 0) {
		event.returnValue = false;
		event.cancelBubble = false;
	}
}

/* address completion */

function onContactKeydown(event) {
	if (event.ctrlKey || event.metaKey) {
		this.focussed = true;
		return;
	}
	if (event.keyCode == Event.KEY_TAB) {
		if (this.confirmedValue)
			this.value = this.confirmedValue;
		if (document.currentPopupMenu)
			hideMenu(document.currentPopupMenu);
	}
	else if (event.keyCode == 0
					 || event.keyCode == Event.KEY_BACKSPACE
					 || event.keyCode == 32  // Space
					 || event.keyCode > 47) {
		this.confirmedValue = null;
		MailEditor.selectedIndex = -1;
		MailEditor.currentField = this;
		if (this.value.length > 1 && MailEditor.delayedSearch == false) {
			MailEditor.delayedSearch = true;
			setTimeout("performSearch()", MailEditor.delay);
		}
		else if (this.value.length == 0) {
			if (document.currentPopupMenu)
				hideMenu(document.currentPopupMenu);
		}
	}
	else if (event.keyCode == Event.KEY_RETURN) {
		preventDefault(event);
		if (this.confirmedValue)
			this.value = this.confirmedValue;
		$(this).select();
		if (document.currentPopupMenu)
			hideMenu(document.currentPopupMenu);
		MailEditor.selectedIndex = -1;
	}
	else if ($('contactsMenu').getStyle('visibility') == 'visible') {
		if (event.keyCode == Event.KEY_UP) { // Up arrow
			if (MailEditor.selectedIndex > 0) {
				var contacts = $('contactsMenu').select("li");
				contacts[MailEditor.selectedIndex--].removeClassName("selected");
				this.value = contacts[MailEditor.selectedIndex].firstChild.nodeValue.trim();
				contacts[MailEditor.selectedIndex].addClassName("selected");
			}
		}
		else if (event.keyCode == Event.KEY_DOWN) { // Down arrow
			var contacts = $('contactsMenu').select("li");
			if (contacts.size() - 1 > MailEditor.selectedIndex) {
				if (MailEditor.selectedIndex >= 0)
					contacts[MailEditor.selectedIndex].removeClassName("selected");
				MailEditor.selectedIndex++;
				this.value = contacts[MailEditor.selectedIndex].firstChild.nodeValue.trim();
				contacts[MailEditor.selectedIndex].addClassName("selected");
			}
		}
	}
}

function performSearch() {
	// Perform address completion
	if (MailEditor.currentField) {
		if (document.contactLookupAjaxRequest) {
			// Abort any pending request
			document.contactLookupAjaxRequest.aborted = true;
			document.contactLookupAjaxRequest.abort();
		}
		if (MailEditor.currentField.value.trim().length > 1) {
			var urlstr = ( UserFolderURL + "Contacts/allContactSearch?search="
										 + MailEditor.currentField.value );
			document.contactLookupAjaxRequest =
				triggerAjaxRequest(urlstr, performSearchCallback, MailEditor.currentField);
		}
	}
	MailEditor.delayedSearch = false;
}

function performSearchCallback(http) {
	if (http.readyState == 4) {
		var menu = $('contactsMenu');
		var list = menu.down("ul");
    
		var input = http.callbackData;
    
		if (http.status == 200) {
			var start = input.value.length;
			var data = http.responseText.evalJSON(true);
      
			if (data.length > 1) {
				list.select("li").each(function(item) {
						item.remove();
					});
	
				// Populate popup menu
				for (var i = 0; i < data.length; i++) {
					var contact = data[i];
					var completeEmail = contact["displayName"] + " <" + contact["mail"] + ">";
					var node = document.createElement("li");
					list.appendChild(node);
					node.uid = contact["c_uid"];
					node.appendChild(document.createTextNode(completeEmail));
					$(node).observe("mousedown", onAddressResultClick);
				}

				// Show popup menu
				var offsetScroll = Element.cumulativeScrollOffset(MailEditor.currentField);
				var offset = Element.cumulativeOffset(MailEditor.currentField);
				var top = offset[1] - offsetScroll[1] + node.offsetHeight + 3;
				var height = 'auto';
				var heightDiff = window.height() - offset[1];
				var nodeHeight = node.getHeight();

				if ((data.length * nodeHeight) > heightDiff)
					// Limit the size of the popup to the window height, minus 12 pixels
					height = parseInt(heightDiff/nodeHeight) * nodeHeight - 12 + 'px';

				menu.setStyle({ top: top + "px",
							left: offset[0] + "px",
							height: height,
							visibility: "visible" });
				menu.scrollTop = 0;

				document.currentPopupMenu = menu;
				$(document.body).observe("click", onBodyClickMenuHandler);
			}
			else {
				if (document.currentPopupMenu)
					hideMenu(document.currentPopupMenu);

				if (data.length == 1) {
					// Single result
					var contact = data[0];
					if (contact["c_uid"].length > 0)
						input.uid = contact["c_uid"];
					var completeEmail = contact["displayName"] + " <" + contact["mail"] + ">";
					if (contact["displayName"].substring(0, input.value.length).toUpperCase()
							== input.value.toUpperCase())
						input.value = completeEmail;
					else
						// The result matches email address, not user name
						input.value += ' >> ' + completeEmail;
					input.confirmedValue = completeEmail;
	  
					var end = input.value.length;
					$(input).selectText(start, end);

					MailEditor.selectedIndex = -1;
				}
			}
		}
		else
			if (document.currentPopupMenu)
				hideMenu(document.currentPopupMenu);
		document.contactLookupAjaxRequest = null;
	}
}

function onAddressResultClick(event) {
	if (MailEditor.currentField) {
		MailEditor.currentField.uid = this.uid;
		MailEditor.currentField.value = this.firstChild.nodeValue.trim();
		MailEditor.currentField.confirmedValue = MailEditor.currentField.value;
	}
}

function initTabIndex(addressList, subjectField, msgArea) {
	var i = 1;
	addressList.select("input.textField").each(function (input) {
			if (!input.readAttribute("readonly")) {
				input.writeAttribute("tabindex", i++);
				input.writeAttribute("autocomplete", "off");
				input.observe("keydown", onContactKeydown); // bind listener for address completion
			}
		});
	subjectField.writeAttribute("tabindex", i++);
	msgArea.writeAttribute("tabindex", i);
}

function initMailEditor() {
	var list = $("attachments");
	$(list).attachMenu("attachmentsMenu");
	var elements = $(list).childNodesWithTag("li");
	for (var i = 0; i < elements.length; i++)
		elements[i].observe("click", onRowClick);

	var listContent = $("attachments").childNodesWithTag("li");
	if (listContent.length > 0)
		$("attachmentsArea").setStyle({ display: "block" });

	var textarea = $("text");
  
	var textContent = textarea.getValue();
	var sigLimit = textContent.lastIndexOf("--");
	if (sigLimit > -1)
		signatureLength = (textContent.length - sigLimit);
	textarea.scrollTop = textarea.scrollHeight;
	textarea.observe("focus", onTextFirstFocus);
	textarea.observe("focus", onTextFocus);
	//   textarea.observe("contextmenu", onTextContextMenu);
	textarea.observe("mousedown", onTextMouseDown, true);
	textarea.observe("keydown", onTextKeyDown);

	if (Prototype.Browser.IE) {
		var ieEvents = [ "click", "select", "keyup" ];
		for (var i = 0; i < ieEvents.length; i++)
			textarea.observe(ieEvents[i], onTextIEUpdateCursorPos, false);
	}

	var subjectField = $$("div#subjectRow input").first();
	initTabIndex($("addressList"), subjectField, textarea);
	onWindowResize(null);

	Event.observe(window, "resize", onWindowResize);
	Event.observe(window, "beforeunload", onMailEditorClose);

	var focusField = (mailIsReply ? textarea : $("addr_0"));
	focusField.focus();
}

function getMenus() {
	return { "attachmentsMenu": new Array(null, onRemoveAttachments,
																				onSelectAllAttachments,
																				"-",
																				onAddAttachment, null) };
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
			var filename = "";
			var childNodes = nodes[i].childNodes;
			for (var j = 0; j < childNodes.length; j++) {
				if (childNodes[j].nodeType == 3)
					filename += childNodes[j].nodeValue;
			}
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

function onSelectAllAttachments() {
	var list = $("attachments");
	var nodes = list.childNodesWithTag("li");
	for (var i = 0; i < nodes.length; i++)
		nodes[i].selectElement();
}

function onWindowResize(event) {
	var textarea = document.pageform.text;
	var rowheight = (Element.getHeight(textarea) / textarea.rows);
	var headerarea = $("headerArea");
  
	var attachmentsarea = $("attachmentsArea");
	var attachmentswidth = 0;
	if (attachmentsarea.style.display) {
		attachmentswidth = attachmentsarea.getWidth();
		// Resize of attachment list is b0rken under IE7
		//    fromfield = $(document).getElementsByClassName('headerField',
		//						   headerarea)[0];
		//    $("attachments").setStyle({ height: (headerarea.getHeight() - fromfield.getHeight() - 10) + 'px' });
	}
	var subjectfield = headerarea.down("div#subjectRow span.headerField");
	var subjectinput = headerarea.down("div#subjectRow input.textField");
  
	// Resize subject field
	subjectinput.setStyle({ width: (window.width()
																	- $(subjectfield).getWidth()
																	- attachmentswidth
																	- 16) + 'px' });

	// Resize address fields
	var addresslist = $('addressList');
	addresslist.setStyle({ width: ($(this).width() - attachmentswidth - 10) + 'px' });

	// Set textarea position
	var hr = headerarea.select("hr").first();
	textarea.setStyle({ 'top': hr.offsetTop + 'px' });

	// Resize the textarea (message content)
	textarea.rows = Math.floor((window.height() - textarea.offsetTop) / rowheight);
}

function onMailEditorClose(event) {
	if (window.shouldPreserve)
		window.shouldPreserve = false;
	else {
		if (window.opener && window.opener.open && !window.opener.closed) {
			var url = "" + window.location;
			var parts = url.split("/");
			parts[parts.length-1] = "delete";
			url = parts.join("/");
			window.opener.deleteDraft(url);
		}
	}

	if (MailEditor.addressBook && MailEditor.addressBook.open
			&& !MailEditor.addressBook.closed)
		MailEditor.addressBook.close();

	Event.stopObserving(window, "beforeunload", onMailEditorClose);
}

FastInit.addOnLoad(initMailEditor);
