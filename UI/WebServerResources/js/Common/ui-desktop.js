/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* JavaScript for common UI services */

(function() {
    'use strict';

    /* Dialog */
    function Dialog() {
    }

    Dialog.alert = function(title, content) {
        var modal = this.$modal.open({
            template: 
              '<h2>{{title}}</h2>' +
              '<p>{{content}}</p>' +
              '<a class="button button-primary" ng-click="closeModal()">' + l('OK') + '</a>' +
              '<span class="close-reveal-modal" ng-click="closeModal()"><i class="icon-close"></i></span>',
            windowClass: 'small',
            controller: function($scope, $modalInstance) {
                $scope.title = title;
                $scope.content = content;
                $scope.closeModal = function() {
                    $modalInstance.close();
                };
            }
        });
    };

    Dialog.confirm = function(title, content, callback) {
        var modal = this.$modal.open({
            template: 
              '<h2>{{title}}</h2>' +
              '<p>{{content}}</p>' +
              '<a class="button button-primary" ng-click="confirm()">' + l('OK') + '</a>' +
              '<a class="button button-secondary" ng-click="closeModal()">' + l('Cancel') + '</a>' +
              '<span class="close-reveal-modal" ng-click="closeModal()"><i class="icon-close"></i></span>',
            windowClass: 'small',
            controller: function($scope, $modalInstance) {
                $scope.title = title;
                $scope.content = content;
                $scope.closeModal = function() {
                    $modalInstance.close();
                };
                $scope.confirm = function() {
                    callback();
                    $modalInstance.close();
                };
            }
        });
    };

    /* The factory we'll use to register with Angular */
    Dialog.$factory = ['$modal', function($modal) {
        angular.extend(Dialog, { $modal: $modal });

        return Dialog; // return constructor
    }];

    /* Angular module instanciation */
    angular.module('SOGo.UIDesktop', ['mm.foundation'])

    /* Factory registration in Angular module */
    .factory('sgDialog', Dialog.$factory);
})();
