/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';

  angular.module('SOGo.Common', []);
  angular.module('SOGo.ContactsUI', []);
  angular.module('SOGo.MailerUI', []);

  angular.module('SOGo.PreferencesUI', ['ngSanitize', 'ui.router', 'SOGo.Common', 'SOGo.MailerUI', 'SOGo.UIDesktop', 'SOGo.UI', 'SOGo.ContactsUI', 'SOGo.Authentication'])

    .constant('sgSettings', {
      baseURL: ApplicationBaseURL,
      activeUser: {
        login: UserLogin,
        identification: UserIdentification,
        language: UserLanguage,
        folderURL: UserFolderURL,
        isSuperUser: IsSuperUser
      }
    })

    .config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
      $stateProvider
        .state('preferences', {
          abstract: true,
          views: {
            preferences: {
              templateUrl: 'preferences.html',
              controller: 'PreferencesCtrl'
            }
          },
          resolve: {
            statePreferences: ['sgPreferences', function(Preferences) {
              return new Preferences();
            }]
          }
        })
        .state('preferences.general', {
          url: '/general',
          views: {
            module: {
              templateUrl: 'generalPreferences.html'
            }
          }
        })
        .state('preferences.calendars', {
          url: '/calendars',
          views: {
            module: {
              templateUrl: 'calendarsPreferences.html'
            }
          }
        })
        .state('preferences.addressbooks', {
          url: '/addressbooks',
          views: {
            module: {
              templateUrl: 'addressbooksPreferences.html'
            }
          }
        })
        .state('preferences.mailer', {
          url: '/mailer',
          views: {
            module: {
              templateUrl: 'mailerPreferences.html'
            }
          }
        })
      // if none of the above states are matched, use this as the fallback
      $urlRouterProvider.otherwise('/general');
    }])

    .controller('PreferencesCtrl', ['$scope', '$timeout', '$q', '$mdDialog', 'sgPreferences', 'sgUser', 'statePreferences', 'Authentication', function($scope, $timeout, $q, $mdDialog, Preferences, User, statePreferences, Authentication) {

      $scope.preferences = statePreferences;
      
      $scope.addCalendarCategory = function() {
        $scope.preferences.defaults.SOGoCalendarCategoriesColors["New category"] = "#aaa";
        $scope.preferences.defaults.SOGoCalendarCategories.push("New category");
      }
      
      $scope.removeCalendarCategory = function(index) {
        var key = $scope.preferences.defaults.SOGoCalendarCategories[index];
        $scope.preferences.defaults.SOGoCalendarCategories.splice(index, 1);
        delete $scope.preferences.defaults.SOGoCalendarCategoriesColors[key];
      }
      
      $scope.addContactCategory = function() {
        $scope.preferences.defaults.SOGoContactsCategories.push("");
      };

      $scope.removeContactCategory = function(index) {
        $scope.preferences.defaults.SOGoContactsCategories.splice(index, 1);
      }
      
      $scope.addMailAccount = function(ev) {
        $scope.preferences.defaults.AuxiliaryMailAccounts.push({});
        var account = _.last($scope.preferences.defaults.AuxiliaryMailAccounts);
        $mdDialog.show({
          controller: AccountDialogCtrl,
          templateUrl: 'editAccount?account=new',
          targetEvent: ev,
          locals: { account: account }
        });
      };

      $scope.editMailAccount = function(index) {
        var account = $scope.preferences.defaults.AuxiliaryMailAccounts[index];
        $mdDialog.show({
          controller: AccountDialogCtrl,
          templateUrl: 'editAccount?account=' + index,
          targetEvent: null,
          locals: { account: account,
                    accountId: index,
                    mailCustomFromEnabled: window.mailCustomFromEnabled}
        }).then(function() {
          $scope.preferences.defaults.AuxiliaryMailAccounts[index] = account;
        });
      };

      $scope.removeMailAccount = function(index) {
        $scope.preferences.defaults.AuxiliaryMailAccounts.splice(index, 1);
      };
      
      $scope.addMailLabel = function() {
        $scope.preferences.defaults.SOGoMailLabelsColors["foo_bar"] =  ["foo bar", "#FFFF00"];
      };

      $scope.removeMailLabel = function(key) {
        delete $scope.preferences.defaults.SOGoMailLabelsColors[key];
      };

      $scope.addMailFilter = function(ev) {
        if (!$scope.preferences.defaults.SOGoSieveFilters)
          $scope.preferences.defaults.SOGoSieveFilters = [];

        $scope.preferences.defaults.SOGoSieveFilters.push({});
        var filter = _.last($scope.preferences.defaults.SOGoSieveFilters);
        $mdDialog.show({
          controller: FiltersDialogCtrl,
          templateUrl: 'editFilter?filter=new',
          targetEvent: ev,
          locals: { filter: filter,
                    mailboxes: $scope.preferences.mailboxes,
                    labels: $scope.preferences.defaults.SOGoMailLabelsColors}
        });
      };
      
      $scope.editMailFilter = function(index) {
        var filter = angular.copy($scope.preferences.defaults.SOGoSieveFilters[index]);
        
        $mdDialog.show({
          controller: FiltersDialogCtrl,
          templateUrl: 'editFilter?filter=' + index,
          targetEvent: null,
          locals: { filter: filter,
                    mailboxes: $scope.preferences.mailboxes,
                    labels: $scope.preferences.defaults.SOGoMailLabelsColors }
        }).then(function() {
          $scope.preferences.defaults.SOGoSieveFilters[index] = filter;
        });
      };


      $scope.removeMailFilter = function(index) {
        $scope.preferences.defaults.SOGoSieveFilters.splice(index, 1);
      };

      $scope.userFilter = function($query) {
        var deferred = $q.defer();
        User.$filter($query).then(function(results) {
          deferred.resolve(results)
        });
        return deferred.promise;
      };
      
      $scope.save = function() {
        $scope.preferences.$save();
      };

      $scope.passwords = { newPassword: null, newPasswordConfirmation: null };
      
      $scope.canChangePassword = function() {
        if ($scope.passwords.newPassword && $scope.passwords.newPassword.length > 0 &&
            $scope.passwords.newPasswordConfirmation && $scope.passwords.newPasswordConfirmation.length &&
            $scope.passwords.newPassword == $scope.passwords.newPasswordConfirmation)
          return true;

        return false;
      };
      
      $scope.changePassword = function() {
        Authentication.changePassword($scope.passwords.newPassword).then(function() {
          var alert = $mdDialog.alert({
            title: l('Password'),
            content: l('The password was changed successfully.'),
            ok: 'OK'
          });
          $mdDialog.show( alert )
            .finally(function() {
              alert = undefined;
            });
        }, function(msg) {
          var alert = $mdDialog.alert({
            title: l('Password'),
            content: msg,
            ok: 'OK'
          });
          $mdDialog.show( alert )
            .finally(function() {
              alert = undefined;
            });
        });
      };
    }]);

  function FiltersDialogCtrl($scope, $mdDialog, filter, mailboxes, labels) {
    $scope.filter = filter;
    $scope.mailboxes = mailboxes;
    $scope.labels = labels;

    $scope.fieldLabels = { "subject": l("Subject"),
                           "from": l("From"),
                           "to": l("To"),
                           "cc": l("Cc"),
                           "to_or_cc": l("To or Cc"),
                           "size": l("Size (Kb)"),
                           "header": l("Header"),
                           "body": l("Body") };

    $scope.methodLabels = { "addflag": l("Flag the message with:"),                         
                            "discard": l("Discard the message"),
                            "fileinto": l("File the message in:"),
                            "keep": l("Keep the message"),
                            "redirect": l("Forward the message to:"),
                            "reject": l("Send a reject message:"),
                            "vacation": l("Send a vacation message"),
                            "stop": l("Stop processing filter rules") };
    
    $scope.numberOperatorLabels = { "under": l("is under"),
                                    "over": l("is over") };
    
    $scope.textOperatorLabels = { "is": l("is"),
                                  "is_not": l("is not"),
                                  "contains": l("contains"),
                                  "contains_not": l("does not contain"),
                                  "matches": l("matches"),
                                  "matches_not": l("does not match"),
                                  "regex": l("matches regex"),
                                  "regex_not": l("does not match regex") };
    
    $scope.flagLabels = { "seen": l("Seen"),
                          "deleted": l("Deleted"),
                          "answered": l("Answered"),
                          "flagged": l("Flagged"),
                          "junk": l("Junk"),
                          "not_junk": l("Not Junk") };
    
    $scope.cancel = function() {
      $mdDialog.cancel();
    };
    $scope.save = function() {
      $mdDialog.hide();
    };
    $scope.addMailFilterRule = function(event) {
      if (!$scope.filter.rules)
        $scope.filter.rules = [];

      $scope.filter.rules.push({});
    }
    $scope.removeMailFilterRule = function(index) {
      $scope.filter.rules.splice(index, 1);
    };
    $scope.addMailFilterAction = function(event) {
      if (!$scope.filter.actions)
        $scope.filter.actions = [];

      $scope.filter.actions.push({});
    }
    $scope.removeMailFilterAction = function(index) {
      $scope.filter.actions.splice(index, 1);
    };
  }
  
  function AccountDialogCtrl($scope, $mdDialog, account, accountId, mailCustomFromEnabled) {
    $scope.account = account;
    $scope.accountId = accountId;
    $scope.customFromIsReadonly = function() {
      if (accountId > 0)
        return false;

      return !mailCustomFromEnabled;
    };
    $scope.cancel = function() {
      $mdDialog.cancel();
    };
    $scope.save = function() {
      $mdDialog.hide();
    };
  }
})();
