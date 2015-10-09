/**
 * SUBMODAL v2
 * Used for displaying DHTML only popups instead of using buggy modal windows.
 *
 * Rewritten on 8/24/2010 to respect JS namespaces and provide a way to
 * resize windows based on content.
 *
 * (c) 2010 Subimage LLC
 * http://www.subimage.com/
 *
 * Contributions by:
 *  Eric Angel - tab index code
 *  Scott - hiding/showing selects for IE users
 *  Todd Huss - inserting modal dynamically and anchor classes
 *
 * Up to date code can be found at http://www.subimage.com/dhtml/subModal
 * This code is free for you to use anywhere, just keep this comment block.
 */

/**
 * Other event handlers use this to set up basic
 * event objects...
 */
function getEventSource(e) {
  var source;
  if (typeof e == 'undefined') {
    var e = window.event;
  }
  if (typeof e.target != 'undefined') {
    source = e.target;
  } else if (typeof e.srcElement != 'undefined') {
    source = e.srcElement;
  } else {
    return false;
  }
  return source;
}

/**
 * X-browser event handler attachment
 *
 * @argument obj - the object to attach event to
 * @argument evType - name of the event - DONT ADD "on", pass only "mouseover", etc
 * @argument fn - function to call
 */
function addEvent(obj, evType, fn){
  if (obj == null) return false;
  if (obj.addEventListener){
    obj.addEventListener(evType, fn, false);
    return true;
  } else if (obj.attachEvent){
    var r = obj.attachEvent("on"+evType, fn);
    return r;
  } else {
    return false;
  }
}
function removeEvent(obj, evType, fn, useCapture){
  if (obj.removeEventListener){
    obj.removeEventListener(evType, fn, useCapture);
    return true;
  } else if (obj.detachEvent){
    var r = obj.detachEvent("on"+evType, fn);
    return r;
  } else {
    alert("Handler could not be removed");
  }
}

/**
 * Gets the real scroll top
 */
function getScrollTop() {
  if (self.pageYOffset) // all except Explorer
  {
    return self.pageYOffset;
  }
  else if (document.documentElement && document.documentElement.scrollTop)
    // Explorer 6 Strict
  {
    return document.documentElement.scrollTop;
  }
  else if (document.body) // all other Explorers
  {
    return document.body.scrollTop;
  }
}
function getScrollLeft() {
  if (self.pageXOffset) // all except Explorer
  {
    return self.pageXOffset;
  }
  else if (document.documentElement && document.documentElement.scrollLeft)
    // Explorer 6 Strict
  {
    return document.documentElement.scrollLeft;
  }
  else if (document.body) // all other Explorers
  {
    return document.body.scrollLeft;
  }
}

/**
 * Code below taken from - http://www.evolt.org/article/document_body_doctype_switching_and_more/17/30655/
 * Modified 4/22/04 to work with Opera/Moz (by webmaster at subimage dot com)
 * Gets the full width/height because it's different for most browsers.
 */
function getViewportHeight() {
  if (window.innerHeight!=window.undefined) return window.innerHeight;
  if (document.compatMode=='CSS1Compat') return document.documentElement.clientHeight;
  if (document.body) return document.body.clientHeight; 

  return window.undefined; 
}
function getViewportWidth() {
  var offset = 17;
  var width = null;
  if (window.innerWidth!=window.undefined) return window.innerWidth; 
  if (document.compatMode=='CSS1Compat') return document.documentElement.clientWidth; 
  if (document.body) return document.body.clientWidth; 
}

