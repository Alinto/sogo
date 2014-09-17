/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoContacts */

(function() {
  'use strict';

  angular.module('SOGo.Common', []);

  angular.module('SOGo.ContactsUI', ['ngSanitize', 'ui.router', 'mm.foundation', 'SOGo.Common', 'SOGo.UIDesktop'])

    .constant('sgSettings', {
      baseURL: ApplicationBaseURL
    })

    .config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
      $stateProvider
        .state('addressbook', {
          url: '/:addressbook_id',
          views: {
            addressbooks: {
              templateUrl: 'addressbooks.html',
              controller: 'AddressBookCtrl'
            }
          },
          resolve: {
            stateAddressbooks: ['sgAddressBook', function(AddressBook) {
              return AddressBook.$all(contactFolders);
            }],
            stateAddressbook: ['$stateParams', 'sgAddressBook', function($stateParams, AddressBook) {
              return AddressBook.$find($stateParams.addressbook_id);
            }]
          }
        })
        .state('addressbook.card', {
          url: '/:card_id',
          views: {
            card: {
              templateUrl: 'card.html',
              controller: 'CardCtrl'
            }
          },
          resolve: {
            stateCard: ['$stateParams', 'stateAddressbook', function($stateParams, stateAddressbook) {
              return stateAddressbook.$getCard($stateParams.card_id);
            }]
          }
        })
        .state('addressbook.new', {
          url: '/:contact_type/new',
          views: {
            card: {
              templateUrl: 'cardEditor.html',
              controller: 'CardCtrl'
            }
          },
          resolve: {
            stateCard: ['$stateParams', 'stateAddressbook', 'sgCard', function($stateParams, stateAddressbook, Card) {
              var tag = 'v' + $stateParams.contact_type;
              stateAddressbook.card = new Card({ pid: $stateParams.addressbook_id, tag: tag });
              return stateAddressbook.card;
            }]
          }
        })
        .state('addressbook.editor', {
          url: '/:card_id/edit',
          views: {
            card: {
              templateUrl: 'cardEditor.html',
              controller: 'CardCtrl'
            }
          },
          resolve: {
            stateCard: ['$stateParams', 'stateAddressbook', function($stateParams, stateAddressbook) {
              return stateAddressbook.$getCard($stateParams.card_id);
            }]
          }
        });

      // if none of the above states are matched, use this as the fallback
      $urlRouterProvider.otherwise('/personal');
    }])

    .directive('sgFocusOn', function() {
      return function(scope, elem, attr) {
        scope.$on('sgFocusOn', function(e, name) {
          if (name === attr.sgFocusOn) {
            elem[0].focus();
            elem[0].select();
          }
        });
      };
    })

    .factory('sgFocus', ['$rootScope', '$timeout', function($rootScope, $timeout) {
      return function(name) {
        $timeout(function() {
          $rootScope.$broadcast('sgFocusOn', name);
        });
      }
    }])

    .controller('AddressBookCtrl', ['$state', '$scope', '$rootScope', '$stateParams', '$timeout', '$modal', 'sgFocus', 'sgCard', 'sgAddressBook', 'sgDialog', 'stateAddressbooks', 'stateAddressbook', function($state, $scope, $rootScope, $stateParams, $timeout, $modal, focus, Card, AddressBook, Dialog, stateAddressbooks, stateAddressbook) {
      var addressbookEntry;

      // $scope objects
      $scope.search = { status: null, filter: null, last_filter: null };

      $rootScope.addressbooks = stateAddressbooks;
      $rootScope.addressbook = stateAddressbook;

      // Adjust search status depending on addressbook type
      var o = _.find($rootScope.addressbooks, function(o) {
        return o.id ==  $stateParams.addressbook_id;
      });
      $scope.search.status = (o && o.isRemote)? 'remote-addressbook' : '';

      // $scope functions
      $scope.select = function(rowIndex) {
        $scope.editMode = false;
      };
      $scope.newAddressbook = function() {
        $scope.editMode = false;
        Dialog.prompt(l('New addressbook'),
                      l('Name of new addressbook'))
          .then(function(name) {
            if (name && name.length > 0) {
              var addressbook = new AddressBook(
                {
                  name: name,
                  isEditable: true,
                  isRemote: false
                }
              );
              AddressBook.$add(addressbook);
            }
          });
      };
      $scope.edit = function(i) {
        if (!$rootScope.addressbook.isRemote) {
          if (angular.isUndefined(i)) {
            i = _.indexOf(_.pluck($rootScope.addressbooks, 'id'), $rootScope.addressbook.id);
          }
          $scope.editMode = $rootScope.addressbook.id;
          focus('addressBookName_' + i);
        }
      };
      $scope.save = function(i) {
        var name = $rootScope.addressbooks[i].name;
        if (name && name.length > 0) {
          $scope.addressbook.$rename(name)
            .then(function(data) {
              $scope.editMode = false;
            }, function(data, status) {
              Dialog.alert(l('Warning'), data);
            });
        }
      };
      $scope.confirmDelete = function() {
        Dialog.confirm(l('Warning'), l('Are you sure you want to delete the addressbook <em>%{0}</em>?',
                                       $rootScope.addressbook.name))
          .then(function(res) {
            if (res) {
              $rootScope.addressbook.$delete()
                .then(function() {
                  $rootScope.addressbook = null;
                }, function(data, status) {
                  Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                                 $rootScope.addressbook.name),
                               l(data.error));
                });
            }
          });
      };
      $scope.importCards = function() {
      };
      $scope.share = function() {
        var modal = $modal.open({
          templateUrl: 'addressbookSharing.html',
          controller: function($scope, $modalInstance) {
            $scope.closeModal = function() {
              $modalInstance.close();
            };
          }
        });
      };
      $scope.doSearch = function(keyEvent) {
        if ($scope.search.filter != $scope.search.last_filter) {
          if ($scope.search.filter.length > 2) {
            $rootScope.addressbook.$filter($scope.search.filter).then(function(data) {
              if (data.length == 0)
                $scope.search.status = 'no-result';
              else
                $scope.search.status = '';
            });
          }
          else if ($scope.search.filter.length == 0) {
            $rootScope.addressbook = AddressBook.$find($stateParams.addressbook_id);
            // Extend resulting model instance with parameters from addressbooks listing
            var o = _.find($rootScope.addressbooks, function(o) {
              return o.id ==  $stateParams.addressbook_id;
            });
            $scope.search.status = (o.isRemote)? 'remote-addressbook' : '';
          }
          else {
            $scope.search.status = 'min-char';
            $rootScope.addressbook.cards = [];
          }
        }
        $scope.search.last_filter = $scope.search.filter;
      };
    }])

    .controller('CardCtrl', ['$scope', '$rootScope', 'sgAddressBook', 'sgCard', 'sgDialog', 'sgFocus', '$state', '$stateParams', function($scope, $rootScope, AddressBook, Card, Dialog, focus, $state, $stateParams) {
      $scope.allEmailTypes = Card.$email_types;
      $scope.allTelTypes = Card.$tel_types;
      $scope.allUrlTypes = Card.$url_types;
      $scope.allAddressTypes = Card.$address_types;

      $rootScope.master_card = angular.copy($rootScope.addressbook.card);

      $scope.addOrgUnit = function() {
        var i = $rootScope.addressbook.card.$addOrgUnit('');
        focus('orgUnit_' + i);
      };
      $scope.addCategory = function() {
        var i = $rootScope.addressbook.card.$addCategory($scope.new_category);
        focus('category_' + i);
      };
      $scope.addEmail = function() {
        var i = $rootScope.addressbook.card.$addEmail($scope.new_email_type);
        focus('email_' + i);
      };
      $scope.addPhone = function() {
        var i = $rootScope.addressbook.card.$addPhone($scope.new_phone_type);
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
              var i = _.indexOf(_.pluck($rootScope.addressbook.cards, 'id'), $rootScope.addressbook.card.id);
              if (i < 0) {
                // Reload contacts list and show addressbook in which the card has been created
                $rootScope.addressbook = AddressBook.$find(data.pid);
              }
              else {
                // Update contacts list with new version of the Card object
                $rootScope.addressbook.cards[i] = angular.copy($rootScope.addressbook.card);
              }
              $state.go('addressbook.card');
            }, function(data, status) {
              console.debug('failed');
            });
        }
      };
      $scope.cancel = function() {
        $scope.reset();
        delete $rootScope.master_card;
        if ($scope.addressbook.card.id) {
          // Cancelling the edition of an existing card
          $state.go('addressbook.card', { card_id: $scope.addressbook.card.id });
        }
        else {
          // Cancelling the creation of a card
          delete $rootScope.addressbook.card;
          $state.go('addressbook', { addressbook_id: $scope.addressbook.id });
        }
      };
      $scope.reset = function() {
        $rootScope.addressbook.card = angular.copy($rootScope.master_card);
      };
      $scope.confirmDelete = function(card) {
        Dialog.confirm(l('Warning'),
                       l('Are you sure you want to delete the card of <em>%{0}</em>?', card.$fullname()))
          .then(function(res) {
            if (res) {
              // User confirmed the deletion
              card.$delete()
                .then(function() {
                  $rootScope.addressbook.cards = _.reject($rootScope.addressbook.cards, function(o) {
                    return o.id == card.id;
                  });
                  delete $rootScope.addressbook.card;
                }, function(data, status) {
                  Dialog.alert(l('Warning'), l('An error occured while deleting the card "%{0}".',
                                               card.$fullname()));
                });
            }
          });
      };
    }]);

})();
