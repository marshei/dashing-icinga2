class Dashing.Dnsstats extends Dashing.Widget
  @accessor 'queriesToday', Dashing.AnimatedValue
  @accessor 'blockedToday', Dashing.AnimatedValue

  @accessor 'blockedClass', ->
    if @get('enabled') then 'blocked' else 'blocked-disabled'

  onData: (data) ->
    if data.status
      # clear existing "status-*" classes
      $(@get('node')).attr 'class', (i,c) ->
        c.replace /\bstatus-\S+/g, ''
      # add new class
      $(@get('node')).addClass "status-#{data.status}"
