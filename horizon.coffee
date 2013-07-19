# Horizon
# Ties scroll events conveniently

window.Horizon_VERBOSE = false

Math.clamp = (value, min, max) ->
	if min > value then min else if max < value then max else value

class window.HorizonHook
	constructor: (@min, @max, @lambda) ->
		# min is the minimum offset at which this hook begins.
		# max is the maximum offset at which this hook ends.
		@edges_state = 0 #-1 when minned, 1 when maxed, 0 when neither (hypothetically)
		@offset = 0

	repr: () ->
		"HorizonHook #{@min}-#(@max}, offset #{@offset} (#{@get_offset_frac()}/1), edges-state #{@edges_state}"

	invoke: () ->
		# Call the lambda.

		# TODO: Add more invocation code like maxing and minning.
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
	constructor: (@the_window = window, skip_bind = false) ->
		# if typeof @the_window is "function"
		@hooks = []
		@get_offset = () => jQuery(@the_window).scrollTop()

		if not skip_bind
			jQuery(the_window).scroll =>
				@refresh()

	register_hook: (hook) ->
		@hooks.push hook
		@init_hook hook

	init_hook: (hook) ->
		hook.invoke() if hook.should_fire(@get_offset(), true)
	
	new_hook: (min, max, lambda) ->
		@register_hook(new HorizonHook min, max, lambda)

	refresh: (offset = @get_offset()) ->
		hook.invoke() for hook in @hooks when hook.should_fire(offset)
