
class @ValidatorsLayer

  @callbacks = {}
  @callbackCounter = 0

  @jsonpRequest: (url, cb) ->
    counter = (@callbackCounter += 1)
    callback = "ValidatorsLayer.callbacks[#{counter}]"

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

    map.on('move', @limitedUpdate, @)
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
      bounds = @map.getBounds()
      sw = bounds.getSouthWest()
      ne = bounds.getNorthEast()

      url = validator.url
        .replace('{minlat}', sw.lat)
        .replace('{maxlat}', ne.lat)
        .replace('{minlon}', sw.lng)
        .replace('{maxlon}', ne.lng)

      layer = @layers[validator.url]

      ValidatorsLayer.jsonpRequest url, (data) =>
        map.removeLayer(layer)
        layer.clearLayers()

        for res in data.results
          layer.addLayer(new L.GeoJSON(type: 'Feature', geometry: res.geometry))

        map.addLayer(layer)
