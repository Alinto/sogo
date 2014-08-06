/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* JavaScript for SOGoContacts */

(function() {
'use strict';

    angular.module('SOGo.Authentication', [])
    
    .constant('passwordPolicyConfig', {
        'PolicyPasswordChangeUnsupported': -3,
        'PolicyPasswordSystemUnknown': -2,
        'PolicyPasswordUnknown': -1,
        'PolicyPasswordExpired': 0,
        'PolicyAccountLocked': 1,
        'PolicyChangeAfterReset': 2,
        'PolicyPasswordModNotAllowed': 3,
        'PolicyMustSupplyOldPassword': 4,
        'PolicyInsufficientPasswordQuality': 5,
        'PolicyPasswordTooShort': 6,
        'PolicyPasswordTooYoung': 7,
        'PolicyPasswordInHistory': 8,
        'PolicyNoError': 65535
    })
    
    // TODO: convert to a Factory recipe?
    .provider('Authentication', function(passwordPolicyConfig) {
        this.readCookie = function(name) {
            var foundCookie = null;
    
            var prefix = name + "=";
            var pairs = document.cookie.split(';');
            for (var i = 0; !foundCookie && i < pairs.length; i++) {
                var currentPair = pairs[i];
                var start = 0;
                while (currentPair.charAt(start) == " ")
                    start++;
                if (start > 0)
                    currentPair = currentPair.substr(start);
                if (currentPair.indexOf(prefix) == 0)
                    foundCookie = currentPair.substr(prefix.length);
            }
    
            return foundCookie;
        };
    
        this.readLoginCookie = function() {
            var loginValues = null;
            var cookie = this.readCookie("0xHIGHFLYxSOGo");
            if (cookie && cookie.length > 8) {
                var value = decodeURIComponent(cookie.substr(8));
                loginValues = value.base64decode().split(":");
            }
    
            return loginValues;
        };
    
        this.redirectUrl = function(username, domain) {
            var userName = username;
            if (domain)
                userName += '@' + domain.value;
            var address = "" + window.location.href;
            var baseAddress = ApplicationBaseURL + "/" + encodeURIComponent(userName);
            var altBaseAddress;
            if (baseAddress[0] == "/") {
                var parts = address.split("/");
                var hostpart = parts[2];
                var protocol = parts[0];
                baseAddress = protocol + "//" + hostpart + baseAddress;
            }
            var altBaseAddress;
            var parts = baseAddress.split("/");
            parts.splice(0, 3);
            altBaseAddress = parts.join("/");
            var newAddress;
            if ((address.startsWith(baseAddress)
                 || address.startsWith(altBaseAddress))
                && !address.endsWith("/logoff")) {
                newAddress = address;
            } else {
                newAddress = baseAddress;
            }
            if (/theme=mobile/.test(window.location.search)) {
                return baseAddress + '/Contacts' + '?theme=mobile';
            }
            return newAddress.replace(/(Calendar|Mail)/, 'Contacts');
            return newAddress;
        };
    
        this.$get = ['$q', '$http', function($q, $http) {
            var self = this;
            var service = {
                // login: function(username, password, domain, language, rememberLogin) {
                //     var d = $q.defer();
                login: function(data) {
                    var d = $q.defer(),
                        username = data.username,
                        password = data.password,
                        domain = data.domain,
                        language,
                        rememberLogin = data.rememberLogin ? 1 : 0;
    
                    if (data.loginSuffix && !username.endsWith(data.loginSuffix)) {
                        username += loginSuffix;
                        domain = false;
                    }
                    if (data.language && data.language != 'WONoSelectionString') {
                        language = data.language;
                    }
    
                    $http({
                        method: 'POST',
                        url: '/SOGo/connect',
                        data: {'userName': username,
                                 'password': password,
                                 'domain': domain,
                                 'language': language,
                                 'rememberLogin': rememberLogin}
                    }).success(function(data, status) {
                        // Make sure browser's cookies are enabled
                        var loginCookie = self.readLoginCookie();
                        if (!loginCookie) {
                            d.reject(l("cookiesNotEnabled"));
                        }
                        else {
                            // Check password policy
                            if (typeof(data['expire']) != 'undefined' && typeof(data['grace']) != 'undefined') {
                                if (data['expire'] < 0 && data['grace'] > 0) {
                                    d.reject({'grace': data['grace']});
                                    //showPasswordDialog('grace', createPasswordGraceDialog, data['grace']);
                                } else if (data['expire'] > 0 && data['grace'] == -1) {
                                    d.reject({'expire': data['expire']});
                                    //showPasswordDialog('expiration', createPasswordExpirationDialog, data['expire']);
                                }
                                else {
                                    d.resolve(self.redirectUrl(username, domain));
                                }
                            }
                            else {
                                d.resolve(self.redirectUrl(username, domain));
                            }
                        }
                    }).error(function(data, status) {
                        var msg;
                        if (data && data['LDAPPasswordPolicyError']) {
                            var perr = data['LDAPPasswordPolicyError'];
                            if (perr == passwordPolicyConfig.PolicyNoError) {
                                msg = l("Wrong username or password.");
                            }
                            else {
                                msg = l("Login failed due to unhandled error case: " + perr);
                            }
                        }
                        else {
                            msg = l("Unhandled error response");
                        }
                        d.reject({error: msg});
                    });
                    return d.promise;
                }
            };
            return service;
        }];
    });

})();
