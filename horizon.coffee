window.HorizonGenerator = {} # Hosts generator functions.
utils = {} # Hosts various local utilities. 
  
Math.clamp = (value, min, max) ->
	# Fuck js.
	# Do you realize this is one single line?
	# One.
	if min > value then min else if max < value then max else value 
  
class window.HorizonHook 
	constructor: (@min, @max, @lambda, @easing) ->
		# min is the minimum offset at which this hook begins. 
		# max is the maximum offset at which this hook ends. 
		@edges_state = 0 #-1 when minned, 1 when maxed, 0 when neither (hypothetically) 
		@offset = 0

		if @easing?
			if typeof @easing is "string"
				@easing = jQuery.easing[@easing]

	repr: () ->
		"HorizonHook #{@min}-#{@max}, offset #{@offset} (#{@get_offset_frac()}/1), edges-state #{@edges_state}"
  
	invoke: () ->
		# Call the lambda regardless of whether it needs to or not.
		console.log "Invoking: #{@repr()}" if Horizon.VERBOSE 
		# @lambda.call this, @get_offset_frac(), @offset
		if @easing?
			console.log "(Raw: #{@get_offset_frac()}, with easing: #{@easing(@get_offset_frac(), @offset, @min, @max, @get_range())})" if Horizon.VERBOSE
			@lambda.call this,
				@easing(@get_offset_frac(), @offset, @min, @max, @get_range()),
				@offset
		else
			@lambda.call this,
				@get_offset_frac()
				@offset

	get_range: () ->
		# Gets the total range of the hook. 
		@max - @min
  
	get_offset_pct: () ->
		(@get_offset_frac) * 100
  
	get_offset_frac: () ->
		@offset * 1.0 / (@max * 1.0 - @min)
  
	should_fire: (absolute_offset = @offset, force_fire = false) ->
		# Checks if the hook should fire at all. 
		@offset = Math.clamp(absolute_offset, @min, @max) - @min
		console.log "Current offset: abs #{absolute_offset}, rel #{@offset}" if Horizon.VERBOSE 
  
		# If the offset is between the min 0 and max. 
		if 0 < @offset < @get_range() 
			@edges_state = 0
			console.log "Offset falls within boundaries." if Horizon.VERBOSE 
			return true 
  
		# We shouldn't run if the edge state doesn't say we should: 
		if (@edges_state == -1 and @offset == 0) or (@edges_state == 1 and @offset == @get_range())
			console.log "Should not run. Edge state: #{@edges_state}" if Horizon.VERBOSE 
			return false
  
		if @offset == 0 # We're right at the beginning 
			if @edges_state == -1 # Minned already. 
				return false 
			else
				@edges_state = -1
				console.log "Minning." if Horizon.VERBOSE
				return true 
		else if @offset == @get_range() # Max 
			if @edges_state == 1
				return false 
			else
				@edges_state = 1
				console.log "Maxing." if Horizon.VERBOSE 
				return true 
		else
			@edges_state = 0
		  
		# If all else fails... 
		false 
	  
class window.Horizon 
	constructor: (@window, skip_bind = false) ->
		# Where window is either:
		# * the window DOM object; or
		# * a function which returns a number which will be used as an offset
		# if skip_bind is true, Horizon will not bind itself to window's
		# refresh function. This is useful in case the target object isn't
		# actually the window, but a smaller frame etc.
		@hooks = []
	
		if typeof @window is "function"
			console.log "Got function for @window." if Horizon.VERBOSE
			@get_offset = () -> @window()
		else
			@get_offset = () => jQuery(@window).scrollTop()
			if not skip_bind 
				jQuery(@window).scroll =>
					@refresh()
  
	register_hook: (hook) ->
		@hooks.push hook
  
	init_hook: (hook) ->
		hook.invoke() if hook.should_fire(@get_offset())
		hook.initialized = true
	  
	new_hook: (min, max, lambda) ->
		@register_hook(new HorizonHook min, max, lambda)
  
	refresh: (offset = @get_offset()) ->
		# TODO: sort out a bug where yanking all the way to the bottom
		# can cause hooks to not execute in the correct order.
		console.log "offset: #{offset}" if Horizon.VERBOSE
		# @init_hook hook for hook in @hooks when not hook.initialized
		# @prepare_hooks(offset)
		@sort_hooks offset
		hook.invoke() for hook in @hooks when hook.should_fire(offset)


	prepare_hooks: (offset = @get_offset()) ->
		# TODO: make this check if you need to actually load the hook
		# if there's any other hook that has already been initialized
		# that preceeds it.
		# This is to allow prepare_hooks to be run during runtime and
		# not just once at init.
		# @init_hook hook for hook in @hooks when not hook.initialized
		hook_list = @sort_hooks offset
		@init_hook hook for hook in hook_list when not hook.initialized

		console.log "Done preparing hooks." if Horizon.VERBOSE

	sort_hooks: (offset) ->
		hooks_before = (hook for hook in @hooks when hook.max < offset)
		hooks_before.sort (a, b) -> a.max - b.max

		hooks_after = (hook for hook in @hooks when (hook.min >= offset) and (hook not in hooks_before))
		hooks_after.sort (a, b) -> b.min - a.min


		hook_list = hooks_before.concat hooks_after
		console.log hook_list if Horizon.VERBOSE

		# return the sorted list
		hook_list

  
