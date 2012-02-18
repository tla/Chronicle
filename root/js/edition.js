function showApparatus() {
	var args = Array.prototype.slice.call(arguments);
	var lemma = args.shift();
	var content = '<span class="apparatuslemma">' + lemma + '</span><br/>';
	jQuery.each( args, function( index, rdgset ) {
		content = content + '<span class="appreading">' + rdgset.shift() + '</span>&nbsp;';
		content = content + '<span class="appwitlist">' + rdgset.join(', ') + '</span><br/>';
	});
	$('#apparatusdisplay').empty();
	$('#apparatusdisplay').append( content );
	$('#apparatusdisplay').show();
};

function showNote( lemma, notetext ) {
	var content = '<span class="notelemma">' + lemma + '</span> ] ';
	content = content + '<span class="notetext">' + notetext + '</span><br/>';
	$('#notedisplay').empty();
	$('#notedisplay').append( content );
	$('#notedisplay').show();
};

function hideApparatus() {
	$('#apparatusdisplay').empty();
	$('#apparatusdisplay').hide();	
};
function hideNote() {
	$('#notedisplay').empty();
	$('#notedisplay').hide();	
};

$(document).ready( function() {
	hideApparatus();
	hideNote();
});