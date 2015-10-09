/**
 * Handles files area code on the admin UI.
 */
var S_FILES = {
  status: function(file_id) {
		$('trash_'+file_id).hide();
		$('spin_'+file_id).show();
	},
	destroy: function(file_id) {
		new Effect.Fade($('file_'+file_id));
	},
	showUploadArea: function() {
		new Effect.Appear($('upload_container'));
		$('show_upload_button').hide();
		$('hide_upload_button').show();
	},
	hideUploadArea: function() {
		new Effect.Fade($('upload_container'));
		$('hide_upload_button').hide();
		$('show_upload_button').show();
	}
}
/**
 * Code for selecting image files from a subModal and inserting into
 * a TinyMCE editor.
 */
var S_FILE_SELECT = {
  selected: {},
	// Called when an image is clicked from our 'image_library' select window.
	// Shows select panel
	fillPanel: function(e) {
	  ss = S_FILE_SELECT.selected;
	  
	  ss['container'] = $(Event.element(event)).up('div.user_upload.select');
	  ss['image']     = ss['container'].down('div.image img');
	  ss['file_name'] = ss['container'].getAttribute("filename");
	  
	  $('insert_details_image').src = ss['container'].getAttribute('src_small');
	  console.log(ss['container'].getAttribute('src_small'));
	  $('insert_details_title').innerHTML = ss['file_name'];
	  
	  // Insert original image and get computed height / width
	  $('image_width').value = ss['container'].getAttribute('orig_width');
	  $('image_height').value = ss['container'].getAttribute('orig_height');

	  $('insert_details').show();
	  new Effect.Fade($('images'), {duration: 0.15});
	  window.setTimeout("$('image_width').focus();",151);
	},
	
	cancel: function() {
	  $('insert_details').hide();
	  new Effect.Appear($('images'), {duration: 0.15});
	},
	// Inserts code to TinyMCE editor and closes subModal.
	insertImage: function() {
	  var ed = window.top.gMceEditor;
	  var tinymce = window.top.tinymce;
	  
	  var f = $('insert_form');

    var image_src = S_FILE_SELECT.selected['container'].getAttribute('src_original'); 
	  var image_width = $F('image_width');
	  var image_height = $F('image_height');
	  var image_alt = $F('image_alt');
	  
	  var args = {};

  	tinymce.extend(args, {
			src: image_src,
			alt: image_alt,
			width: image_width + "px",
			height: image_height + "px",
			title: image_alt
			//id: nl.id.value,
		});

		el = ed.selection.getNode();

		if (el && el.nodeName == 'IMG') {
			ed.dom.setAttribs(el, args);
		} else {
			ed.execCommand('mceInsertContent', false, '<img id="__mce_tmp" />', {skip_undo : 1});
			ed.dom.setAttribs('__mce_tmp', args);
			ed.dom.setAttrib('__mce_tmp', 'id', '');
			ed.undoManager.add();
		}
	  window.top.SUBMODAL.hide();
	},
	// Initializes event handlers for clicking on images.
	init: function() {
	  var image_select_links = $$('.user_upload.select');
	  image_select_links.each(function(link){
	    Event.observe(link, 'click', S_FILE_SELECT.fillPanel);
	  });
	  // For tab switching
	  gPanes = new Array(
  	  'image_library', 
  	  'image_upload'
  	);
	}
}
var gPanes = null;
Event.observe(window, 'load', S_FILE_SELECT.init);