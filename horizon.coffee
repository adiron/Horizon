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
	constructor: (@window = window, skip_bind = false) ->
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
		@hooks.sort (a,b) -> b.min - a.min
  
	init_hook: (hook) ->
		hook.invoke() if hook.should_fire(@get_offset(), true)
		hook.initialized = true
	  
	new_hook: (min, max, lambda) ->
		@register_hook(new HorizonHook min, max, lambda)
  
	refresh: (offset = @get_offset()) ->
		@init_hook hook for hook in @hooks when not hook.initialized
		hook.invoke() for hook in @hooks when hook.should_fire(offset)

	prepare_hooks: () ->
		@init_hook hook for hook in @hooks when not hook.initialized

  
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
			parts = start.split(/^([+|-|\d|\.]+)([A-Za-z]+)/)
			if parts.length is 1
				# This means the user passed a number as a string.
				start = parseFloat(start)
			else
				scale = parts[2]
				start = parseFloat(parts[1])

			# Now the end bit.
			end_parts = end.split(/^([+|-|\d|\.]+)([A-Za-z]+)/)
			if end_parts.length is 1
				# This means the user passed a number as a string.
				end = parseFloat(end)
			else
				# Scale is implied. May not be the best strategy.
				end = parseFloat(end_parts[1])
			res = (start + ((end - start) * frac))
			res.toString() + scale
		when "color"
			if not Horizon.HSL_mode
				console.log "Interpolating color (#{start}->#{end})" if Horizon.VERBOSE
				start = utils.convert_to_rgba(start)
				end = utils.convert_to_rgba(end) 
				a= start.map (item, idx) ->
					utils.interpolate_css item, end[idx], frac
				console.log a
				console.log "Interpolating color (#{start}->#{end})" if Horizon.VERBOSE
				utils.rgba_to_css(start.map (item, idx) ->
					utils.interpolate_css item, end[idx], frac)
			else
				# HSL mode is on. We have to convert the values to HSL first.
				# TODO
				0
		when "int_value"
			start + ((end - start) * frac)
		
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
	if csscolor[0..3] is "rgb" then mode = "rgb"
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
			[r,g,b,a] # return array form
		when "rgb"
			# rgb() format
			parseInt color for color in csscolor.match /([0-9]+)/g

utils.rgba_to_css = (r,g,b,a = 1) ->
	if typeof r is "object"
		# at this point it is assumed that r is an array representing
		# rgba values respectively.
		console.log "Got an array! Relaunching."
		return utils.rgba_to_css.apply this, r
	console.log "got the following args: #{r}, #{g}, #{b}"	
	r = Math.round(r); g = Math.round(g); b = Math.round(b);
	if a is 1
		"rgb(#{r}, #{g}, #{b})"
	else "rgb(#{r}, #{g}, #{b}, #{a})"

		
	


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

window.Horizon.VERBOSE = false 
window.Horizon.HSL_mode = false
