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
    };


    // Register a sgMailboxListItem controller
    this.addMailboxController = function (mailboxController) {
      mailboxes.push(mailboxController);
    };


    // Called from a sgMailboxListItem controller
    this.selectFolder = function (mailboxController) {
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
