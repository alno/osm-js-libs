
Layer = L.Class.extend

  includes: L.Mixin.Events

  initialize: (@options = {})->
    @sources = {}
    @sourceLayers = {}
    @sourceRequests = {}

    for source in (@options.sources or [])
      @addSource(source)

  addSource: (source) ->
    if @sources[source.url]
      @sources[source.url] = source
      @updateValidator(source) if @map

      @fire('sourcechange', {source: source})
    else
      @sourceLayers[source.url] = new L.LayerGroup()
      @sources[source.url] = source

      if @sourceRequests[source.url]
        @sourceRequests[source.url].abort()
        delete @sourceRequests[source.url]

      if @map
        @map.addLayer(@sourceLayers[source.url])
        @updateValidator(source)

      @fire('sourceadd', {source: source})

  removeSource: (source) ->
    if @sources[source.url]
      @map.removeLayer(@sourceLayers[source.url]) if @map

      delete @sourceLayers[source.url]
      delete @sources[source.url]

      if @sourceRequests[source.url]
        @sourceRequests[source.url].abort()
        delete @sourceRequests[source.url]

      @fire('sourceremove', {source: source})

  onAdd: (map) ->
    @map = map

    for key, layer of @sourceLayers
      map.addLayer(layer)

    map.on('moveend', @update, @)

    @update()

  onRemove: (map) ->
    map.off('moveend', @update, @)

    for key, layer of @sourceLayers
      map.removeLayer(layer)

    @map = undefined

  update: ->
    for url, req of @sourceRequests
      req.abort()

    @sourceRequests = {}

    for url, source of @sources
      @updateValidator(source)

  updateValidator: (source) ->
    bounds = @map.getBounds()
    sw = bounds.getSouthWest()
    ne = bounds.getNorthEast()

    url = source.url
      .replace('{minlat}', sw.lat)
      .replace('{maxlat}', ne.lat)
      .replace('{minlon}', sw.lng)
      .replace('{maxlon}', ne.lng)

    @sourceRequests[source.url] = Layer.Utils.request url, source, (data) =>
      delete @sourceRequests[source.url]

      layer = @sourceLayers[source.url]
      map.removeLayer(layer)

      layer.clearLayers()
      layer.addLayer(@buildResult(source, res)) for res in data.results

      map.addLayer(layer)

  buildResult: (source, res) ->
    bounds = new L.LatLngBounds()
    resLayer = new L.GeoJSON(type: 'Feature', geometry: res.geometry)
    resLayer._iterateLayers(((l) -> bounds.extend(if l instanceof L.Marker then l.getLatLng() else l.getBounds())), resLayer)

    center = bounds.getCenter()
    sw = bounds.getSouthWest()
    ne = bounds.getNorthEast()
    errorText = res.text or source.types[res.type].text

    popupText = "<p>#{errorText}</p>"

    if res.objects
      popupText += "<ul>"
      for obj in res.objects
        popupText += "<li><a href=\"http://www.openstreetmap.org/browse/#{obj[0]}/#{obj[1]}\" target=\"_blank\">#{obj.join('-')}</a></li>"
      popupText += "</ul>"

    popupText += "<p>"
    popupText += "<a href=\"http://localhost:8111/load_and_zoom?top=#{ne.lat}&bottom=#{sw.lat}&left=#{sw.lng}&right=#{ne.lng}\" target=\"josm\">Edit in JOSM</a><br />"
    popupText += "<a href=\"http://openstreetmap.org/edit?lat=#{center.lat}&lon=#{center.lng}&zoom=17\" target=\"_blank\">Edit in Potlatch</a><br />"
    popupText += "</p>"

    resLayer.bindPopup(popupText)
    resLayer

Layer.Utils =
  callbacks: {}
  callbackCounter: 0

  request: (url, source, cb) ->
    if source.jsonp
      @requestJsonp url, cb
    else
      @requestXhr url, cb

  requestXhr: (url, cb) ->
    xhr = new XMLHttpRequest()
    xhr.open 'GET', url, true
    xhr.onreadystatechange = ->
      if xhr.readyState == 4
        if xhr.status == 200
          cb(eval("(#{xhr.responseText})"))

    xhr.send()
    xhr

  requestJsonp: (url, cb) ->
    el = document.createElement('script')
    counter = (@callbackCounter += 1)
    callback = "OsmJs.Validators.LeafletLayer.Utils.callbacks[#{counter}]"

    abort = ->
      el.parentNode.removeChild(el) if el.parentNode

    @callbacks[counter] = (data) =>
      document.getElementsByTagName('body')[0].removeChild(el)
      delete @callbacks[counter]
      cb(data)

    delim = if url.indexOf('?') >= 0
      '&'
    else
      '?'

    el.src = "#{url}#{delim}callback=#{callback}"
    document.getElementsByTagName('body')[0].appendChild(el)

    {abort: abort}

@OsmJs = {} unless @OsmJs
@OsmJs.Validators = {} unless @OsmJs.Validators
@OsmJs.Validators.LeafletLayer = Layer
