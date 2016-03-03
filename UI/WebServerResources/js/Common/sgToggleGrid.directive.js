/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgToggleGrid - Convert the tiles of a grid to toggle buttons
   * @memberof SOGo.Common
   * @restrict attribute
   * @param {object} sgToggleGrid - the model of the source objects
   * @param {string} [sgToggleGridAttr] - the attribute that specifies if an object is enabled (toggled)
   * @ngInject
   * @example:

    <md-grid-list md-cols="7" md-row-height="1:1"
                  sg-toggle-grid="editor.event.repeat.days"
                  sg-toggle-grid-attr="day">..</md-grid-list>
  */
  sgToggleGrid.$inject = ['$parse'];
  function sgToggleGrid($parse) {
    return {
      restrict: 'A',
      link: link
    };

    function link(scope, iElement, attrs, ctrl) {
      var tiles = iElement.find('md-grid-tile'),
          tile,
          i,
          modelDays,
          modelAttr,
          ensureInitRunsOnce,
          toggleClass;

      ensureInitRunsOnce = scope.$watch(function() {
        // Parse attribute until it returns a valid object
        return $parse(attrs.sgToggleGrid)(scope);
      }, function(days) {
        if (angular.isDefined(days)) {
          var flattenedDays = days;
          modelDays = days;
          if (attrs.sgToggleGridAttr) {
            modelAttr = attrs.sgToggleGridAttr;
            flattenedDays = _.map(days, attrs.sgToggleGridAttr);
          }
          _.forEach(tiles, function(o) {
            var tile = angular.element(o);
            if (_.includes(flattenedDays, tile.attr('value'))) {
              tile.addClass('sg-active');
            }
          });
          ensureInitRunsOnce();
        }
      });

      toggleClass = function() {
          // Toggle class on click event and call toggle function
          var tile = angular.element(this),
              day = tile.attr('value');
          tile.toggleClass('sg-active');
          toggle(day);
      };

      for (i = 0; i < tiles.length; i++) {
        tile = angular.element(tiles[i]);
        tile.addClass('sg-icon-button');
        tile.find('figure').addClass('md-icon');
        tile.on('click', toggleClass);
      }

      function toggle(day) {
        var i = _.findIndex(modelDays, function(o) {
          if (modelAttr)
            return o[modelAttr] == day;
          else
            return o == day;
        });
        if (i < 0) {
          if (modelAttr) {
            var o = {};
            o[modelAttr] = day;
            modelDays.push(o);
          }
          else
            modelDays.push(day);
        }
        else
          modelDays.splice(i, 1);
      }
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgToggleGrid', sgToggleGrid);
})();