utils.interpolate_css = (start, end, frac) ->
	#Interpolates between two CSS values. 
	if typeof start is "string"
		start = start.toLowerCase()
		end = end.toLowerCase()
		if (start[0] is "#") or (start[0..2] is "rgb")
			mode = "color"
		else
			mode = "str_value"
	else
		mode = "int_value"

	switch mode
		when "str_value"
			# Parse scales and stuff.
			parts = start.split(/^([+-\d\.]+)([A-Za-z]+)/) #TODO: Decrypt this line, please
			if parts.length is 1
				# This means the user passed a number as a string.
				start = parseFloat(start)
			else
				# The user passed a number with a unit as a string: "1rem", "3pt", etc.
				scale = parts[2]
				start = parseFloat(parts[1])

			# Now the end bit.
			end_parts = end.split(/^([+|-|\d|\.]+)([A-Za-z]+)/)
			if end_parts.length is 1
				# This means the user passed a number as a string.
				end = parseFloat(end)
			else
				# Scale is implied. TODO: make this convert between different units
				end = parseFloat(end_parts[1])
			res = (start + ((end - start) * frac))
			res.toString() + scale
		when "color"
			if not Horizon.HSV_mode
				# Interpolate colours through RGB
				console.log "Interpolating color (#{start}->#{end})" if Horizon.VERBOSE

				# Parse start and end colours
				start = utils.convert_to_rgba(start)
				end = utils.convert_to_rgba(end) 

				# And interpolate each element (red, green, blue, alpha) separately
				curval = start.map (el, i) ->
					utils.interpolate_css el, end[i], frac

				console.log curval if Horizon.VERBOSE
				console.log "Interpolating color (#{start}->#{end})" if Horizon.VERBOSE
				
				# Return the result as a nice CSS colour string
				return utils.rgba_to_css curval
			else
				# HSV mode is on. We have to convert the values to HSV first.
				console.log "Interpolating color (#{start}->#{end}) via HSV" if Horizon.VERBOSE

				# Parse start and end colours
				start = utils.convert_to_hsva(start)
				end = utils.convert_to_hsva(end)

				# And interpolate each element (hue, chroma/saturation, value, alpha) separately
				curval = [(utils.interpolate_hue start[0], end[0], frac)].concat (start[1..].map (el, i) ->
					utils.interpolate_css el, end[i + 1], frac)

				console.log curval if Horizon.VERBOSE
				console.log "Interpolating color (#{start}->#{end}) via HSV" if Horizon.VERBOSE
				
				# Return the result as a nice CSS colour string
				return utils.hsva_to_css curval


		when "int_value"
			start + ((end - start) * frac)

utils.interpolate_hue = (start, end, frac) ->
	# Because degrees go in a circle, and circles are bitches who wrap around 360° back to 0°
	distance_neg = Math.abs end - start
	distance_pos = Math.abs (posend = (if end < frac then end + 360 else end - 360)) - start

	if distance_neg <= distance_pos
		utils.interpolate_css(start, end, frac)
	else
		utils.interpolate_css(start, end + posend, frac)
		
utils.lambda_for_css_property = (element, property, params) ->
	# retuns the lambda for property with params to be used in the hook.
	(offset_frac, offset_rel) ->
		if Horizon.VERBOSE 
			console.log "Changing CSS property #{property} to 
			#{utils.interpolate_css(params.start, params.end, offset_frac)}"
		element.css property, utils.interpolate_css(params.start, params.end, offset_frac)

utils.convert_to_rgba = (csscolor) ->
	# Converts a CSS color to an RGBA array
	csscolor = csscolor.toLowerCase()
	mode = "classic"
	if csscolor[0..2] is "rgb" then mode = "rgb"
	r=0
	g=0
	b=0
	a=1
	switch mode
		when "classic"
			# classic css
			if csscolor.length is 4
				# Shorthand format
				r = parseInt csscolor[1] + csscolor[1], 16
				g = parseInt csscolor[2] + csscolor[2], 16
				b = parseInt csscolor[3] + csscolor[3], 16
			else if csscolor.length is 7
				# long format
				r = parseInt csscolor[1..2], 16
				g = parseInt csscolor[3..4], 16
				b = parseInt csscolor[5..6], 16
		when "rgb"
			# rgb() format
			[r, g, b, atmp] = (parseInt color for color in csscolor.match /([0-9]+)/g)
			if atmp? then a = atmp
	[r, g, b, a]
			

