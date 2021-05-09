class Dashing.Tacticalmeter extends Dashing.Widget

  @accessor 'value_ok', Dashing.AnimatedValue
  @accessor 'value_warning', Dashing.AnimatedValue
  @accessor 'value_critical', Dashing.AnimatedValue
  @accessor 'value_unknown', Dashing.AnimatedValue

  constructor: ->
    super
    @observe 'value_ok', (value) ->
      $(@node).find(".tactical-meter-ok").val(value).trigger('change')

    @observe 'value_warning', (value) ->
      $(@node).find(".tactical-meter-warning").val(value).trigger('change')

    @observe 'value_critical', (value) ->
      $(@node).find(".tactical-meter-critical").val(value).trigger('change')

    @observe 'value_unknown', (value) ->
      $(@node).find(".tactical-meter-unknown").val(value).trigger('change')

    @observe 'max', (max) ->
      $(@node).find(".tactical-meter-ok").trigger('configure', {'max': max})
      $(@node).find(".tactical-meter-warning").trigger('configure', {'max': max})
      $(@node).find(".tactical-meter-critical").trigger('configure', {'max': max})
      $(@node).find(".tactical-meter-unknown").trigger('configure', {'max': max})

  ready: ->
    meter_ok = $(@node).find(".tactical-meter-ok")
    meter_ok.attr("data-bgcolor", meter_ok.css("background-color"))
    meter_ok.attr("data-fgcolor", meter_ok.css("color"))
    meter_ok.knob()

    meter_warning = $(@node).find(".tactical-meter-warning")
    meter_warning.attr("data-bgcolor", meter_warning.css("background-color"))
    meter_warning.attr("data-fgcolor", meter_warning.css("color"))
    meter_warning.knob()

    meter_critical = $(@node).find(".tactical-meter-critical")
    meter_critical.attr("data-bgcolor", meter_critical.css("background-color"))
    meter_critical.attr("data-fgcolor", meter_critical.css("color"))
    meter_critical.knob()

    meter_unknown = $(@node).find(".tactical-meter-unknown")
    meter_unknown.attr("data-bgcolor", meter_unknown.css("background-color"))
    meter_unknown.attr("data-fgcolor", meter_unknown.css("color"))
    meter_unknown.knob()
