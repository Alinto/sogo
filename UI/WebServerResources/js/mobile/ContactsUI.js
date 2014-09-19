/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoContacts (mobile) */

(function() {
  'use strict';

  angular.module('SOGo.Common', []);

  angular.module('SOGo.ContactsUI', ['ionic', 'SOGo.Common', 'SOGo.UIMobile'])

    .constant('sgSettings', {
      baseURL: ApplicationBaseURL
    })

    .run(function($ionicPlatform) {
      $ionicPlatform.ready(function() {
        // Hide the accessory bar by default (remove this to show the accessory bar above the keyboard
        // for form inputs)
        if (window.cordova && window.cordova.plugins.Keyboard) {
          cordova.plugins.Keyboard.hideKeyboardAccessoryBar(true);
        }
        if (window.StatusBar) {
          // org.apache.cordova.statusbar required
          StatusBar.styleDefault();
        }
      });
    })

    .config(function($stateProvider, $urlRouterProvider) {
      $stateProvider
        .state('app', {
          url: '/app',
          abstract: true,
          templateUrl: 'menu.html',
          controller: 'AppCtrl'
        })

        .state('app.addressbooks', {
          url: '/addressbooks',
          views: {
            menuContent: {
              templateUrl: 'addressbooks.html',
              controller: 'AddressBooksCtrl'
            }
          }
        })

        .state('app.addressbook', {
          url: '/addressbook/:addressbookId',
          views: {
            menuContent: {
              templateUrl: 'addressbook.html',
              controller: 'AddressBookCtrl',
              resolve: {
                stateAddressbook: function($stateParams, sgAddressBook) {
                  return sgAddressBook.$find($stateParams.addressbookId);
                }
              }
            }
          }
        })

        .state('app.newCard', {
          url: '/addressbook/:addressbookId/:contactType/new',
          views: {
            menuContent: {
              templateUrl: 'card.html',
              controller: 'CardCtrl',
              resolve: {
                stateCard: ['$rootScope', '$stateParams', 'sgAddressBook', 'sgCard', function($rootScope, $stateParams, sgAddressBook, Card) {
                  var tag = 'v' + $stateParams.contactType;
                  if (!$rootScope.addressbook) {
                    $rootScope.addressbook = sgAddressBook.$find($stateParams.addressbookId);
                  }
                  return new Card(
                    {
                      pid: $stateParams.addressbookId,
                      tag: tag,
                      isNew: true
                    }
                  );
                }]
              }
            }
          }
        })

        .state('app.card', {
          url: '/addressbook/:addressbookId/:cardId',
          views: {
            menuContent: {
              templateUrl: 'card.html',
              controller: 'CardCtrl',
              resolve: {
                stateCard: function($rootScope, $stateParams, sgAddressBook) {
                  if (!$rootScope.addressbook) {
                    $rootScope.addressbook = sgAddressBook.$find($stateParams.addressbookId);
                  }
                  return $rootScope.addressbook.$getCard($stateParams.cardId);
                }
              }
            }
          }
        });

      // if none of the above states are matched, use this as the fallback
      $urlRouterProvider.otherwise('/app/addressbooks');
    })

    .controller('AppCtrl', ['$scope', '$http', function($scope, $http) {
      $scope.UserLogin = UserLogin;
      $scope.UserFolderURL = UserFolderURL;
      $scope.ApplicationBaseURL = ApplicationBaseURL;
      // $scope.logout = function(url) {
      //     $http.get(url)
      //     .success(function(data, status, headers) {
      //         console.debug(headers);
      //     });
      // };
    }])

    .controller('AddressBooksCtrl', ['$scope', '$rootScope', '$ionicModal', '$ionicListDelegate', '$ionicActionSheet', 'sgDialog', 'sgAddressBook', function($scope, $rootScope, $ionicModal, $ionicListDelegate, $ionicActionSheet, Dialog, AddressBook) {
      // Initialize with data from template
      $scope.addressbooks = AddressBook.$all(contactFolders);
      $scope.newAddressbook = function() {
        Dialog.prompt(l('Create addressbook'),
                      l('Name of new addressbook'))
          .then(function(res) {
            if (res && res.length > 0) {
              var addressbook = new AddressBook(
                {
                  name: res,
                  isEditable: true,
                  isRemote: false
                }
              );
              AddressBook.$add(addressbook);
            }
          });
      };
      $scope.edit = function(addressbook) {
        $ionicActionSheet.show({
          titleText: l('Modify your addressbook %{0}', addressbook.name),
          buttons: [
            { text: l('Rename') }
          ],
          destructiveText: l('Delete'),
          cancelText: l('Cancel'),
          buttonClicked: function(index) {
            // Rename addressbook
            Dialog.prompt(l('Rename addressbook'),
                          addressbook.name)
              .then(function(name) {
                if (name && name.length > 0) {
                  addressbook.$rename(name);
                }
              });
            return true;
          },
          destructiveButtonClicked: function() {
            // Delete addressbook
            addressbook.$delete()
              .then(function() {
                addressbook = null;
              }, function(data) {
                Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                               addressbook.name),
                             l(data.error));
              });
            return true;
          }
          // cancel: function() {
          // },
        });
        $ionicListDelegate.closeOptionButtons();
      };
    }])

    .controller('AddressBookCtrl', ['$scope', '$rootScope', '$stateParams', '$state', 'sgAddressBook', 'sgCard', 'stateAddressbook', function($scope, $rootScope, $stateParams, $state, AddressBook, Card, stateAddressbook) {
      $rootScope.addressbook = stateAddressbook;

      $scope.search = { status: null, filter: null, lastFilter: null };
      $scope.doSearch = function(keyEvent) {
        if ($scope.search.lastFilter != $scope.search.filter) {
          if ($scope.search.filter.length > 2) {
            $rootScope.addressbook.$filter($scope.search.filter).then(function(data) {
              if (data.length == 0)
                $scope.search.status = 'no-result';
              else
                $scope.search.status = '';
            });
          }
          else if ($scope.search.filter.length == 0) {
            $scope.searchStatus = '';
            $rootScope.addressbook = AddressBook.$find($rootScope.addressbook.id);
          }
          else {
            $scope.search.status = 'min-char';
            $rootScope.addressbook.cards = [];
          }
        }
        $scope.search.lastFilter = $scope.search.filter;
      };
    }])

    .controller('CardCtrl', ['$scope', '$rootScope', '$state', '$stateParams', '$ionicModal', 'sgDialog', 'sgAddressBook', 'sgCard', 'stateCard', function($scope, $rootScope, $state, $stateParams, $ionicModal, Dialog, AddressBook, Card, stateCard) {
      $rootScope.addressbook.card = stateCard;

      $scope.UserFolderURL = UserFolderURL;
      $scope.allEmailTypes = Card.$EMAIL_TYPES;
      $scope.allTelTypes = Card.$TEL_TYPES;
      $scope.allUrlTypes = Card.$URL_TYPES;
      $scope.allAddressTypes = Card.$ADDRESS_TYPES;

      $scope.edit = function() {
        // Copy card to be able to cancel changes later
        $scope.masterCard = angular.copy($rootScope.addressbook.card);
        // Build modal editor
        $ionicModal.fromTemplateUrl('cardEditor.html', {
          scope: $scope,
          focusFirstInput: false
        }).then(function(modal) {
          if ($scope.$cardEditorModal) {
            // Delete previous modal
            $scope.$cardEditorModal.remove();
          }
          $scope.$cardEditorModal = modal;
          // Show modal
          $scope.$cardEditorModal.show();
        });
      };
      $scope.cancel = function() {
        if ($rootScope.addressbook.card.isNew) {
          $scope.$cardEditorModal.hide().then(function() {
            // Go back to addressbook
            $state.go('app.addressbook', { addressbookId: $rootScope.addressbook.id });
          });
        }
        else {
          $rootScope.addressbook.card = angular.copy($scope.masterCard);
          $scope.$cardEditorModal.hide()
        }
      };
      $scope.addOrgUnit = function() {
        var i = $rootScope.addressbook.card.$addOrgUnit('');
        focus('orgUnit_' + i);
      };
      $scope.addCategory = function() {
        var i = $rootScope.addressbook.card.$addCategory('');
        focus('category_' + i);
      };
      $scope.addEmail = function() {
        var i = $rootScope.addressbook.card.$addEmail('');
        focus('email_' + i);
      };
      $scope.addPhone = function() {
        var i = $rootScope.addressbook.card.$addPhone('');
        focus('phone_' + i);
      };
      $scope.addUrl = function() {
        var i = $rootScope.addressbook.card.$addUrl('', '');
        focus('url_' + i);
      };
      $scope.addAddress = function() {
        var i = $rootScope.addressbook.card.$addAddress('', '', '', '', '', '', '', '');
        focus('address_' + i);
      };
      $scope.addMember = function() {
        var i = $rootScope.addressbook.card.$addMember('');
        focus('ref_' + i);
      };
      $scope.save = function(form) {
        if (form.$valid) {
          $rootScope.addressbook.card.$save()
            .then(function(data) {
              var i, card;
              delete $rootScope.addressbook.card.isNew;
              i = _.indexOf(_.pluck($rootScope.addressbook.cards, 'id'), $rootScope.addressbook.card.id);
              if (i < 0) {
                // New card
                // Reload contacts list and show addressbook in which the card has been created
                card = angular.copy($rootScope.addressbook.card);
                $rootScope.addressbook = AddressBook.$find(data.pid);
                $rootScope.addressbook.card = card;
              }
              else {
                // Update contacts list with new version of the Card object
                $rootScope.addressbook.cards[i] = angular.copy($rootScope.addressbook.card);
              }
              // Close editor
              $scope.$cardEditorModal.hide();
            });
        }
      };
      $scope.confirmDelete = function(card) {
        Dialog.confirm(l('Warning'),
                       l('Are you sure you want to delete the card of <b>%{0}</b>?', card.$fullname()))
          .then(function(res) {
            if (res) {
              // User has confirmed deletion
              card.$delete()
                .then(function() {
                  // Delete card from list of addressbook
                  $rootScope.addressbook.cards = _.reject($rootScope.addressbook.cards, function(o) {
                    return o.id == card.id;
                  });
                  // Delete card object
                  delete $rootScope.addressbook.card;
                  // Delete modal editor
                  $scope.$cardEditorModal.remove();
                  // Go back to addressbook
                  $state.go('app.addressbook', { addressbookId: $rootScope.addressbook.id });
                }, function(data, status) {
                  Dialog.alert(l('Warning'), l('An error occured while deleting the card "%{0}".',
                                               card.$fullname()));
                });
            }
          });
      };

      if ($scope.addressbook.card && $scope.addressbook.card.isNew) {
        // New contact
        $scope.edit();
      }
    }]);

})();
