
Layer = L.Class.extend

  includes: L.Mixin.Events

  initialize: (@options = {})->
    @sources = {}
    @sourceLayers = {}
    @sourceRequests = {}
    @disabledErrors = []

    for source in (@options.sources or [])
      @addSource(source)

  disableError: (error) ->
    if @disabledErrors.indexOf(error) < 0
      @disabledErrors.push(error)
      @update()

  enableError: (error) ->
    if (idx = @disabledErrors.indexOf(error)) >= 0
      @disabledErrors.splice(idx, 1)
      @update()

  addSource: (source) ->
    if @sources[source.url]
      @sources[source.url] = source
      @updateSource(source) if @map

      @fire('sourcechange', {source: source})
    else
      @sourceLayers[source.url] = new L.LayerGroup()
      @sources[source.url] = source

      if @sourceRequests[source.url]
        @sourceRequests[source.url].abort()
        delete @sourceRequests[source.url]

      if @map
        @map.addLayer(@sourceLayers[source.url])
        @updateSource(source)

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
      @updateSource(source)

  updateSource: (source) ->
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
      @map.removeLayer(layer)

      layer.clearLayers()
      layer.addLayer(@buildResult(source, res)) for res in data.results when @disabledErrors.indexOf(res.type) < 0

      @map.addLayer(layer)

  buildResult: (source, res) ->
    bounds = new L.LatLngBounds()
    resLayer = new L.GeoJSON(type: 'Feature', geometry: res.geometry)

    Layer.Utils.extendBounds(bounds, resLayer)

    center = bounds.getCenter()
    sw = bounds.getSouthWest()
    ne = bounds.getNorthEast()
    errorText = L.Util.template(res.text or source.types[res.type].text, res.params)

    popupText = "<div class=\"map-validation-error\">"

    popupText += "<p>#{errorText}</p>"

    popupText += "<p>"
    popupText += "<a href=\"http://localhost:8111/load_and_zoom?top=#{ne.lat}&bottom=#{sw.lat}&left=#{sw.lng}&right=#{ne.lng}\" target=\"josm\">Edit in JOSM</a><br />"
    popupText += "<a href=\"http://openstreetmap.org/edit?lat=#{center.lat}&lon=#{center.lng}&zoom=17\" target=\"_blank\">Edit in Potlatch</a><br />"
    popupText += "</p>"

    if res.objects
      popupText += "<p>Objects</p>"
      popupText += "<ul class=\"objects\">"
      for obj in res.objects
        popupText += "<li><a href=\"http://www.openstreetmap.org/browse/#{obj[0]}/#{obj[1]}\" target=\"_blank\">#{obj.join('-')}</a></li>"
      popupText += "</ul>"

    if res.params
      popupText += "<p>Params</p>"
      popupText += "<ul class=\"params\">"
      for key, value of res.params
        popupText += "<li>#{key}: #{value}</li>"
      popupText += "</ul>"

    popupText += "</div>"

    resLayer.bindPopup(popupText)
    resLayer

Layer.Utils =
  callbacks: {}
  callbackCounter: 0

  extendBounds: (bounds, l) ->
    if l.getBounds
      bounds.extend l.getBounds().getSouthWest()
      bounds.extend l.getBounds().getNorthEast()
    else if l.getLatLng
      bounds.extend l.getLatLng()
    else if l._iterateLayers
      l._iterateLayers (c) ->
        Layer.Utils.extendBounds(bounds, c)
    else
      console.log(["Can't determine layer bounds", l])

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
      el.parentNode.removeChild(el) if el.parentNode
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
