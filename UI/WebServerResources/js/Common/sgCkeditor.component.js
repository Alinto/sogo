/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgCkeditor - A component for the CKEditor v4
   * Based on https://github.com/jziggas/ng-ck/.
   * @memberof SOGo.Common
   * @example:
     <sg-ckeditor
        config="$ctrl.config"
        on-instance-ready="$ctrl.onEditorReady($editor)"
        on-focus="$ctrl.onEditorFocus($editor)"
        ng-model="$ctrl.content"></sg-ckeditor>
  */
  function sgCkeditorConfigProvider() {
    // Default plugins that have successfully passed through Angular's $sanitize service
    

    var events = [
      'activeEnterModeChange',
      'activeFilterChange',
      'afterCommandExec',
      'afterInsertHtml',
      'afterPaste',
      'afterPasteFromWord',
      'afterSetData',
      'afterUndoImage',
      'ariaEditorHelpLabel',
      'autogrow',
      'beforeCommandExec',
      'beforeDestroy',
      'beforeGetData',
      'beforeModeUnload',
      'beforeSetMode',
      'beforeUndoImage',
      'blur',
      'change',
      'configLoaded',
      'contentDirLoaded',
      'contentDom',
      'contentDomInvalidated',
      'contentDomUnload',
      'customConfigLoaded',
      'dataFiltered',
      'dataReady',
      'destroy',
      'dialogHide',
      'dialogShow',
      'dirChanged',
      'doubleclick',
      'dragend',
      'dragstart',
      'drop',
      'elementsPathUpdate',
      'fileUploadRequest',
      'fileUploadResponse',
      'floatingSpaceLayout',
      'focus',
      'getData',
      'getSnapshot',
      'insertElement',
      'insertHtml',
      'insertText',
      'instanceReady',
      'key',
      'langLoaded',
      'loadSnapshot',
      'loaded',
      'lockSnapshot',
      'maximize',
      'menuShow',
      'mode',
      'notificationHide',
      'notificationShow',
      'notificationUpdate',
      'paste',
      'pasteFromWord',
      'pluginsLoaded',
      'readOnly',
      'removeFormatCleanup',
      'required',
      'resize',
      'save',
      'saveSnapshot',
      'selectionChange',
      'setData',
      'stylesSet',
      'template',
      'toDataFormat',
      'toHtml',
      'unlockSnapshot',
      'updateSnapshot',
      'widgetDefinition'
    ];

    var config = {};//angular.copy(defaultConfiguration);

    this.$get = function () {
      return {
        config: config,
        events: events
      }
    };
  }

  var sgCkeditorComponent = {
    controllerAs: 'vm',
    require: {
      ngModelCtrl: 'ngModel'
    },
    bindings: {
      checkTextLength: '<?',
      config: '<?',
      maxLength: '<?',
      minLength: '<?',
      ckMargin: '@?',
      onActiveEnterModeChange: '&?',
      onActiveFilterChange: '&?',
      onAfterCommandExec: '&?',
      onAfterInsertHtml: '&?',
      onAfterPaste: '&?',
      onAfterPasteFromWord: '&?',
      onAfterSetData: '&?',
      onAfterUndoImage: '&?',
      onAriaEditorHelpLabel: '&?',
      onAutogrow: '&?',
      onBeforeCommandExec: '&?',
      onBeforeDestroy: '&?',
      onBeforeGetData: '&?',
      onBeforeModeUnload: '&?',
      onBeforeSetMode: '&?',
      onBeforeUndoImage: '&?',
      onBlur: '&?',
      onChange: '&?',
      onConfigLoaded: '&?',
      onContentChanged: '&?', // Not CKEditor API
      onContentDirLoaded: '&?',
      onContentDom: '&?',
      onContentDomInvalidated: '&?',
      onContentDomUnload: '&?',
      onCustomConfigLoaded: '&?',
      onDataFiltered: '&?',
      onDataReady: '&?',
      onDestroy: '&?', // Not sure if this works because of the cleanup done in $onDestroy. Needs testing.
      onDialogHide: '&?',
      onDialogShow: '&?',
      onDirChanged: '&?',
      onDoubleclick: '&?',
      onDragend: '&?',
      onDragstart: '&?',
      onDrop: '&?',
      onElementsPathUpdate: '&?',
      onFileUploadRequest: '&?',
      onFileUploadResponse: '&?',
      onFloatingSpaceLayout: '&?',
      onFocus: '&?',
      onGetData: '&?',
      onGetSnapshot: '&?',
      onInsertElement: '&?',
      onInsertHtml: '&?',
      onInsertText: '&?',
      onInstanceReady: '&?',
      onKey: '&?',
      onLangLoaded: '&?',
      onLoadSnapshot: '&?',
      onLoaded: '&?',
      onLockSnapshot: '&?',
      onMaximize: '&?',
      onMenuShow: '&?',
      onMode: '&?',
      onNotificationHide: '&?',
      onNotificationShow: '&?',
      onNotificationUpdate: '&?',
      onPaste: '&?',
      onPasteFromWord: '&?',
      onPluginsLoaded: '&?',
      onReadOnly: '&?',
      onRemoveFormatCleanup: '&?',
      onRequired: '&?',
      onResize: '&?',
      onSave: '&?',
      onSaveSnapshot: '&?',
      onSelectionChange: '&?',
      onSetData: '&?',
      onStylesSet: '&?',
      onTemplate: '&?',
      onToDataFormat: '&?',
      onToHtml: '&?',
      onUnlockSnapshot: '&?',
      onUpdateSnapshot: '&?',
      onWidgetDefinition: '&?',
      placeholder: '<?',
      readOnly: '<?',
      required: '<?'
    },
    template: '<textarea ng-attr-placeholder="{{vm.placeholder}}"></textarea>',
    controller: sgCkeditorController
  };

  var emojis = [
    { title: 'Grinning Face', character: '😀' }, { title: 'Grinning Face with Big Eyes', character: '😃' }, { title: 'Grinning Face with Smiling Eyes', character: '😄' }, { title: 'Beaming Face with Smiling Eyes', character: '😁' }, { title: 'Grinning Squinting Face', character: '😆' }, { title: 'Grinning Face with Sweat', character: '😅' }, { title: 'Rolling on the Floor Laughing', character: '🤣' }, { title: 'Face with Tears of Joy', character: '😂' }, { title: 'Slightly Smiling Face', character: '🙂' }, { title: 'Upside-Down Face', character: '🙃' }, { title: 'Winking Face', character: '😉' }, { title: 'Smiling Face with Smiling Eyes', character: '😊' }, { title: 'Smiling Face with Halo', character: '😇' }, { title: 'Smiling Face with Hearts', character: '🥰' }, { title: 'Smiling Face with Heart-Eyes', character: '😍' }, { title: 'Star-Struck', character: '🤩' }, { title: 'Face Blowing a Kiss', character: '😘' }, { title: 'Kissing Face', character: '😗' }, { title: 'Smiling Face', character: '☺️' }, { title: 'Kissing Face with Closed Eyes', character: '😚' }, { title: 'Kissing Face with Smiling Eyes', character: '😙' }, { title: 'Smiling Face with Tear', character: '🥲' }, { title: 'Face Savoring Food', character: '😋' }, { title: 'Face with Tongue', character: '😛' }, { title: 'Winking Face with Tongue', character: '😜' }, { title: 'Zany Face', character: '🤪' }, { title: 'Squinting Face with Tongue', character: '😝' }, { title: 'Money-Mouth Face', character: '🤑' }, { title: 'Hugging Face', character: '🤗' }, { title: 'Face with Hand Over Mouth', character: '🤭' }, { title: 'Shushing Face', character: '🤫' }, { title: 'Thinking Face', character: '🤔' }, { title: 'Zipper-Mouth Face', character: '🤐' }, { title: 'Face with Raised Eyebrow', character: '🤨' }, { title: 'Neutral Face', character: '😐' }, { title: 'Expressionless Face', character: '😑' }, { title: 'Face Without Mouth', character: '😶' }, { title: 'Smirking Face', character: '😏' }, { title: 'Unamused Face', character: '😒' }, { title: 'Face with Rolling Eyes', character: '🙄' }, { title: 'Grimacing Face', character: '😬' }, { title: 'Lying Face', character: '🤥' }, { title: 'Relieved Face', character: '😌' }, { title: 'Pensive Face', character: '😔' }, { title: 'Sleepy Face', character: '😪' }, { title: 'Drooling Face', character: '🤤' }, { title: 'Sleeping Face', character: '😴' }, { title: 'Face with Medical Mask', character: '😷' }, { title: 'Face with Thermometer', character: '🤒' }, { title: 'Face with Head-Bandage', character: '🤕' }, { title: 'Nauseated Face', character: '🤢' }, { title: 'Face Vomiting', character: '🤮' }, { title: 'Sneezing Face', character: '🤧' }, { title: 'Hot Face', character: '🥵' }, { title: 'Cold Face', character: '🥶' }, { title: 'Woozy Face', character: '🥴' }, { title: 'Dizzy Face', character: '😵' }, { title: 'Exploding Head', character: '🤯' }, { title: 'Cowboy Hat Face', character: '🤠' }, { title: 'Partying Face', character: '🥳' }, { title: 'Disguised Face', character: '🥸' }, { title: 'Smiling Face with Sunglasses', character: '😎' }, { title: 'Nerd Face', character: '🤓' }, { title: 'Face with Monocle', character: '🧐' }, { title: 'Confused Face', character: '😕' }, { title: 'Worried Face', character: '😟' }, { title: 'Slightly Frowning Face', character: '🙁' }, { title: 'Frowning Face', character: '☹️' }, { title: 'Face with Open Mouth', character: '😮' }, { title: 'Hushed Face', character: '😯' }, { title: 'Astonished Face', character: '😲' }, { title: 'Flushed Face', character: '😳' }, { title: 'Pleading Face', character: '🥺' }, { title: 'Frowning Face with Open Mouth', character: '😦' }, { title: 'Anguished Face', character: '😧' }, { title: 'Fearful Face', character: '😨' }, { title: 'Anxious Face with Sweat', character: '😰' }, { title: 'Sad but Relieved Face', character: '😥' }, { title: 'Crying Face', character: '😢' }, { title: 'Loudly Crying Face', character: '😭' }, { title: 'Face Screaming in Fear', character: '😱' }, { title: 'Confounded Face', character: '😖' }, { title: 'Persevering Face', character: '😣' }, { title: 'Disappointed Face', character: '😞' }, { title: 'Downcast Face with Sweat', character: '😓' }, { title: 'Weary Face', character: '😩' }, { title: 'Tired Face', character: '😫' }, { title: 'Yawning Face', character: '🥱' }, { title: 'Face with Steam From Nose', character: '😤' }, { title: 'Pouting Face', character: '😡' }, { title: 'Angry Face', character: '😠' }, { title: 'Face with Symbols on Mouth', character: '🤬' }, { title: 'Smiling Face with Horns', character: '😈' }, { title: 'Angry Face with Horns', character: '👿' }, { title: 'Skull', character: '💀' }, { title: 'Skull and Crossbones', character: '☠️' }, { title: 'Pile of Poo', character: '💩' }, { title: 'Clown Face', character: '🤡' }, { title: 'Ogre', character: '👹' }, { title: 'Goblin', character: '👺' }, { title: 'Ghost', character: '👻' }, { title: 'Alien', character: '👽' }, { title: 'Alien Monster', character: '👾' }, { title: 'Robot', character: '🤖' }, { title: 'Grinning Cat', character: '😺' }, { title: 'Grinning Cat with Smiling Eyes', character: '😸' }, { title: 'Cat with Tears of Joy', character: '😹' }, { title: 'Smiling Cat with Heart-Eyes', character: '😻' }, { title: 'Cat with Wry Smile', character: '😼' }, { title: 'Kissing Cat', character: '😽' }, { title: 'Weary Cat', character: '🙀' }, { title: 'Crying Cat', character: '😿' }, { title: 'Pouting Cat', character: '😾' }, { title: 'Kiss Mark', character: '💋' }, { title: 'Waving Hand', character: '👋' }, { title: 'Raised Back of Hand', character: '🤚' }, { title: 'Hand with Fingers Splayed', character: '🖐️' }, { title: 'Raised Hand', character: '✋' }, { title: 'Vulcan Salute', character: '🖖' }, { title: 'OK Hand', character: '👌' }, { title: 'Pinched Fingers', character: '🤌' }, { title: 'Pinching Hand', character: '🤏' }, { title: 'Victory Hand', character: '✌️' }, { title: 'Crossed Fingers', character: '🤞' }, { title: 'Love-You Gesture', character: '🤟' }, { title: 'Sign of the Horns', character: '🤘' }, { title: 'Call Me Hand', character: '🤙' }, { title: 'Backhand Index Pointing Left', character: '👈' }, { title: 'Backhand Index Pointing Right', character: '👉' }, { title: 'Backhand Index Pointing Up', character: '👆' }, { title: 'Middle Finger', character: '🖕' }, { title: 'Backhand Index Pointing Down', character: '👇' }, { title: 'Index Pointing Up', character: '☝️' }, { title: 'Thumbs Up', character: '👍' }, { title: 'Thumbs Down', character: '👎' }, { title: 'Raised Fist', character: '✊' }, { title: 'Oncoming Fist', character: '👊' }, { title: 'Left-Facing Fist', character: '🤛' }, { title: 'Right-Facing Fist', character: '🤜' }, { title: 'Clapping Hands', character: '👏' }, { title: 'Raising Hands', character: '🙌' }, { title: 'Open Hands', character: '👐' }, { title: 'Palms Up Together', character: '🤲' }, { title: 'Handshake', character: '🤝' }, { title: 'Folded Hands', character: '🙏' }, { title: 'Writing Hand', character: '✍️' }, { title: 'Nail Polish', character: '💅' }, { title: 'Selfie', character: '🤳' }, { title: 'Flexed Biceps', character: '💪' }, { title: 'Mechanical Arm', character: '🦾' }, { title: 'Mechanical Leg', character: '🦿' }, { title: 'Leg', character: '🦵' }, { title: 'Foot', character: '🦶' }, { title: 'Ear', character: '👂' }, { title: 'Ear with Hearing Aid', character: '🦻' }, { title: 'Nose', character: '👃' }, { title: 'Brain', character: '🧠' }, { title: 'Anatomical Heart', character: '🫀' }, { title: 'Lungs', character: '🫁' }, { title: 'Tooth', character: '🦷' }, { title: 'Bone', character: '🦴' }, { title: 'Eyes', character: '👀' }, { title: 'Eye', character: '👁️' }, { title: 'Tongue', character: '👅' }, { title: 'Mouth', character: '👄' }, { title: 'Baby', character: '👶' }, { title: 'Child', character: '🧒' }, { title: 'Boy', character: '👦' }, { title: 'Girl', character: '👧' }, { title: 'Person', character: '🧑' }, { title: 'Person: Blond Hair', character: '👱' }, { title: 'Man', character: '👨' }, { title: 'Person: Beard', character: '🧔' }, { title: 'Man: Red Hair', character: '👨‍🦰' }, { title: 'Man: Curly Hair', character: '👨‍🦱' }, { title: 'Man: White Hair', character: '👨‍🦳' }, { title: 'Man: Bald', character: '👨‍🦲' }, { title: 'Woman', character: '👩' }, { title: 'Woman: Red Hair', character: '👩‍🦰' }, { title: 'Person: Red Hair', character: '🧑‍🦰' }, { title: 'Woman: Curly Hair', character: '👩‍🦱' }, { title: 'Person: Curly Hair', character: '🧑‍🦱' }, { title: 'Woman: White Hair', character: '👩‍🦳' }, { title: 'Person: White Hair', character: '🧑‍🦳' }, { title: 'Woman: Bald', character: '👩‍🦲' }, { title: 'Person: Bald', character: '🧑‍🦲' }, { title: 'Woman: Blond Hair', character: '👱‍♀️' }, { title: 'Man: Blond Hair', character: '👱‍♂️' }, { title: 'Older Person', character: '🧓' }, { title: 'Old Man', character: '👴' }, { title: 'Old Woman', character: '👵' }, { title: 'Person Frowning', character: '🙍' }, { title: 'Man Frowning', character: '🙍‍♂️' }, { title: 'Woman Frowning', character: '🙍‍♀️' }, { title: 'Person Pouting', character: '🙎' }, { title: 'Man Pouting', character: '🙎‍♂️' }, { title: 'Woman Pouting', character: '🙎‍♀️' }, { title: 'Person Gesturing No', character: '🙅' }, { title: 'Man Gesturing No', character: '🙅‍♂️' }, { title: 'Woman Gesturing No', character: '🙅‍♀️' }, { title: 'Person Gesturing OK', character: '🙆' }, { title: 'Man Gesturing OK', character: '🙆‍♂️' }, { title: 'Woman Gesturing OK', character: '🙆‍♀️' }, { title: 'Person Tipping Hand', character: '💁' }, { title: 'Man Tipping Hand', character: '💁‍♂️' }, { title: 'Woman Tipping Hand', character: '💁‍♀️' }, { title: 'Person Raising Hand', character: '🙋' }, { title: 'Man Raising Hand', character: '🙋‍♂️' }, { title: 'Woman Raising Hand', character: '🙋‍♀️' }, { title: 'Deaf Person', character: '🧏' }, { title: 'Deaf Man', character: '🧏‍♂️' }, { title: 'Deaf Woman', character: '🧏‍♀️' }, { title: 'Person Bowing', character: '🙇' }, { title: 'Man Bowing', character: '🙇‍♂️' }, { title: 'Woman Bowing', character: '🙇‍♀️' }, { title: 'Person Facepalming', character: '🤦' }, { title: 'Man Facepalming', character: '🤦‍♂️' }, { title: 'Woman Facepalming', character: '🤦‍♀️' }, { title: 'Person Shrugging', character: '🤷' }, { title: 'Man Shrugging', character: '🤷‍♂️' }, { title: 'Woman Shrugging', character: '🤷‍♀️' }, { title: 'Health Worker', character: '🧑‍⚕️' }, { title: 'Man Health Worker', character: '👨‍⚕️' }, { title: 'Woman Health Worker', character: '👩‍⚕️' }, { title: 'Student', character: '🧑‍🎓' }, { title: 'Man Student', character: '👨‍🎓' }, { title: 'Woman Student', character: '👩‍🎓' }, { title: 'Teacher', character: '🧑‍🏫' }, { title: 'Man Teacher', character: '👨‍🏫' }, { title: 'Woman Teacher', character: '👩‍🏫' }, { title: 'Judge', character: '🧑‍⚖️' }, { title: 'Man Judge', character: '👨‍⚖️' }, { title: 'Woman Judge', character: '👩‍⚖️' }, { title: 'Farmer', character: '🧑‍🌾' }, { title: 'Man Farmer', character: '👨‍🌾' }, { title: 'Woman Farmer', character: '👩‍🌾' }, { title: 'Cook', character: '🧑‍🍳' }, { title: 'Man Cook', character: '👨‍🍳' }, { title: 'Woman Cook', character: '👩‍🍳' }, { title: 'Mechanic', character: '🧑‍🔧' }, { title: 'Man Mechanic', character: '👨‍🔧' }, { title: 'Woman Mechanic', character: '👩‍🔧' }, { title: 'Factory Worker', character: '🧑‍🏭' }, { title: 'Man Factory Worker', character: '👨‍🏭' }, { title: 'Woman Factory Worker', character: '👩‍🏭' }, { title: 'Office Worker', character: '🧑‍💼' }, { title: 'Man Office Worker', character: '👨‍💼' }, { title: 'Woman Office Worker', character: '👩‍💼' }, { title: 'Scientist', character: '🧑‍🔬' }, { title: 'Man Scientist', character: '👨‍🔬' }, { title: 'Woman Scientist', character: '👩‍🔬' }, { title: 'Technologist', character: '🧑‍💻' }, { title: 'Man Technologist', character: '👨‍💻' }, { title: 'Woman Technologist', character: '👩‍💻' }, { title: 'Singer', character: '🧑‍🎤' }, { title: 'Man Singer', character: '👨‍🎤' }, { title: 'Woman Singer', character: '👩‍🎤' }, { title: 'Artist', character: '🧑‍🎨' }, { title: 'Man Artist', character: '👨‍🎨' }, { title: 'Woman Artist', character: '👩‍🎨' }, { title: 'Pilot', character: '🧑‍✈️' }, { title: 'Man Pilot', character: '👨‍✈️' }, { title: 'Woman Pilot', character: '👩‍✈️' }, { title: 'Astronaut', character: '🧑‍🚀' }, { title: 'Man Astronaut', character: '👨‍🚀' }, { title: 'Woman Astronaut', character: '👩‍🚀' }, { title: 'Firefighter', character: '🧑‍🚒' }, { title: 'Man Firefighter', character: '👨‍🚒' }, { title: 'Woman Firefighter', character: '👩‍🚒' }, { title: 'Police Officer', character: '👮' }, { title: 'Man Police Officer', character: '👮‍♂️' }, { title: 'Woman Police Officer', character: '👮‍♀️' }, { title: 'Detective', character: '🕵️' }, { title: 'Man Detective', character: '🕵️‍♂️' }, { title: 'Woman Detective', character: '🕵️‍♀️' }, { title: 'Guard', character: '💂' }, { title: 'Man Guard', character: '💂‍♂️' }, { title: 'Woman Guard', character: '💂‍♀️' }, { title: 'Ninja', character: '🥷' }, { title: 'Construction Worker', character: '👷' }, { title: 'Man Construction Worker', character: '👷‍♂️' }, { title: 'Woman Construction Worker', character: '👷‍♀️' }, { title: 'Prince', character: '🤴' }, { title: 'Princess', character: '👸' }, { title: 'Person Wearing Turban', character: '👳' }, { title: 'Man Wearing Turban', character: '👳‍♂️' }, { title: 'Woman Wearing Turban', character: '👳‍♀️' }, { title: 'Person With Skullcap', character: '👲' }, { title: 'Woman with Headscarf', character: '🧕' }, { title: 'Person in Tuxedo', character: '🤵' }, { title: 'Man in Tuxedo', character: '🤵‍♂️' }, { title: 'Woman in Tuxedo', character: '🤵‍♀️' }, { title: 'Person With Veil', character: '👰' }, { title: 'Man with Veil', character: '👰‍♂️' }, { title: 'Woman with Veil', character: '👰‍♀️' }, { title: 'Pregnant Woman', character: '🤰' }, { title: 'Breast-Feeding', character: '🤱' }, { title: 'Woman Feeding Baby', character: '👩‍🍼' }, { title: 'Man Feeding Baby', character: '👨‍🍼' }, { title: 'Person Feeding Baby', character: '🧑‍🍼' }, { title: 'Baby Angel', character: '👼' }, { title: 'Santa Claus', character: '🎅' }, { title: 'Mrs. Claus', character: '🤶' }, { title: 'Mx Claus', character: '🧑‍🎄' }, { title: 'Superhero', character: '🦸' }, { title: 'Man Superhero', character: '🦸‍♂️' }, { title: 'Woman Superhero', character: '🦸‍♀️' }, { title: 'Supervillain', character: '🦹' }, { title: 'Man Supervillain', character: '🦹‍♂️' }, { title: 'Woman Supervillain', character: '🦹‍♀️' }, { title: 'Mage', character: '🧙' }, { title: 'Man Mage', character: '🧙‍♂️' }, { title: 'Woman Mage', character: '🧙‍♀️' }, { title: 'Fairy', character: '🧚' }, { title: 'Man Fairy', character: '🧚‍♂️' }, { title: 'Woman Fairy', character: '🧚‍♀️' }, { title: 'Vampire', character: '🧛' }, { title: 'Man Vampire', character: '🧛‍♂️' }, { title: 'Woman Vampire', character: '🧛‍♀️' }, { title: 'Merperson', character: '🧜' }, { title: 'Merman', character: '🧜‍♂️' }, { title: 'Mermaid', character: '🧜‍♀️' }, { title: 'Elf', character: '🧝' }, { title: 'Man Elf', character: '🧝‍♂️' }, { title: 'Woman Elf', character: '🧝‍♀️' }, { title: 'Genie', character: '🧞' }, { title: 'Man Genie', character: '🧞‍♂️' }, { title: 'Woman Genie', character: '🧞‍♀️' }, { title: 'Zombie', character: '🧟' }, { title: 'Man Zombie', character: '🧟‍♂️' }, { title: 'Woman Zombie', character: '🧟‍♀️' }, { title: 'Person Getting Massage', character: '💆' }, { title: 'Man Getting Massage', character: '💆‍♂️' }, { title: 'Woman Getting Massage', character: '💆‍♀️' }, { title: 'Person Getting Haircut', character: '💇' }, { title: 'Man Getting Haircut', character: '💇‍♂️' }, { title: 'Woman Getting Haircut', character: '💇‍♀️' }, { title: 'Person Walking', character: '🚶' }, { title: 'Man Walking', character: '🚶‍♂️' }, { title: 'Woman Walking', character: '🚶‍♀️' }, { title: 'Person Standing', character: '🧍' }, { title: 'Man Standing', character: '🧍‍♂️' }, { title: 'Woman Standing', character: '🧍‍♀️' }, { title: 'Person Kneeling', character: '🧎' }, { title: 'Man Kneeling', character: '🧎‍♂️' }, { title: 'Woman Kneeling', character: '🧎‍♀️' }, { title: 'Person with White Cane', character: '🧑‍🦯' }, { title: 'Man with White Cane', character: '👨‍🦯' }, { title: 'Woman with White Cane', character: '👩‍🦯' }, { title: 'Person in Motorized Wheelchair', character: '🧑‍🦼' }, { title: 'Man in Motorized Wheelchair', character: '👨‍🦼' }, { title: 'Woman in Motorized Wheelchair', character: '👩‍🦼' }, { title: 'Person in Manual Wheelchair', character: '🧑‍🦽' }, { title: 'Man in Manual Wheelchair', character: '👨‍🦽' }, { title: 'Woman in Manual Wheelchair', character: '👩‍🦽' }, { title: 'Person Running', character: '🏃' }, { title: 'Man Running', character: '🏃‍♂️' }, { title: 'Woman Running', character: '🏃‍♀️' }, { title: 'Woman Dancing', character: '💃' }, { title: 'Man Dancing', character: '🕺' }, { title: 'Person in Suit Levitating', character: '🕴️' }, { title: 'People with Bunny Ears', character: '👯' }, { title: 'Men with Bunny Ears', character: '👯‍♂️' }, { title: 'Women with Bunny Ears', character: '👯‍♀️' }, { title: 'Person in Steamy Room', character: '🧖' }, { title: 'Man in Steamy Room', character: '🧖‍♂️' }, { title: 'Woman in Steamy Room', character: '🧖‍♀️' }, { title: 'Person in Lotus Position', character: '🧘' }, { title: 'People Holding Hands', character: '🧑‍🤝‍🧑' }, { title: 'Women Holding Hands', character: '👭' }, { title: 'Woman and Man Holding Hands', character: '👫' }, { title: 'Men Holding Hands', character: '👬' }, { title: 'Kiss', character: '💏' }, { title: 'Kiss: Woman, Man', character: '👩‍❤️‍💋‍👨' }, { title: 'Kiss: Man, Man', character: '👨‍❤️‍💋‍👨' }, { title: 'Kiss: Woman, Woman', character: '👩‍❤️‍💋‍👩' }, { title: 'Couple with Heart', character: '💑' }, { title: 'Couple with Heart: Woman, Man', character: '👩‍❤️‍👨' }, { title: 'Couple with Heart: Man, Man', character: '👨‍❤️‍👨' }, { title: 'Couple with Heart: Woman, Woman', character: '👩‍❤️‍👩' }, { title: 'Family', character: '👪' }, { title: 'Family: Man, Woman, Boy', character: '👨‍👩‍👦' }, { title: 'Family: Man, Woman, Girl', character: '👨‍👩‍👧' }, { title: 'Family: Man, Woman, Girl, Boy', character: '👨‍👩‍👧‍👦' }, { title: 'Family: Man, Woman, Boy, Boy', character: '👨‍👩‍👦‍👦' }, { title: 'Family: Man, Woman, Girl, Girl', character: '👨‍👩‍👧‍👧' }, { title: 'Family: Man, Man, Boy', character: '👨‍👨‍👦' }, { title: 'Family: Man, Man, Girl', character: '👨‍👨‍👧' }, { title: 'Family: Man, Man, Girl, Boy', character: '👨‍👨‍👧‍👦' }, { title: 'Family: Man, Man, Boy, Boy', character: '👨‍👨‍👦‍👦' }, { title: 'Family: Man, Man, Girl, Girl', character: '👨‍👨‍👧‍👧' }, { title: 'Family: Woman, Woman, Boy', character: '👩‍👩‍👦' }, { title: 'Family: Woman, Woman, Girl', character: '👩‍👩‍👧' }, { title: 'Family: Woman, Woman, Girl, Boy', character: '👩‍👩‍👧‍👦' }, { title: 'Family: Woman, Woman, Boy, Boy', character: '👩‍👩‍👦‍👦' }, { title: 'Family: Woman, Woman, Girl, Girl', character: '👩‍👩‍👧‍👧' }, { title: 'Family: Man, Boy', character: '👨‍👦' }, { title: 'Family: Man, Boy, Boy', character: '👨‍👦‍👦' }, { title: 'Family: Man, Girl', character: '👨‍👧' }, { title: 'Family: Man, Girl, Boy', character: '👨‍👧‍👦' }, { title: 'Family: Man, Girl, Girl', character: '👨‍👧‍👧' }, { title: 'Family: Woman, Boy', character: '👩‍👦' }, { title: 'Family: Woman, Boy, Boy', character: '👩‍👦‍👦' }, { title: 'Family: Woman, Girl', character: '👩‍👧' }, { title: 'Family: Woman, Girl, Boy', character: '👩‍👧‍👦' }, { title: 'Family: Woman, Girl, Girl', character: '👩‍👧‍👧' }, { title: 'Speaking Head', character: '🗣️' }, { title: 'Bust in Silhouette', character: '👤' }, { title: 'Busts in Silhouette', character: '👥' }, { title: 'People Hugging', character: '🫂' }, { title: 'Footprints', character: '👣' }, { title: 'Luggage', character: '🧳' }, { title: 'Closed Umbrella', character: '🌂' }, { title: 'Umbrella', character: '☂️' }, { title: 'Jack-O-Lantern', character: '🎃' }, { title: 'Thread', character: '🧵' }, { title: 'Yarn', character: '🧶' }, { title: 'Glasses', character: '👓' }, { title: 'Sunglasses', character: '🕶️' }, { title: 'Goggles', character: '🥽' }, { title: 'Lab Coat', character: '🥼' }, { title: 'Safety Vest', character: '🦺' }, { title: 'Necktie', character: '👔' }, { title: 'T-Shirt', character: '👕' }, { title: 'Jeans', character: '👖' }, { title: 'Scarf', character: '🧣' }, { title: 'Gloves', character: '🧤' }, { title: 'Coat', character: '🧥' }, { title: 'Socks', character: '🧦' }, { title: 'Dress', character: '👗' }, { title: 'Kimono', character: '👘' }, { title: 'Sari', character: '🥻' }, { title: 'One-Piece Swimsuit', character: '🩱' }, { title: 'Briefs', character: '🩲' }, { title: 'Shorts', character: '🩳' }, { title: 'Bikini', character: '👙' }, { title: 'Woman’s Clothes', character: '👚' }, { title: 'Purse', character: '👛' }, { title: 'Handbag', character: '👜' }, { title: 'Clutch Bag', character: '👝' }, { title: 'Backpack', character: '🎒' }, { title: 'Thong Sandal', character: '🩴' }, { title: 'Man’s Shoe', character: '👞' }, { title: 'Running Shoe', character: '👟' }, { title: 'Hiking Boot', character: '🥾' }, { title: 'Flat Shoe', character: '🥿' }, { title: 'High-Heeled Shoe', character: '👠' }, { title: 'Woman’s Sandal', character: '👡' }, { title: 'Ballet Shoes', character: '🩰' }, { title: 'Woman’s Boot', character: '👢' }, { title: 'Crown', character: '👑' }, { title: 'Woman’s Hat', character: '👒' }, { title: 'Top Hat', character: '🎩' }, { title: 'Graduation Cap', character: '🎓' }, { title: 'Billed Cap', character: '🧢' }, { title: 'Military Helmet', character: '🪖' }, { title: 'Rescue Worker’s Helmet', character: '⛑️' }, { title: 'Lipstick', character: '💄' }, { title: 'Ring', character: '💍' }, { title: 'Briefcase', character: '💼' }, { title: 'Drop of Blood', character: '🩸' }
  ];

  sgCkeditorController.$inject = ['$element', 'sgCkeditorConfig'];
  function sgCkeditorController ($element, sgCkeditorConfig) {
    var vm = this;
    var config;
    var content;
    var editor;
    var editorChanged = false;
    var modelChanged = false;
    var editorChangedTimerValue = 2000;
    var editorChangedTimer = null;

    this.$onInit = function () {
      vm.ngModelCtrl.$render = function () {
        content = vm.ngModelCtrl.$viewValue;
        // Clean message with invalid HTML tags
        content = cleanDirtyHTMLElements(content, 50);
        if (vm.editor) {
          vm.editor.setData(content, {
            noSnapshot: true,
            callback: function () {
              vm.editor.fire('updateSnapshot')
            }
          })
        }
      };

      config = vm.config ? angular.merge(sgCkeditorConfig.config, vm.config) : sgCkeditorConfig.config;
      config.licenseKey = "GPL";

      if (!config.toolbar) {
        config.toolbar = {
          "items": [
            "bold", "italic", "underline", "|",
            "fontColor", "fontFamily", "fontSize", "removeFormat", "|",
            "numberedList", "bulletedList", "|",
            "outdent", "indent", "|",
            "blockQuote", "|",
            "alignment", "|",
            "link", "|",
            "insertTable", "specialCharacters", "imageUpload", "|",
            "undo", "redo", "sourceEditing", "htmlEmbed"
          ],
          "shouldNotGroupWhenFull": true
        }
      }
      config.htmlSupport = {
        allow: [
          {
            name: /.*/,
            attributes: true,
            classes: true,
            styles: true
          }
        ]
      };
      config.fontFamily = {
        supportAllValues: true,
        style: {
          element: 'span',
          attributes: {
            style: 'font-family'
          }
        }
      };

      config.fontSize = {
        options: ['10px', '12px', '14px', '16px', '18px', '20px', '24px'],
        supportAllValues: true,
        style: {
          element: 'span',
          attributes: {
            style: 'font-size'
          }
        }
      };

      config.htmlEmbed = {
        showPreviews: true
      };
      config.mediaEmbed = {
        providers: []
      };
      config.image = {
        resizeUnit: "px",
        insert: {
          type: "inline"
        }
      };
      config.disableNativeSpellChecker = false;
      vm.config = config;
    };

    this.$postLink = function () {
      var editorElement = $element[0].children[0];;
      ClassicEditor
        .create(editorElement, vm.config)
        .then(editor => {
          vm.editor = editor;

          // Add Emoticons
          editor.plugins.get('SpecialCharacters').addItems('Emoji', emojis, { label: 'Emoticons' });
          
          vm.editor.model.document.on('pasteState', function () { vm.onEditorChange(false); });
          vm.editor.model.document.on('change:data', function () { vm.onEditorChange(false); });
          vm.editor.model.document.on('paste', function () { vm.onEditorChange(false); });
          vm.editor.editing.view.document.on('blur', function () { vm.onEditorChange(true); });
          vm.editor.component = this;

          onInstanceReady();

          if (content) {
            modelChanged = true
            vm.editor.setData(content, {
              noSnapshot: true,
              callback: function () {
                vm.editor.fire('updateSnapshot')
              }
            });
          }
          
        })
        .catch(error => {
          console.error(error);
        });
    };

    this.$onChanges = function (changes) {
      if (
        changes.ngModel &&
        changes.ngModel.currentValue !== changes.ngModel.previousValue
      ) {
        content = changes.ngModel.currentValue;
        if (vm.editor && !editorChanged) {
          if (content) {
            vm.editor.setData(content, {
              noSnapshot: true,
              callback: function () {
                vm.editor.fire('updateSnapshot')
              }
            });
            modelChanged = true;
          }
        }
        editorChanged = false;
      }
      if (editor && changes.readOnly) {
        editor.setReadOnly(changes.readOnly.currentValue);
      }
    }

    this.$onDestroy = function () {
      var noUpdate = true;
      if (vm.editor)
        vm.editor.destroy(noUpdate);
    }

    this.onEditorChange = function(force) {
      if (editorChangedTimer)
        clearTimeout(editorChangedTimer);

      var refresh = function() {
        var html = vm.editor.getData();
        html = inlineImageDimensions(html);

        var dom = document.createElement("DIV");
        dom.innerHTML = html;
        var text = (dom.textContent || dom.innerText);

        if (text === '\n') {
          text = '';
        }

        if (!modelChanged && html !== vm.ngModelCtrl.$viewValue) {
          editorChanged = true;
          vm.ngModelCtrl.$setViewValue(html);
          validate(vm.checkTextLength ? text : html);
          if (vm.onContentChanged) {
            vm.onContentChanged({
              'editor': vm.editor,
              'html': html,
              'text': text
            });
          }
        }
        modelChanged = false;
        editorChangedTimer = null;
      };

      if (force) {
        refresh();
      } else {
        editorChangedTimer = setTimeout(refresh, editorChangedTimerValue);
      }
    }

    function onEditorPaste (event) {
      var html;
      if (event.data.type == 'html') {
        html = event.data.dataValue;
        // Remove images to avoid ghost image in Firefox; images will be handled by the Image Upload plugin
        event.data.dataValue = html.replace(/<img( [^>]*)?>/gi, '');
      }
    }

    function onInstanceReady(event) {
      if (vm.onInstanceReady) {
        vm.onInstanceReady({
          '$event': event,
          '$editor': vm.editor
        });
      }

      vm.ngModelCtrl.$render();
    }

    function validate(body) {
      if (vm.maxLength) {
        vm.ngModelCtrl.$setValidity('maxlength', body.length > vm.maxLength + 1);
      }
      if (vm.minLength) {
        vm.ngModelCtrl.$setValidity('minlength', body.length <= vm.minLength);
      }
      if (vm.required) {
        vm.ngModelCtrl.$setValidity('required', body.length > 0);
      }
      
    }
    
    function inlineImageDimensions(html) {
      return html.replace(/<img\b[^>]*>/gi, function (tag) {
        var style = (tag.match(/style="([^"]*)"/i) || [])[1];
        if (!style) return tag;
        var r = style.match(/aspect-ratio\s*:\s*(\d+)\s*\/\s*(\d+)/i);
        if (!r) return tag;
        var w = (style.match(/(?:^|;)\s*width\s*:\s*(\d+)px/i) || [])[1]
             || (tag.match(/\swidth="(\d+)"/i) || [])[1];
        if (!w) return tag;
        var h = Math.round(w * r[2] / r[1]);

        var newStyle = style;
        if (!/(?:^|;)\s*width\s*:/i.test(newStyle)) newStyle = newStyle.replace(/;?\s*$/, '') + ';width:' + w + 'px';
        if (!/(?:^|;)\s*height\s*:/i.test(newStyle)) newStyle = newStyle.replace(/;?\s*$/, '') + ';height:' + h + 'px';
        
        return tag
          .replace(/style="[^"]*"/i, 'style="' + newStyle + '"')
          .replace(/\swidth="[^"]*"/gi, '')
          .replace(/\sheight="[^"]*"/gi, '')
          .replace(/\s*\/?>$/, ' width="' + w + '" height="' + h + '">');
      });
    }

    function cleanDirtyHTMLElements(html, threshold) {
      var regex = /(<[^>^/]+>(&nbsp;)*<\/[^>]+>)/gm;
      var m;
      var duplicates = {};
      while ((m = regex.exec(html)) !== null) {
        if (m[0]) {
          var hash = (m[0]).md5();
          if (duplicates[hash]) {
            duplicates[hash].counter++;
          } else {
            duplicates[hash] = {
              code: m[0],
              counter: 1
            };
          }
        }
      }

      var i;
      var duplicatesKeys = Object.keys(duplicates);
      for (i = 0; i < duplicatesKeys.length; i++) {
        if (duplicates[duplicatesKeys[i]].counter >= threshold) {
          // Remove element
          html = html.replaceAll(duplicates[duplicatesKeys[i]].code, '');
          console.log("Removed tag for cleaning : ");
          console.log(duplicates[duplicatesKeys[i]].code);
        }
      }

      return html;
    }
  }

  angular
    .module('sgCkeditor', [])
    .provider('sgCkeditorConfig', sgCkeditorConfigProvider)
    .component('sgCkeditor', sgCkeditorComponent);
})();
