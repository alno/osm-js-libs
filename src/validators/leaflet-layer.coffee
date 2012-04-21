
Layer = L.Class.extend

  includes: L.Mixin.Events

  initialize: (@options = {})->
    @layers = {}
    @validators = {}
    @limitedUpdate = L.Util.limitExecByInterval(@update, 3000, @)

    if @options.validators
      for validator in @options.validators
        @addValidator(validator)

  addValidator: (validator) ->
    if @validators[validator.url]
      @validators[validator.url] = validator
      @updateValidator(validator) if @map

      @fire('validatorchange', {validator: validator})
    else
      @layers[validator.url] = new L.LayerGroup()
      @validators[validator.url] = validator

      if @map
        @map.addLayer(@layers[validator.url])
        @updateValidator(validator)

      @fire('validatoradd', {validator: validator})

  removeValidator: (validator) ->
    if @validators[validator.url]
      @map.removeLayer(@layers[validator.url]) if @map
      @layers[validator.url] = undefined
      @validators[validator.url] = undefined
      @fire('validatorremove', {validator: validator})

  onAdd: (map) ->
    @map = map

    for key, layer of @layers
      map.addLayer(layer)

    map.on('moveend', @update, @)

    @update()

  onRemove: (map) ->
    map.off('moveend', @update, @)

    for key, layer of @layers
      map.removeLayer(layer)

    @map = undefined

  update: ->
    Layer.Utils.cancelRequests()

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

    Layer.Utils.request url, validator, (data) =>
      layer = @layers[validator.url]
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

  activeXhr: []
  activeJsonp: []

  cancelRequests: ->
    for xhr in @activeXhr
      xhr.abort()

    for el in @activeJsonp
      el.src = undefined
      document.getElementsByTagName('body')[0].removeChild(el)

    @activeXhr = []
    @activeJsonp = []

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
          @activeXhr.splice(idx, 1) if (idx = @activeXhr.indexOf(xhr)) >= 0
          cb(eval("(#{xhr.responseText})"))

    xhr.send()
    @activeXhr.push xhr

  requestJsonp: (url, cb) ->
    el = document.createElement('script')
    counter = (@callbackCounter += 1)
    callback = "OsmJs.Validators.LeafletLayer.Utils.callbacks[#{counter}]"

    @callbacks[counter] = (data) =>
      if (idx = @activeJsonp.indexOf(el)) >= 0
        @activeJsonp.splice(idx, 1)
        document.getElementsByTagName('body')[0].removeChild(el)
        @callbacks[counter] = undefined
        cb(data)

    delim = if url.indexOf('?') >= 0
      '&'
    else
      '?'

    el.src = "#{url}#{delim}callback=#{callback}"
    document.getElementsByTagName('body')[0].appendChild(el)
    @activeJsonp.push el

@OsmJs = {} unless @OsmJs
@OsmJs.Validators = {} unless @OsmJs.Validators
@OsmJs.Validators.LeafletLayer = Layer
