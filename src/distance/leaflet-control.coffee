DistancePopup = L.Popup.extend

  _close: () -> null

class DistancePath

  constructor: (@map, @control) ->
    @active = false
    @poly = new L.Polyline([])
    @poly.on 'dblclick', @remove
    @poly.on 'click', =>
      if @active
        @passivate()
      else
        @activate()
    @poly.on 'edit', @onEdited

    @map.addLayer(@poly)

  activate: =>
    @active = true
    @poly.editing.enable() if @poly.editing?
    @poly.setStyle @control.options.activeStyle

    @map.on 'click', @onMapClick
    @control.activate(@)

  passivate: =>
    @active = false
    @poly.editing.disable() if @poly?.editing?
    @poly.setStyle @control.options.passiveStyle

    @map.off 'click', @onMapClick
    @control.passivate()

  remove: =>
    @passivate()
    @map.removeLayer(@poly)
    @map.removeLayer(@popup) if @popup

  onMapClick: (e) =>
    @poly.addLatLng(e.latlng)

    unless @popup
      @popup = new DistancePopup()
      @popup.setLatLng(e.latlng)
      @map.addLayer(@popup)

    if @poly.editing?
      @poly.editing.disable()
      @poly.editing.enable()
      @poly.fire('edit')

    @onEdited()

  onEdited: =>
    points = @poly.getLatLngs()

    @popup.setContent(@formatDistance(@calculateDistance(points)))
    @popup.setLatLng(points[points.length-1])

  calculateDistance: (points) ->
    len = 0

    if points.length > 1
      for i in [1..points.length-1]
        len += points[i-1].distanceTo points[i]

    len

  formatDistance: (dist) ->
    if dist > 2000
      Math.round(dist/100)/10 + " km"
    else if dist > 5
      Math.round(dist) + " m"
    else
      dist + " m"

class DistanceControl

  constructor: (@map, @options) ->
    @map = map
    @container = L.DomUtil.create('div', 'leaflet-control-distance')
    @link = L.DomUtil.create('a', '', @container)
    @link.href = '#'
    @link.title = "Start measuring distance"

    L.DomEvent.addListener(@link, 'click', L.DomEvent.stopPropagation)
    L.DomEvent.addListener(@link, 'click', L.DomEvent.preventDefault)
    L.DomEvent.addListener(@link, 'click', @toggleMeasure)

  toggleMeasure: =>
    if @path
      @path.passivate()
    else
      new DistancePath(@map, @).activate()

  activate: (path) ->
    if @path and @path != path
      @path.passivate()

    L.DomUtil.addClass @link, 'active'

    @path = path

  passivate: ->
    L.DomUtil.removeClass @link, 'active'
    @path = null

@L.Control.Distance = @L.Control.extend

  options:
    position: 'topleft'

    activeStyle:
      color: 'red'

    passiveStyle:
      color: 'blue'

  onAdd: (map) ->
    new DistanceControl(map, @options).container
