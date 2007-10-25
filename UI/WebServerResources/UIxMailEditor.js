var contactSelectorAction = 'mailer-contacts';

function onContactAdd() {
  var selector = null;
  var selectorURL = '?popup=YES&selectorId=mailer-contacts';
 
  urlstr = ApplicationBaseURL;
  if (urlstr[urlstr.length-1] != '/')
    urlstr += '/';
  urlstr += ("../../" + UserLogin + "/Contacts/"
             + contactSelectorAction + selectorURL);
  var w = window.open(urlstr, "Addressbook",
                      "width=640,height=400,resizable=1,scrollbars=0");
  w.selector = selector;
  w.opener = this;
  w.focus();

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
      var currentValue = $(currentRow.childNodesWithTag("span")[1]).childNodesWithTag("input")[0].value;
      if (currentValue == neededOptionValue) {
        stop = true;
        insertContact($("addr_" + counter), contactName, contactEmail);
      }
      counter++;
      currentRow = $('row_' + counter);
    }

    if (!stop) {
      fancyAddRow(false, "");
      $("row_" + counter).childNodesWithTag("span")[0].childNodesWithTag("select")[0].value
        = neededOptionValue;
      insertContact($("addr_" + counter), contactName, contactEmail);
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
  if (div.style.display)
    div.style.display = "";
  else
    div.style.display = "block;";

  return false;
}

function updateInlineAttachmentList(sender, attachments) {
  var count = 0;

  var div = $("attachmentsArea");
  if (attachments)
    count = attachments.length;
  if (count)
    {
      var text  = "";
      for (var i = 0; i < count; i++) {
        text = text + attachments[i];
        text = text + '<br />';
      }

      var e = $('compose_attachments_list');
      e.innerHTML = text;
      if (!div.style.display)
        div.style.display = "block;";
    }
  else
    div.style.display = "";
}
/* mail editor */

function validateEditorInput(sender) {
   var errortext = "";
   var field;
   
   field = document.pageform.subject;
   if (field.value == "")
      errortext = errortext + labels["error_missingsubject"] + "\n";

   if (!UIxRecipientSelectorHasRecipients())
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

   window.shouldPreserve = true;
   document.pageform.action = "send";
   document.pageform.submit();

   return false;
}

function clickedEditorAttach(sender) {
  var area = $("attachmentsArea");

  if (!area.style.display) {
    area.setStyle({ display: "block" });
    onWindowResize(null);
  }  

  var inputs = area.getElementsByTagName("input");

  // Verify if there's already a visible file input field
  for (var i = 0; i < inputs.length; i++)
    if ($(inputs[i]).hasClassName("currentAttachment"))
      return false;
  
  // Add new file input field
  var attachmentName = "attachment" + inputs.length;
  var newAttachment = createElement("input", attachmentName,
				    "currentAttachment", null,
				    { type: "file",
				      name: attachmentName },
				    area);
  Event.observe(newAttachment, "change",
		onAttachmentChange.bindAsEventListener(newAttachment));

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
  }
}

function createAttachment(node, list) {
  var attachment = createElement("li", null, null, { node: node }, null, list);
  createElement("img", null, null, { src: ResourcesURL + "/attachment.gif" },
		null, attachment);
  Event.observe(attachment, "click", onRowClick);

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
  window.shouldPreserve = true;
  document.pageform.action = "save";
  document.pageform.submit();

  refreshMailbox();
  return false;
}

function initMailEditor() {
  var list = $("attachments");
  $(list).attachMenu("attachmentsMenu");
  var elements = list.childNodesWithTag("li");
  for (var i = 0; i < elements.length; i++) {
    Event.observe(elements[i], "click",
		  onRowClick.bindAsEventListener(elements[i]));
  }

  var listContent = $("attachments").childNodesWithTag("li");
  if (listContent.length > 0)
    $("attachmentsArea").setStyle({ display: "block" });

  onWindowResize(null);
  Event.observe(window, "resize", onWindowResize);
  Event.observe(window, "beforeunload", onMailEditorClose);
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
    nodes[i].select();
}

function onWindowResize(event) {
  var textarea = document.pageform.text;
  var rowheight = (Element.getHeight(textarea) / textarea.rows);
  var headerarea = $("headerArea");

  // Set textarea position
  textarea.setStyle({ 'top': (headerarea.getHeight() + headerarea.offsetTop) + 'px' });

  var textareaoffset = textarea.offsetTop;

  // Resize the textarea (message content)
  textarea.rows = Math.round((window.height() - textareaoffset) / rowheight);
  
  var attachmentsarea = $("attachmentsArea");
  var attachmentswidth = 0;
  if (attachmentsarea.style.display)
    attachmentswidth = attachmentsarea.getWidth();
  var subjectfield = $(document).getElementsByClassName('headerField',
							$('subjectRow'))[0];
  var subjectinput = $(document).getElementsByClassName('textField',
							$('subjectRow'))[0];

  // Resize subject field
  subjectinput.setStyle({ width: (window.width()
				  - $(subjectfield).getWidth()
				  - attachmentswidth
				  - 4 - 30) + 'px' });

  // Resize address fields
  var addresslist = $('addressList');
  var firstselect = document.getElementsByClassName('headerField', addresslist)[0];
  var inputwidth = ($(this).width() - $(firstselect).getWidth()
		    - attachmentswidth - 24 - 30);
  var addresses = document.getElementsByClassName('textField', addresslist);
  for (var i = 0; i < addresses.length; i++)
    addresses[i].setStyle({ width: inputwidth + 'px' });
}

function onMailEditorClose(event) {
  if (window.shouldPreserve)
    window.shouldPreserve = false;
  else {
    var url = "" + window.location;
    var parts = url.split("/");
    parts[parts.length-1] = "delete";
    url = parts.join("/");
    http = createHTTPClient();
    http.open("POST", url, false /* not async */);
    http.send("");
  }

  Event.stopObserving(window, "beforeunload", onMailEditorClose);
}

addEvent(window, 'load', initMailEditor);