utils.convert_to_hsva = (csscolor) ->
	# Converts a CSS colour to an HSVA array
	# Slight cheating/"reuse": We use convert_to_rgba, then work on the result

	color = utils.convert_to_rgba csscolor
	console.log "Colour #{csscolor} was converted into array: #{color}" if Horizon.VERBOSE
	color = (color[0..2].map (el, i) -> el / 255.0).concat color[3]
	console.log "And its array is now: #{color}" if Horizon.VERBOSE

	value = Math.max color[0..2]...
	chroma = value - (Math.min color[0..2]...)

	# Note that the +2 and +4 should both, technically, have %6 done on them (but it's redundant in those two cases)
	hue = 0
	if value == color[0]
		hue = (1.0 * (color[1] - color[2]) / chroma + 6) % 6
	else if value == color[1]
		hue = 1.0 * (color[2] - color[0]) / chroma + 2
	else if value == color[2]
		hue = 1.0 * (color[0] - color[1]) / chroma + 4
	hue *= 60

	saturation = if chroma == 0 then 0 else 1.0 * chroma / value

	return [hue, saturation, value, color[3]]

utils.rgba_to_css = (r,g,b,a = 1) ->
	if typeof r is "object"
		# at this point it is assumed that r is an array representing
		# rgba values respectively.
		console.log "Got an array! Relaunching." if Horizon.VERBOSE

		return utils.rgba_to_css r...
	console.log "got the following args: #{r}, #{g}, #{b}" if Horizon.VERBOSE
	
	"rgba(#{r}, #{g}, #{b}, #{a})"

utils.hsva_to_css = (h,s,v,a = 1) ->
	if typeof h is "object"
		# analogous to rgba_to_css
		console.log "Got an array! Relaunching." if Horizon.VERBOSE

		return utils.hsva_to_css h...

	console.log "hsv got the following args: #{h}, #{s}, #{v}" if Horizon.VERBOSE

	while h < 0
		h += 360 # JS modulus doesn't like negatives...

	chroma = s * v
	relhue = (h % 360) / 60.0
	x = chroma * (1 - Math.abs (relhue % 2 - 1))

	relcolor = [0, 0, 0]
	if 0 <= relhue < 1
		relcolor = [chroma, x, 0]
	else if 1 <= relhue < 2
		relcolor = [x, chroma, 0]
	else if 2 <= relhue < 3
		relcolor = [0, chroma, x]
	else if 3 <= relhue < 4
		relcolor = [0, x, chroma]
	else if 4 <= relhue < 5
		relcolor = [x, 0, chroma]
	else if 5 <= relhue < 6
		relcolor = [chroma, 0, x]
	
	color = (el + v - chroma for el in relcolor).concat(a)
	result = utils.rgba_to_css ((relcolor.map (el, i) -> (Math.floor ((el + v - chroma) * 255.0))).concat [a])
	console.log "Got #{result}" if Horizon.VERBOSE

	return result

window.HorizonGenerator.CSSHook = (selector, animation, options) ->
	# animation contains a list of properties and their animations. Example: 
	# animation =  
	#   top: 
	#       start: 0 
	#       end: 200 
	#   left: 
	#       start: "5%" 
	#       end: "0%" 
  
	# Possible options: 
	# size 
	# start (at what offset to start) 
	# easing (an easing function)  
  
	# If we got a string, make it into a jQuery. 
	selector = jQuery selector if typeof selector is "string"
  
	# List out all the lambdas that will need to run. 
	lambdas = (utils.lambda_for_css_property selector, property, val for property, val of animation)
	f = (offset_frac, offset_rel) ->
		l.call(this, offset_frac, offset_rel) for l in lambdas 
  
	# Now generate the function that will be used for the hooks 
	hook = new HorizonHook options.start, options.start + options.size, f, options.easing
	hook

window.HorizonGenerator.BinaryHook = (start, size, lambda_in, lambda_out) ->
	# For this I'll need to implement a few things for the lambda. Just a meta-state object thing.
	# I think I might as well just change everything. I'll see.
	f = (offset_frac, offset_rel) ->
		if offset_frac <= 0
			lambda_in offset_frac, offset_rel
		if offset_frac >= 1
			lambda_out offset_frac, offset_rel

	hook = new HorizonHook start, start+size, f
	hook

window.Horizon.VERBOSE = false
window.Horizon.HSV_mode = true
