/* custom extensions to the DOM api */
Element.addMethods({

  addInterface: function(element, objectInterface) {
    element = $(element);
    Object.extend(element, objectInterface);
    if (element.bind)
      element.bind();
  },

  childNodesWithTag: function(element, tagName) {
    element = $(element);
    var matchingNodes = new Array();
    var tagName = tagName.toUpperCase();
    
    for (var i = 0; i < element.childNodes.length; i++) {
      if (typeof(element.childNodes[i]) == "object"
	  && element.childNodes[i].tagName
	  && element.childNodes[i].tagName.toUpperCase() == tagName)
	matchingNodes.push(element.childNodes[i]);
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
	var value = element.getAttribute(additionalKeys[i]);
	if (value)
	  str += "; " + additionalKeys[i] + " = " + value;
      }
    
    log (str);
  },

  getSelectedNodes: function(element) {
    element = $(element);
    var selArray = new Array();
    
    for (var i = 0; i < element.childNodes.length; i++) {
      node = element.childNodes.item(i);
      if (node.nodeType == 1
	  && isNodeSelected(node))
	selArray.push(node);
    }
    
    return selArray;
  },

  getSelectedNodesId: function(element) {
    element = $(element);
    var selArray = new Array();
    
    for (var i = 0; i < element.childNodes.length; i++) {
      node = element.childNodes.item(i);
      if (node.nodeType == 1
	  && isNodeSelected(node)) {
	selArray.push(node.getAttribute("id")); }
    }

    return selArray;
  },

  onContextMenu: function(element, event) {
    element = $(element);
    var popup = element.sogoContextMenu;

    if (document.currentPopupMenu)
      hideMenu(document.currentPopupMenu);
    
    var menuTop = event.pageY;
    var menuLeft = event.pageX;
    var heightDiff = (window.innerHeight
		      - (menuTop + popup.offsetHeight));
    if (heightDiff < 0)
      menuTop += heightDiff;
    
    var leftDiff = (window.innerWidth
		    - (menuLeft + popup.offsetWidth));
    if (leftDiff < 0)
      menuLeft -= popup.offsetWidth;

    popup.setStyle( { top: menuTop + "px",
		      left: menuLeft + "px",
		      visibility: "visible" } );
    
    document.currentPopupMenu = popup;
    Event.observe(document.body, "click", onBodyClickMenuHandler);
  },

  attachMenu: function(element, menuName) {
    element = $(element);
    element.sogoContextMenu = $(menuName);
    Event.observe(element, "contextmenu", element.onContextMenu.bindAsEventListener(element));
  },

  select: function(element) {
    element = $(element);
    element.addClassName('_selected');
  },

  deselect: function(element) {
    element = $(element);
    element.removeClassName('_selected');
  },

  deselectAll: function(element) {
    element = $(element);
    for (var i = 0; i < element.childNodes.length; i++) {
      var node = element.childNodes.item(i);
      if (node.nodeType == 1)
	$(node).deselect();
    }
  },

  setCaretTo: function(element, pos) { 
    element = $(element);
    if (element.selectionStart) { // For Mozilla and Safari
      element.focus(); 
      element.setSelectionRange(pos, pos); 
    }
    else if (element.createTextRange) {       // For IE
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
 }

});
