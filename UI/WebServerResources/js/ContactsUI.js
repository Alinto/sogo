/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* JavaScript for SOGoContacts */

(function() {
    'use strict';

    angular.module('SOGo.Common', []);

    angular.module('SOGo.Contacts', ['ngSanitize', 'ui.router', 'mm.foundation', 'mm.foundation.offcanvas', 'SOGo.Common'])

    .constant('sgSettings', {
        'baseURL': '/SOGo/so/francis/Contacts'
    })

    .config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
        $stateProvider
            .state('addressbook', {
                url: "/:addressbook_id",
                views: {
                    'addressbook': {
                        templateUrl: "addressbook.html",
                        controller: 'AddressBookCtrl'
                    }
                }
            })
            .state('addressbook.card', {
                url: "/:card_id",
                views: {
                    'card': {
                        templateUrl: "card.html",
                        controller: 'cardCtrl'
                    }
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

    .factory('sgFocus', ['$rootScope', '$timeout', function ($rootScope, $timeout) {
      return function(name) {
        $timeout(function (){
          $rootScope.$broadcast('sgFocusOn', name);
        });
      }
    }])

    .controller('AddressBookCtrl', ['$state', '$scope', '$rootScope', '$stateParams', '$timeout', '$modal', 'sgFocus', 'sgCard', 'sgAddressBook', function($state, $scope, $rootScope, $stateParams, $timeout, $modal, focus, Card, AddressBook) {
        $scope.search = { 'status': null, 'filter': null, 'last_filter': null };
        if ($stateParams.addressbook_id &&
            ($rootScope.addressbook == undefined || $stateParams.addressbook_id != $rootScope.addressbook.id)) {
            // Selected addressbook has changed
            $rootScope.addressbook = AddressBook.$find($stateParams.addressbook_id);
            // Extend resulting model instance with parameters from addressbooks listing
            var o = _.find($rootScope.addressbooks, function(o) {
                return o.id ==  $stateParams.addressbook_id;
            });
            $scope.search.status = (o.isRemote)? 'remote-addressbook' : '';
        }
        // Initialize with data from template
        $scope.init = function() {
            $rootScope.addressbooks = AddressBook.$all(contactFolders);
        };
        $scope.select = function(rowIndex) {
            $scope.editMode = false;
        };
        $scope.edit = function(i) {
            if (angular.isUndefined(i)) {
                i = _.indexOf(_.pluck($rootScope.addressbooks, 'id'), $rootScope.addressbook.id);
            }
            $scope.editMode = $rootScope.addressbook.id;
            focus('addressBookName_' + i);
        };
        $scope.save = function(i) {
            $rootScope.addressbook.name = $rootScope.addressbooks[i].name;
            $rootScope.addressbook.$save()
                .then(function(data) {
                    console.debug("saved!");
                    $scope.editMode = false;
                }, function(data, status) {
                    console.debug("failed");
                });
        };
        $scope.sharing = function() {
            var modal = $modal.open({
                templateUrl: 'addressbookSharing.html',
                //controller: 'addressbookSharingCtrl'
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

    // angular.module('SOGo').controller('addressbookSharingCtrl', ['$scope', '$modalInstance', function($scope, modal) {
    //     $scope.closeModal = function() {
    //         console.debug('please close it');
    //         modal.close();
    //     };
    // }]);

    .controller('cardCtrl', ['$scope', '$rootScope', 'sgAddressBook', 'sgCard', 'sgFocus', '$stateParams', function($scope, $rootScope, AddressBook, Card, focus, $stateParams) {
        if ($stateParams.card_id) {
            if ($rootScope.addressbook == null) {
                // Card is directly access with URL fragment
                $rootScope.addressbook = AddressBook.$find($stateParams.addressbook_id);
            }
            $rootScope.addressbook.$getCard($stateParams.card_id);
            $scope.editMode = false;
        }
        $scope.allEmailTypes = Card.$email_types;
        $scope.allTelTypes = Card.$tel_types;
        $scope.allUrlTypes = Card.$url_types;
        $scope.allAddressTypes = Card.$address_types;
        $scope.edit = function() {
            $rootScope.master_card = angular.copy($rootScope.addressbook.card);
            $scope.editMode = true;
            console.debug('edit');
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
        $scope.save = function(cardForm) {
            console.debug("save");
            if (cardForm.$valid) {
                $rootScope.addressbook.card.$save()
                    .then(function(data) {
                        console.debug("saved!");
                        $scope.editMode = false;
                    }, function(data, status) {
                        console.debug("failed");
                    });
            }
        };
        $scope.cancel = function() {
            $scope.reset();
            $scope.editMode = false;
        };
        $scope.reset = function() {
            $rootScope.addressbook.card = angular.copy($rootScope.master_card);
        };
    }]);

})();
