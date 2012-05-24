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

    @map.addLayer(@poly)

  activate: =>
    @active = true
    @poly.editing.enable() if @poly.editing?

    @map.on 'click', @onMapClick
    @control.activate()

  passivate: =>
    @active = false
    @poly.editing.disable() if @poly?.editing?

    @map.off 'click', @onMapClick
    @control.passivate()

  remove: =>
    @passivate()
    @map.removeLayer(@poly)
    @map.removeLayer(@start) if @start
    @map.removeLayer(@finish) if @finish
    @map.removeLayer(@popup) if @popup

  onMapClick: (e) =>
    @poly.addLatLng(e.latlng)

    unless @start
      @start = new L.CircleMarker(e.latlng)
      @start.setRadius(5)
      @map.addLayer(@start)

    unless @finish
      @finish = new L.CircleMarker(e.latlng)
      @finish.setRadius(5)
      @map.addLayer(@finish)

    unless @popup
      @popup = new L.Popup()
      @popup.setLatLng(e.latlng)
      @map.addLayer(@popup)

    if @poly.editing?
      @poly.editing.disable()
      @poly.editing.enable()
      @poly.fire('edit')

    @onEdited()

  onEdited: =>
    points = @poly.getLatLngs()

    @start.setLatLng(points[0])
    @finish.setLatLng(points[points.length-1])

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

  constructor: (@map) ->
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
      @path = new DistancePath(@map, @)
      @path.activate()

  activate: ->
    L.DomUtil.addClass(@link, 'active')

  passivate: ->
    L.DomUtil.removeClass(@link, 'active')
    @path = null

@L.Control.Distance = @L.Control.extend

  options:
    position: 'topleft'

  onAdd: (map) ->
    new DistanceControl(map).container
