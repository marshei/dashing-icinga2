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

    date = new Date().toLocaleDateString(locale, optionsDate);
    time = new Date().toLocaleTimeString(locale, optionsTime);

    @set('time', time)
    @set('date', date)
    @set('title', @get('title'))
