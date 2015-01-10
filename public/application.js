$('li>a').click( function(event) { 

	var target = $( event.target );
	
	$(this).parent().parents().each(function() {
		
		// Remove the active tag for each child
		$(this).children().each(function() {
			$(this).removeClass("active");
		});
	});

	target.parent().addClass("active");
} );

$(document).ready(function(){

	console.log("Loaded app");

	// TODO: Set the currently active tab when we load the page

});