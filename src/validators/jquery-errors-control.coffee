
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
    cb.attr('checked', 'checked')
    cb.change =>
      if cb.attr('checked')
        ul.find('input').removeAttr('disabled')
      else
        ul.find('input').attr('disabled','true')

    li = $('<li />')
    li.append(cb)
    li.append(error.name)
    li.append(ul)
    li

jQuery.fn.validatorErrorsControl = (layer, options) ->
  @each ->
    new JqueryValidatorErrorsControl($(@), layer, options)
