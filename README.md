Horizon
=======

A library to control scrolling animations. Those neat little things that change as you scroll the page. In addition, this library will also handle various events related to scrolling, which can be used to detach/reattach top menus, trigger functions when the page reaches certain points and so forth.

This library depends on jQuery which you're probably using anyway. At this point, it does not plug into it, but it's planned.

## Basic usage

The most simple use case:

	// Initialize it:
	c = new Horizon(window)

	// Use this method. It generates a new hook based on your input and then registers it.
	// (just so you don't have to do it yourself.)
	c.new_hook(600, 600+255, function(offset_frac, offset) {
		$("#somebox").css({"opacity": 1 - offset_frac})
	})
	
or alternatively:

	c.register_hook(
		HorizonGenerator.CSSHook("#somebox",
								 {"opacity": {"start": 1, "end": 0}}, // parameters to animate
								 {"start": 600, "size": 255} // options
								 )
	)

Then after you're done:

	c.prepare_hooks()

And that's that! Just make sure to call `prepare_hooks` each time you add new hooks.

## Code documentation

### *HorizonHook* Class

	constructor: (min, max, lambda, easing)

`min` refers to the beginning of the scrolling hook.

`max` is the end of it. The range of the hook is essentially `max - min`.

`lambda` is the function which will be called for every time Horizon sees fit to refresh it.

`easing` is the easing function to be used. Takes either a function or a string, where the string a reference to a member of `jQuery.easing`.

	repr: ()

Returns a human-readable string representation of the hook. (For debugging purposes)

	invoke: ()

**This function should not be called manually.** This method is called whenever the lambda needs to be called. It does NOT check whether it SHOULD run in fact and does not update the offset either.

	get_range: ()

Returns the total range covered by the hook.

	get_offset_pct: () ->
	get_offset_frac: () ->

Returns the current offset in percents or a fraction respectively.

	should_fire: (absolute_offset = @offset, force_fire = false) ->

Checks whether the hook should fire **but does not invoke it**, where `absolute_offset` is equal to the absolute offset of the window (by default, or whatever you bound it to).


#### Lambda

The lambda referenced in `HorizonHook` and other places is a function which should contain animation code. It takes two arguments:

	function (frac_offset, relative_offset)

`frac_offset` is what fraction of the animation we are in. This is useful, because you can (most of the time?) just have it perform animation code and use it as a multiplier:

	something.css({"width" : 200 + (300 * frac_offset)})

`relative_offset` is more situational and generally speaking optional, since the function would work just as well had it been written this way:

	function (frac_offset)

##### A note about easing

If you write your own lambda (which is not optimal, but you might), you don't need to do the easing yourself in the lambda. For greater code portability, just don't.

Easing is defined per hook, and the values your lambda will get will already have been put through the easing function of your choice.

### `HorizonGenerator` object

This object contains a bunch of generators of hooks. Note that they generate hooks that you later have to register yourself.

#### `CSSHook` 

	HorizonGenerator.CSSHook = (selector, animation, options) ->

Animate between two ends of a CSS property (defined in `animation`) over time defined in `options` for `selector`.

#### `BinaryHook`

	HorizonGenerator.BinaryHook = (start, size, lambda_in, lambda_out) ->

A hook that does something when entered, and does something when left, as specified by `lambda_in` and `lambda_out`, respectively. `start` and `size` deine the timeframe for the hook to be `lambda_in`ned.