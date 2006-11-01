HTMLTableElement.prototype.getSelectedRows = function() {
  var tbody = (this.getElementsByTagName('tbody'))[0];

  return tbody.getSelectedNodes();
}

HTMLTableElement.prototype.getSelectedRowsId = function() {
  var tbody = (this.getElementsByTagName('tbody'))[0];

  return tbody.getSelectedNodesId();
}

HTMLTableElement.prototype.selectRowsMatchingClass = function(className) {
  var tbody = (this.getElementsByTagName('tbody'))[0];
  var nodes = tbody.childNodes;
  for (var i = 0; i < nodes.length; i++) {
    var node = nodes.item(i);
    if (node instanceof HTMLElement) {
      var classStr = '' + node.getAttribute("class");
      if (classStr.indexOf(className, 0) >= 0)
        selectNode(node);
    }
  }
}

HTMLTableElement.prototype.deselectAll = function() {
  var nodes = this.getSelectedRows();
  for (var i = 0; i < nodes.length; i++)
    deselectNode(nodes[i]);
}
