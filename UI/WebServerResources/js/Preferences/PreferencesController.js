/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  PreferencesController.$inject = ['$state', '$mdDialog', '$mdToast', 'Dialog', 'User', 'Mailbox', 'statePreferences', 'Authentication'];
  function PreferencesController($state, $mdDialog, $mdToast, Dialog, User, Mailbox, statePreferences, Authentication) {
    var vm = this;

    vm.preferences = statePreferences;
    vm.passwords = { newPassword: null, newPasswordConfirmation: null };

    vm.go = go;
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
    vm.addDefaultEmailAddresses = addDefaultEmailAddresses;
    vm.userFilter = User.$filter;
    vm.save = save;
    vm.canChangePassword = canChangePassword;
    vm.changePassword = changePassword;
    vm.timeZonesList = window.timeZonesList;
    vm.timeZonesListFilter = timeZonesListFilter;
    vm.timeZonesSearchText = '';
    vm.mailboxes = Mailbox.$find({ id: 0 });

    function go(module) {
      $state.go('preferences.' + module);
    }

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
      account.name = l("New account");
      account.identities = [
        {
          fullName: "",
          email: ""
        }
      ];
      account.receipts = {
        receiptAction: "ignore",
        receiptNonRecipientAction: "ignore",
        receiptOutsideDomainAction: "ignore",
        receiptAnyAction: "ignore"
      };

      $mdDialog.show({
        controller: 'AccountDialogController',
        controllerAs: '$AccountDialogController',
        templateUrl: 'editAccount?account=new',
        targetEvent: ev,
        locals: {
          defaults: vm.preferences.defaults,
          account: account,
          accountId: (vm.preferences.defaults.AuxiliaryMailAccounts.length-1),
          mailCustomFromEnabled: window.mailCustomFromEnabled
        }
      });
    }

    function editMailAccount(event, index) {
      var account = vm.preferences.defaults.AuxiliaryMailAccounts[index];
      $mdDialog.show({
        controller: 'AccountDialogController',
        controllerAs: '$AccountDialogController',
        templateUrl: 'editAccount?account=' + index,
        targetEvent: event,
        locals: {
          defaults: vm.preferences.defaults,
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
      vm.preferences.defaults.SOGoMailLabelsColors.new_label =  ["New label", "#aaa"];
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
          mailboxes: vm.mailboxes,
          labels: vm.preferences.defaults.SOGoMailLabelsColors,
          sieveCapabilities: window.sieveCapabilities
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
          mailboxes: vm.mailboxes,
          labels: vm.preferences.defaults.SOGoMailLabelsColors,
          sieveCapabilities: window.sieveCapabilities
        }
      }).then(function() {
        vm.preferences.defaults.SOGoSieveFilters[index] = filter;
      });
    }

    function removeMailFilter(index) {
      vm.preferences.defaults.SOGoSieveFilters.splice(index, 1);
    }

    function addDefaultEmailAddresses() {
      var v = [];

      if (angular.isDefined(vm.preferences.defaults.Vacation.autoReplyEmailAddresses)) {
        v = vm.preferences.defaults.Vacation.autoReplyEmailAddresses.split(',');
      }

      vm.preferences.defaults.Vacation.autoReplyEmailAddresses = (_.union(window.defaultEmailAddresses.split(','), v)).join(',');
    }
    
    function save() {
      var sendForm = true;

      // We do some sanity checks
      if (window.forwardConstraints > 0 &&
          angular.isDefined(vm.preferences.defaults.Forward) &&
          vm.preferences.defaults.Forward.enabled &&
          angular.isDefined(vm.preferences.defaults.Forward.forwardAddress)) {

        var addresses = vm.preferences.defaults.Forward.forwardAddress.split(",");

        // We first extract the list of 'known domains' to SOGo
        var defaultAddresses = window.defaultEmailAddresses.split(/, */);
        var domains = [];

        _.forEach(defaultAddresses, function(adr) {
          var domain = adr.split("@")[1];
          if (domain) {
            domains.push(domain.toLowerCase());
          }
        });

        // We check if we're allowed or not to forward based on the domain defaults
        for (var i = 0; i < addresses.length && sendForm; i++) {
          var domain = addresses[i].split("@")[1].toLowerCase();
          if (domains.indexOf(domain) < 0 && window.forwardConstraints == 1) {
            Dialog.alert(l('Error'), l("You are not allowed to forward your messages to an external email address."));
            sendForm = false;
          }
          else if (domains.indexOf(domain) >= 0 && window.forwardConstraints == 2) {
            Dialog.alert(l('Error'), l("You are not allowed to forward your messages to an internal email address."));
            sendForm = false;
          }
        }
      }

      if (sendForm)
        vm.preferences.$save().then(function(data) {
              $mdToast.show(
                $mdToast.simple()
                  .content('Preferences saved!')
                  .position('top right')
                  .hideDelay(3000)
              );
        });
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

    function timeZonesListFilter(filter) {
      return _.filter(vm.timeZonesList, function(value) {
        return value.toUpperCase().indexOf(filter.toUpperCase()) >= 0;
      });
    }
  }

  angular
    .module('SOGo.PreferencesUI')
    .controller('PreferencesController', PreferencesController);

})();
