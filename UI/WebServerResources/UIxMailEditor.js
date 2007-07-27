var contactSelectorAction = 'mailer-contacts';

function onContactAdd() {
  var selector = null;
  var selectorURL = '?popup=YES&selectorId=mailer-contacts';
 
  urlstr = ApplicationBaseURL;
  if (urlstr[urlstr.length-1] != '/')
    urlstr += '/';
  urlstr += ("../../" + UserLogin + "/Contacts/"
             + contactSelectorAction + selectorURL);
//   log (urlstr);
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
    while (currentRow
           && !stop) {
      var currentValue = currentRow.childNodesWithTag("span")[1].childNodesWithTag("input")[0].value;
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
      errortext = errortext + labels.error_missingsubject + "\n";

   if (!UIxRecipientSelectorHasRecipients())
      errortext = errortext + labels.error_missingrecipients + "\n";
   
   if (errortext.length > 0) {
      alert(labels.error_validationfailed.decodeEntities() + ":\n"
	    + errortext.decodeEntities());
      return false;
   }
   return true;
}

function clickedEditorSend(sender) {
   if (!validateEditorInput(sender))
      return false;

   document.pageform.action = "send";
   document.pageform.submit();

   window.alert("cocou");

   return false;
}

function clickedEditorAttach(sender) {
  var area = $("attachmentsArea");

  area.setStyle({ display: "block" });
  
  var inputs = area.getElementsByTagName("input");
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
  var area = $("attachmentsArea");
  var inputs = area.getElementsByTagName("input");
  var attachmentName = "attachment" + inputs.length;
  var newAttachment = createElement("input", attachmentName,
				    "currentAttachment", null,
				    { type: "file",
				      name: attachmentName },
				    area);
  Event.observe(newAttachment, "change",
		onAttachmentChange.bindAsEventListener(newAttachment));
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
   document.pageform.action = "save";
   document.pageform.submit();
   refreshOpener();

  return false;
}

function clickedEditorDelete(sender) {
   document.pageform.action = "delete";
   document.pageform.submit();
   refreshOpener();
   window.close();

  return false;
}

function initMailEditor() {
  var list = $("attachments");
  $(list).attachMenu("attachmentsMenu");
  var elements = list.childNodesWithTag("li");
  for (var i = 0; i < elements.length; i++)
    Event.observe(elements[i], "click",
		  onRowClick.bindAsEventListener(elements[i]));
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
    else
      window.alert("Server attachments not handled");
  }
}

function onSelectAllAttachments() {
  var list = $("attachments");
  var nodes = list.childNodesWithTag("li");
  for (var i = 0; i < nodes.length; i++)
    nodes[i].select();
}

window.addEventListener("load", initMailEditor, false);