var SUBMODAL = {
  // "Private" variables ------------------------------------------------------
  _doc_body: null, // reference to document body
  _pop_mask: null,
  _pop_container: null,
  _pop_frame: null,
  // Pre-defined list of tags we want to disable/enable tabbing into
  _tabbable_tags: new Array("A","BUTTON","TEXTAREA","INPUT","IFRAME"),
  _is_shown: false,
  _default_page: "/loading.html",
  _tab_indexes: new Array(),
  
  // Accessible variables -----------------------------------------------------
  center_on_scroll: false, // should we center the modal on scroll?
  disable_scrolling: false, // disable scrolling of main window on show
  hide_selects: false, // should SELECT tags be hidden on show
  close_img: '/plugin_assets/substruct/images/close.gif',
  return_function: null, // called when SUBMODAL.hide is done
  return_val: null, // global return value to access in SUBMODAL.return_function
  // We can set this from within the modal to ALWAYS call the return function,
  // even from the close box.
  should_call_return_function: false,


  // Methods ------------------------------------------------------------------

  // Called on window load.
  // This is NOT to be used like var s = new SUBMODAL();
  init: function() {
    // If using Mozilla or Firefox, use Tab-key trap.
    if (!document.all) {
      document.onkeypress = SUBMODAL.keyDownHandler;
    }
    // Add the HTML to the body
    SUBMODAL._doc_body = document.getElementsByTagName('BODY')[0];
    
    popmask = document.createElement('div');
    popmask.id = 'popupMask';
    popcont = document.createElement('div');
    popcont.id = 'popupContainer';
    popcont.innerHTML = '' +
      '<div id="popupInner">' +
        '<div id="popupTitleBar">' +
          '<div id="popupTitle"></div>' +
          '<div id="popupControls">' +
            '<img src="'+ SUBMODAL.close_img +'" onclick="SUBMODAL.hide(false);" id="popCloseBox" />' +
          '</div>' +
        '</div>' +
        '<iframe src="'+ SUBMODAL._default_page +'" style="width:100%;height:100%;background-color:transparent;" scrolling="auto" frameborder="0" allowtransparency="true" id="popupFrame" name="popupFrame" width="100%" height="100%"></iframe>' +
      '</div>';
    SUBMODAL._doc_body.appendChild(popmask);
    SUBMODAL._doc_body.appendChild(popcont);
    addEvent(popmask, "click", SUBMODAL.hide);

    SUBMODAL._pop_mask = document.getElementById("popupMask");
    SUBMODAL._pop_container = document.getElementById("popupContainer");
    SUBMODAL._pop_frame = document.getElementById("popupFrame");  

    // check to see if this is IE version 6 or lower. hide select boxes if so
    // maybe they'll fix this in version 7?
    var brsVersion = parseInt(window.navigator.appVersion.charAt(0), 10);
    if (brsVersion <= 6 && window.navigator.userAgent.indexOf("MSIE") > -1) {
      SUBMODAL.hide_selects = true;
    }

    // Add onclick handlers to 'a' elements of class submodal or submodal-width-height
    var elms = document.getElementsByTagName('a');
    for (i = 0; i < elms.length; i++) {
      if (elms[i].className.indexOf("submodal") == 0) { 
        elms[i].onclick = function(){
          // default width and height
          var width = 400;
          var height = 200;
          // Parse out optional width and height from className
          params = this.className.split('-');
          if (params.length == 3) {
            width = parseInt(params[1]);
            height = parseInt(params[2]);
          }
          SUBMODAL.show(this.href,width,height,null); return false;
        }
      }
    }
  },
  
  // @width - int in pixels
  // @height - int in pixels
  // @url - url to display
  // @returnFunc - function to call when returning true from the window.
  // @showCloseBox - show the close box - default true
  show: function(url, width, height, returnFunc, showCloseBox) {
    // show or hide the window close widget
    showCloseBox = showCloseBox || true;
    if (showCloseBox == true) {
      document.getElementById("popCloseBox").style.display = "block";
    } else {
      document.getElementById("popCloseBox").style.display = "none";
    }
    if (SUBMODAL.disable_scrolling == true) {
      SUBMODAL._doc_body.style.overflow = "hidden";
    }
    SUBMODAL._is_shown = true;
    SUBMODAL.disableTabIndexes();
    SUBMODAL._pop_mask.style.display = "block";
    SUBMODAL._pop_container.style.display = "block";
    // calculate where to place the window on screen
    SUBMODAL.center(width, height);

    var titleBarHeight = parseInt(document.getElementById("popupTitleBar").offsetHeight, 10);

    SUBMODAL._pop_container.style.width = width + "px";
    SUBMODAL._pop_container.style.height = (height+titleBarHeight) + "px";

    SUBMODAL.setMaskSize();

    // need to set the width of the iframe to the title bar width because of the dropshadow
    // some oddness was occuring and causing the frame to poke outside the border in IE6
    SUBMODAL._pop_frame.style.width = parseInt(
      document.getElementById("popupTitleBar").offsetWidth, 10
    ) + "px";
    SUBMODAL._pop_frame.style.height = (height) + "px";

    // set the url
    SUBMODAL._pop_frame.src = url;
    SUBMODAL.return_function = returnFunc;
    // for IE
    if (SUBMODAL.hide_selects == true) {
      SUBMODAL.hideSelectBoxes();
    }
  },
  
  // @callReturnFunc - bool - determines if we call the return function specified
  hide: function(callReturnFunc) {
    SUBMODAL._is_shown = false;
    // restore any hidden scrollbars
    SUBMODAL._doc_body.style.overflow = "";
    SUBMODAL.restoreTabIndexes();
    if (SUBMODAL._pop_mask == null) {
      return;
    }
    SUBMODAL._pop_mask.style.display = "none";
    SUBMODAL._pop_container.style.display = "none";
    
    if (
      (callReturnFunc == true || SUBMODAL.should_call_return_function == true) && 
      SUBMODAL.return_function != null
    ) {
      // Set the return code to run in a timeout.
      // Was having issues using with an XMLHttpRequests
      SUBMODAL.return_val = window.frames["popupFrame"].returnVal;
      window.setTimeout('SUBMODAL.return_function(SUBMODAL.return_val);', 1);
      // Reset global return function boolean.
      SUBMODAL.should_call_return_function = false;
    }
    
    SUBMODAL._pop_frame.src = SUBMODAL._default_page;
    
    // display all select boxes
    if (SUBMODAL.hide_selects == true) { 
      SUBMODAL.displaySelectBoxes(); 
    }
  },
    
  center: function(width, height) {
    if (SUBMODAL._is_shown == true) {
      if (width == null || isNaN(width)) {
        width = SUBMODAL._pop_container.offsetWidth;
      }
      if (height == null) {
        height = SUBMODAL._pop_container.offsetHeight;
      }
      SUBMODAL.setMaskSize();   
      var titleBarHeight = parseInt(document.getElementById("popupTitleBar").offsetHeight, 10);
      var fullHeight = getViewportHeight();
      var fullWidth = getViewportWidth();
      SUBMODAL._pop_container.style.top = (((fullHeight - (height+titleBarHeight)) / 2)+getScrollTop()) + "px";
      SUBMODAL._pop_container.style.left =  (((fullWidth - width) / 2)) + "px";
    }
  },
  
  // Sets the size of our popup mask
  setMaskSize: function() {
    var fullHeight = getViewportHeight();
    // Determine what's bigger, scrollHeight or fullHeight / width
    if (fullHeight > SUBMODAL._doc_body.scrollHeight) {
      popHeight = fullHeight;
    } else {
      popHeight = SUBMODAL._doc_body.scrollHeight;
    }
    SUBMODAL._pop_mask.style.height = popHeight + "px";
    SUBMODAL._pop_mask.style.width = "100%";
  },
  
  // For IE.  Go through predefined tags and disable tabbing into them.
  disableTabIndexes: function() {
    if (document.all) {
      var i = 0;
      for (var j = 0; j < SUBMODAL._tabbable_tags.length; j++) {
        var tagElements = document.getElementsByTagName(SUBMODAL._tabbable_tags[j]);
        for (var k = 0 ; k < tagElements.length; k++) {
          SUBMODAL._tab_indexes[i] = tagElements[k].tabIndex;
          tagElements[k].tabIndex="-1";
          i++;
        }
      }
    }
  },
  // For IE. Restore tab-indexes.
  restoreTabIndexes: function() {
    if (document.all) {
      var i = 0;
      for (var j = 0; j < SUBMODAL._tabbable_tags.length; j++) {
        var tagElements = document.getElementsByTagName(SUBMODAL._tabbable_tags[j]);
        for (var k = 0 ; k < tagElements.length; k++) {
          tagElements[k].tabIndex = SUBMODAL._tab_indexes[i];
          tagElements[k].tabEnabled = true;
          i++;
        }
      }
    }
  },

  // Hides all drop down form select boxes on the screen so they do not appear above the mask layer.
  // IE has a problem with wanted select form tags to always be the topmost z-index or layer
  // 
  // Thanks for the code Scott!
  hideSelectBoxes: function() {
    var df = document.forms;
    for(var i = 0; i < df.length; i++) {
      for(var e = 0; e < df[i].length; e++){
        if(df[i].elements[e].tagName == "SELECT") {
          df[i].elements[e].style.visibility="hidden";
        }
      }
    }
  },
  // Makes all drop down form select boxes on the screen visible so they do not 
  // reappear after the dialog is closed.
  // IE has a problem with wanting select form tags to always be the topmost z-index or layer
  displaySelectBoxes: function() {
    var df = document.forms;
    for(var i = 0; i < df.length; i++) {
      for(var e = 0; e < df[i].length; e++){
        if(df[i].elements[e].tagName == "SELECT") {
        df[i].elements[e].style.visibility="visible";
        }
      }
    }
  },

  // Tab key trap. iff popup is shown and key was [TAB], suppress it.
  // @argument e - event - keyboard event that caused this function to be called.
  keyDownHandler: function(e) {
    if (SUBMODAL._is_shown && e.keyCode == 9)  return false;
  }
};
addEvent(window, "load", SUBMODAL.init);
addEvent(window, "resize", SUBMODAL.center);
if (SUBMODAL.center_on_scroll == true) {
  addEvent(window, "scroll", SUBMODAL.center);
}