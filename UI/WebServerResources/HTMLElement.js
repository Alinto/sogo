Element.addMethods({

  addInterface:  function(element, objectInterface) {
    element = $(element);
    Object.extend(element, objectInterface);
    if (element.bind)
      element.bind();
  },

  childNodesWithTag:  function(element, tagName) {
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

  getParentWithTagName:  function(element, tagName) {
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

  cascadeLeftOffset:  function(element) {
    element = $(element);
    var currentElement = element;
  
    var offset = 0;
    while (currentElement) {
      offset += currentElement.offsetLeft;
      currentElement = currentElement.getParentWithTagName("div");
    }

    return offset;
  },

  cascadeTopOffset:  function(element) { 
    element = $(element);
    var currentElement = element;
    var offset = 0;
    
    var i = 0;
    while (currentElement
	   && currentElement instanceof HTMLElement) {
      offset += currentElement.offsetTop;
      currentElement = currentElement.parentNode;
      i++;
    }

    return offset;
  },

  dump:  function(element,  additionalInfo, additionalKeys) {
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

  getSelectedNodes:  function(element) {
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
 
  getSelectedNodesId:  function(element) {
    element = $(element);
    var selArray = new Array();
    
    for (var i = 0; i < element.childNodes.length; i++) {
      node = element.childNodes.item(i);
      if (node.nodeType == 1
	  && isNodeSelected(node))
	selArray.push(node.getAttribute("id"));
    }
    
    return selArray;
  },

  onContextMenu:  function(element, event) {
    element = $(element);
    var popup = element.sogoContextMenu;

    if (document.currentPopupMenu)
      hideMenu(event, document.currentPopupMenu);
    
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
    
    popup.style.top = menuTop + "px;";
    popup.style.left = menuLeft + "px;";
    popup.style.visibility = "visible;";
    
    bodyOnClick = "" + document.body.getAttribute("onclick");
    document.body.setAttribute("onclick", "onBodyClick(event);");
    document.currentPopupMenu = popup;
  },

  attachMenu:  function(element, menuName) {
    element = $(element);
    element.sogoContextMenu = $(menuName);
    element.addEventListener("contextmenu", element.onContextMenu, true);
  },

  select:  function(element) {
    element = $(element);
    element.addClassName('_selected');
  },

  deselect:  function(element) {  
    element = $(element);
    element.removeClassName('_selected');
  },

  deselectAll:  function(element) { 
    element = $(element);
    var nodes;
    if (element.tagName == 'TABLE')
      nodes = element.getSelectedRows();
    else
      nodes = element.childNodes;
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes.item(i);
      if (node.nodeType == 1)
	node.deselect();
    }
  }

}); // Element.addMethods
