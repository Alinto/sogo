/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  PreferencesController.$inject = ['$scope', '$timeout', '$q', '$mdDialog', 'Preferences', 'User', 'statePreferences', 'Authentication'];
  function PreferencesController($scope, $timeout, $q, $mdDialog, Preferences, User, statePreferences, Authentication) {
    var vm = this;

    vm.preferences = statePreferences;
    vm.passwords = { newPassword: null, newPasswordConfirmation: null };

    vm.addCalendarCategory = addCalendarCategory;
    vm.removeCalendarCategory = removeCalendarCategory;
    vm.addContactCategory = addContactCategory;
    vm.removeContactCategory = removeContactCategory;
    vm.addMailAccount = addMailAccount;
    vm.editMailAccount = editMailAccount;
    vm.removeMailAccount = removeMailAccount;
    vm.addMailLabel = addMailLabel;
    vm.removeMailLabel = removeMailLabel;
    vm.addMailFilter = addMailFilter;
    vm.editMailFilter = editMailFilter;
    vm.removeMailFilter = removeMailFilter;
    vm.userFilter = userFilter;
    vm.save = save;
    vm.canChangePassword = canChangePassword;
    vm.changePassword = changePassword;
    
    function addCalendarCategory() {
      vm.preferences.defaults.SOGoCalendarCategoriesColors["New category"] = "#aaa";
      vm.preferences.defaults.SOGoCalendarCategories.push("New category");
    }

    function removeCalendarCategory(index) {
      var key = vm.preferences.defaults.SOGoCalendarCategories[index];
      vm.preferences.defaults.SOGoCalendarCategories.splice(index, 1);
      delete vm.preferences.defaults.SOGoCalendarCategoriesColors[key];
    }

    function addContactCategory() {
      vm.preferences.defaults.SOGoContactsCategories.push("");
    }

    function removeContactCategory(index) {
      vm.preferences.defaults.SOGoContactsCategories.splice(index, 1);
    }

    function addMailAccount(ev) {
      var account;

      vm.preferences.defaults.AuxiliaryMailAccounts.push({});
      account = _.last(vm.preferences.defaults.AuxiliaryMailAccounts);
      account['name'] = "New account";
      account['identities'] = [];
      account['identities'][0] = {};
      account['identities'][0]['fullName'] = "";
      account['identities'][0]['email'] = "";
      account['receipts'] = {};
      account['receipts']['receiptAction'] = "ignore";
      account['receipts']['receiptNonRecipientAction'] = "ignore";
      account['receipts']['receiptOutsideDomainAction'] = "ignore";
      account['receipts']['receiptAnyAction'] = "ignore";

      $mdDialog.show({
        controller: 'AccountDialogController',
        templateUrl: 'editAccount?account=new',
        targetEvent: ev,
        locals: {
          account: account,
          accountId: (vm.preferences.defaults.AuxiliaryMailAccounts.length-1),
          mailCustomFromEnabled: window.mailCustomFromEnabled
        }
      });
    }

    function editMailAccount(index) {
      var account = vm.preferences.defaults.AuxiliaryMailAccounts[index];
      $mdDialog.show({
        controller: 'AccountDialogController',
        templateUrl: 'editAccount?account=' + index,
        targetEvent: null,
        locals: {
          account: account,
          accountId: index,
          mailCustomFromEnabled: window.mailCustomFromEnabled
        }
      }).then(function() {
        vm.preferences.defaults.AuxiliaryMailAccounts[index] = account;
      });
    }

    function removeMailAccount(index) {
      vm.preferences.defaults.AuxiliaryMailAccounts.splice(index, 1);
    }
    
    function addMailLabel() {
      vm.preferences.defaults.SOGoMailLabelsColors["new_label"] =  ["New label", "#aaa"];
    }

    function removeMailLabel(key) {
      delete vm.preferences.defaults.SOGoMailLabelsColors[key];
    }

    function addMailFilter(ev) {
      if (!vm.preferences.defaults.SOGoSieveFilters)
        vm.preferences.defaults.SOGoSieveFilters = [];

      vm.preferences.defaults.SOGoSieveFilters.push({});
      var filter = _.last(vm.preferences.defaults.SOGoSieveFilters);
      $mdDialog.show({
        controller: 'FiltersDialogController',
        templateUrl: 'editFilter?filter=new',
        targetEvent: ev,
        locals: {
          filter: filter,
          mailboxes: vm.preferences.mailboxes,
          labels: vm.preferences.defaults.SOGoMailLabelsColors
        }
      });
    }
    
    function editMailFilter(index) {
      var filter = angular.copy(vm.preferences.defaults.SOGoSieveFilters[index]);
      
      $mdDialog.show({
        controller: 'FiltersDialogController',
        templateUrl: 'editFilter?filter=' + index,
        targetEvent: null,
        locals: {
          filter: filter,
          mailboxes: vm.preferences.mailboxes,
          labels: vm.preferences.defaults.SOGoMailLabelsColors
        }
      }).then(function() {
        vm.preferences.defaults.SOGoSieveFilters[index] = filter;
      });
    }

    function removeMailFilter(index) {
      vm.preferences.defaults.SOGoSieveFilters.splice(index, 1);
    }

    function userFilter($query) {
      User.$filter($query);
      return User.$users;
    }
    
    function save() {
      vm.preferences.$save();
    }

    function canChangePassword() {
      if (vm.passwords.newPassword && vm.passwords.newPassword.length > 0 &&
          vm.passwords.newPasswordConfirmation && vm.passwords.newPasswordConfirmation.length &&
          vm.passwords.newPassword == vm.passwords.newPasswordConfirmation)
        return true;

      return false;
    }
    
    function changePassword() {
      Authentication.changePassword(vm.passwords.newPassword).then(function() {
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
    }
  }

  angular
    .module('SOGo.PreferencesUI')
    .controller('PreferencesController', PreferencesController);

})();
