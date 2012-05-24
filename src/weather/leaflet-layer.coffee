Icon = L.Icon.extend

  options:
    popupAnchor: new L.Point(0, -25)

  initialize: (options) ->
    L.Util.setOptions(this, options)

  createIcon: ->
    div = document.createElement('div')
    div.className = 'leaflet-marker-icon weather-icon'
    div.style['margin-left'] = '-30px'
    div.style['margin-top'] = '-30px'
    div.style['width'] = '60px'
    div.style['height'] = '20px'
    div.style['padding'] = "#{@options.textOffset}px 0px 0px 0px"
    div.style['background'] = "url(#{@options.image}) no-repeat center top"
    div.style['text-align'] = 'center'

    span = document.createElement('span')
    span.innerHTML = @options.text

    div.appendChild(span)
    div

  createShadow: -> null

Layer = L.Class.extend

  defaultI18n:
    en:
      currentTemperature: "Temperature"
      maximumTemperature: "Max. temp"
      minimumTemperature: "Min. temp"
      humidity: "Humidity"
      wind: "Wind"
      show: "Snow"
      snow_possible: "Snow possible"
      rain: "Rain"
      rain_possible: "Rain possible"
      icerain: "Ice rain"
      rime: "Rime"
      rime_possible: "Rime"
      clear: "Clear"

    ru:
      currentTemperature: "Температура"
      maximumTemperature: "Макс. темп"
      minimumTemperature: "Мин. темп"
      humidity: "Влажность"
      wind: "Ветер"
      show: "Снег"
      snow_possible: "Возможен снег"
      rain: "Дождь"
      rain_possible: "Возможен дождь"
      icerain: "Ледяной дождь"
      rime: "Гололед"
      rime_possible: "Возможен гололед"
      clear: "Ясно"

  includes: L.Mixin.Events

  initialize: (@options = {})->
    @layer = new L.LayerGroup()
    @sourceUrl = "http://openweathermap.org/data/getrect?type={type}&lat1={minlat}&lat2={maxlat}&lng1={minlon}&lng2={maxlon}"
    @sourceRequests = {}

    @clusterWidth = @options.clusterWidth or 150
    @clusterHeight = @options.clusterHeight or 150

    @type = @options.type or 'city'
    @i18n = @options.i18n or @defaultI18n[@options.lang or 'en']
    @temperatureDigits = @options.temperatureDigits
    @temperatureDigits = 2 unless @temperatureDigits?

    Layer.Utils.checkSunCal()

  onAdd: (map) ->
    @map = map
    @map.addLayer(@layer)
    @map.on('moveend', @update, @)

    @update()

  onRemove: (map) ->
    return unless @map == map

    @map.off('moveend', @update, @)
    @map.removeLayer(@layer)
    @map = undefined

  getAttribution: ->
    'Weather data provided by <a href="http://openweathermap.org/">OpenWeatherMap</a>.'

  update: ->
    for url, req of @sourceRequests
      req.abort()

    @sourceRequests = {}

    @updateType @type

  updateType: (type) ->
    bounds = @map.getBounds()
    sw = bounds.getSouthWest()
    ne = bounds.getNorthEast()

    url = @sourceUrl
      .replace('{type}', type)
      .replace('{minlat}', sw.lat)
      .replace('{maxlat}', ne.lat)
      .replace('{minlon}', sw.lng)
      .replace('{maxlon}', ne.lng)

    @sourceRequests[type] = Layer.Utils.requestJsonp url, (data) =>
      delete @sourceRequests[type]

      @map.removeLayer(@layer)
      @layer.clearLayers()

      cells = {}

      for st in data.list
        ll = new L.LatLng(st.lat, st.lng)
        p = @map.latLngToLayerPoint(ll)
        key = "#{Math.round(p.x / @clusterWidth)}_#{Math.round(p.y / @clusterHeight)}"
        cells[key] = st if not cells[key] or parseInt(cells[key].rang) < parseInt(st.rang)

      for key, st of cells
        @layer.addLayer(@buildMarker(st, new L.LatLng(st.lat, st.lng)))

      @map.addLayer(@layer)

  buildMarker: (st, ll) ->
    weatherText = @weatherText(st)
    weatherIcon = @weatherIcon(st)

    popupContent = "<div class=\"weather-place\">"
    popupContent += "<img height=\"38\" width=\"45\" style=\"border: none; float: right;\" alt=\"#{weatherText}\" src=\"#{weatherIcon}\" />"
    popupContent += "<h3>#{st.name}</h3>"
    popupContent += "<p>#{weatherText}</p>"
    popupContent += "<p>"
    popupContent += "#{@i18n.currentTemperature}:&nbsp;#{@toCelc(st.temp)}&nbsp;°C<br />"
    popupContent += "#{@i18n.maximumTemperature}:&nbsp;#{@toCelc(st.temp_max)}&nbsp;°C<br />" if st.temp_max
    popupContent += "#{@i18n.minimumTemperature}:&nbsp;#{@toCelc(st.temp_min)}&nbsp;°C<br />" if st.temp_min
    popupContent += "#{@i18n.humidity}:&nbsp;#{st.humidity}<br />"
    popupContent += "#{@i18n.wind}:&nbsp;#{st.wind_ms}&nbsp;m/s<br />"
    popupContent += "</p>"
    popupContent += "</div>"

    typeIcon = @typeIcon(st)

    markerIcon = if typeIcon
      new Icon image: typeIcon, text: "#{@toCelc(st.temp)}&nbsp;°C", textOffset: 30
    else
      new Icon image: weatherIcon, text: "#{@toCelc(st.temp)}&nbsp;°C", textOffset: 45

    marker = new L.Marker ll, icon: markerIcon
    marker.bindPopup(popupContent)
    marker

  weatherIcon: (st) ->
    day = @dayTime(st)
    cl = st.cloud
    img = 'transparent'

    if cl < 25 and cl >= 0
      img = '01' + day
    if cl < 50 and cl >= 25
      img = '02' + day
    if cl < 75 and cl >= 50
      img = '03' + day
    if cl >= 75
      img = '04'

    if st.prsp_type == '1' and st.prcp > 0
      img = '13'

    if st.prsp_type == '4' and st.prcp > 0
      img = '09'

    for i in ['23','24','26','27','28','29','33','38','42']
      if st.prsp_type == i
        img = '09'

    "http://openweathermap.org/images/icons60/#{img}.png"

  typeIcon: (st) ->
    if st.datatype == 'station'
      if st.type == '1'
        "http://openweathermap.org/images/list-icon-3.png"
      else if st.type == '2'
        "http://openweathermap.org/images/list-icon-2.png"

  weatherText: (st) ->

    if st.prsp_type == '1'
      if  st.prcp!=0 and st.prcp > 0
        "#{@i18n.snow}&nbsp;(#{st.prcp}&nbsp;mm)"
      else
        @i18n.snow_possible
    else if st.prsp_type == '2'
      if  st.prcp!=0 and st.prcp > 0
        "#{@i18n.rime}&nbsp;(#{st.prcp}&nbsp;mm)"
      else
        @i18n.rime_possible
    else if st.prsp_type == '3'
      @i18n.icerain
    else if st.prsp_type == '4'
      if  st.prcp!=0 and st.prcp > 0
        "#{@i18n.rain}&nbsp;(#{st.prcp}&nbsp;mm)"
      else
        @i18n.rain_possible
    else
      @i18n.clear

  dayTime: (st) ->
    return 'd' unless SunCalc?

    dt = new Date()
    times = SunCalc.getTimes(dt, st.lat, st.lng)
    if dt > times.sunrise && dt < times.sunset
      'd'
    else
      'n'

  toCelc: (t) ->
    p = Math.pow(10, @temperatureDigits)
    Math.round((t - 273.15) * p) / p

Layer.Utils =
  callbacks: {}
  callbackCounter: 0

  checkSunCal: ->
    return if SunCalc?

    el = document.createElement('script')
    el.src = 'https://raw.github.com/mourner/suncalc/master/suncalc-min.js'
    el.type = 'text/javascript'
    document.getElementsByTagName('body')[0].appendChild(el)

  requestJsonp: (url, cb) ->
    el = document.createElement('script')
    counter = (@callbackCounter += 1)
    callback = "OsmJs.Weather.LeafletLayer.Utils.callbacks[#{counter}]"

    abort = ->
      el.parentNode.removeChild(el) if el.parentNode

    @callbacks[counter] = (data) =>
     # el.parentNode.removeChild(el) if el.parentNode
      delete @callbacks[counter]
      cb(data)

    delim = if url.indexOf('?') >= 0
      '&'
    else
      '?'

    el.src = "#{url}#{delim}callback=#{callback}"
    el.type = 'text/javascript'
    document.getElementsByTagName('body')[0].appendChild(el)

    {abort: abort}

@OsmJs = {} unless @OsmJs
@OsmJs.Weather = {} unless @OsmJs.Weather
@OsmJs.Weather.LeafletLayer = Layer
