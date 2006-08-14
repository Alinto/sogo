function newEvent(sender) {
  var urlstr;
  
  urlstr = "new";
  window.open(urlstr, "SOGo_compose",
	      "width=680,height=520,resizable=1,scrollbars=1,toolbar=0," +
	      "location=0,directories=0,status=0,menubar=0,copyhistory=0");
  return false; /* stop following the link */
}

function onContactRefresh(node)
{
  var parentNode = node.parentNode;
  var contacts = '';
  var done = false;

  var currentNode = parentNode.firstChild;
  while (currentNode && !done)
    {
      if (currentNode.nodeType == 1
          && currentNode.getAttribute("type") == "hidden")
        {
          contacts = currentNode.value;
          done = true;
        }
      else
        currentNode = currentNode.nextSibling;
    }

  log ('contacts: ' + contacts);
  if (contacts.length > 0)
    window.location = ApplicationBaseURL + '/show?userUIDString=' + contacts;

  return false;
}
