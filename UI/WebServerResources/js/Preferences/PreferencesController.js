/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  PreferencesController.$inject = ['$q', '$window', '$state', '$mdMedia', '$mdSidenav', '$mdDialog', '$mdToast', 'sgFocus', 'Dialog', 'User', 'Account', 'statePreferences', 'Authentication'];
  function PreferencesController($q, $window, $state, $mdMedia, $mdSidenav, $mdDialog, $mdToast, focus, Dialog, User, Account, statePreferences, Authentication) {
    var vm = this, account, mailboxes = [];

    vm.preferences = statePreferences;
    vm.passwords = { newPassword: null, newPasswordConfirmation: null };

    vm.go = go;
    vm.onLanguageChange = onLanguageChange;
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

    // Fetch a flatten version of the mailboxes list of the main account (0)
    // This list will be forwarded to the Sieve filter controller
    account = new Account({ id: 0 });
    account.$getMailboxes().then(function() {
      var allMailboxes = account.$flattenMailboxes({all: true}),
          index = -1,
          length = allMailboxes.length;
      while (++index < length) {
        mailboxes.push(allMailboxes[index]);
      }
    });

    // Set alternate avatar in User service
    statePreferences.ready().then(function() {
      if (statePreferences.defaults.SOGoAlternateAvatar)
        User.$alternateAvatar = statePreferences.defaults.SOGoAlternateAvatar;
    });

    function go(module) {
      // Close sidenav on small devices
      if ($mdMedia('xs'))
        $mdSidenav('left').close();
      $state.go('preferences.' + module);
    }

    function onLanguageChange() {
      Dialog.confirm(l('Warning'),
                     l('Save preferences and reload page now?'),
                     {ok: l('Yes'), cancel: l('No')})
        .then(function() {
          save().then(function() {
            $window.location.reload(true);
          });
        });
    }

    function addCalendarCategory() {
      vm.preferences.defaults.SOGoCalendarCategoriesColors["New category"] = "#aaa";
      vm.preferences.defaults.SOGoCalendarCategories.push("New category");
      focus('calendarCategory_' + (vm.preferences.defaults.SOGoCalendarCategories.length - 1));
    }

    function removeCalendarCategory(index) {
      var key = vm.preferences.defaults.SOGoCalendarCategories[index];
      vm.preferences.defaults.SOGoCalendarCategories.splice(index, 1);
      delete vm.preferences.defaults.SOGoCalendarCategoriesColors[key];
    }

    function addContactCategory() {
      vm.preferences.defaults.SOGoContactsCategories.push("");
      focus('contactCategory_' + (vm.preferences.defaults.SOGoContactsCategories.length - 1));
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
      // See $omit() in the Preferences services for real key generation
      var key = '_$$' + guid();
      vm.preferences.defaults.SOGoMailLabelsColors[key] =  ["New label", "#aaa"];
    }

    function removeMailLabel(key) {
      delete vm.preferences.defaults.SOGoMailLabelsColors[key];
    }

    function addMailFilter(ev) {
      var filter = { match: 'all' };

      $mdDialog.show({
        templateUrl: 'editFilter?filter=new',
        controller: 'FiltersDialogController',
        controllerAs: 'filterEditor',
        targetEvent: ev,
        locals: {
          filter: filter,
          mailboxes: mailboxes,
          labels: vm.preferences.defaults.SOGoMailLabelsColors
        }
      }).then(function() {
        if (!vm.preferences.defaults.SOGoSieveFilters)
          vm.preferences.defaults.SOGoSieveFilters = [];
        vm.preferences.defaults.SOGoSieveFilters.push(filter);
      });
    }
    
    function editMailFilter(ev, index) {
      var filter = angular.copy(vm.preferences.defaults.SOGoSieveFilters[index]);
      
      $mdDialog.show({
        templateUrl: 'editFilter?filter=' + index,
        controller: 'FiltersDialogController',
        controllerAs: 'filterEditor',
        targetEvent: null,
        locals: {
          filter: filter,
          mailboxes: mailboxes,
          labels: vm.preferences.defaults.SOGoMailLabelsColors
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
      var i, sendForm, addresses, defaultAddresses, domains, domain;

      sendForm = true;
      domains = [];

      // We do some sanity checks
      if (window.forwardConstraints > 0 &&
          angular.isDefined(vm.preferences.defaults.Forward) &&
          vm.preferences.defaults.Forward.enabled &&
          angular.isDefined(vm.preferences.defaults.Forward.forwardAddress)) {

        addresses = vm.preferences.defaults.Forward.forwardAddress.split(",");

        // We first extract the list of 'known domains' to SOGo
        defaultAddresses = window.defaultEmailAddresses.split(/, */);

        _.forEach(defaultAddresses, function(adr) {
          var domain = adr.split("@")[1];
          if (domain) {
            domains.push(domain.toLowerCase());
          }
        });

        // We check if we're allowed or not to forward based on the domain defaults
        for (i = 0; i < addresses.length && sendForm; i++) {
          domain = addresses[i].split("@")[1].toLowerCase();
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
        return vm.preferences.$save().then(function(data) {
          $mdToast.show({
            controller: 'savePreferencesToastCtrl',
            template: [
              '<md-toast>',
              '  <div class="md-toast-content">',
              '    <span flex>' + l('Preferences saved') + '</span>',
              '    <md-button class="md-icon-button md-primary" ng-click="closeToast()">',
              '      <md-icon>close</md-icon>',
              '    </md-button>',
              '  </div>',
              '</md-toast>'
            ].join(''),
            hideDelay: 2000,
            position: 'top right'
          });
        });

      return $q.reject();
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
          ok: l('OK')
        });
        $mdDialog.show( alert )
          .finally(function() {
            alert = undefined;
          });
      }, function(msg) {
        var alert = $mdDialog.alert({
          title: l('Password'),
          content: msg,
          ok: l('OK')
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

  savePreferencesToastCtrl.$inject = ['$scope', '$mdToast'];
  function savePreferencesToastCtrl($scope, $mdToast) {
    $scope.closeToast = function() {
      $mdToast.hide();
    };
  }

  angular
    .module('SOGo.PreferencesUI')
    .controller('savePreferencesToastCtrl', savePreferencesToastCtrl)
    .controller('PreferencesController', PreferencesController);

})();
