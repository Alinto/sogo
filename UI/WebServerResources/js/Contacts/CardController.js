/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * Controller to view and edit a card
   * @ngInject
   */
  CardController.$inject = ['$scope', '$timeout', '$window', '$mdDialog', 'sgSettings', 'AddressBook', 'Card', 'Dialog', 'sgHotkeys', 'sgFocus', '$state', '$stateParams', 'stateCard'];
  function CardController($scope, $timeout, $window, $mdDialog, sgSettings, AddressBook, Card, Dialog, sgHotkeys, focus, $state, $stateParams, stateCard) {
    var vm = this, hotkeys = [];

    vm.card = stateCard;

    vm.currentFolder = AddressBook.selectedFolder;
    vm.allEmailTypes = Card.$EMAIL_TYPES;
    vm.allTelTypes = Card.$TEL_TYPES;
    vm.allUrlTypes = Card.$URL_TYPES;
    vm.allAddressTypes = Card.$ADDRESS_TYPES;
    vm.categories = {};
    vm.userFilterResults = [];
    vm.transformCategory = transformCategory;
    vm.removeAttribute = removeAttribute;
    vm.addOrg = addOrg;
    vm.addBirthday = addBirthday;
    vm.addScreenName = addScreenName;
    vm.addEmail = addEmail;
    vm.addPhone = addPhone;
    vm.addUrl = addUrl;
    vm.addAddress = addAddress;
    vm.canAddCustomField = canAddCustomField;
    vm.addCustomField = addCustomField;
    vm.deleteCustomField = deleteCustomField;
    vm.userFilter = userFilter;
    vm.save = save;
    vm.close = close;
    vm.reset = reset;
    vm.cancel = cancel;
    vm.confirmDelete = confirmDelete;
    vm.toggleRawSource = toggleRawSource;
    vm.showRawSource = false;


    _registerHotkeys(hotkeys);

    $scope.$on('$destroy', function() {
      // Deregister hotkeys
      _.forEach(hotkeys, function(key) {
        sgHotkeys.deregisterHotkey(key);
      });
    });


    function _registerHotkeys(keys) {
      keys.push(sgHotkeys.createHotkey({
        key: 'backspace',
        description: l('Delete'),
        callback: function($event) {
          if (vm.currentFolder.$selectedCount() === 0)
            confirmDelete();
          $event.preventDefault();
        }
      }));

      // Register the hotkeys
      _.forEach(keys, function(key) {
        sgHotkeys.registerHotkey(key);
      });
    }

    function transformCategory(input) {
      if (angular.isString(input))
        return { value: input };
      else
        return input;
    }
    function removeAttribute(form, attribute, index) {
      vm.card.$delete(attribute, index);
      form.$setDirty();
    }
    function addOrg() {
      var i = vm.card.$addOrg({ value: '' });
      focus('org_' + i);
    }
    function addBirthday() {
      vm.card.birthday = new Date();
    }
    function addScreenName() {
      vm.card.$addScreenName('');
    }
    function addEmail() {
      var i = vm.card.$addEmail('');
      focus('email_' + i);
    }
    function addPhone() {
      var i = vm.card.$addPhone('');
      focus('phone_' + i);
    }
    function addUrl() {
      var i = vm.card.$addUrl('', '');
      focus('url_' + i);
    }
    function canAddCustomField() {
      return _.keys(stateCard.customFields).length < 4;
    }
    function addCustomField() {
      if (!angular.isDefined(vm.card.customFields))
        vm.card.customFields = {};

      // Find the first 'available' custom field
      var availableKeys = _.pullAll(['1', '2', '3', '4'], _.keys(stateCard.customFields));
      vm.card.customFields[availableKeys[0]] = "";
    }
    function deleteCustomField(key) {
      delete vm.card.customFields[key];
    }
    function addAddress() {
      var i = vm.card.$addAddress('', '', '', '', '', '', '', '');
      focus('address_' + i);
    }
    function userFilter($query, excludedCards) {
      if ($query.length < sgSettings.minimumSearchLength())
        return [];

      return AddressBook.selectedFolder.$filter($query, {dry: true, excludeLists: true}, excludedCards).then(function(cards) {
        return cards;
      });
    }
    function save(form) {
      if (form.$valid) {
        vm.card.$save()
          .then(function(data) {
            var i = _.indexOf(_.map(AddressBook.selectedFolder.$cards, 'id'), vm.card.id);
            if (i < 0) {
              // New card; reload contacts list and show addressbook in which the card has been created
              AddressBook.selectedFolder.$reload();
            }
            else {
              // Update contacts list with new version of the Card object
              AddressBook.selectedFolder.$cards[i] = angular.copy(vm.card);
            }
            $state.go('app.addressbook.card.view', { cardId: vm.card.id });
          });
      }
    }
    function close() {
      $state.go('app.addressbook').then(function() {
        vm.card = null;
        delete AddressBook.selectedFolder.selectedCard;
      });
    }
    function reset(form) {
      vm.card.$reset();
      form.$setPristine();
    }
    function cancel() {
      vm.card.$reset();
      if (vm.card.isNew) {
        // Cancelling the creation of a card
        vm.card = null;
        delete AddressBook.selectedFolder.selectedCard;
        $state.go('app.addressbook', { addressbookId: AddressBook.selectedFolder.id });
      }
      else {
        // Cancelling the edition of an existing card
        $state.go('app.addressbook.card.view', { cardId: vm.card.id });
      }
    }
    function confirmDelete() {
      var card = stateCard;

      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the card of %{0}?', '<b>' + card.$fullname() + '</b>'),
                     { ok: l('Delete') })
        .then(function() {
          // User confirmed the deletion
          AddressBook.selectedFolder.$deleteCards([card])
            .then(function() {
              close();
            }, function(data, status) {
              Dialog.alert(l('Warning'), l('An error occured while deleting the card "%{0}".',
                                           card.$fullname()));
            });
        });
    }

    function toggleRawSource($event) {
      if (!vm.showRawSource && !vm.rawSource) {
        Card.$$resource.post(vm.currentFolder.id + '/' + vm.card.id, "raw").then(function(data) {
          vm.rawSource = data;
          vm.showRawSource = true;
        });
      }
      else {
        vm.showRawSource = !vm.showRawSource;
      }
    }
  }

  angular
    .module('SOGo.ContactsUI')
    .controller('CardController', CardController);
})();
