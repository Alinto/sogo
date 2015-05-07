/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * Controller to view and edit a card
   * @ngInject
   */
  CardController.$inject = ['$scope', '$rootScope', '$timeout', 'AddressBook', 'Card', 'Dialog', 'sgFocus', '$state', '$stateParams', 'stateCard'];
  function CardController($scope, $rootScope, $timeout, AddressBook, Card, Dialog, focus, $state, $stateParams, stateCard) {
    $rootScope.card = stateCard;

    $scope.allEmailTypes = Card.$EMAIL_TYPES;
    $scope.allTelTypes = Card.$TEL_TYPES;
    $scope.allUrlTypes = Card.$URL_TYPES;
    $scope.allAddressTypes = Card.$ADDRESS_TYPES;
    $scope.categories = {};
    $scope.userFilterResults = [];

    $scope.addOrgUnit = function() {
      var i = $scope.card.$addOrgUnit('');
      focus('orgUnit_' + i);
    };
    $scope.addEmail = function() {
      var i = $scope.card.$addEmail('');
      focus('email_' + i);
    };
    $scope.addPhone = function() {
      var i = $scope.card.$addPhone('');
      focus('phone_' + i);
    };
    $scope.addUrl = function() {
      var i = $scope.card.$addUrl('', '');
      focus('url_' + i);
    };
    $scope.addAddress = function() {
      var i = $scope.card.$addAddress('', '', '', '', '', '', '', '');
      focus('address_' + i);
    };
    $scope.addMember = function() {
      var i = $scope.card.$addMember('');
      focus('ref_' + i);
    };
    $scope.userFilter = function($query) {
      $scope.currentFolder.$filter($query, {dry: true, excludeLists: true}).then(function(results) {
        $scope.userFilterResults = results;
      });
      return $scope.userFilterResults;
    };
    $scope.save = function(form) {
      if (form.$valid) {
        $scope.card.$save()
          .then(function(data) {
            var i = _.indexOf(_.pluck($scope.currentFolder.cards, 'id'), $scope.card.id);
            if (i < 0) {
              // New card; reload contacts list and show addressbook in which the card has been created
              $rootScope.currentFolder = AddressBook.$find(data.pid);
            }
            else {
              // Update contacts list with new version of the Card object
              $rootScope.currentFolder.cards[i] = angular.copy($scope.card);
            }
            $state.go('app.addressbook.card.view', { cardId: $scope.card.id });
          }, function(data, status) {
            console.debug('failed');
          });
      }
    };
    $scope.reset = function() {
      $scope.card.$reset();
    };
    $scope.cancel = function() {
      $scope.card.$reset();
      if ($scope.card.isNew) {
        // Cancelling the creation of a card
        $rootScope.card = null;
        $state.go('app.addressbook', { addressbookId: $scope.currentFolder.id });
      }
      else {
        // Cancelling the edition of an existing card
        $state.go('app.addressbook.card.view', { cardId: $scope.card.id });
      }
    };
    $scope.confirmDelete = function(card) {
      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the card of %{0}?', card.$fullname()))
        .then(function() {
          // User confirmed the deletion
          card.$delete()
            .then(function() {
              // Remove card from list of addressbook
              $rootScope.currentFolder.cards = _.reject($rootScope.currentFolder.cards, function(o) {
                return o.id == card.id;
              });
              // Remove card object from scope
              $rootScope.card = null;
              $state.go('app.addressbook', { addressbookId: $scope.currentFolder.id });
            }, function(data, status) {
              Dialog.alert(l('Warning'), l('An error occured while deleting the card "%{0}".',
                                           card.$fullname()));
            });
        });
    };
  }

  angular
    .module('SOGo.ContactsUI')
    .controller('CardController', CardController);
})();
