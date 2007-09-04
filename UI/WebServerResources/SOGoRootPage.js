function initLogin() {
  var submit = $("submit");
  var userName = $("userName");
  userName.focus();
  Event.observe(submit, "click", onLoginClick);
}

function onLoginClick(event) {
  startAnimation($("loginButton"), $("submit"));

  var loginString = $("userName").value + ":" + $("password").value;
  document.cookie = ("0xHIGHFLYxSOGo-0.9 = basic" + loginString.base64encode()
		     + "; path=/");
}

addEvent(window, 'load', initLogin);
