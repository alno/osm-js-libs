
class JqueryValidatorsControl

  constructor: (@elem, @layer, @options = {}) ->
    @validators = []

    if @options.validators
      for validator in @options.validators
        @validators.push(validator)

    for url, validator of @layer.validators when @validators.indexOf(validator) < 0
      @validators.push(validator)

    @layer.on 'validatoradd', (e) =>
      @validators.push(e.validator) if @validators.indexOf(e.validator) < 0
      @update()

    @layer.on 'validatorremove', @update, @

    @update()

  update: ->
    @elem.html('')

    for validator in @validators
      @elem.append(@buildListItem(validator))

  buildListItem: (validator) ->
    cb = $('<input type="checkbox" />')
    cb.attr('checked', 'checked') if @layer.validators[validator.url]
    cb.change =>
      if cb.attr('checked')
        @layer.addValidator(validator)
      else
        @layer.removeValidator(validator)

    li = $('<li />')
    li.append(cb)
    li.append(validator.name)
    li


jQuery.fn.validatorsControl = (layer, options) ->
  @each ->
    new JqueryValidatorsControl($(@), layer, options)
