HTMLInputElement.prototype._replicate = function() {
  if (this.replica) {
    this.replica.value = this.value;
    var onReplicaChangeEvent = document.createEvent("Event");
    onReplicaChangeEvent.initEvent("change", true, true);
    this.replica.dispatchEvent(onReplicaChangeEvent);
  }
}

HTMLInputElement.prototype.assignReplica = function(otherInput) {
  if (!this._onChangeBound) {
    this.addEventListener("change", this._replicate, false);
    this._onChangeBound = true;
  }
  this.replica = otherInput;
}

HTMLInputElement.prototype.valueAsDate = function () {
  return this.value.asDate();
}

HTMLInputElement.prototype.setValueAsDate = function(dateValue) {
  if (!this.dateSeparator)
    this._detectDateSeparator();
  this.value = dateValue.stringWithSeparator(this.dateSeparator);
}

HTMLInputElement.prototype.updateShadowValue = function () {
  this.setAttribute("shadow-value", this.value);
}

HTMLInputElement.prototype._detectDateSeparator = function() {
  var date = this.value.split("/");
  if (date.length == 3)
    this.dateSeparator = "/";
  else
    this.dateSeparator = "-";
}

HTMLInputElement.prototype.valueAsShortDateString = function() {
  var dateStr = '';

  if (!this.dateSeparator)
    this._detectDateSeparator();

  var date = this.value.split(this.dateSeparator);
  if (this.dateSeparator == '/')
    dateStr += date[2] + date[1] + date[0];
  else
    dateStr += date[0] + date[1] + date[2];

  return dateStr;
}

/* "select" is part of the inputs so it's included here */
HTMLSelectElement.prototype._replicate = function() {
  if (this.replica) {
    this.replica.value = this.value;
    var onReplicaChangeEvent = document.createEvent("Event");
    onReplicaChangeEvent.initEvent("change", true, true);
    this.replica.dispatchEvent(onReplicaChangeEvent);
  }
}

HTMLSelectElement.prototype.assignReplica = function(otherSelect) {
  if (!this._onChangeBound) {
    this.addEventListener("change", this._replicate, false);
    this._onChangeBound = true;
  }
  this.replica = otherSelect;
}

HTMLSelectElement.prototype.updateShadowValue = function () {
  this.setAttribute("shadow-value", this.value);
}
