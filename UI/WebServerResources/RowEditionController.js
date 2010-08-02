/* bind method: attachToRowElement(row: TD or LI)
 * callback methods:
     notifyStartEditingCallback(this)
     notifyEndEditingCallback(this)
     notifyNewValueCallback(this, newValue),
 */

function RowEditionController() {
}

RowEditionController.prototype = {
    initialValue: null,
    rowElement: null,
    textField: null,

    /*  notification callbacks */
    notifyStartEditingCallback: null,
    notifyEndEditingCallback: null,
    notifyNewValueCallback: null,

    /* bind method */
    attachToRowElement: function REC_attachToRowElement(rowElement) {
        var onRowDblClickBound = this.onRowDblClick.bindAsEventListener(this);
        rowElement.observe("dblclick", onRowDblClickBound);
        this.rowElement = rowElement;
        rowElement.editionController = this;
    },

    /* internal */
    emptyRow: function REC_emptyRow() {
        var rowElement = this.rowElement;
        while (rowElement.firstChild) {
            rowElement.removeChild(rowElement.firstChild);
        }
    },

    startEditing: function REC_startEditing() {
        var rowElement = this.rowElement;
        rowElement.previousClassName = rowElement.className;
        rowElement.className = "editing";

        var value = "";
        for (var i = 0; i < rowElement.childNodes.length; i++) {
            var child = rowElement.childNodes[i];
            if (child.nodeType == Node.TEXT_NODE) {
                value += child.nodeValue;
            }
        }
        log("initial Value: " + value);
        this.initialValue = value;
        this.emptyRow();

        this.showInputField(value);

        this.onBodyMouseDownBound = this.onBodyMouseDown.bindAsEventListener(this);
        $(document.body).observe("mousedown", this.onBodyMouseDownBound);

        if (this.notifyStartEditingCallback) {
            this.notifyStartEditingCallback(this);
        }
    },
    showInputField: function REC_showInputField(value) {
        var textField = createElement("input", null, null, {"type": "text"});
        this.textField = textField;
        if (value) {
            textField.value = value;
        }
        this.rowElement.appendChild(textField);
        var onInputKeyDownBound = this.onInputKeyDown.bindAsEventListener(this);
        textField.observe("keydown", onInputKeyDownBound);
        textField.focus();
        textField.select();
    },

    stopEditing: function REC_stopEditing(accept) {
        var displayValue = (accept ? this.textField.value : this.initialValue);
        this.textField = null;
        this.emptyRow();
        var rowElement = this.rowElement;
        rowElement.className = rowElement.previousClassName;
        rowElement.previousClassName = null;
        rowElement.appendChild(document.createTextNode(displayValue));
        this.initialValue = null;

        $(document.body).stopObserving("mousedown", this.onBodyMouseDownBound);
        this.onBodyMouseDownBound = null;

        if (this.notifyEndEditingCallback) {
            this.notifyEndEditingCallback(this);
        }
    },

    acceptEdition: function REC_acceptEdition() {
        var newValue = this.textField.value;
        if (this.initialValue != newValue
            && this.notifyNewValueCallback) {
            this.notifyNewValueCallback(this, value);
        }
        this.stopEditing(true);
    },
    cancelEdition: function REC_acceptEdition() {
        this.stopEditing(false);
    },

    /* event handlers */
    onRowDblClick: function REC_onRowDblClick(event) {
        log("onRowDblClick");
        if (!this.textField) {
            this.startEditing();
            event.stop();
        }
    },

    onInputKeyDown: function REC_onInputKeyDown(event) {
        if (event.keyCode == Event.KEY_ESC) {
            this.cancelEdition();
            event.stop();
        }
        else if (event.keyCode == Event.KEY_RETURN) {
            this.acceptEdition();
            event.stop();
        }
    },
    onBodyMouseDown: function REC_onBodyMouseDown(event) {
        if (event.target != this.textField) {
            this.acceptEdition();
        }
    }
};
