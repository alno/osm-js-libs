
class ValidatorsLayer

  @callbacks = {}
  @callbackCounter = 0

  @request: (url, validator, cb) ->
    if validator.jsonp
      @jsonpRequest url, cb
    else
      xhr = new XMLHttpRequest()
      xhr.open 'GET', url, true
      xhr.onreadystatechange = ->
        if xhr.readyState == 4
          if xhr.status == 200
            cb(eval("(#{xhr.responseText})"))

      xhr.send()

  @jsonpRequest: (url, cb) ->
    counter = (@callbackCounter += 1)
    callback = "OsmJs.Validators.LeafletLayer.callbacks[#{counter}]"

    @callbacks[counter] = (data) =>
      @callbacks[counter] = undefined
      cb(data)

    delim = if url.indexOf('?') >= 0
      '&'
    else
      '?'

    el = document.createElement('script')
    el.src = "#{url}#{delim}callback=#{callback}"
    document.getElementsByTagName('body')[0].appendChild(el)

  constructor: (@options)->
    @layers = {}

    for validator in @options.validators
      @layers[validator.url] = new L.LayerGroup()

    @limitedUpdate = L.Util.limitExecByInterval(@update, 2000, @)

  onAdd: (map) ->
    @map = map

    for key, layer of @layers
      map.addLayer(layer)

    # map.on('move', @limitedUpdate, @)
    map.on('moveend', @update, @)
    map.on('viewreset', @update, @)

    @update()

  onRemove: (map) ->
    map.off('viewreset', @update, @)
    map.off('moveend', @update, @)
    map.off('move', @limitedUpdate, @)

    for key, layer of @layers
      map.removeLayer(layer)

    @map = undefined

  update: ->
    for validator in @options.validators
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

    layer = @layers[validator.url]

    ValidatorsLayer.request url, validator, (data) =>
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


@OsmJs = {} unless @OsmJs
@OsmJs.Validators = {} unless @OsmJs.Validators
@OsmJs.Validators.LeafletLayer = ValidatorsLayer
