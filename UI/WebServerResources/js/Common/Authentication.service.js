/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for Authentication */

(function() {
  /* jshint validthis: true */
  'use strict';

  angular.module('SOGo.Authentication', ['ngCookies'])

    .constant('passwordPolicyConfig', {
      PolicyPasswordChangeUnsupported: -3,
      PolicyPasswordSystemUnknown: -2,
      PolicyPasswordUnknown: -1,
      PolicyPasswordExpired: 0,
      PolicyAccountLocked: 1,
      PolicyChangeAfterReset: 2,
      PolicyPasswordModNotAllowed: 3,
      PolicyMustSupplyOldPassword: 4,
      PolicyInsufficientPasswordQuality: 5,
      PolicyPasswordTooShort: 6,
      PolicyPasswordTooYoung: 7,
      PolicyPasswordInHistory: 8,
      PolicyNoError: 65535
    })

  .provider('Authentication', Authentication);

  function Authentication() {
    function redirectUrl(username, domain) {
      var userName, address, baseAddress, parts, hostpart, protocol, newAddress;

      userName = username;
      if (domain)
        userName += '@' + domain.value;
      address = '' + window.location.href;
      baseAddress = ApplicationBaseURL + encodeURIComponent(userName);
      if (baseAddress[0] == '/') {
        parts = address.split('/');
        hostpart = parts[2];
        protocol = parts[0];
        baseAddress = protocol + '//' + hostpart + baseAddress;
      }
      if (address.startsWith(baseAddress) && !address.endsWith('/logoff'))
        newAddress = address;
      else
        newAddress = baseAddress;

      return newAddress;
    }

    this.$get = getService;

    /**
     * @ngInject
     */
    getService.$inject = ['$q', '$http', '$cookies', 'passwordPolicyConfig'];
    function getService($q, $http, $cookies, passwordPolicyConfig) {
      var service;

      service = {
        login: function(data) {
          var d = $q.defer(),
              username = data.username,
              password = data.password,
              verificationCode = data.verificationCode,
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
            data: {
              userName: username,
              password: password,
              verificationCode: verificationCode,
              domain: domain,
              language: language,
              rememberLogin: rememberLogin
            }
          }).then(function(response) {
            var data = response.data;
            // Make sure browser's cookies are enabled
            if (navigator && !navigator.cookieEnabled) {
              d.reject({error: l('cookiesNotEnabled')});
            }
            else {
              // Check for Google Authenticator 2FA
              if (typeof data.GoogleAuthenticatorMissingKey != 'undefined' && response.status == 202) {
                d.resolve({gamissingkey: 1});
              }
              // Check password policy
              else if (typeof data.expire != 'undefined' && typeof data.grace != 'undefined') {
                if (data.expire < 0 && data.grace > 0) {
                  d.reject({
                    cn: data.cn,
                    url: redirectUrl(username, domain),
                    grace: data.grace
                  });
                } else if (data.expire > 0 && data.grace == -1) {
                  d.reject({
                    cn: data.cn,
                    url: redirectUrl(username, domain),
                    expire: data.expire
                  });
                }
                else {
                  d.resolve({
                    cn: data.cn,
                    url: redirectUrl(username, domain)
                  });
                }
              }
              else {
                d.resolve({ url: redirectUrl(username, domain) });
              }
            }
          }, function(error) {
            var response, perr, data = error.data;
            if (data && data.GoogleAuthenticatorInvalidKey) {
              response = {error: l('You provided an invalid Google Authenticator key.')};
            }
            else if (data && angular.isDefined(data.LDAPPasswordPolicyError)) {
              perr = data.LDAPPasswordPolicyError;
              if (perr == passwordPolicyConfig.PolicyNoError) {
                response = {error: l('Wrong username or password.')};
              }
              else if (perr == passwordPolicyConfig.PolicyAccountLocked) {
                response = {error: l('Your account was locked due to too many failed attempts.')};
              }
              else if (perr == passwordPolicyConfig.PolicyPasswordExpired ||
                       perr == passwordPolicyConfig.PolicyChangeAfterReset) {
                response = {
                  passwordexpired: 1,
                  url: redirectUrl(username, domain)
                };
              }
              else if (perr == passwordPolicyConfig.PolicyChangeAfterReset) {
                response = {
                  passwordexpired: 1,
                  url: redirectUrl(username, domain)
                };
              }
              else {
                response = {error: l('Login failed due to unhandled error case: ') + perr};
              }
            }
            else {
              response = {error: l('Unhandled error response')};
            }
            d.reject(response);
          });
          return d.promise;
        }, // login: function(data) { ...

        changePassword: function(userName, domain, newPassword, oldPassword) {
          var d = $q.defer(),
              xsrfCookie = $cookies.get('XSRF-TOKEN');

          $cookies.remove('XSRF-TOKEN', {path: '/SOGo/'});

          $http({
            method: 'POST',
            url: '/SOGo/so/changePassword',
            headers: {
              'X-XSRF-TOKEN' : xsrfCookie
            },
            data: { userName: userName, newPassword: newPassword, oldPassword: oldPassword }
          }).then(function() {
            d.resolve({url: redirectUrl(userName, domain)});
          }, function(response) {
            var error,
                data = response.data,
                perr = data.LDAPPasswordPolicyError;

            if (!perr) {
              perr = passwordPolicyConfig.PolicyPasswordSystemUnknown;
              error = _("Unhandled error response");
            }
            else if (perr == passwordPolicyConfig.PolicyNoError ||
                     perr == passwordPolicyConfig.PolicyPasswordUnknown) {
              error = l("Password change failed");
            } else if (perr == passwordPolicyConfig.PolicyPasswordModNotAllowed) {
              error = l("Password change failed - Permission denied");
            } else if (perr == passwordPolicyConfig.PolicyInsufficientPasswordQuality) {
              error = l("Password change failed - Insufficient password quality");
            } else if (perr == passwordPolicyConfig.PolicyPasswordTooShort) {
              error = l("Password change failed - Password is too short");
            } else if (perr == passwordPolicyConfig.PolicyPasswordTooYoung) {
              error = l("Password change failed - Password is too young");
            } else if (perr == passwordPolicyConfig.PolicyPasswordInHistory) {
              error = l("Password change failed - Password is in history");
            } else {
              error = l("Unhandled policy error: %{0}").formatted(perr);
              perr = passwordPolicyConfig.PolicyPasswordUnknown;
            }

            // Restore the cookie
            $cookies.put('XSRF-TOKEN', xsrfCookie, {path: '/SOGo/'});
            d.reject(error);
          });
          return d.promise;
        }
      };
      return service;
    }
  }

})();
