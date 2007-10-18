function initLogin() {
  var date = new Date();
  date.setTime(date.getTime() - 86400000);
  document.cookie = ("0xHIGHFLYxSOGo-0.9=discard; path=/"
		     + "; expires=" + date.toGMTString());
  var submit = $("submit");
  Event.observe(submit, "click", onLoginClick);

  var userName = $("userName");
  userName.focus();

  var image = $("preparedAnimation");
  image.parentNode.removeChild(image);
}

function onLoginClick(event) {
  startAnimation($("loginButton"), $("submit"));

  var userName = $("userName").value;
  var password = $("password").value;

  if (userName.length > 0) {
    var url = ($("connectForm").getAttribute("action")
	       + "?userName=" + userName
	       + "&password=" + password);
    document.cookie = "";
    triggerAjaxRequest(url, onLoginCallback);
  }

  preventDefault(event);
}

function onLoginCallback(http) {
  if (http.readyState == 4) {
    if (isHttpStatus204(http.status)) {
      window.location.href = ApplicationBaseURL + $("userName").value;
    }
  }
}

addEvent(window, 'load', initLogin);
