/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {

  /**
   * sgMessageListItemMain - The main section of a list item for a message. It relies on the
   * 'onUpdate' method of the parent sgMessageListItem controller to update its content.
   * @memberof SOGo.MailerUI
   * @example:
  */
  function sgMessageListItemMain() {
    return {
      restrict: 'C',
      require: '^^sgMessageListItem',
      scope: {},
      template: [
        '<div class="sg-tile-content">',
        '  <div class="sg-md-subhead">',
        '    <div>',
        '      <span class="sg-label-outline ng-hide"><!-- mailbox --></span>',
        '      <md-icon class="ng-hide">error</md-icon>', // the priority icon
        '      <span><!-- sender or recipient --></span>',
        '    </div>',
        '    <div class="sg-tile-date"><!-- date --></div>',
        '  </div>',
        '  <div class="sg-md-body">',
        '    <div class="sg-tile-subject"><!-- subject --></div>',
        '    <div class="sg-tile-size"><!-- size --></div>',
        '    <md-button class="sg-tile-thread md-secondary ng-hide" md-colors="::{ color: \'accent-600\'}" ng-click="$ctrl.toggleThread()">',
        '      <md-icon class="md-rotate-180-ccw" md-colors="::{ color: \'accent-600\'}">expand_more</md-icon><span></span>', // expanded by default (icon is rotated)
        '    </md-button>',
        '  </div>',
        '</div>',
        '<div class="sg-tile-icons">',
        '  <md-icon class="ng-hide">star</md-icon>',
        '  <md-icon class="ng-hide">reply</md-icon>',
        '  <md-icon class="ng-hide">forward</md-icon>',
        '  <md-icon class="ng-hide">attach_file</md-icon>',
        '</div>',
        '<div class="sg-progress-linear-bottom">',
        '  <md-progress-linear class="md-accent"',
        '                      md-mode="indeterminate"',
        '                      ng-disabled="!$ctrl.message.$isLoading()"><!-- message loading progress --></md-progress-linear>',
        '</div>'
      ].join(''),
      link: postLink,
      controller: 'sgMessageListItemMainController',
      controllerAs: '$ctrl'
    };

    function postLink(scope, element, attrs, parentController) {
      scope.parentController = parentController;
    }

  }

  /**
   * @ngInject
   */
  sgMessageListItemMainController.$inject = ['$scope', '$element', '$parse', '$state', '$mdUtil', '$mdToast', 'Mailbox', 'Message', 'encodeUriFilter'];
  function sgMessageListItemMainController($scope, $element, $parse, $state, $mdUtil, $mdToast, Mailbox, Message, encodeUriFilter) {
    var $ctrl = this;

    this.$postLink = function () {
      var contentDivElement, threadButton, iconsDivElement;
      var parentControllerOnUpdate, setVisibility;

      this.parentController = $scope.parentController;

      parentControllerOnUpdate = this.parentController.onUpdate;
      setVisibility = this.parentController.setVisibility;

      _.forEach($element.find('div'), function(div) {
        if (div.classList.contains('sg-tile-content'))
          contentDivElement = angular.element(div);
        else if (div.classList.contains('sg-tile-icons'))
          iconsDivElement = angular.element(div);
      });

      threadButton = contentDivElement.find('button')[0];
      this.threadButton = threadButton;
      threadButton = angular.element(threadButton);
      this.threadIconElement = threadButton.find('md-icon')[0];
      this.threadCountElement = threadButton.find('span')[0];

      this.priorityIconElement = contentDivElement.find('md-icon')[0];

      if (Mailbox.$virtualMode) {
        // Show mailbox name in front of the subject
        this.mailboxNameElement = contentDivElement.find('span')[0];
        this.mailboxNameElement.classList.remove('ng-hide');
      }

      this.senderElement = contentDivElement.find('span')[1];

      _.forEach(contentDivElement.find('div'), function(div) {
        if (div.classList.contains('sg-tile-subject'))
          $ctrl.subjectElement = div;
        else if (div.classList.contains('sg-tile-size'))
          $ctrl.sizeElement = div;
        else if (div.classList.contains('sg-tile-date'))
          $ctrl.dateElement = div;
      });

      _.forEach(iconsDivElement.find('md-icon'), function(div) {
        if (div.textContent == 'star')
          $ctrl.flagIconElement = div;
        else if (div.textContent == 'reply')
          $ctrl.answerIconElement = div;
        else if (div.textContent == 'forward')
          $ctrl.forwardIconElement = div;
        else if (div.textContent == 'attach_file')
          $ctrl.attachmentIconElement = div;
      });

      /**
       * Update the template when the parent controller has detected a change.
       */
      this.parentController.onUpdate = function () {
        var i;
        $ctrl.message = $ctrl.parentController.message;

        // Flags
        var flagElements = $mdUtil.nodesToArray($element[0].querySelectorAll('.sg-category'));
        _.forEach(flagElements, function(flagElement) {
          $element[0].removeChild(flagElement);
        });
        for (i = 0; i < $ctrl.message.flags.length && i < 5; i++) {
          var tag = $ctrl.message.flags[i];
          if ($ctrl.service.$tags[tag]) {
            var flagElement = angular.element('<div class="sg-category"></div>');
            flagElement.css('left', (i*3) + 'px');
            flagElement.css('background-color', $ctrl.service.$tags[tag][1]);
            $element.prepend(flagElement);
          }
        }

        // Mailbox name when in virtual mode
        if ($ctrl.mailboxNameElement)
          $ctrl.mailboxNameElement.innerHTML = $ctrl.message.$mailbox.$displayName;

        // Sender or recipient when in
        if ($ctrl.MailboxService.selectedFolder.type == 'sent')
          $ctrl.senderElement.innerHTML = $ctrl.message.$shortAddress('to').encodeEntities();
        else
          $ctrl.senderElement.innerHTML = $ctrl.message.$shortAddress('from').encodeEntities();

        // Priority icon
        if ($ctrl.message.priority && $ctrl.message.priority.level < 3) {
          $ctrl.priorityIconElement.classList.remove('ng-hide');
          if ($ctrl.message.priority.level < 2)
            $ctrl.priorityIconElement.classList.add('md-warn');
          else
            $ctrl.priorityIconElement.classList.remove('md-warn');
        }
        else
          $ctrl.priorityIconElement.classList.add('ng-hide');

        // Mail thread
        if ($ctrl.message.first) {
          $ctrl.threadButton.classList.remove('ng-hide');
          $ctrl.threadCountElement.innerHTML = $ctrl.message.threadCount;
          if ($ctrl.message.collapsed)
            $ctrl.threadIconElement.classList.remove('md-rotate-180-ccw');
        }
        else {
          $ctrl.threadButton.classList.add('ng-hide');
        }

        // Subject
        $ctrl.subjectElement.innerHTML = $ctrl.message.subject.encodeEntities();

        // Message size
        $ctrl.sizeElement.innerHTML = $ctrl.message.size;

        // Received Date
        $ctrl.dateElement.innerHTML = $ctrl.message.relativedate;

        setVisibility($ctrl.flagIconElement,
                       $ctrl.message.isflagged);
        setVisibility($ctrl.answerIconElement,
                       $ctrl.message.isanswered);
        setVisibility($ctrl.forwardIconElement,
                       $ctrl.message.isforwarded);
        setVisibility($ctrl.attachmentIconElement,
                       $ctrl.message.hasattachment);

        // Call original method on parent controller
        angular.bind($ctrl.parentController, parentControllerOnUpdate)();
      };

      this.service = Message;
      this.MailboxService = Mailbox;
    };

    this.toggleThread = function() {
      if (this.message.collapsed)
        this.threadIconElement.classList.add('md-rotate-180-ccw');
      else
        this.threadIconElement.classList.remove('md-rotate-180-ccw');
      this.message.toggleThread();
    };

  }


  angular
    .module('SOGo.MailerUI')
    .controller('sgMessageListItemMainController', sgMessageListItemMainController)
    .directive('sgMessageListItemMain', sgMessageListItemMain);
})();
