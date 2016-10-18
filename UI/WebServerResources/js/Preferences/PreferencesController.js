/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  PreferencesController.$inject = ['$q', '$window', '$state', '$mdMedia', '$mdSidenav', '$mdDialog', '$mdToast', 'sgFocus', 'Dialog', 'User', 'Account', 'statePreferences', 'Authentication'];
  function PreferencesController($q, $window, $state, $mdMedia, $mdSidenav, $mdDialog, $mdToast, focus, Dialog, User, Account, statePreferences, Authentication) {
    var vm = this, account, mailboxes = [], today = new Date(), tomorrow = today.addDays(1);

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
    vm.userFilter = userFilter;
    vm.confirmChanges = confirmChanges;
    vm.save = save;
    vm.canChangePassword = canChangePassword;
    vm.changePassword = changePassword;
    vm.timeZonesList = window.timeZonesList;
    vm.timeZonesListFilter = timeZonesListFilter;
    vm.timeZonesSearchText = '';
    vm.sieveVariablesCapability = ($window.sieveCapabilities.indexOf('variables') >= 0);
    vm.updateVacationDates = updateVacationDates;

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
      updateVacationDates();
    });

    function go(module, form) {
      if (form.$valid) {
        // Close sidenav on small devices
        if ($mdMedia('xs'))
          $mdSidenav('left').close();
        $state.go('preferences.' + module);
      }
    }

    function onLanguageChange(form) {
      Dialog.confirm(l('Warning'),
                     l('Save preferences and reload page now?'),
                     {ok: l('Yes'), cancel: l('No')})
        .then(function() {
          save(form, { quick: true }).then(function() {
            $window.location.reload(true);
          });
        });
    }

    function addCalendarCategory(form) {
      vm.preferences.defaults.SOGoCalendarCategoriesColors["New category"] = "#aaa";
      vm.preferences.defaults.SOGoCalendarCategories.push("New category");
      focus('calendarCategory_' + (vm.preferences.defaults.SOGoCalendarCategories.length - 1));
      form.$setDirty();
    }

    function removeCalendarCategory(index, form) {
      var key = vm.preferences.defaults.SOGoCalendarCategories[index];
      vm.preferences.defaults.SOGoCalendarCategories.splice(index, 1);
      delete vm.preferences.defaults.SOGoCalendarCategoriesColors[key];
      form.$setDirty();
    }

    function addContactCategory(form) {
      vm.preferences.defaults.SOGoContactsCategories.push("");
      focus('contactCategory_' + (vm.preferences.defaults.SOGoContactsCategories.length - 1));
      form.$setDirty();
    }

    function removeContactCategory(index, form) {
      vm.preferences.defaults.SOGoContactsCategories.splice(index, 1);
      form.$setDirty();
    }

    function addMailAccount(ev, form) {
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
      }).then(function() {
        form.$setDirty();
      });
    }

    function editMailAccount(event, index, form) {
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
        form.$setDirty();
      });
    }

    function removeMailAccount(index, form) {
      vm.preferences.defaults.AuxiliaryMailAccounts.splice(index, 1);
      form.$setDirty();
    }
    
    function addMailLabel(form) {
      // See $omit() in the Preferences services for real key generation
      var key = '_$$' + guid();
      vm.preferences.defaults.SOGoMailLabelsColors[key] =  ["New label", "#aaa"];
      form.$setDirty();
    }

    function removeMailLabel(key, form) {
      delete vm.preferences.defaults.SOGoMailLabelsColors[key];
      form.$setDirty();
    }

    function addMailFilter(ev, form) {
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
        form.$setDirty();
      });
    }
    
    function editMailFilter(ev, index, form) {
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
        form.$setDirty();
      });
    }

    function removeMailFilter(index, form) {
      vm.preferences.defaults.SOGoSieveFilters.splice(index, 1);
      form.$setDirty();
    }

    function addDefaultEmailAddresses(form) {
      var v = [];

      if (angular.isDefined(vm.preferences.defaults.Vacation.autoReplyEmailAddresses)) {
        v = vm.preferences.defaults.Vacation.autoReplyEmailAddresses.split(',');
      }

      vm.preferences.defaults.Vacation.autoReplyEmailAddresses = (_.union(window.defaultEmailAddresses.split(','), v)).join(',');
      form.$setDirty();
    }

    function userFilter(search, excludedUsers) {
      return User.$filter(search, excludedUsers).then(function(users) {
        // Set users avatars
        _.forEach(users, function(user) {
          if (!user.$$image) {
            if (user.image)
              user.$$image = user.image;
            else
              vm.preferences.avatar(user.c_email, 32, {no_404: true}).then(function(url) {
                user.$$image = url;
              });
            }
        });
        return users;
      });
    }

    function confirmChanges($event, form) {
      var target;

      if (form.$dirty) {
        // Stop default action
        $event.preventDefault();
        $event.stopPropagation();

        // Find target link
        target = $event.target;
        while (target.tagName != 'A')
          target = target.parentNode;

        Dialog.confirm(l('Unsaved Changes'),
                       l('Do you want to save your changes made to the configuration?'),
                       { ok: l('Save'), cancel: l('Don\'t Save') })
        .then(function() {
          // Save & follow link
          save(form, { quick: true }).then(function() {
            $window.location = target.href;
          });
        }, function() {
          // Don't save & follow link
          $window.location = target.href;
        });
      }
    }

    function save(form, options) {
      var i, sendForm, addresses, defaultAddresses, domains, domain;

      sendForm = true;
      domains = [];

      // We do some sanity checks
      if ($window.forwardConstraints > 0 &&
          angular.isDefined(vm.preferences.defaults.Forward) &&
          vm.preferences.defaults.Forward.enabled &&
          angular.isDefined(vm.preferences.defaults.Forward.forwardAddress)) {

        addresses = vm.preferences.defaults.Forward.forwardAddress.split(",");

        // We first extract the list of 'known domains' to SOGo
        defaultAddresses = $window.defaultEmailAddresses.split(/, */);

        _.forEach(defaultAddresses, function(adr) {
          var domain = adr.split("@")[1];
          if (domain) {
            domains.push(domain.toLowerCase());
          }
        });

        // We check if we're allowed or not to forward based on the domain defaults
        for (i = 0; i < addresses.length && sendForm; i++) {
          domain = addresses[i].split("@")[1].toLowerCase();
          if (domains.indexOf(domain) < 0 && $window.forwardConstraints == 1) {
            Dialog.alert(l('Error'), l("You are not allowed to forward your messages to an external email address."));
            sendForm = false;
          }
          else if (domains.indexOf(domain) >= 0 && $window.forwardConstraints == 2) {
            Dialog.alert(l('Error'), l("You are not allowed to forward your messages to an internal email address."));
            sendForm = false;
          }
        }
      }

      if (sendForm)
        return vm.preferences.$save().then(function(data) {
          if (!options || !options.quick) {
            $mdToast.show(
              $mdToast.simple()
                .content(l('Preferences saved'))
                .position('bottom right')
                .hideDelay(2000));
            form.$setPristine();
          }
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

    function updateVacationDates() {
      if (statePreferences.defaults &&
          statePreferences.defaults.Vacation &&
          statePreferences.defaults.Vacation.enabled) {

        // Determine minimum dates
        vm.vacationStartDateMin = undefined;
        if (statePreferences.defaults.Vacation.startDateEnabled) {
          vm.vacationStartDateMin = tomorrow;
          vm.vacationStartDate = statePreferences.defaults.Vacation.startDate;
        }
        else if (statePreferences.defaults.Vacation.endDateEnabled)
          vm.vacationStartDate = tomorrow;
        else
          vm.vacationStartDate = undefined;

        // Determine maximum value of start date
        if (statePreferences.defaults.Vacation.endDateEnabled)
          vm.vacationEndDate = statePreferences.defaults.Vacation.endDate;
        else
          vm.vacationEndDate = undefined;
      }
      else {
        vm.vacationStartDateMin = undefined;
        vm.vacationStartDate = undefined;
        vm.vacationEndDate = undefined;
      }
    }
  }

  angular
    .module('SOGo.PreferencesUI')
    .controller('PreferencesController', PreferencesController);

})();
