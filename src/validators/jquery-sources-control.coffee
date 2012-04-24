
class JqueryValidatorSourcesControl

  constructor: (@elem, @layer, @options = {}) ->
    @sources = []

    if @options.sources
      for source in @options.sources
        @sources.push(source)

    for url, source of @layer.sources when @sources.indexOf(source) < 0
      @sources.push(source)

    @layer.on 'sourceadd', (e) =>
      @sources.push(e.source) if @sources.indexOf(e.source) < 0
      @update()

    @layer.on 'sourceremove', @update, @

    @update()

  update: ->
    @elem.html('')

    for source in @sources
      @elem.append(@buildListItem(source))

  buildListItem: (source) ->
    cb = $('<input type="checkbox" />')
    cb.attr('checked', 'checked') if @layer.sources[source.url]
    cb.change =>
      if cb.attr('checked')
        @layer.addSource(source)
      else
        @layer.removeSource(source)

    tx = $('<span />')
    tx.text(source.name)

    li = $('<li />')
    li.append(cb)
    li.append(tx)
    li


jQuery.fn.validatorSourcesControl = (layer, options) ->
  @each ->
    new JqueryValidatorSourcesControl($(@), layer, options)
