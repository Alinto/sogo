/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgDroppable - Make an element a possible destination while dragging
   * @memberof SOGo.Common
   * @restrict attribute
   * @param {expression} sgDroppable - dropping is accepted only if this expression returs true.
   *        One variables is exposed: dragFolder.
   * @param {expression} sgDrop - called when dropping ends on the element.
   *        Two variables are exposed: dragFolder and dragMode.
   *
   * @example:

   <md-list-item sg-droppable="folder.id != dragFolder.id"
                 sg-drop="app.dragSelectedMessages(dragFolder, folder, dragMode)">
  */
  sgDroppable.$inject = ['$parse', '$rootScope', '$document', '$timeout', '$log'];
  function sgDroppable($parse, $rootScope, $document, $timeout, $log) {
    return {
      restrict: 'A',
      link: link
    };

    function link(scope, element, attrs) {
      var overElement = false, dropAction, droppable,
          deregisterFolderDragStart, deregisterFolderDragEnd;

      if (!attrs.sgDrop) {
        throw Error('sg-droppable requires a sg-drop action.');
      }

      overElement = false;
      droppable = $parse(attrs.sgDroppable);
      dropAction = $parse(attrs.sgDrop);

      // Register listeners of custom events on root scope
      deregisterFolderDragStart = $rootScope.$on('folder:dragstart', function(event, folder) {
        if (droppable(scope, { dragFolder: folder })) {
          element.on('mouseenter', onEnter);
          element.on('mouseleave', onLeave);
        }
      });
      deregisterFolderDragEnd = $rootScope.$on('folder:dragend', function(event, folder, mode) {
        element.off('mouseenter');
        element.off('mouseleave');
        if (overElement) {
          angular.bind(element[0], onLeave)(event);
          dropAction(scope, { dragFolder: folder, dragMode: mode });
        }
      });

      scope.$on('destroy', function() {
        deregisterFolderDragStart();
        deregisterFolderDragEnd();
      });

      function onEnter(event) {
        overElement = true;
        element.addClass('sg-droppable-over');
      }

      function onLeave(event) {
        overElement = false;
        this.classList.remove('sg-droppable-over');
        element.off('mousemove');
      }
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgDroppable', sgDroppable);
})();

