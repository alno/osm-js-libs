
class JqueryValidatorErrorsControl

  constructor: (@elem, @layer, @options = {}) ->
    @errors = @options.errors

    @update()

  update: ->
    @elem.html('')

    for error in @errors
      @elem.append(@buildListItem(error))

  buildListItem: (error) ->
    ul = $('<ul />')

    for childErr in (error.children or [])
      ul.append(@buildListItem(childErr))

    cb = $('<input type="checkbox" />')
    cb.data('type', error.type)
    cb.attr('checked', 'checked') unless error.type and @layer.disabledErrors.indexOf(error.type) >= 0
    cb.change =>
      if cb.attr('checked')
        ul.find('input').removeAttr('disabled')
      else
        ul.find('input').attr('disabled','true')

      for e in li.find('input')
        ee = $(e)
        if type = ee.data('type')
          if !ee.attr('disabled') && ee.attr('checked')
            @layer.enableError(type)
          else
            @layer.disableError(type)

    tx = $('<span />')
    tx.text(error.name)

    li = $('<li />')
    li.append(cb)
    li.append(tx)
    li.append(ul)
    li

jQuery.fn.validatorErrorsControl = (layer, options) ->
  @each ->
    new JqueryValidatorErrorsControl($(@), layer, options)
