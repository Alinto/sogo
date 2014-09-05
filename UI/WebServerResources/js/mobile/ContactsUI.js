/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* JavaScript for SOGoContacts (mobile) */

(function() {
    'use strict';

    angular.module('SOGo.Common', []);

    angular.module('SOGo.ContactsUI', ['ionic', 'SOGo.Common', 'SOGo.UIMobile'])

    .constant('sgSettings', {
        'baseURL': ApplicationBaseURL
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
                url: "/app",
                abstract: true,
                templateUrl: "menu.html",
                controller: 'AppCtrl'
            })

            .state('app.addressbooks', {
                url: "/addressbooks",
                views: {
                    'menuContent': {
                        templateUrl: "addressbooks.html",
                        controller: 'AddressBooksCtrl'
                    }
                }
            })

            .state('app.addressbook', {
                url: "/addressbook/:addressbook_id",
                views: {
                    'menuContent': {
                        templateUrl: "addressbook.html",
                        controller: 'AddressBookCtrl',
                        resolve: {
                            stateAddressbook: function($stateParams, sgAddressBook) {
                                return sgAddressBook.$find($stateParams.addressbook_id);
                            }
                        }
                    }
                }
            })

            .state('app.newCard', {
                url: "/addressbook/:addressbook_id/:contact_type/new",
                views: {
                    'menuContent': {
                        templateUrl: "card.html",
                        controller: 'CardCtrl',
                        resolve: {
                            stateCard: function($rootScope, $stateParams, sgAddressBook, sgCard) {
                                var tag = 'v' + $stateParams.contact_type;
                                if (!$rootScope.addressbook) {
                                    $rootScope.addressbook = sgAddressBook.$find($stateParams.addressbook_id);
                                }
                                return new sgCard({ 'pid': $stateParams.addressbook_id,
                                                                           'tag': tag,
                                                                           'isNew': true });
                            }
                        }
                    }
                }
            })

            .state('app.card', {
                url: "/addressbook/:addressbook_id/:card_id",
                views: {
                    'menuContent': {
                        templateUrl: "card.html",
                        controller: 'CardCtrl',
                        resolve: {
                            stateCard: function($rootScope, $stateParams, sgAddressBook) {
                                if (!$rootScope.addressbook) {
                                    $rootScope.addressbook = sgAddressBook.$find($stateParams.addressbook_id);
                                }
                                return $rootScope.addressbook.$getCard($stateParams.card_id);
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

.controller('AddressBooksCtrl', ['$scope', '$rootScope', '$timeout', 'sgAddressBook', function($scope, $rootScope, $timeout, AddressBook) {
    // Initialize with data from template
    $scope.addressbooks = AddressBook.$all(contactFolders);
    $scope.edit = function(i) {

    };
    $scope.save = function(i) {

    };
}])

    .controller('AddressBookCtrl', ['$scope', '$rootScope', '$stateParams', '$state', 'sgAddressBook', 'sgCard', 'stateAddressbook', function($scope, $rootScope, $stateParams, $state, AddressBook, Card, stateAddressbook) {
        $rootScope.addressbook = stateAddressbook;

        $scope.search = { 'status': null, 'filter': null, 'last_filter': null };
        $scope.doSearch = function(keyEvent) {
            if ($scope.search.last_filter != $scope.search.filter) {
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
            $scope.search.last_filter = $scope.search.filter;
        };
    }])

    .controller('CardCtrl', ['$scope', '$rootScope', '$state', '$stateParams', '$ionicModal', 'sgDialog', 'sgAddressBook', 'sgCard', 'stateCard', function($scope, $rootScope, $state, $stateParams, $ionicModal, Dialog, AddressBook, Card, stateCard) {
        $rootScope.addressbook.card = stateCard;

        $scope.UserFolderURL = UserFolderURL;
        $scope.allEmailTypes = Card.$email_types;
        $scope.allTelTypes = Card.$tel_types;
        $scope.allUrlTypes = Card.$url_types;
        $scope.allAddressTypes = Card.$address_types;

        $scope.edit = function() {
            // Copy card to be able to cancel changes later
            $scope.master_card = angular.copy($rootScope.addressbook.card);
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
                    $state.go('app.addressbook', { addressbook_id: $rootScope.addressbook.id });
                });
            }
            else {
                $rootScope.addressbook.card = angular.copy($scope.master_card);
                $scope.$cardEditorModal.hide()
            }
        };
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
                        delete $rootScope.addressbook.card.isNew;
                        var i = _.indexOf(_.pluck($rootScope.addressbook.cards, 'id'), $rootScope.addressbook.card.id);
                        if (i < 0) {
                            // New card
                            // Reload contacts list and show addressbook in which the card has been created
                            var card = angular.copy($rootScope.addressbook.card);
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
                                $state.go('app.addressbook', { addressbook_id: $rootScope.addressbook.id });
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
