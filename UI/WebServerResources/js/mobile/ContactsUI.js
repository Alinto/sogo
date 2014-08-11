/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* JavaScript for SOGoContacts (mobile) */

(function() {
    'use strict';

    angular.module('SOGo.Common', []);

    angular.module('SOGo.Contacts', ['ionic', 'SOGo.Common', 'SOGo.Contacts'])

    .constant('sgSettings', {
        'baseURL': ApplicationBaseURL
    })

    .run(function($ionicPlatform) {
        $ionicPlatform.ready(function() {
            // Hide the accessory bar by default (remove this to show the accessory bar above the keyboard
            // for form inputs)
            if(window.cordova && window.cordova.plugins.Keyboard) {
                cordova.plugins.Keyboard.hideKeyboardAccessoryBar(true);
            }
            if(window.StatusBar) {
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
                        controller: 'AddressBookCtrl'
                    }
                }
            })

            .state('app.contact', {
                url: "/addressbook/:addressbook_id/:card_id",
                views: {
                    'menuContent': {
                        templateUrl: "card.html",
                        controller: 'CardCtrl'
                    }
                }
            });

        // if none of the above states are matched, use this as the fallback
        $urlRouterProvider.otherwise('/app/addressbooks');
    })

// .directive('sgAddress', function() {
//     return {
//         restrict: 'A',
//         replace: false,
//         scope: { data: '=sgAddress' },
//         controller: ['$scope', function($scope) {
//             $scope.addressLines = function(data) {
//                 var lines = [];
//                 if (data.street) lines.push(data.street);
//                 if (data.street2) lines.push(data.street2);
//                 var locality_region = [];
//                 if (data.locality) locality_region.push(data.locality);
//                 if (data.region) locality_region.push(data.region);
//                 if (locality_region.length > 0) lines.push(locality_region.join(', '));
//                 if (data.country) lines.push(data.country);
//                 if (data.postalcode) lines.push(data.postalcode);
//                 return lines.join('<br>');
//             };
//         }],
//         template: '<address ng-bind-html="addressLines(data)"></address>'
//     }
// })

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
    // $scope.select = function(rowIndex) {
    //     $rootScope.selectedAddressBook = $rootScope.addressbooks[rowIndex];
    // };
    // $scope.rename = function() {
    //     console.debug("rename folder");
    //     $scope.editMode = $rootScope.addressbook.id;
    //     //focus('folderName');
    // };
    // $scope.save = function() {
    //     console.debug("save addressbook");
    //     $rootScope.addressbook.$save()
    //         .then(function(data) {
    //             console.debug("saved!");
    //             $scope.editMode = false;
    //         }, function(data, status) {
    //             console.debug("failed");
    //         });
    // };
}])

    .controller('AddressBookCtrl', ['$scope', '$rootScope', '$stateParams', 'sgAddressBook', function($scope, $rootScope, $stateParams, AddressBook) {
        var id = $stateParams.addressbook_id;
        $rootScope.addressbook = AddressBook.$find(id);

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
                    $rootScope.addressbook = AddressBook.$find(id);
                }
                else {
                    $scope.search.status = 'min-char';
                    $rootScope.addressbook.cards = [];
                }
            }
            $scope.search.last_filter = $scope.search.filter;
        };

    }])

    .controller('CardCtrl', ['$scope', '$rootScope', '$stateParams', 'sgAddressBook', 'sgCard', function($scope, $rootScope, $stateParams, AddressBook, Card) {
        $scope.UserFolderURL = UserFolderURL;
        if (!$rootScope.addressbook) {
            $rootScope.addressbook = AddressBook.$find($stateParams.addressbook_id);
        }
        $rootScope.addressbook.$getCard($stateParams.card_id);
    }])

})();
