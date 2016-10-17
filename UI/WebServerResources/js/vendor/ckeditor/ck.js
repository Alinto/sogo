/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for CKEditor module */

(function() {
  'use strict';

  ckEditor.$inject = ['$parse'];
  function ckEditor($parse) {
    var calledEarly, loaded;
    loaded = false;
    calledEarly = false;

    return {
      restrict: 'C',
      require: '?ngModel',
      compile: function(element, attributes, transclude) {
        var loadIt, local;

        local = this;
        loadIt = function() {
          return calledEarly = true;
        };

        element.ready(function() {
          return loadIt();
        });

        return {
          post: function($scope, element, attributes, controller) {
            if (calledEarly) {
              return local.link($scope, element, attributes, controller);
            }
            loadIt = (function($scope, element, attributes, controller) {
              return function() {
                local.link($scope, element, attributes, controller);
              };
            })($scope, element, attributes, controller);
          }
        };
      },

      link: function($scope, elm, attr, ngModel) {
        var ck, options = {}, locale;
        if (!ngModel) {
          return;
        }

        if (calledEarly && !loaded) {
          return loaded = true;
        }
        loaded = false;

        if (attr.ckOptions)
          options = angular.fromJson(attr.ckOptions.replace(/'/g, "\""));

        if (attr.ckLocale) {
          locale = $parse(attr.ckLocale)($scope);
          options.language = locale;
          options.scayt_sLang = locale;
        }

        ck = CKEDITOR.replace(elm[0], options);
        ck.on('change', function() {
          $scope.$apply(function() {
            ngModel.$setViewValue(ck.getData());
          });
        });

        ngModel.$render = function(value) {
          ck.setData(ngModel.$viewValue);
        };
      }
    };
  }

  angular
    .module('ck', [])
    .directive('ckEditor', ckEditor);
})();
