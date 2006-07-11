/* contacts */
function newContactFromEmail(sender) {
  var emailre
    = /([a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z])/g;

  emailre.exec(menuClickNode.innerHTML);
  email = RegExp.$1;

  if (email.length > 0)
    {
      emailre.exec("");
      w = window.open("../../../../Contacts/new?contactEmail=" + email,
		      "SOGo_new_contact",
		      "width=680,height=520,resizable=1,scrollbars=1,toolbar=0," +
		      "location=0,directories=0,status=0,menubar=0,copyhistory=0");
      w.focus();
    }

  return false; /* stop following the link */
}

function newEmailTo(sender) {
  var mailto = sanitizeMailTo(menuClickNode.innerHTML);

  if (mailto.length > 0)
    {
      w = window.open("compose?mailto=" + mailto,
		      "SOGo_compose",
		      "width=680,height=520,resizable=1,scrollbars=1,toolbar=0," +
		      "location=0,directories=0,status=0,menubar=0,copyhistory=0");
      w.focus();
    }

  return false; /* stop following the link */
}
