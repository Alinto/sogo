function newContact(sender) {
  var urlstr;

  urlstr = "new";
  newcwin = window.open(urlstr, "SOGo_new_contact",
			"width=680,height=520,resizable=1,scrollbars=1,toolbar=0," +
			"location=0,directories=0,status=0,menubar=0,copyhistory=0");
  newcwin.focus();

  return false; /* stop following the link */
}

