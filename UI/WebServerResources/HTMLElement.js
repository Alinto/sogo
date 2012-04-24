/* -*- Mode: js-mode; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

["HTMLCollection", "NodeList"].each(
    function (className) {
        if (className in window) {
            var contClass = window[className];
            var _each = contClass.prototype.forEach;
            if (!_each) {
                _each = function HTMLElement_each(iterator, context) {
                    for (var i = 0, length = this.length >>> 0; i < length; i++) {
                        if (i in this) iterator.call(context, this[i], i, this);
                    }
                };
            }
            contClass.prototype._each = _each;
            Object.extend(contClass.prototype, Enumerable);
        }
    }
);

/* custom extensions to the DOM api */
Element.addMethods({
        addInterface: function(element, objectInterface) {
            element = $(element);
            Object.extend(element, objectInterface);
            if (element.bind)
                element.bind();
        },

        allTextContent: function(element) {
            var content = "";
            for (var i = 0; i < element.childNodes.length; i++) {
                var node = $(element.childNodes[i]);
                if (node.nodeType == Node.TEXT_NODE) {
                    content += node.nodeValue;
                }
                else if (node.nodeType == Node.ELEMENT_NODE) {
                    content += Element.allTextContent(node);
                }
            }

            return content;
        },

        childNodesWithTag: function(element, tagName) {
            element = $(element);

            var matchingNodes = new Array();
            tagName = tagName.toUpperCase();

            for (var i = 0; i < element.childNodes.length; i++) {
                var childNode = $(element.childNodes[i]);
                if (Object.isElement(childNode)
                    && childNode.tagName
                    && childNode.tagName.toUpperCase() == tagName)
                    matchingNodes.push(childNode);
            }

            return matchingNodes;
        },

        getParentWithTagName: function(element, tagName) {
            element = $(element);
            var currentElement = element;
            tagName = tagName.toUpperCase();

            currentElement = currentElement.parentNode;
            while (currentElement
                   && currentElement.tagName != tagName) {
                currentElement = currentElement.parentNode;
            }

            return currentElement;
        },

        cascadeLeftOffset: function(element) {
            element = $(element);
            var currentElement = element;

            var offset = 0;
            while (currentElement) {
                offset += currentElement.offsetLeft;
                currentElement = $(currentElement).getParentWithTagName("div");
            }

            return offset;
        },

        cascadeTopOffset: function(element) {
            element = $(element);
            var currentElement = element;
            var offset = 0;

            var i = 0;

            while (currentElement && currentElement.tagName) {
                offset += currentElement.offsetTop;
                currentElement = currentElement.parentNode;
                i++;
            }

            return offset;
        },

        dump: function(element, additionalInfo, additionalKeys) {
            element = $(element);
            var id = element.getAttribute("id");
            var nclass = element.getAttribute("class");

            var str = element.tagName;
            if (id)
                str += "; id = " + id;
            if (nclass)
                str += "; class = " + nclass;

            if (additionalInfo)
                str += "; " + additionalInfo;

            if (additionalKeys)
                for (var i = 0; i < additionalKeys.length; i++) {
                    var value = element.readAttribute(additionalKeys[i]);
                    if (value)
                        str += "; " + additionalKeys[i] + " = " + value;
                }

            log (str);
        },

        getSelectedNodes: function(element) {
            element = $(element);

            if (!element.selectedElements)
                element.selectedElements = new Array();

            return element.selectedElements;
        },

        getSelectedNodesId: function(element) {
            element = $(element);

            var selArray = null;
            if (element.selectedIds) {
                selArray = element.selectedIds;
            }
            else {
                selArray = [];
                if (element.selectedElements) {
                    for (var i = 0; i < element.selectedElements.length; i++) {
                        var node = element.selectedElements[i];
                        selArray.push(node.getAttribute("id"));
                    }
                }
            }

            return selArray;
        },

        onContextMenu: function(element, event) {
            element = $(element);
            if (document.currentPopupMenu)
                hideMenu(document.currentPopupMenu);

            var popup = element.sogoContextMenu;
            var menuTop = Event.pointerY(event);
            var menuLeft = Event.pointerX(event);
            var heightDiff = (window.height()
                              - (menuTop + popup.offsetHeight));
            if (heightDiff < 0)
                menuTop += heightDiff;

            var leftDiff = (window.width()
                            - (menuLeft + popup.offsetWidth));
            if (leftDiff < 0)
                menuLeft -= popup.offsetWidth;

            var isVisible = true;
            if (popup.prepareVisibility)
                isVisible = popup.prepareVisibility();

            Event.stop(event);

            if (isVisible) {
                popup.setStyle( { top: menuTop + "px",
                            left: menuLeft + "px",
                            visibility: "visible" } );
                document.currentPopupMenu = popup;
                $(document.body).on("mousedown", onBodyClickMenuHandler);
            }
            else
                log ("Warning: not showing the contextual menu " + element.id);
        },

        attachMenu: function(element, menuName) {
            element = $(element);
            element.sogoContextMenu = $(menuName);
            element.on("contextmenu", element.onContextMenu);
        },

        selectElement: function(element) {
            element = $(element);
            element.addClassName('_selected');
            var parent = element.up();
            if (!parent.selectedElements || !parent.selectedIds) {
                // Selected nodes are kept in a array at the
                // container level.
                parent.selectedElements = new Array();
                parent.selectedIds = new Array();
            }
            for (var i = 0; i < parent.selectedElements.length; i++)
                if (parent.selectedElements[i] == element) return;
            parent.selectedElements.push(element); // use index instead ?
            if (element.id) {
                for (var i = 0; i < parent.selectedIds.length; i++)
                    if (parent.selectedIds[i] == element.id) return;
                parent.selectedIds.push(element.id);
            }
        },

        selectRange: function(element, startIndex, endIndex) {
            element = $(element);
            var s;
            var e;
            var rows;

            if (startIndex > endIndex) {
                s = endIndex;
                e = startIndex;
            }
            else {
                s = startIndex;
                e = endIndex;
            }
            if (element.tagName == 'UL')
                rows = element.getElementsByTagName('LI');
            else
                rows = element.getElementsByTagName('TR');
            while (s <= e) {
                if (rows[s].nodeType == 1)
                    $(rows[s]).selectElement();
                s++;
            }
        },

        selectAll: function(element) {
            element = $(element);
            if (element.tagName == 'UL')
                rows = element.getElementsByTagName('LI');
            else
                rows = element.select('TBODY TR');
            for (var i = 0; i < rows.length; i++) {
                if (rows[i].nodeType == 1)
                    $(rows[i]).selectElement();
            }
        },

        deselect: function(element) {
            element = $(element);
            element.removeClassName('_selected');
            var parent = element.parentNode;
            if (parent) {
                if (parent.selectedElements)
                    parent.selectedElements = parent.selectedElements.without(element);
                if (parent.selectedIds)
                    parent.selectedIds = parent.selectedIds.without(element.id);
            }
        },

        deselectAll: function(element) {
            if (element.tagName == 'TABLE') {
                var tbody = element.tBodies[0];
                if (tbody)
                    element = tbody;
            }
            element = $(element);
            var s = element.select("._selected");
            for (var i = 0; i < s.length; i++)
                s[i].removeClassName("_selected");

            element.selectedElements = null;
            element.selectedIds = null;
        },

        refreshSelectionByIds: function(element, selectedIds) {
            element = $(element);
            var selectedCount = 0;
            if (selectedIds)
                element.selectedIds = selectedIds;
            if (element.selectedIds) {
                for (var i = 0; i < element.selectedIds.length; i++) {
                    //var e = element.down('#'+element.selectedIds[i]); // buggy with IE
                    var e = $(element.selectedIds[i]);
                    if (e) {
                        if (!e.hasClassName('_selected'))
                            e.addClassName('_selected');
                        selectedCount++;
                    }
                    else {
                        log ("refreshSelectionByIds Error: " + element.tagName
                             + " select by ID " + element.selectedIds[i]
                             + " not found (" + element.childNodes.length + " children)");
                    }
                }
            }
            return selectedCount;
        },

        setCaretTo: function(element, pos) {
            element = $(element);
            if (element.setSelectionRange) {  // For Mozilla and Safari
                element.focus();
                element.setSelectionRange(pos, pos);
            }
            else if (element.createTextRange) {  // For IE
                var range = element.createTextRange();
                range.move("character", pos);
                range.select();
            }
        },

        selectText: function(element, start, end) {
            element = $(element);
            if (element.setSelectionRange) {     // For Mozilla and Safari
                element.setSelectionRange(start, end);
            }
            else if (element.createTextRange) {  // For IE
                var textRange = element.createTextRange();
                textRange.moveStart("character", start);
                textRange.moveEnd("character", end-element.value.length);
                textRange.select();
            }
            else {
                element.select();
            }
        },

        getRadioValue: function(element, radioName) {
            element = $(element);
            var radioValue;
            Form.getInputs(element, 'radio', radioName).each(function(input) {
                    if (input.checked)
                        radioValue = input.value;
                });
            return radioValue;
        },

        setRadioValue: function(element, radioName, value) {
            element = $(element);
            var i = 0;

            Form.getInputs(element, 'radio', radioName).each(function(input) {
                    if (i == value)
                        input.checked = 1;
                    i++;
                });
        },

        getCheckBoxListValues: function(element, checkboxName) {
            element = $(element);
            var values = new Array();
            var i = 0;

            Form.getInputs(element, 'checkbox', checkboxName).each(function(input) {
                    if (input.checked)
                        values.push(i+1);

                    i++;
                });
            return values.join(",");
        },

        setCheckBoxListValues: function(element, checkboxName, values) {
            element = $(element);
            var v = values.split(',');
            var i = 1;

            Form.getInputs(element, 'checkbox', checkboxName).each(function(input) {

                    if ($(v).indexOf(i+"") != -1)
                        input.checked = 1;
                    i++;
                });
        }
});
