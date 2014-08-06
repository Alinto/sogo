/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* JavaScript for SOGoContacts */

(function() {
    'use strict';

    /* Constructor */
    function Dialog() {
    }

    Dialog.alert = function(title, content) {
        var alertPopup = this.$ionicPopup.alert({
            title: title,
            template: content
        });
        // alertPopup.then(function(res) {
        //     console.log('Thank you for not eating my delicious ice cream cone');
        // });
    };

    Dialog.$factory = ['$ionicPopup', function($ionicPopup) {
        angular.extend(Dialog, { $ionicPopup: $ionicPopup });

        return Dialog; // return constructor
    }];

    angular.module('SOGo.UIMobile', ['ionic'])

    .factory('sgDialog', Dialog.$factory);
    // angular.module('SOGo').factory('sgDialog', Dialog);

    // Dialog.prototype.alert = function(title, content) {
    //     var alertPopup = $ionicPopup.alert({
    //         title: title,
    //         template: content
    //     });
    //     alertPopup.then(function(res) {
    //         console.log('Thank you for not eating my delicious ice cream cone');
    //     });
    // };
})();
