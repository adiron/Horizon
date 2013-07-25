// Generated by CoffeeScript 1.6.3
(function() {
  var utils;

  window.Horizon_VERBOSE = false;

  window.HorizonGenerator = {};

  utils = {};

  Math.clamp = function(value, min, max) {
    if (min > value) {
      return min;
    } else if (max < value) {
      return max;
    } else {
      return value;
    }
  };

  window.HorizonHook = (function() {
    function HorizonHook(min, max, lambda, easing) {
      this.min = min;
      this.max = max;
      this.lambda = lambda;
      this.easing = easing;
      this.edges_state = 0;
      this.offset = 0;
      if (this.easing != null) {
        if (typeof this.easing === "string") {
          this.easing = jQuery.easing[this.easing];
        }
      }
    }

    HorizonHook.prototype.repr = function() {
      return "HorizonHook " + this.min + "-" + this.max + ", offset " + this.offset + " (" + (this.get_offset_frac()) + "/1), edges-state " + this.edges_state;
    };

    HorizonHook.prototype.invoke = function() {
      if (Horizon_VERBOSE) {
        console.log("Invoking: " + (this.repr()));
      }
      if (this.easing != null) {
        if (Horizon_VERBOSE) {
          console.log("(Raw: " + (this.get_offset_frac()) + ", with easing: " + (this.easing(this.get_offset_frac(), this.offset, this.min, this.max, this.get_range())) + ")");
        }
        return this.lambda.call(this, this.easing(this.get_offset_frac(), this.offset, this.min, this.max, this.get_range()), this.offset);
      } else {
        return this.lambda.call(this, this.get_offset_frac(), this.offset);
      }
    };

    HorizonHook.prototype.get_range = function() {
      return this.max - this.min;
    };

    HorizonHook.prototype.get_offset_pct = function() {
      return this.get_offset_frac * 100;
    };

    HorizonHook.prototype.get_offset_frac = function() {
      return this.offset * 1.0 / (this.max * 1.0 - this.min);
    };

    HorizonHook.prototype.should_fire = function(absolute_offset, force_fire) {
      var _ref;
      if (absolute_offset == null) {
        absolute_offset = this.offset;
      }
      if (force_fire == null) {
        force_fire = false;
      }
      this.offset = Math.clamp(absolute_offset, this.min, this.max) - this.min;
      if (Horizon_VERBOSE) {
        console.log("Current offset: abs " + absolute_offset + ", rel " + this.offset);
      }
      if ((0 < (_ref = this.offset) && _ref < this.get_range())) {
        this.edges_state = 0;
        if (Horizon_VERBOSE) {
          console.log("Offset falls within boundaries.");
        }
        return true;
      }
      if ((this.edges_state === -1 && this.offset === 0) || (this.edges_state === 1 && this.offset === this.get_range())) {
        if (Horizon_VERBOSE) {
          console.log("Should not run. Edge state: " + this.edges_state);
        }
        return false;
      }
      if (this.offset === 0) {
        if (this.edges_state === -1) {
          return false;
        } else {
          this.edges_state = -1;
          if (Horizon_VERBOSE) {
            console.log("Minning.");
          }
          return true;
        }
      } else if (this.offset === this.get_range()) {
        if (this.edges_state === 1) {
          return false;
        } else {
          this.edges_state = 1;
          if (Horizon_VERBOSE) {
            console.log("Maxing.");
          }
          return true;
        }
      } else {
        this.edges_state = 0;
      }
      return false;
    };

    return HorizonHook;

  })();

  window.Horizon = (function() {
    function Horizon(window, skip_bind) {
      var _this = this;
      this.window = window != null ? window : window;
      if (skip_bind == null) {
        skip_bind = false;
      }
      this.hooks = [];
      if (typeof this.window === "function") {
        if (Horizon_VERBOSE) {
          console.log("Got function for @window.");
        }
        this.get_offset = function() {
          return this.window();
        };
      } else {
        this.get_offset = function() {
          return jQuery(_this.window).scrollTop();
        };
        if (!skip_bind) {
          jQuery(this.window).scroll(function() {
            return _this.refresh();
          });
        }
      }
    }

    Horizon.prototype.register_hook = function(hook) {
      this.hooks.push(hook);
      if (!hook.initialized) {
        return this.init_hook(hook);
      }
    };

    Horizon.prototype.init_hook = function(hook) {
      if (hook.should_fire(this.get_offset(), true)) {
        return hook.invoke();
      }
    };

    Horizon.prototype.new_hook = function(min, max, lambda) {
      return this.register_hook(new HorizonHook(min, max, lambda));
    };

    Horizon.prototype.refresh = function(offset) {
      var hook, _i, _len, _ref, _results;
      if (offset == null) {
        offset = this.get_offset();
      }
      _ref = this.hooks;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        hook = _ref[_i];
        if (hook.should_fire(offset)) {
          _results.push(hook.invoke());
        }
      }
      return _results;
    };

    return Horizon;

  })();

  utils.interpolate_css = function(start, end, frac) {
    var end_parts, parts, res, scale;
    if (typeof start === "string") {
      parts = start.split(/^([+|-|\d|\.]+)([A-Za-z]+)/);
      if (parts.length === 1) {
        start = parseFloat(start);
      } else {
        scale = parts[2];
        start = parseFloat(parts[1]);
      }
      end_parts = end.split(/^([+|-|\d|\.]+)([A-Za-z]+)/);
      if (end_parts.length === 1) {
        end = parseFloat(end);
      } else {
        end = parseFloat(end_parts[1]);
      }
    }
    if (scale == null) {
      return start + ((end - start) * frac);
    } else {
      res = start + ((end - start) * frac);
      return res.toString() + scale;
    }
  };

  utils.lambda_for_css_property = function(element, property, params) {
    return function(offset_frac, offset_rel) {
      if (Horizon_VERBOSE) {
        console.log("Changing CSS property " + property + " to 			" + (utils.interpolate_css(params.start, params.end, offset_frac)));
      }
      return element.css(property, utils.interpolate_css(params.start, params.end, offset_frac));
    };
  };

  window.HorizonGenerator.CSSHook = function(selector, animation, options) {
    var f, hook, lambdas, property, val;
    if (typeof selector === "string") {
      selector = jQuery(selector);
    }
    lambdas = (function() {
      var _results;
      _results = [];
      for (property in animation) {
        val = animation[property];
        _results.push(utils.lambda_for_css_property(selector, property, val));
      }
      return _results;
    })();
    f = function(offset_frac, offset_rel) {
      var l, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = lambdas.length; _i < _len; _i++) {
        l = lambdas[_i];
        _results.push(l.call(this, offset_frac, offset_rel));
      }
      return _results;
    };
    hook = new HorizonHook(options.start, options.start + options.size, f, options.easing);
    return hook;
  };

}).call(this);
