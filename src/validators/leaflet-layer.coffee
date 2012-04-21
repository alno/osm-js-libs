
Layer = L.Class.extend

  includes: L.Mixin.Events

  initialize: (@options = {})->
    @validators = {}
    @validatorLayers = {}
    @validatorRequests = {}

    if @options.validators
      for validator in @options.validators
        @addValidator(validator)

  addValidator: (validator) ->
    if @validators[validator.url]
      @validators[validator.url] = validator
      @updateValidator(validator) if @map

      @fire('validatorchange', {validator: validator})
    else
      @validatorLayers[validator.url] = new L.LayerGroup()
      @validators[validator.url] = validator

      if @validatorRequests[validator.url]
        @validatorRequests[validator.url].abort()
        delete @validatorRequests[validator.url]

      if @map
        @map.addLayer(@validatorLayers[validator.url])
        @updateValidator(validator)

      @fire('validatoradd', {validator: validator})

  removeValidator: (validator) ->
    if @validators[validator.url]
      @map.removeLayer(@validatorLayers[validator.url]) if @map

      delete @validatorLayers[validator.url]
      delete @validators[validator.url]

      if @validatorRequests[validator.url]
        @validatorRequests[validator.url].abort()
        delete @validatorRequests[validator.url]

      @fire('validatorremove', {validator: validator})

  onAdd: (map) ->
    @map = map

    for key, layer of @validatorLayers
      map.addLayer(layer)

    map.on('moveend', @update, @)

    @update()

  onRemove: (map) ->
    map.off('moveend', @update, @)

    for key, layer of @validatorLayers
      map.removeLayer(layer)

    @map = undefined

  update: ->
    for url, req of @validatorRequests
      req.abort()

    @validatorRequests = {}

    for url, validator of @validators
      @updateValidator(validator)

  updateValidator: (validator) ->
    bounds = @map.getBounds()
    sw = bounds.getSouthWest()
    ne = bounds.getNorthEast()

    url = validator.url
      .replace('{minlat}', sw.lat)
      .replace('{maxlat}', ne.lat)
      .replace('{minlon}', sw.lng)
      .replace('{maxlon}', ne.lng)

    @validatorRequests[validator.url] = Layer.Utils.request url, validator, (data) =>
      delete @validatorRequests[validator.url]

      layer = @validatorLayers[validator.url]
      map.removeLayer(layer)
      layer.clearLayers()

      for res in data.results
        layer.addLayer(@buildResult(validator, res))

      map.addLayer(layer)

  buildResult: (validator, res) ->
    bounds = new L.LatLngBounds()
    resLayer = new L.GeoJSON(type: 'Feature', geometry: res.geometry)
    resLayer._iterateLayers(((l) -> bounds.extend(if l instanceof L.Marker then l.getLatLng() else l.getBounds())), resLayer)

    center = bounds.getCenter()
    sw = bounds.getSouthWest()
    ne = bounds.getNorthEast()
    errorText = res.text or validator.types[res.type].text

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

  request: (url, validator, cb) ->
    if validator.jsonp
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
