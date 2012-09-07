/* -*- Mode: java; tab-width: 2; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function SOGoTabsController() {
}

SOGoTabsController.prototype = {
    container: null,
    firstTab: null,
    activeTab: null,

    list: null,
    offset: 0,

    createScrollButtons: function STC_createScrollButtons() {
        var scrollToolbar = createElement("div", null, "scrollToolbar");
        scrollToolbar.hide();
        var lnk = createElement("a", null,
                                [ "leftScrollButton",
                                  "scrollButton", "smallToolbarButton"],
                                { href: "#" },
                                null, scrollToolbar);
        var span = createElement("span");
        lnk.appendChild(span);
        span.appendChild(document.createTextNode("<"));
        this.onScrollLeftBound = this.onScrollLeft.bindAsEventListener(this);
        lnk.observe("click", this.onScrollLeftBound, false);

        var lnk = createElement("a", null,
                                [ "rightScrollButton",
                                  "scrollButton", "smallToolbarButton"],
                                { href: "#" },
                                null, scrollToolbar);
        var span = createElement("span");
        lnk.appendChild(span);
        span.appendChild(document.createTextNode(">"));
        this.onScrollRightBound = this.onScrollRight.bindAsEventListener(this);
        lnk.observe("click", this.onScrollRightBound, false);

        this.container.appendChild(scrollToolbar);
        this.scrollToolbar = scrollToolbar;
    },

    onScrollLeft: function(event) {
        if (this.offset < 0) {
            var offset = this.offset + 20;
            if (offset > 0) {
                offset = 0;
            }
            this.list.setStyle("margin-left: " + offset + "px;");
            // log("offset: " + offset);
            this.offset = offset;
        }
        event.stop();
    },
    onScrollRight: function(event) {
        if (this.offset > this.minOffset) {
            var offset = this.offset - 20;
            if (offset < this.minOffset) {
                offset = this.minOffset;
            }
            this.list.setStyle("margin-left: " + offset + "px;");
            // log("offset: " + offset);
            this.offset = offset;
        }
        event.stop();
    },

    attachToTabsContainer: function STC_attachToTabsContainer(container) {
        this.container = container;
        this.onTabMouseDownBound
        = this.onTabMouseDown.bindAsEventListener(this);
        this.onTabClickBound
        = this.onTabClick.bindAsEventListener(this);

        var list = container.childNodesWithTag("ul");
        if (list.length > 0) {
            this.list = $(list[0]);
            var nodes = this.list.childNodesWithTag("li");
            if (nodes.length > 0) {
                this.firstTab = $(nodes[0]);
                for (var i = 0; i < nodes.length; i++) {
                    var currentNode = $(nodes[i]);
                    currentNode.observe("mousedown",
                                        this.onTabMouseDownBound, false);
                    currentNode.observe("click", this.onTabClickBound, false);
                    if (currentNode.hasClassName("active"))
                        this.activeTab = currentNode;
                    //$(currentNode.getAttribute("target")).hide();
                }

                this.firstTab.addClassName("first");
                if (this.activeTab == null) {
                    this.activeTab = this.firstTab;
                    this.activeTab.addClassName("active");
                }
                var last = nodes.length - 1;
                this.lastTab = $(nodes[last]);

                var target = $(this.activeTab.getAttribute("target"));
                target.addClassName("active");
            }
            this.onWindowResizeBound = this.onWindowResize.bindAsEventListener(this);
            Event.observe(window, "resize", this.onWindowResizeBound, false);
        }

        this.createScrollButtons();
        this.recomputeMinOffset();
    },

    onWindowResize: function STC_onWindowResize(event) {
        this.recomputeMinOffset();
    },

    recomputeMinOffset: function() {
        var tabsWidth = (this.lastTab.offsetLeft + this.lastTab.clientWidth
                         - this.firstTab.offsetLeft
                         + 4);
        this.minOffset = (this.container.clientWidth - tabsWidth - 40);
        if (this.minOffset < -40) {
            this.scrollToolbar.show();
        } else {
            this.scrollToolbar.hide();
            if (this.offset < 0) {
                this.list.setStyle("margin-left: 0px;");
                this.offset = 0;
            }
        }
    },

    onTabMouseDown: function STC_onTabMouseDown(event) {
        event.stop();
    },

    onTabClick: function STC_onTabClick(event) {
        var clickedTab = getTarget(event);
        if (clickedTab.nodeType == 1) {
            while (clickedTab.tagName.toLowerCase() != "li") {
                clickedTab = $(clickedTab.parentNode);
            }
            var content = $(clickedTab.getAttribute("target"));
            var oldContent = $(this.activeTab.getAttribute("target"));
            oldContent.removeClassName("active");
            this.activeTab.removeClassName("active"); // previous LI
            this.activeTab = $(clickedTab);
            this.activeTab.addClassName("active"); // current LI
            content.addClassName("active");
            this.activeTab.fire("tabs:click", content.id);

            // Prototype alternative
        
            //oldContent.removeClassName("active");
            //container.activeTab.removeClassName("active"); // previous LI
            //container.activeTab = node;
            //container.activeTab.addClassName("active"); // current LI
            
            //container.activeTab.hide();
            //oldContent.hide();
            //content.show();

            //container.activeTab = node;
            //container.activeTab.show();
        }
    }
}
