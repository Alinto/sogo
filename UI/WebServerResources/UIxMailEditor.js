var contactSelectorAction = 'mailer-contacts';

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
