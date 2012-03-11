function showApparatus() {
	var args = Array.prototype.slice.call(arguments);
	var lemma = args.shift();
	var svgid = args.shift();
	var content = '<span class="apparatuslemma">' + lemma + '</span><br/>';
	jQuery.each( args, function( index, rdgset ) {
		content = content + '<span class="appreading">' + rdgset.shift() + '</span>&nbsp;';
		content = content + '<span class="appwitlist">' + rdgset.join(', ') + '</span><br/>';
	});
	hideApparatus();
	$('#apparatusdisplay').append( content );
	$('#graphlink').click( function() {
		centerPopup('#variantgraph_popup');
		showPopup('#variantgraph_popup', svgid );
	});
	$('#apparatusbox').show();
};

function showNote( notetext ) {
	content = '<span class="notetext">' + notetext + '</span><br/>';
	$('#notedisplay').empty();
	$('#notedisplay').append( content );
	$('#notebox').show();
};

function hideApparatus() {
	$('#apparatusdisplay').empty();
	$('#apparatusbox').hide();	
	$('#notedisplay').empty();
	$('#notebox').hide();	
	$('.lemma').removeClass('selectedlemma');
};

var popped = null;
function showPopup( elname, scrollto_id ) {
	if( popped != elname ) {
		$('#backgroundPopup').css({ "opacity": "0.7" });
		$('#backgroundPopup').fadeIn("slow");
		$(elname).fadeIn("slow");
		popped = elname;
	}
	if( elname == '#variantgraph_popup' ) {
		scrollGraph( scrollto_id );
	}
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
	$(document).keypress( function(e) {
		if( e.keyCode == 27 && popped != null ) {
			closePopup( popped );
		}
	});
});