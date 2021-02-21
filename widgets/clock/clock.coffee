class Dashing.Clock extends Dashing.Widget

  ready: ->
    setInterval(@startTime, 500)

  startTime: =>
    zone = @get('timezone')
    locale = @get('locale')
    optionsDate = {
      timeZone: zone,
      weekday: 'short',
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    };
    optionsTime = {
      timeZone: zone,
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    };

    d = new Date()
    date = d.toLocaleDateString(locale, optionsDate)
    time = d.toLocaleTimeString(locale, optionsTime)

    @set('time', time)
    @set('date', date)
    @set('weekday', d.toLocaleDateString(locale, { timeZone: zone, weekday: 'short' }))
    @set('shortdate', d.toLocaleDateString(locale, { timeZone: zone, day: 'numeric', month: 'numeric' }))
    @set('title', @get('title'))
