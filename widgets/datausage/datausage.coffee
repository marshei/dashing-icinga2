class Dashing.Datausage extends Dashing.Widget
  @accessor 'downstream', Dashing.AnimatedValue
  @accessor 'upstream', Dashing.AnimatedValue

  @accessor 'total-arrow-down', ->
    if @get('totaldown')
      'fa fa-arrow-down'

  @accessor 'total-arrow-up', ->
    if @get('totalup')
      'fa fa-arrow-up'

  onData: (data) ->
    if data.status
      # clear existing "status-*" classes
      $(@get('node')).attr 'class', (i,c) ->
        c.replace /\bstatus-\S+/g, ''
      # add new class
      $(@get('node')).addClass "status-#{data.status}"
