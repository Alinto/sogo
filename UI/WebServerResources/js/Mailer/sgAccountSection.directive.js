/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {

  /**
   * sgAccountSection - A directive that is only a controller to manage the selection of the mailboxes.
   * @memberof SOGo.MailerUI
  */
  function sgAccountSection() {
    return {
      restrict: 'C',
      scope: {},
      controller: 'sgAccountController'
    };
  }

  /**
   * @ngInject
   */
  sgAccountController.$inject = ['$element', '$transitions', '$state', '$mdMedia', '$mdSidenav', 'sgConstant', 'Mailbox', 'encodeUriFilter'];
  function sgAccountController($element, $transitions, $state, $mdMedia, $mdSidenav, sgConstant, Mailbox, encodeUriFilter) {
    var $ctrl = this, mailboxes = [];


    this.$postLink = function () {
      this.quotaElement = _.find($element.find('div'), function(div) {
        return div.classList.contains('sg-quota');
      });

      // The mailboxes list (md-virtual-repeat) only renders the rows that fit in its last
      // measured height, and only re-measures on window resize. Expanding/collapsing an
      // account changes the height of the other accounts' lists, so re-measure on any resize.
      var container = $element[0].querySelector('md-virtual-repeat-container');
      if (container && window.ResizeObserver) {
        this.resizeObserver = new ResizeObserver(function () {
          var containerCtrl = angular.element(container).controller('mdVirtualRepeatContainer');
          if (containerCtrl && containerCtrl.repeater)
            containerCtrl.updateSize();
        });
        this.resizeObserver.observe(container);
      }
    };

    this.$onDestroy = function () {
      if (this.resizeObserver)
        this.resizeObserver.disconnect();
    };


    // Register a sgMailboxListItem controller
    this.addMailboxController = function (mailboxController) {
      mailboxes.push(mailboxController);
    };


    // Called from a sgMailboxListItem controller
    this.selectFolder = function (mailboxController) {
      Mailbox.selectedFolderController = mailboxController;
      if (Mailbox.selectedFolder !== null) {
        var selectedMailboxCtrl = _.find(mailboxes, function(ctrl) {
          return ctrl.mailbox.id == Mailbox.selectedFolder.id;
        });
        if (selectedMailboxCtrl)
          selectedMailboxCtrl.unselectFolder();
      }
      // Close sidenav on small devices
      if (!$mdMedia(sgConstant['gt-md']))
        $mdSidenav('left').close();
    };

  }

  angular
    .module('SOGo.MailerUI')
    .controller('sgAccountController', sgAccountController)
    .directive('sgAccountSection', sgAccountSection);
})();
