function showApparatus() {
	var args = Array.prototype.slice.call(arguments);
	var lemma = args.shift();
	var content = '<span class="apparatuslemma">' + lemma + '</span><br/>';
	jQuery.each( args, function( index, rdgset ) {
		content = content + '<span class="appreading">' + rdgset.shift() + '</span>&nbsp;';
		content = content + '<span class="appwitlist">' + rdgset.join(', ') + '</span><br/>';
	});
	hideApparatus();
	$('#apparatusdisplay').append( content );
	$('#apparatusdisplay').click( function() { hideApparatus() });
	$('#apparatusdisplay').show();
};

function showNote( notetext ) {
	content = '<span class="notetext">' + notetext + '</span><br/>';
	$('#notedisplay').empty();
	$('#notedisplay').append( content );
	$('#notedisplay').click( function() { hideApparatus() });
	$('#notedisplay').show();
};

function hideApparatus() {
	$('#apparatusdisplay').empty();
	$('#apparatusdisplay').hide();	
	$('#notedisplay').empty();
	$('#notedisplay').hide();	
	$('.lemma').removeClass('selectedlemma');
};

$(document).ready( function() {
	hideApparatus();
});