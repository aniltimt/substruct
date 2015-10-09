tinyMCE.init({
  theme: "advanced",
  theme_advanced_toolbar_location: "top",
  theme_advanced_statusbar_location: "bottom",	
	theme_advanced_resizing: true,
	theme_advanced_resize_horizontal: false,
  theme_advanced_toolbar_align : "left",
  theme_advanced_buttons1: "formatselect, bold, italic, link, bullist, numlist, blockquote, substruct_browser, justifyleft, justifycenter, justifyright, justifyfull, pagebreak, fullscreen, cleanup, code",
	theme_advanced_buttons2: "",
	theme_advanced_buttons3: "",
  // Add editor to Content desc & Product desc only
  mode: "exact",
  elements: "content_node_content,product_description",
  plugins : "safari,paste,pagebreak,fullscreen,substruct_browser",
  pagebreak_separator: "<!--more-->",
  relative_urls: false,
  // Allow iFrames
  extended_valid_elements: "iframe[align<bottom?left?middle?right?top|class|frameborder|height|id"
    +"|longdesc|marginheight|marginwidth|allowTransparency|name|scrolling<auto?no?yes|src|style"
    +"|title|width]"
});