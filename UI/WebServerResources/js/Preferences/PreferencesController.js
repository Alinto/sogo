/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  PreferencesController.$inject = ['$q', '$window', '$state', '$mdConstant', '$mdMedia', '$mdSidenav', '$mdDialog', '$mdToast', 'sgSettings', 'sgFocus', 'Dialog', 'User', 'Account', 'Preferences', 'Authentication'];
  function PreferencesController($q, $window, $state, $mdConstant, $mdMedia, $mdSidenav, $mdDialog, $mdToast, sgSettings, focus, Dialog, User, Account, Preferences, Authentication) {
    var vm = this, mailboxes = [], today = new Date().beginOfDay();

    this.$onInit = function() {
      this.preferences = Preferences;
      this.passwords = { newPassword: null, newPasswordConfirmation: null, oldPassword: null };
      this.timeZonesList = $window.timeZonesList;
      this.timeZonesSearchText = '';
      this.sieveVariablesCapability = ($window.sieveCapabilities.indexOf('variables') >= 0);
      this.addressesSearchText = '';
      this.mailLabelKeyRE = new RegExp(/^(?!^_\$)[^(){} %*\"\\\\]*?$/);
      this.emailSeparatorKeys = [
        $mdConstant.KEY_CODE.ENTER,
        $mdConstant.KEY_CODE.TAB,
        $mdConstant.KEY_CODE.COMMA,
        $mdConstant.KEY_CODE.SEMICOLON
      ];

      // Set alternate avatar in User service
      if (Preferences.defaults.SOGoAlternateAvatar)
        User.$alternateAvatar = Preferences.defaults.SOGoAlternateAvatar;

      this.preferences.hasActiveExternalSieveScripts();
      this.updateVacationDates();
    };

    this.go = function(module, form) {
      if (form.$valid) {
        // Close sidenav on small devices
        if (!$mdMedia('gt-md'))
          $mdSidenav('left').close();
        $state.go('preferences.' + module);
      }
    };

    this.onLanguageChange = function(form) {
      if (form.$valid)
        Dialog.confirm(l('Warning'),
                       l('Save preferences and reload page now?'),
                       {ok: l('Yes'), cancel: l('No')})
        .then(function() {
          vm.save(form, { quick: true }).then(function() {
            $window.location.reload(true);
          });
        });
    };

    this.onDesktopNotificationsChange = function() {
      if (this.preferences.defaults.SOGoDesktopNotifications)
        this.preferences.authorizeNotifications();
    };

    this.resetContactsCategories = function(form) {
      this.preferences.defaults.SOGoContactsCategories = $window.defaultContactsCategories;
      form.$setDirty();
    };

    this.resetCalendarCategories = function(form) {
      this.preferences.defaults.SOGoCalendarCategories = _.keys($window.defaultCalendarCategories);
      this.preferences.defaults.SOGoCalendarCategoriesColorsValues = _.values($window.defaultCalendarCategories);
      form.$setDirty();
    };

    this.addCalendarCategory = function(form) {
      var i = _.indexOf(this.preferences.defaults.SOGoCalendarCategories, l('New category'));
      if (i < 0) {
        this.preferences.defaults.SOGoCalendarCategories.push(l('New category'));
        this.preferences.defaults.SOGoCalendarCategoriesColorsValues.push("#aaa");
        form.$setDirty();
        i = this.preferences.defaults.SOGoCalendarCategories.length - 1;
      }
      focus('calendarCategory_' + i);
    };

    this.resetCalendarCategoryValidity = function(index, form) {
      form['calendarCategory_' + index].$setValidity('duplicate', true);
    };

    this.removeCalendarCategory = function(index, form) {
      this.preferences.defaults.SOGoCalendarCategories.splice(index, 1);
      this.preferences.defaults.SOGoCalendarCategoriesColorsValues.splice(index, 1);
      form.$setDirty();
    };

    this.addContactCategory = function(form) {
      var i = _.indexOf(this.preferences.defaults.SOGoContactsCategories, "");
      if (i < 0) {
        this.preferences.defaults.SOGoContactsCategories.push("");
        i = this.preferences.defaults.SOGoContactsCategories.length - 1;
      }
      focus('contactCategory_' + i);
      form.$setDirty();
    };

    this.removeContactCategory = function(index, form) {
      this.preferences.defaults.SOGoContactsCategories.splice(index, 1);
      form.$setDirty();
    };

    this.addMailAccount = function(ev, form) {
      var account, index;

      index = this.preferences.defaults.AuxiliaryMailAccounts.length;
      account = new Account({
        id: index,
        isNew: true,
        name: "",
        identities: [
          {
            fullName: "",
            email: ""
          }
        ],
        receipts: {
          receiptAction: "ignore",
          receiptNonRecipientAction: "ignore",
          receiptOutsideDomainAction: "ignore",
          receiptAnyAction: "ignore"
        }
      });

      $mdDialog.show({
        controller: 'AccountDialogController',
        controllerAs: '$AccountDialogController',
        templateUrl: 'editAccount?account=new',
        targetEvent: ev,
        locals: {
          defaults: this.preferences.defaults,
          account: account,
          accountId: index,
          mailCustomFromEnabled: $window.mailCustomFromEnabled
        }
      }).then(function() {
        // Automatically expand the new mail account
        if (!angular.isArray(vm.preferences.settings.Mail.ExpandedFolders)) {
          vm.preferences.settings.Mail.ExpandedFolders = ['/0'];
        }
        vm.preferences.settings.Mail.ExpandedFolders.push('/' + index);
        vm.preferences.defaults.AuxiliaryMailAccounts.push(account.$omit());

        form.$setDirty();
      });
    };

    this.editMailAccount = function(event, index, form) {
      var data, account;

      data = _.assign({ id: index }, _.cloneDeep(this.preferences.defaults.AuxiliaryMailAccounts[index]));
      account = new Account(data);
      $mdDialog.show({
        controller: 'AccountDialogController',
        controllerAs: '$AccountDialogController',
        templateUrl: 'editAccount?account=' + index,
        targetEvent: event,
        locals: {
          defaults: this.preferences.defaults,
          account: account,
          accountId: index,
          mailCustomFromEnabled: $window.mailCustomFromEnabled
        }
      }).then(function() {
        vm.preferences.defaults.AuxiliaryMailAccounts[index] = account.$omit();
        form.$setDirty();
      }).catch(_.noop); // Cancel
    };

    this.removeMailAccount = function(index, form) {
      this.preferences.defaults.AuxiliaryMailAccounts.splice(index, 1);
      form.$setDirty();
    };

    this.resetMailLabelValidity = function(index, form) {
      form['mailIMAPLabel_' + index].$setValidity('duplicate', true);
    };

    this.addMailLabel = function(form) {
      // See $omit() in the Preferences services for real key generation
      var key = '_$$' + guid();
      this.preferences.defaults.SOGoMailLabelsColorsKeys.push("label");
      this.preferences.defaults.SOGoMailLabelsColorsValues.push(["New label", "#aaa"]);
      focus('mailLabel_' + (_.size(this.preferences.defaults.SOGoMailLabelsColorsKeys) - 1));
      form.$setDirty();
    };

    this.removeMailLabel = function(index, form) {
      this.preferences.defaults.SOGoMailLabelsColorsKeys.splice(index, 1);
      this.preferences.defaults.SOGoMailLabelsColorsValues.splice(index, 1);
      form.$setDirty();
    };

    function _loadAllMailboxes() {
      var account;

      if (mailboxes.length) {
        return;
      }
      if (sgSettings.activeUser('path').mail) {
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
      }
    }

    this.addMailFilter = function(ev, form) {
      var filter = { match: 'all', active: 1 };

      _loadAllMailboxes();
      $mdDialog.show({
        templateUrl: 'editFilter?filter=new',
        controller: 'FiltersDialogController',
        controllerAs: 'filterEditor',
        targetEvent: ev,
        locals: {
          filter: filter,
          mailboxes: mailboxes,
          labels: this.preferences.defaults.SOGoMailLabelsColors,
          validateForwardAddress: validateForwardAddress
        }
      }).then(function() {
        if (!vm.preferences.defaults.SOGoSieveFilters)
          vm.preferences.defaults.SOGoSieveFilters = [];
        vm.preferences.defaults.SOGoSieveFilters.push(filter);
        form.$setDirty();
      });
    };

    this.editMailFilter = function(ev, index, form) {
      var filter = angular.copy(this.preferences.defaults.SOGoSieveFilters[index]);

      _loadAllMailboxes();
      $mdDialog.show({
        templateUrl: 'editFilter?filter=' + index,
        controller: 'FiltersDialogController',
        controllerAs: 'filterEditor',
        targetEvent: null,
        locals: {
          filter: filter,
          mailboxes: mailboxes,
          labels: this.preferences.defaults.SOGoMailLabelsColors,
          validateForwardAddress: validateForwardAddress
        }
      }).then(function() {
        vm.preferences.defaults.SOGoSieveFilters[index] = filter;
        form.$setDirty();
      },
              _.noop); // Cancel
    };

    this.removeMailFilter = function(index, form) {
      this.preferences.defaults.SOGoSieveFilters.splice(index, 1);
      form.$setDirty();
    };

    this.onFiltersOrderChanged = function(form) {
      // Return a callback that will affect the form
      if (!this._onFiltersOrderChanged) {
        this._onFiltersOrderChanged = function(type) {
          form.$setDirty();
        };
      }
      return this._onFiltersOrderChanged;
    };

    this.filterEmailAddresses = function ($query) {
      return _.filter(
        _.difference($window.defaultEmailAddresses,
                     this.preferences.defaults.Vacation.autoReplyEmailAddresses),
        function (address) {
          return address.toLowerCase().indexOf($query.toLowerCase()) >= 0;
        }
      );
    };

    this.addDefaultEmailAddresses = function(form) {
      var v = [];

      if (angular.isDefined(this.preferences.defaults.Vacation.autoReplyEmailAddresses)) {
        v = this.preferences.defaults.Vacation.autoReplyEmailAddresses;
      }

      this.preferences.defaults.Vacation.autoReplyEmailAddresses = _.union($window.defaultEmailAddresses, v);
      form.$setDirty();
    };

    this.userFilter = function(search, excludedUsers) {
      if (!search || search.length < sgSettings.minimumSearchLength())
        return [];

      return User.$filter(search, excludedUsers).then(function(users) {
        // Set users avatars
        _.forEach(users, function(user) {
          if (!user.$$image) {
            if (user.image)
              user.$$image = user.image;
            else
              user.$$image = vm.preferences.avatar(user.c_email, 40, {no_404: true});
            }
        });
        return users;
      });
    };

    this.manageSieveScript = function(form) {
      this.preferences.hasActiveExternalSieveScripts(false);
      form.$setDirty();
    };

    this.confirmChanges = function($event, form) {
      var target;

      if (form.$dirty && form.$valid) {
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
          vm.save(form, { quick: true }).then(function() {
            $window.location = target.href;
          });
        }, function() {
          // Don't save & follow link
          $window.location = target.href;
        });
      }
    };

    function validateForwardAddress(address) {
      var defaultAddresses, domains, domain;

      domains = [];

      if ($window.forwardConstraints > 0 &&
          angular.isDefined(Preferences.defaults.Forward) &&
          Preferences.defaults.Forward.enabled &&
          angular.isDefined(Preferences.defaults.Forward.forwardAddress)) {

        // We first extract the list of 'known domains' to SOGo
        defaultAddresses = $window.defaultEmailAddresses;
        _.forEach(defaultAddresses, function(adr) {
          var domain = adr.split("@")[1];
          if (domain) {
            domains.push(domain.toLowerCase());
          }
        });

        // We check if we're allowed or not to forward based on the domain defaults
        domain = address.split("@")[1].toLowerCase();
        if (domains.indexOf(domain) < 0 && $window.forwardConstraints == 1) {
          throw new Error(l("You are not allowed to forward your messages to an external email address."));
        }
        else if (domains.indexOf(domain) >= 0 && $window.forwardConstraints == 2) {
          throw new Error(l("You are not allowed to forward your messages to an internal email address."));
        }
        else if ($window.forwardConstraints == 2 &&
                 $window.forwardConstraintsDomains.length > 0 &&
                 $window.forwardConstraintsDomains.indexOf(domain) < 0) {
          throw new Error(l("You are not allowed to forward your messages to this domain:") + " " + domain);
        }
      }

      return true;
    }

    this.save = function(form, options) {
      var i, sendForm, addresses;

      sendForm = true;

      // We do some sanity checks

      // We check if we're allowed or not to forward based on the domain defaults
      if (this.preferences.defaults.Forward && this.preferences.defaults.Forward.forwardAddress) {
        addresses = this.preferences.defaults.Forward.forwardAddress;
        try {
          for (i = 0; i < addresses.length; i++) {
            validateForwardAddress(addresses[i]);
          }
        } catch (err) {
          Dialog.alert(l('Error'), err);
          sendForm = false;
        }
      }

      // IMAP labels must be unique
      if (this.preferences.defaults.SOGoMailLabelsColorsKeys.length !=
          this.preferences.defaults.SOGoMailLabelsColorsValues.length ||
          this.preferences.defaults.SOGoMailLabelsColorsKeys.length !=
          _.uniq(this.preferences.defaults.SOGoMailLabelsColorsKeys).length) {
        Dialog.alert(l('Error'), l("IMAP labels must have unique names."));
        _.forEach(this.preferences.defaults.SOGoMailLabelsColorsKeys, function (value, i, keys) {
          if (form['mailIMAPLabel_' + i].$dirty &&
              (keys.indexOf(value) != i ||
               keys.indexOf(value, i+1) > -1)) {
            form['mailIMAPLabel_' + i].$setValidity('duplicate', false);
            sendForm = false;
          }
        });
      }

      // Calendar categories must be unique
      if (this.preferences.defaults.SOGoCalendarCategories.length !=
          _.uniq(this.preferences.defaults.SOGoCalendarCategories).length) {
        Dialog.alert(l('Error'), l("Calendar categories must have unique names."));
        _.forEach(this.preferences.defaults.SOGoCalendarCategories, function (value, i, keys) {
          if (form['calendarCategory_' + i].$dirty &&
              (keys.indexOf(value) != i ||
               keys.indexOf(value, i+1) > -1)) {
            form['calendarCategory_' + i].$setValidity('duplicate', false);
            sendForm = false;
          }
        });
      }

      // Contact categories must be unique
      if (this.preferences.defaults.SOGoContactsCategories.length !=
          _.uniq(this.preferences.defaults.SOGoContactsCategories).length) {
        Dialog.alert(l('Error'), l("Contact categories must have unique names."));
        _.forEach(this.preferences.defaults.SOGoContactsCategories, function (value, i, keys) {
          if (form['contactCategory_' + i].$dirty &&
              (keys.indexOf(value) != i ||
               keys.indexOf(value, i+1) > -1)) {
            form['contactCategory_' + i].$setValidity('duplicate', false);
            sendForm = false;
          }
        });
      }

      if (sendForm)
        return this.preferences.$save().then(function(data) {
          if (!options || !options.quick) {
            $mdToast.show(
              $mdToast.simple()
                .textContent(l('Preferences saved'))
                .position('bottom right')
                .hideDelay(2000));
            form.$setPristine();
          }
        });

      return $q.reject('Invalid form');
    };

    this.canChangePassword = function(form) {
      if (this.passwords.newPasswordConfirmation && this.passwords.newPasswordConfirmation.length &&
          this.passwords.newPassword != this.passwords.newPasswordConfirmation) {
        form.newPasswordConfirmation.$setValidity('newPasswordMismatch', false);
        return false;
      }
      else {
        form.newPasswordConfirmation.$setValidity('newPasswordMismatch', true);
      }
      if (this.passwords.newPassword && this.passwords.newPassword.length > 0 &&
          this.passwords.newPasswordConfirmation && this.passwords.newPasswordConfirmation.length &&
          this.passwords.newPassword == this.passwords.newPasswordConfirmation &&
          this.passwords.oldPassword && this.passwords.oldPassword.length > 0)
        return true;

      return false;
    };

    this.changePassword = function() {
      Authentication.changePassword(this.passwords.newPassword, this.passwords.oldPassword).then(function() {
        var alert = $mdDialog.alert({
          title: l('Password'),
          textContent: l('The password was changed successfully.'),
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
    };

    this.timeZonesListFilter = function(filter) {
      return _.filter(this.timeZonesList, function(value) {
        return value.toUpperCase().indexOf(filter.toUpperCase()) >= 0;
      });
    };

    this.updateVacationDates = function() {
      var d = this.preferences.defaults;

      if (d &&
          d.Vacation &&
          d.Vacation.enabled) {
        this.toggleVacationStartDate();
        this.toggleVacationEndDate();
      }
    };

    this.toggleVacationStartDate = function() {
      var v;

      v = this.preferences.defaults.Vacation;

      if (v.startDateEnabled) {
        // Enabling the start date
        if (!v.startDate) {
          v.startDate = new Date();
        }
        if (v.endDateEnabled && v.endDate && v.startDate.getTime() > v.endDate.getTime()) {
          v.startDate = new Date(v.endDate.getTime());
          v.startDate.addDays(-1);
        }
      }
    };

    this.toggleVacationEndDate = function() {
      var v;

      v = this.preferences.defaults.Vacation;

      if (v.endDateEnabled) {
        // Enabling the end date
        if (!v.endDate) {
          v.endDate = new Date();
        }
        if (v.startDateEnabled && v.startDate && v.endDate.getTime() < v.startDate.getTime()) {
          v.endDate = new Date(v.startDate.getTime());
          v.endDate.addDays(1);
        }
      }
    };

    this.validateVacationStartDate = function(date) {
      var d = vm.preferences.defaults, r = true;
      if (d &&
          d.Vacation &&
          d.Vacation.enabled) {
        if (d.Vacation.startDateEnabled) {
          r = (!d.Vacation.endDateEnabled ||
               !d.Vacation.endDate ||
               date.getTime() <= d.Vacation.endDate.getTime());
        }
      }

      return r;
    };

    this.validateVacationEndDate = function(date) {
      var d = vm.preferences.defaults, r = true;
      if (d &&
          d.Vacation &&
          d.Vacation.enabled) {
        if (d.Vacation.endDateEnabled) {
          r = (!d.Vacation.startDateEnabled ||
               !d.Vacation.startDate ||
               date.getTime() >= d.Vacation.startDate.getTime());
        }
      }

      return r;
    };
  }

  angular
    .module('SOGo.PreferencesUI')
    .controller('PreferencesController', PreferencesController);

})();
