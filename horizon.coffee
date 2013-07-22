window.Horizon_VERBOSE = false 
window.HorizonGenerator = {} # Hosts generator functions. 
utils = {} # Hosts various local utilities. 
  
Math.clamp = (value, min, max) ->
	# Fuck js.
	# Do you realize this is one single line?
	# One.
	if min > value then min else if max < value then max else value 
  
class window.HorizonHook 
	constructor: (@min, @max, @lambda) ->
		# min is the minimum offset at which this hook begins. 
		# max is the maximum offset at which this hook ends. 
		@edges_state = 0 #-1 when minned, 1 when maxed, 0 when neither (hypothetically) 
		@offset = 0
  
	repr: () ->
		"HorizonHook #{@min}-#{@max}, offset #{@offset} (#{@get_offset_frac()}/1), edges-state #{@edges_state}"
  
	invoke: () ->
		# Call the lambda regardless of whether it needs to or not.
		console.log "Invoking: #{@repr()}" if Horizon_VERBOSE 
		@lambda.call this, @get_offset_frac(), @offset
  
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
		console.log "Current offset: abs #{absolute_offset}, rel #{@offset}" if Horizon_VERBOSE 
  
		# If the offset is between the min 0 and max. 
		if 0 < @offset < @get_range() 
			@edges_state = 0
			console.log "Offset falls within boundaries." if Horizon_VERBOSE 
			return true 
  
		# We shouldn't run if the edge state doesn't say we should: 
		if (@edges_state == -1 and @offset == 0) or (@edges_state == 1 and @offset == @get_range())
			console.log "Should not run. Edge state: #{@edges_state}" if Horizon_VERBOSE 
			return false 
  
		if @offset == 0 # We're right at the beginning 
			if @edges_state == -1 # Minned already. 
				return false 
			else
				@edges_state = -1
				console.log "Minning." if Horizon_VERBOSE 
				return true 
		else if @offset == @get_range() # Max 
			if @edges_state == 1
				return false 
			else
				@edges_state = 1
				console.log "Maxing." if Horizon_VERBOSE 
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
			console.log "Got function for @window."
			@get_offset = () -> @window()
		else
			@get_offset = () => jQuery(@window).scrollTop()
			if not skip_bind 
				jQuery(@window).scroll =>
					@refresh()

  
	register_hook: (hook) ->
		@hooks.push hook 
		@init_hook hook if not hook.initialized 
  
	init_hook: (hook) ->
		hook.invoke() if hook.should_fire(@get_offset(), true)
	  
	new_hook: (min, max, lambda) ->
		@register_hook(new HorizonHook min, max, lambda)
  
	refresh: (offset = @get_offset()) ->
		hook.invoke() for hook in @hooks when hook.should_fire(offset)
  
utils.interpolate_css = (start, end, frac) ->
	#Interpolates between two CSS values. 
	if typeof start is "number"
		# It's now known to me that it's a number. In this case, simple interpolation 
		start + ((end - start) * frac)
	else if typeof start is "string"
		# Otherwise things could get complicated. 
		# TODO: THIS.
		0 
  
  
utils.lambda_for_css_property = (element, property, params) ->
	# retuns the lambda for property with params to be used in the hook.
	(offset_frac, offset_rel) ->
		if Horizon_VERBOSE 
			console.log "Changing CSS property #{property} to 
			#{utils.interpolate_css(params.start, params.end, offset_frac)}"
		element.css property, utils.interpolate_css(params.start, params.end, offset_frac)
  
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
	hook = new HorizonHook options.start, options.start + options.size, f 
	hook 
