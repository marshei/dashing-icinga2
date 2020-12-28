class Dashing.Datatransfer extends Dashing.Widget
  @accessor 'downstream', Dashing.AnimatedValue
  @accessor 'upstream', Dashing.AnimatedValue

  @accessor 'downarrow', ->
    if @get('downstream')
      'fa fa-arrow-down'

  @accessor 'uparrow', ->
    if @get('upstream')
      'fa fa-arrow-up'

  onData: (data) ->
    if data.status
      # clear existing "status-*" classes
      $(@get('node')).attr 'class', (i,c) ->
        c.replace /\bstatus-\S+/g, ''
      # add new class
      $(@get('node')).addClass "status-#{data.status}"
