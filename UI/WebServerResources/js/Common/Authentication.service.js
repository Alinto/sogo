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
      PolicyPasswordRecoveryFailed: 9,
      PolicyPasswordRecoveryInvalidToken: 10,
      PolicyNoError: 65535
    })

  .provider('Authentication', Authentication);

  function Authentication() {
    function redirectUrl(username, domain) {
      var userName, address, baseAddress, parts, hostpart, protocol, newAddress;

      userName = username;
      if (domain)
        userName += '@' + domain;
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
              // Check for TOTP
              if (typeof data.totpMissingKey != 'undefined' && response.status == 202) {
                d.resolve({totpmissingkey: 1});
              }
              else if (typeof data.totpDisabled != 'undefined') {
                d.resolve({
                  cn: data.cn,
                  url: redirectUrl(username, domain),
                  totpdisabled: 1
                });
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
            if (data && data.totpInvalidKey) {
              response = {error: l('You provided an invalid TOTP key.')};
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

        changePassword: function(userName, domain, newPassword, oldPassword, token) {
          var d = $q.defer(),
              xsrfCookie = $cookies.get('XSRF-TOKEN');

          $cookies.remove('XSRF-TOKEN', {path: '/SOGo/'});

          $http({
            method: 'POST',
            url: '/SOGo/so/changePassword',
            headers: {
              'X-XSRF-TOKEN' : xsrfCookie
            },
            data: { userName: userName, newPassword: newPassword, oldPassword: oldPassword, token: token }
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
            } else if (perr == passwordPolicyConfig.PolicyPasswordRecoveryInvalidToken) {
              error = l("Invalid token. Could not change password");
            } else {
              error = l("Unhandled policy error: %{0}").formatted(perr);
              perr = passwordPolicyConfig.PolicyPasswordUnknown;
            }

            // Restore the cookie
            $cookies.put('XSRF-TOKEN', xsrfCookie, {path: '/SOGo/'});
            d.reject(error);
          });
          return d.promise;
        },

        passwordRecovery: function (userName, domain) {
          var self = this;

          var d = $q.defer(),
            xsrfCookie = $cookies.get('XSRF-TOKEN');

          $cookies.remove('XSRF-TOKEN', { path: '/SOGo/' });

          $http({
            method: 'POST',
            url: '/SOGo/so/passwordRecovery',
            headers: {
              'X-XSRF-TOKEN': xsrfCookie
            },
            data: { userName: userName, domain: domain }
          }).then(function (response) {
            d.resolve(Object.assign(
              { url: redirectUrl(userName, domain) }, 
              response.data, 
              'SecretQuestion' === response.data.mode ? { secretQuestionLabel: l('passwordRecovery_' + response.data.secretQuestion) } : {},
              'SecondaryEmail' === response.data.mode ? { obfuscatedRecoveryEmail: response.data.obfuscatedSecondaryEmail } : {}
              ));
          }, function () {
            // Restore the cookie
            $cookies.put('XSRF-TOKEN', xsrfCookie, { path: '/SOGo/' });
            d.reject(l("Unhandled policy error: %{0}").formatted(passwordPolicyConfig.PolicyPasswordRecoveryFailed));
          });
          return d.promise;
        },


        passwordRecoveryEmail: function (userName, domain, mode, mailDomain) {
          var self = this;

          var d = $q.defer(),
            xsrfCookie = $cookies.get('XSRF-TOKEN');

          $cookies.remove('XSRF-TOKEN', { path: '/SOGo/' });

          $http({
            method: 'POST',
            url: '/SOGo/so/passwordRecoveryEmail',
            headers: {
              'X-XSRF-TOKEN': xsrfCookie
            },
            data: { userName: userName, domain: domain, mode: mode, mailDomain: mailDomain }
          }).then(function (response) {
            d.resolve(response.data.jwt);
          }, function (response) {
            // Restore the cookie
            $cookies.put('XSRF-TOKEN', xsrfCookie, { path: '/SOGo/' });
            d.reject(l(response.data));
          });
          return d.promise;
        },


        passwordRecoveryCheck: function (userName, domain, mode, question, answer, mailDomain) {
          var self = this;

          var d = $q.defer(),
            xsrfCookie = $cookies.get('XSRF-TOKEN');

          $cookies.remove('XSRF-TOKEN', { path: '/SOGo/' });

          $http({
            method: 'POST',
            url: '/SOGo/so/passwordRecoveryCheck',
            headers: {
              'X-XSRF-TOKEN': xsrfCookie
            },
            data: { userName: userName, domain: domain, mode: mode, question: question, answer: answer, mailDomain: mailDomain }
          }).then(function (response) {
            d.resolve(response.data.jwt);
          }, function (response) {
            // Restore the cookie
            $cookies.put('XSRF-TOKEN', xsrfCookie, { path: '/SOGo/' });
            d.reject(l(response.data));
          });
          return d.promise;
        },

        passwordRecoveryEnabled: function (userName, domain) {
          var self = this;

          var d = $q.defer();
          
          $http({
            method: 'POST',
            url: '/SOGo/so/passwordRecoveryEnabled',
            data: { userName: userName, domain: domain }
          }).then(function (response) {
            d.resolve(response.data.domain);
          }, function () {
            d.reject();
          });
          return d.promise;
        }
      };
      return service;
    }
  }

})();
