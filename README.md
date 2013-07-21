Horizon
=======

A library to control scrolling animations.

It depends on jQuery which you're probably using anyway. At this point, it does not plug into it, but it's planned. I guess.

Basic use
-----

	// Initialize it:
	c = new Horizon(window)

	// Use this method. It generates a new hook based on your input and then registers it.
	// (just so you don't have to do it yourself.)
	c.new_hook(600, 600+255, function(offset_frac, offset) {
		$("#explain1").css({"opacity": 1 - offset_frac})
	})

Method documentation
-----

None so far. I'll get back to this later. I promise.
