/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgDraggable - Make an element (usually a folder of elements) draggable.
   * @memberof SOGo.Common
   * @restrict attribute
   * @param {Object=} sgDraggable - the object to be exposed to the droppable target.
   * @param {expression} sgDragStart - dragging will only start if this expression returns true.
   * @param {expression} sgDragCount - the number of items being dragged; this number appears inside
   *        the sg-draggable-helper element that follows the mouse cursor.
   *
   * @example:

   <sg-draggable-helper>
     <md-icon>email</md-icon>
     <sg-draggable-helper-counter></sg-draggable-helper-counter>
   </sg-draggable-helper>

   <md-list sg-draggable="mailbox.service.selectedFolder"
            sg-drag-start="mailbox.selectedFolder.$selectedCount()"
            sg-drag-count="mailbox.selectedFolder.$selectedCount()">
  */
  sgDraggable.$inject = ['$parse', '$rootScope', '$document', '$timeout', '$log'];
  function sgDraggable($parse, $rootScope, $document, $timeout, $log) {
    return {
      restrict: 'A',
      link: link
    };

    function link(scope, element, attrs) {
      var o;
      
      $timeout(function() {
        var folder, dragStart, count;

        folder = $parse(attrs.sgDraggable)(scope);
        dragStart = attrs.sgDragStart? $parse(attrs.sgDragStart) : null;
        count = attrs.sgDragCount? $parse(attrs.sgDragCount) : null;
        o = new sgDraggableObject(element, folder, dragStart, count);
      });

      scope.$on('$destroy', function() {
        o.$destroy();
      });
      
      function sgDraggableObject($element, folder, dragStart, count) {
        this.$element = $element;
        this.folder = folder;
        this.dragStart = dragStart;
        this.count = count;
        this.helper = $document.find('sg-draggable-helper');

        if (!this.helper) {
          throw Error('sg-draggable requires a sg-draggable-helper element.');
        }

        this.bindedOnDragDetect = angular.bind(this, this.onDragDetect);
        this.bindedOnDrag = angular.bind(this, this.onDrag);

        // Register the mousedown event that can trigger the dragging action
        this.$element.on('mousedown', this.bindedOnDragDetect);
      }

      /**
       * sgDraggableObject is an object that wraps the logic to emit the folder:dragstart and
       * folder:dragend custom events.
       */
      sgDraggableObject.prototype = {

        dragHasStarted: false,

        $destroy: function() {
          this.$element.off('mousedown', this.bindedOnDragDetect);
        },

        getDistanceFromStart: function(event) {
          var delta = {
            x: this.startPosition.clientX - event.clientX,
            y: this.startPosition.clientY - event.clientY
          };

          return Math.sqrt(delta.x * delta.x + delta.y * delta.y);
        },


        // Start dragging on mousedown
        onDragDetect: function(ev) {
          ev.stopPropagation();

          if (!this.dragStart || this.dragStart(scope)) {
            // Listen to mousemove and start dragging when mouse has moved from at least 3 pixels
            $document.on('mousemove', this.bindedOnDrag);
            // Stop dragging on the next "mouseup"
            $document.one('mouseup', angular.bind(this, this.onDragEnd));
          }
        },

        // 
        onDrag: function(ev) {
          var counter;

          if (!this.startPosition) {
            this.startPosition = { clientX: ev.clientX, clientY: ev.clientY };
          }
          else if (!this.dragHasStarted && this.getDistanceFromStart(ev) > 10) {
            counter = this.helper.find('sg-draggable-helper-counter');
            this.dragHasStarted = true;

            this.helper.removeClass('ng-hide');
            if (this.count && this.count(scope) > 1)
              counter.text(this.count(scope)).removeClass('ng-hide');
            else
              counter.addClass('ng-hide');
            
            $log.debug('emit folder:dragstart');
            $rootScope.$emit('folder:dragstart', this.folder);
          }
          if (this.dragHasStarted) {
            if (ev.shiftKey)
              this.helper.addClass('sg-draggable-helper--copy');
            else
              this.helper.removeClass('sg-draggable-helper--copy');
            this.helper.css({ top: (ev.pageY + 5) + 'px', left: (ev.pageX + 5) + 'px' });
          }
        },


        onDragEnd: function(ev) {
          this.startPosition = null;
          $document.off('mousemove', this.bindedOnDrag);

          if (this.dragHasStarted) {
            $log.debug('emit folder:dragend');
            $rootScope.$emit('folder:dragend', this.folder, ev.shiftKey?'copy':'move');
            this.dragHasStarted = false;
            this.helper.addClass('ng-hide');
          }
        }

      };

    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgDraggable', sgDraggable);
})();

