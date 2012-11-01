
class JstreeValidatorErrorsControl

  constructor: (@elem, @layer, @options = {}) ->
    @elem.jstree(
      plugins: [ "json_data", "checkbox", "ui" ]
      json_data:
        data:
          @nodeJson(e) for e in @options.errors
      checkbox:
        override_ui: true
    ).bind("change_state.check_box.jstree", @stateChanged).bind("loaded.jstree", @stateChanged)

    @tree = jQuery.jstree._reference(@elem)
    @stateChanged()

  nodeJson: (err) ->
    data: err.name
    attr:
      "data-error-type": err.type
    children: @nodeJson(chd) for chd in (err.children or [])

  stateChanged: =>
    for node in @tree.get_checked(null, true) when $(node).data('error-type')
      @layer.enableError $(node).data('error-type')

    for node in @tree.get_unchecked(null, true) when $(node).data('error-type')
      @layer.disableError $(node).data('error-type')

jQuery.fn.validatorErrorsControl = (layer, options) ->
  @each ->
    new JstreeValidatorErrorsControl($(@), layer, options)
