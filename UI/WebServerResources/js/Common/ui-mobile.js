/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* JavaScript for common UI services for mobile theme */

(function() {
    'use strict';

    /* Dialog */
    function Dialog() {
    }

    Dialog.alert = function(title, content) {
        var alertPopup = this.$ionicPopup.alert({
            title: title,
            template: content
        });
        return alertPopup;
    };

    Dialog.confirm = function(title, content) {
        var alertPopup = this.$ionicPopup.confirm({
            title: title,
            template: content
        });
        return alertPopup;
    };

    /* The factory we'll use to register with Angular */
    Dialog.$factory = ['$ionicPopup', function($ionicPopup) {
        angular.extend(Dialog, { $ionicPopup: $ionicPopup });

        return Dialog; // return constructor
    }];

    /* Angular module instanciation */
    angular.module('SOGo.UIMobile', ['ionic'])

    /* Factory registration in Angular module */
    .factory('sgDialog', Dialog.$factory);
})();
