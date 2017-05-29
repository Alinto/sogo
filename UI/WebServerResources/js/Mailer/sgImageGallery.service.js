/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name ImageGallery
   * @constructor
   */
  function ImageGallery() {
    this.show = false;
    this.message = null;
    this.elements = [];
  }

  /**
   * @memberof ImageGallery
   * @desc The factory we'll use to register with Angular
   * @returns an ImageGallery instance
   */
  ImageGallery.$factory = ['$document', '$timeout', '$mdPanel', 'sgHotkeys', function($document, $timeout, $mdPanel, sgHotkeys) {
    angular.extend(ImageGallery, {
      $document: $document,
      $timeout: $timeout,
      $mdPanel: $mdPanel,
      sgHotkeys: sgHotkeys
    });

    return new ImageGallery(); // return unique instance
  }];

  /**
   * @function setMessage
   * @memberof ImageGallery.prototype
   * @desc Set current message object of gallery
   */
  ImageGallery.prototype.setMessage = function(message) {
    this.message = message;
  };

  /**
   * @function registerImage
   * @memberof ImageGallery.prototype
   * @desc Add an image to the gallery. Called from sgZoomableImage directive.
   */
  ImageGallery.prototype.registerImage = function(element) {
    this.elements.push(element);
  };

  /**
   * @function registerHotkeys
   * @memberof ImageGallery.prototype
   * @desc Allow keyboard navigation
   */
  ImageGallery.prototype.registerHotkeys = function($ctrl) {
    this.keys = [
      ImageGallery.sgHotkeys.createHotkey({
        key: 'left',
        description: l('View previous item'),
        callback: angular.bind($ctrl, $ctrl.previousImage)
      }),
      ImageGallery.sgHotkeys.createHotkey({
        key: 'right',
        description: l('View next item'),
        callback: angular.bind($ctrl, $ctrl.nextImage)
      })
    ];
    _.forEach(this.keys, function(key) {
      ImageGallery.sgHotkeys.registerHotkey(key);
    });
  };

  /**
   * @function showGallery
   * @memberof ImageGallery.prototype
   * @desc Build and show the md-panel
   */
  ImageGallery.prototype.showGallery = function($event, partIndex) {
    var _this = this,
        $mdPanel = ImageGallery.$mdPanel,
        partSrc = angular.element(this.message.parts.content[partIndex].content).find('img')[0].src;

    var images = _.filter(this.message.attachmentAttrs, function(attrs) {
      return attrs.mimetype.indexOf('image/') === 0;
    });

    var selectedIndex = _.findIndex(images, function(image) {
      return image.url.indexOf(partSrc) >= 0;
    });

    // Add a class to the body in order to modify the panel backdrop opacity
    angular.element(ImageGallery.$document[0].body).addClass('sg-image-gallery-backdrop');

    // Fullscreen panel
    var panelPosition = $mdPanel.newPanelPosition()
        .absolute();

    var panelAnimation = $mdPanel.newPanelAnimation()
        .openFrom($event.target)
        .duration(100)
        .withAnimation($mdPanel.animation.FADE);

    var config = {
      attachTo: angular.element(document.body),
      locals: {
        lastIndex: images.length -1,
        images: images,
        selectedIndex: selectedIndex,
        selectedImage: images[selectedIndex]
      },
      bindToController: true,
      controller: PanelController,
      controllerAs: '$panelCtrl',
      position: panelPosition,
      animation: panelAnimation,
      targetEvent: $event,
      fullscreen: true,
      hasBackdrop: true,
      template: [
        '<sg-image-gallery layout="column">',
        '  <div class="md-toolbar-tools" layout="row" layout-align="space-between center">',
        '    <div>',
        '      <md-button class="md-icon-button"',
        '                  aria-label="' + l('Close') + '"',
        '                  ng-click="$panelCtrl.close()">',
        '        <md-icon>arrow_back</md-icon>',
        '      </md-button>',
        '      <md-icon class="md-primary">image</md-icon>',
        '      <span ng-bind="$panelCtrl.selectedImage.filename"></span>',
        '    </div>',
        '    <md-button class="md-icon-button"',
        '                aria-label="' + l('Save Attachment') + '"',
        '                ng-href="{{$panelCtrl.selectedImage.urlAsAttachment}}">',
        '      <md-icon>file_download</md-icon>',
        '    </md-button>',
        '  </div>',
        '  <div class="md-flex" layout="row" layout-align="space-between center">',
        '      <md-button class="md-icon-button" ng-click="$panelCtrl.previousImage()"',
        '                 ng-disabled="$panelCtrl.selectedIndex == 0">',
        '        <md-icon>navigate_before</md-icon>',
        '      </md-button>',
        '      <img class="sg-image" ng-src="{{$panelCtrl.selectedImage.url}}">',
        '      <md-button class="md-icon-button" ng-click="$panelCtrl.nextImage()"',
        '                 ng-disabled="$panelCtrl.selectedIndex == $panelCtrl.lastIndex">',
        '        <md-icon>navigate_next</md-icon>',
        '      </md-button>',
        '  </div>',
        '    <div class="sg-image-thumbnails">',
        '      <div class="sg-image-thumbnail" ng-repeat="image in ::$panelCtrl.images">',
        '        <img class="sg-hide" ng-src="{{::image.url}}" ng-click="$panelCtrl.selectImage($index)">',
        '      </div>',
        '    </div>',
        '</sg-image-gallery>'
      ].join(''),
      trapFocus: true,
      clickOutsideToClose: true,
      escapeToClose: true,
      focusOnOpen: true,
      onOpenComplete: function() {
        _this.show = true;
        _.forEach(ImageGallery.$document.find('sg-image-gallery')[0].getElementsByClassName('sg-image-thumbnail'),
                  function(imgContainer) {
                    var imgEl = imgContainer.children[0];
                    angular.element(imgEl).one('load', function() {
                      if (imgEl.naturalWidth < imgEl.naturalHeight)
                        imgEl.classList.add('portrait');
                    });
                    // Display thumbnail
                    ImageGallery.$timeout(function() {
                      imgEl.classList.remove('sg-hide');
                    }, 1000);
                  });
      },
      onDomRemoved: function() {
        angular.element(ImageGallery.$document[0].body).removeClass('sg-image-gallery-backdrop');
        _this.show = false;
        // Deregister hotkeys
        _.forEach(_this.hotkeys, function(key) {
          ImageGallery.sgHotkeys.deregisterHotkey(key);
        });
      }
    };

    $mdPanel.open(config).then(function(mdPanelRef) {
      _this.registerHotkeys(mdPanelRef.$ctrl);
    });

    PanelController.$inject = ['mdPanelRef'];
    function PanelController(mdPanelRef) {
      var $menuCtrl = this;

      mdPanelRef.$ctrl = this;

      this.close = function() {
        mdPanelRef.close();
      };

      this.selectImage = function(index) {
        this.selectedIndex = index;
        this.selectedImage = this.images[index];
      };

      this.nextImage = function() {
        if (this.selectedIndex != this.lastIndex)
          this.selectImage(this.selectedIndex + 1);
      };

      this.previousImage = function() {
        if (this.selectedIndex > 0)
          this.selectImage(this.selectedIndex - 1);
      };

    } // PanelController

  };

  /* Factory registration in Angular module */
  angular.module('SOGo.MailerUI')
    .factory('ImageGallery', ImageGallery.$factory);

})();
