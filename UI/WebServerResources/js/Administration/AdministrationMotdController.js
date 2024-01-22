/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoAdministration */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  AdministrationMotdController.$inject = ['$timeout', '$state', '$mdMedia', '$mdToast', 'sgConstant', 'Administration', 'sgSettings'];
  function AdministrationMotdController($timeout, $state, $mdMedia, $mdToast, sgConstant, Administration, Settings) {
    var vm = this;
    vm.administration = Administration;
    vm.motd = null;
    vm.save = save;
    vm.clear = clear;
    vm.ckConfig = {
      'autoGrow_minHeight': 200,
      removeButtons: 'Save,NewPage,Preview,Print,Templates,Cut,Copy,Paste,PasteText,PasteFromWord,Undo,Redo,Find,Replace,SelectAll,Scayt,Form,Checkbox,Radio,TextField,Textarea,Select,Button,Image,HiddenField,CopyFormatting,RemoveFormat,NumberedList,BulletedList,Outdent,Indent,Blockquote,CreateDiv,BidiLtr,BidiRtl,Language,Unlink,Anchor,Flash,Table,HorizontalRule,Smiley,SpecialChar,PageBreak,Iframe,Styles,Format,Maximize,ShowBlocks,About,Strike,Subscript,Superscript,Underline,Emojipanel,Emoji,'
    };

    this.administration.$getMotd().then(function (data) {
      if (data && data.motd) {
        vm.motd = data.motd;
      }
    });

    function save() {
      this.administration.$saveMotd(vm.motd).then(function () {
        $mdToast.show(
          $mdToast.simple()
            .textContent(l('Message of the day has been saved'))
            .position(sgConstant.toastPosition)
            .hideDelay(3000));
      });
    }

    function clear() {
      console.log('HEY');
      vm.motd = '';
    }
  }

  angular
    .module('SOGo.AdministrationUI')
    .controller('AdministrationMotdController', AdministrationMotdController);

})();
