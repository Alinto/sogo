/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* JavaScript for common UI services for mobile theme */

(function() {
    'use strict';

    /**
     * @name Dialog
     * @constructor
     */
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
        var confirmPopup = this.$ionicPopup.confirm({
            title: title,
            template: content
        });
        return confirmPopup;
    };

    Dialog.prompt = function(title, content) {
        var promptPopup = this.$ionicPopup.prompt({
            title: title,
            inputPlaceholder: content
        });
        return promptPopup;
    };

    /**
     * @memberof Dialog
     * @desc The factory we'll register as sgDialog in the Angular module SOGo.UIMobile
     */
    Dialog.$factory = ['$ionicPopup', function($ionicPopup) {
        angular.extend(Dialog, { $ionicPopup: $ionicPopup });

        return Dialog; // return constructor
    }];

    /* Angular module instanciation */
    angular.module('SOGo.UIMobile', ['ionic'])

    /* Factory registration in Angular module */
    .factory('sgDialog', Dialog.$factory);
})();
