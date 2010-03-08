var PolicyPasswordChangeUnsupported = -3;
var PolicyPasswordSystemUnknown = -2;
var PolicyPasswordUnknown = -1;
var PolicyPasswordExpired = 0;
var PolicyAccountLocked = 1;
var PolicyChangeAfterReset = 2;
var PolicyPasswordModNotAllowed = 3;
var PolicyMustSupplyOldPassword = 4;
var PolicyInsufficientPasswordQuality = 5;
var PolicyPasswordTooShort = 6;
var PolicyPasswordTooYoung = 7;
var PolicyPasswordInHistory = 8;
var PolicyNoError = 65535;

function _passwordPolicyAjaxCallback(http) {
    if (http.readyState == 4) {
        var policy = http.callbackData;
        policy.callback(http);
    }
}

function PasswordPolicy(userName, password) {
    this.userName = userName;
    this.password = password;
}

PasswordPolicy.prototype = {
    userName: null,
    password: null,
    successCallback: null,
    failureCallback: null,

    setCallbacks: function(successCallback, failureCallback) {
        this.successCallback = successCallback;
        this.failureCallback = failureCallback;
    },

    changePassword: function (newPassword) {
        var content = Object.toJSON({ userName: this.userName,
                                      password: this.password,
                                      newPassword: newPassword });
        var urlParts = ApplicationBaseURL.split("/");
        var url = urlParts[1] + "/so/changePassword";
        triggerAjaxRequest(url, _passwordPolicyAjaxCallback, this,
                           content, {"content-type": "application/json"} );
    },

    callback: function(http) {
        if (isHttpStatus204(http.status)) {
            if (this.successCallback)
                this.successCallback(_("The password was changed successfully."));
        } else {
            if (this.failureCallback) {
                var perr = PolicyPasswordUnknown;
                var error = "";
                switch (http.status) {
                case 403:
                    if (http.getResponseHeader("content-type")
                        == "application/json") {
                        var jsonResponse = http.responseText.evalJSON(false);
                        perr = jsonResponse["LDAPPasswordPolicyError"];
                        
                        // Normal password change failed
                        if (perr == PolicyNoError) {
                            error = _("Password change failed");
                        } else if (perr == PolicyPasswordModNotAllowed) {
                            error = _("Password change failed - Permission denied");
                        } else if (perr == PolicyInsufficientPasswordQuality) {
                            error = _("Password change failed - Insufficient password quality");
                        }  else if (perr == PolicyPasswordTooShort) {
                            error = _("Password change failed - Password is too short");
                        } else if (perr == PolicyPasswordTooYoung) {
                            error = _("Password change failed - Password is too young");
                        } else if (perr == PolicyPasswordInHistory) {
                            error = _("Password change failed - Password is in history");
                        } else {
                            error = _("Unhandled policy error: %{0}").formatted(perr);
                            perr = PolicyPasswordUnknown;
                        }
                    } else {
                        perr = PolicyPasswordSystemUnknown;
                        error = _("Unhandled error response");
                    }
                    break;
                case 404:
                    perr = PolicyPasswordChangeUnsupported;
                    error = _("Password change is not supported.");
                    break;
                default:
                    perr = PolicyPasswordSystemUnknown;
                    error = _("Unhandled HTTP error code: %{0]").formatted(http.status);
                }
                this.failureCallback(perr, error);
                // showPasswordMessage(error);
            }
        }
    }
};
