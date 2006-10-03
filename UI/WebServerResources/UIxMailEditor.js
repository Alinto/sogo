var contactSelectorAction = 'mailer-contacts';

function addContact(tag, fullContactName, contactId, contactName, contactEmail)
{
  if (!mailIsRecipient(contactEmail)) {
    var neededOptionValue = 0;
    if (tag == "cc")
      neededOptionValue = 1;
    else if (tag == "bcc")
      neededOptionValue = 2;
    var rows = $("addressList").childNodes;

    var stop = false;
    var counter = 0;
    var currentRow = $('row_' + counter);
    while (currentRow
           && !stop) {
      var currentValue = currentRow.childNodes[0].childNodes[0].value;
      if (currentValue == neededOptionValue) {
        stop = true;
        insertContact($("addr_" + counter), contactName, contactEmail);
      }
      counter++;
      currentRow = $('row_' + counter);
    }

    if (!stop) {
      fancyAddRow(false, "");
      $("row_" + counter).childNodes[0].childNodes[0].value
        = neededOptionValue;
      insertContact($("addr_" + counter), contactName, contactEmail);
    }
  }
}

function mailIsRecipient(mailto) {
  var isRecipient = false;

  var counter = 0;
  var currentRow = $('row_' + counter);

  var email = extractEmailAddress(mailto);

  while (currentRow && !isRecipient) {
    var currentValue = $("addr_"+counter).value;
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
