function showApparatus() {
	var args = Array.prototype.slice.call(arguments);
	var lemma = args.shift();
	var svgid = args.shift();
	var content = '<span class="apparatuslemma">' + lemma + '</span><br/>';
	jQuery.each( args, function( index, rdgset ) {
		var reading = rdgset[0];
		var witnesses = rdgset.slice(1);
		if( reading != lemma ) {
			content = content + '<span class="appreading">' + reading + '</span>&nbsp;';
			content = content + '<span class="appwitlist">' + witnesses.join(', ') + '</span><br/>';
		}
	});
	hideApparatus();
	$('#apparatusdisplay').append( content );
	$('#graphlink').click( function() {
		centerPopup('#variantgraph_popup');
		showPopup('#variantgraph_popup', function() { scrollGraph( svgid ) });
	});
	$('#stemmalink').click( function() {
		centerPopup('#stemma_popup');
		showPopup('#stemma_popup', function() { colorStemma( lemma, args ) });
	});
	$('#apparatusbox').show( 0, function () { alignFootnote( $(this) ) });
};

function alignFootnote( elobj ) {
	var thisHeight = elobj.height();
	elobj.css({'bottom': thisHeight });
};

function showNote( notetext ) {
	content = '<span class="notetext">' + notetext + '</span><br/>';
	$('#notedisplay').empty();
	$('#notedisplay').append( content );
	$('#notebox').show( 0, function () { alignFootnote( $(this) ) });
};

function hideApparatus() {
	$('#apparatusdisplay').empty();
	$('#apparatusbox').hide();	
	$('#notedisplay').empty();
	$('#notebox').hide();	
	$('.lemma').removeClass('selectedlemma');
};

function scrollGraph( scrollto_id ) {
	// scroll to given ID if asked
	if( scrollto_id != null ) {
		var nodePosition = $(scrollto_id).offset().left + parseFloat( $(scrollto_id + " ellipse").attr('rx') );
		// ...but we really want it centered
		var graphOffset = document.documentElement.clientWidth / 2;
		var leftPoint = nodePosition - graphOffset;
		$('#svgbox').stop().animate({
			scrollLeft: leftPoint
			}, 1000);
	}
};

function colorStemma( lemma, groups ) {
	// List of colors for different variants - how many do we have max?
	var colors = ['#afc6e9','#d5fff6','#ffccaa','#ffaaaa','#e5ff80','#e5d5ff','#ffd5e5'];
	// Make the index of color -> reading
	var colormap = {};
	colormap[lemma] = '#ffeeaa';

	// First color all nodes grey, then color variant nodes.
	var all_mss = $('#stemma_popup .node').children('title');
	color_greynodes( all_mss, function () {
		jQuery.each( groups, function( set_index, rdgset ) {
			var reading = rdgset.shift();
			if( reading != lemma ) {
				colormap[reading] = colors[set_index];
			}
			jQuery.each( rdgset, function(index,value) {
				all_mss.filter( function(index) {
					return $(this).text() == value;
				}).siblings('ellipse').each( function( index ) {
				$(this).siblings('text').each( function() {
					$(this).attr( {stroke:'none', fill:'black'} )});
				$(this).attr( {stroke:'black', fill:colormap[reading]} );
				});
      		});
      	});
	});
	
	// Now make the colorcode key.
	var colorkey = '';
	jQuery.each( colormap, function( reading, color ) {
		colorkey = colorkey + '<span class="colorpatch" style="padding-left: 15px; background-color:'
			+ color + '">&nbsp;</span>&nbsp;' + reading + '<br/>';
	});
	$('#stemma_colorkey').empty();
	$('#stemma_colorkey').append( colorkey );
};

function color_greynodes( group, callback_fn ) {
	group.siblings('ellipse, polygon, text').each( function( index ) {
        $(this).attr( {stroke:'#ddd', fill:'#f8f8f8'} );
      });
    callback_fn.call();
};

var popped = null;
function showPopup( elname, callback_fn ) {
	if( popped != elname ) {
		$('#backgroundPopup').css({ "opacity": "0.7" });
		$('#backgroundPopup').fadeIn("slow");
		$(elname).fadeIn("slow");
		popped = elname;
	}
	callback_fn.call();
};

function closePopup( elname ) {
	if( popped == elname ) {
		$('#backgroundPopup').fadeOut("slow");
		$(elname).fadeOut("slow");
		popped = null;
	}
};

function centerPopup( elname ) {
	var windowWidth = document.documentElement.clientWidth;  
	var windowHeight = document.documentElement.clientHeight;  
	var popupHeight = $(elname).height();  
	var popupWidth = $(elname).width();  
	//centering  
	$(elname).css({  
		"position": "absolute",  
		"top": windowHeight/2-popupHeight/2,  
		"left": windowWidth/2-popupWidth/2  
	});
	$("#backgroundPopup").css({
		"height": windowHeight
	});
};

$(document).ready( function() {
	hideApparatus();
	
	$("#vgpopup_close").click( function() {
		closePopup( '#variantgraph_popup' );
	});
	$("#sgpopup_close").click( function() {
		closePopup( '#stemma_popup' );
	});
	$(document).keypress( function(e) {
		if( e.keyCode == 27 && popped != null ) {
			closePopup( popped );
		}
	});
});