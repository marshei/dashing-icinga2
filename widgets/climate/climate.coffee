class Dashing.Climate extends Dashing.Widget
  @accessor 'temperature', Dashing.AnimatedValue
  @accessor 'humidity', Dashing.AnimatedValue

  onData: (data) ->
    if data.status
      # clear existing "status-*" classes
      $(@get('node')).attr 'class', (i,c) ->
        c.replace /\bstatus-\S+/g, ''
      # add new class
      $(@get('node')).addClass "status-#{data.status}"
