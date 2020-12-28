
#`function generateLabels(chart) {
#  var data = chart.data;
#  if (data.labels.length && data.datasets.length) {
#    return data.labels.map(function(label, i) {
#      var meta = chart.getDatasetMeta(0);
#      var style = meta.controller.getStyle(i);
#
#      // fetch the value
#      var value = chart.config.data.datasets[arc._datasetIndex].data[arc._index];
#
#      return {
#        // Add the numbers next to the label
#        text: label + ": " + value,
#        fillStyle: style.backgroundColor,
#        strokeStyle: style.borderColor,
#        lineWidth: style.borderWidth,
#        hidden: isNaN(data.datasets[0].data[i]) || meta.data[i].hidden,
#
#        // Extra data used for toggling the correct item
#        index: i
# 	    };
#    });
#  }
#  return [];
#}`

class Dashing.Chartjs extends Dashing.Widget

  constructor: ->
    super

    Chart.defaults.global.defaultColor = 'rgb(255, 255, 255)'
    Chart.defaults.global.defaultFontColor = 'rgb(255, 255, 255)'
    Chart.defaults.global.legend.labels.fontColor = 'rgb(255, 255, 255)'
    Chart.defaults.global.layout.padding = { left: 10, right: 10, top: 10, bottom: 10 }
    Chart.defaults.global.elements.point.radius = 5
    Chart.defaults.global.legend.display = false
    Chart.defaults.global.legend.position = 'bottom'

    Chart.defaults.doughnut.legend.position = 'right'
    Chart.defaults.doughnut.legend.display = true

    Chart.defaults.bar.barThickness = 'flex'
    #Chart.defaults.bar.legend.display = false
    Chart.defaults.bar.backgroundColor = 'rgb(255, 255, 255)'
    Chart.defaults.bar.scales.yAxes = [{
            ticks: {
                beginAtZero: true
            }
          }]

    # Override original legend label generator
    # https://github.com/chartjs/Chart.js/blob/master/src/controllers/controller.doughnut.js#L45
    # Chart.defaults.global.legend.labels.generateLabels = generateLabels

    @id = @get("id")
    @type = @get("type")
    @header = @get("header")
    @labels = @get("labels") && @get("labels").split(",")
    @options = @get("options") || {}

    if @type == "scatter"
      @datasets = @get("datasets")
    else
      @datasets = @get("datasets") && @get("datasets").split(",")

    @colorNames = @get("colornames") && @get("colornames").split(",")

  ready: ->
    # This is fired when the widget is done being rendered
    # @draw()

  onData: (data) ->
    @type = data.type || @type
    @header = data.header || @header
    @labels = data.labels || @labels
    @options = data.options || @options
    @datasets = data.datasets || @datasets
    @colorNames = data.colorNames || @colorNames

    @draw()

  draw: ->
    switch @type
      when "pie", "doughnut", "polarArea"
        @circularChart @id,
          type: @type,
          labels: @labels,
          colors: @colorNames,
          datasets: @datasets,
          options: @options

      when "line", "bar", "horizontalBar", "radar", "scatter"
        @linearChart @id,
          type: @type,
          header: @header,
          labels: @labels,
          colors: @colorNames,
          datasets: @datasets,
          options: @options

      else
        return

  circularChart: (id, { type, labels, colors, datasets, options }) ->
    @ensureChartExists()
    @chart.data = @merge labels: labels, datasets: [@merge data: datasets, @colors(colors)]
    @chart.update()

  linearChart: (id, { type, labels, header, colors, datasets, options }) ->
    @ensureChartExists()
    @chart.data = @merge labels: labels, datasets: [@merge(@colors(colors), label: header, data: datasets)]
    @chart.update()

  ensureChartExists: () ->
    if typeof @chart == "undefined"
      @chart = new Chart(document.getElementById(@id), { type: @type, data: @merge labels: @labels, datasets: [@merge data: @datasets, @colors(@colorNames)] }, @options)

  merge: (xs...) =>
    if xs?.length > 0
      @tap {}, (m) -> m[k] = v for k, v of x for x in xs

  tap: (o, fn) -> fn(o); o

  # Keep this in sync with application.scss
  #$background-color-green:        rgba(68, 187, 119, $background-color-transparent-factor);
  #$background-color-red:          rgba(255, 85, 102, $background-color-transparent-factor);
  #$background-color-yellow:       rgba(255, 170, 68, $background-color-transparent-factor);
  #$background-color-purple:       rgba(170, 68, 255, $background-color-transparent-factor);
  #$background-color-grey:         rgba(153, 153, 153, $background-color-transparent-factor);

  colorCode: ->
    aqua: "0, 255, 255"
    black: "0, 0, 0"
    blue: "151, 187, 205"
    cyan:  "0, 255, 255"
    darkgray: "77, 83, 96"
    fuschia: "255, 0, 255"
    gray: "153, 153, 153"
    green: "68, 187, 119"
    lightgray: "220, 220, 220"
    lime: "0, 255, 0"
    magenta: "255, 0, 255"
    maroon: "128, 0, 0"
    navy: "0, 0, 128"
    olive: "128, 128, 0"
    purple: "170, 68, 255"
    red: "255, 85, 102"
    silver: "192, 192, 192"
    teal: "0, 128, 128"
    white: "255, 255, 255"
    yellow: "255, 170, 68"

  colors: (colorNames) ->
    backgroundColor: colorNames.map (colorName) => @backgroundColor(colorName)
    borderColor: colorNames.map (colorName) => @borderColor(colorName)
    borderWidth: colorNames.map (colorName) -> 1
    pointBackgroundColor: colorNames.map (colorName) => @pointBackgroundColor(colorName)
    pointBorderColor: colorNames.map (colorName) => @pointBorderColor(colorName)
    pointHoverBackgroundColor: colorNames.map (colorName) => @pointHoverBackgroundColor(colorName)
    pointHoverBorderColor: colorNames.map (colorName) => @pointHoverBorderColor(colorName)

  backgroundColor: (colorName) -> "rgba(#{ @colorCode()[colorName] }, 0.8)"
  borderColor: (colorName) -> "rgba(#{ @colorCode()[colorName] }, 1)"
  pointBackgroundColor: (colorName) -> "rgba(#{ @colorCode()[colorName] }, 1)"
  pointBorderColor: (colorName) -> "rgba(#{ @colorCode()[colorName] }, 1)"
  pointHoverBackgroundColor: -> "#fff"
  pointHoverBorderColor: (colorName) -> "rgba(#{ @colorCode()[colorName] }, 0.8)"

  circleColor: (colorName) ->
    backgroundColor: "rgba(#{ @colorCode()[colorName] }, 0.2)"
    borderColor: "rgba(#{ @colorCode()[colorName] }, 1)"
    borderWidth: 1
    hoverBackgroundColor: "#fff"
    hoverBorderColor: "rgba(#{ @colorCode()['blue'] },0.8)"
