# frozen_string_literal: true

# Component to render an autocomplete select.
class ButtonComponent < ViewComponent::Base
  # @includes .................................................................
  include ComponentsHelper

  # @security (i.e. attr_accessible) ..........................................
  attr_reader :form, :link, :options

  # @public_instance_methods ..................................................

  # Initialises a Button Component.
  #
  # @param form [ActionView::Helpers::FormBuilder] The form builder object (default is nil).
  # @param link [String] The link possibly associated with the form (default is nil).
  # @param options [Hash] Additional options for customizing the button.
  #
  # @option options [String] :id The HTML ID attribute for the button (default is method button_id).
  # @option options [String] :label The label for the button (default is 'Button Without A Name').
  # @option options [String] :colour The colour of the button (default is 'button').
  # @option options [Hash] :data Additional data attributes for the button field.
  #
  # @return [ButtonComponent] A new instance of ButtonComponent.
  #
  def initialize(form: nil, link: nil, options: {})
    @form = form
    @link = link || "#"
    @options = default_options(options)
    super
  end

  # Sets default `options` for the button.
  #
  # @param options [Hash] Additional options for customizing the button.
  #
  # @return [Hash] Merged options with default values.
  #
  def default_options(options)
    {
      id: options[:id] || button_id,
      label: options[:label] || "Button Without A Name",
      colour: { colour: colours(options[:colour]) },
      type: "button",
      data: options[:data] || {}
    }
  end

  # Sets html id for button based on the presence of a link.
  #
  # @return [String] HTML ID for the button tag.
  #
  def button_id
    return "#{link}_button" if link

    return "#{form.object.model_name.singular}_submit_button" if form

    "idless_button"
  end

  # Sets the `colour` for the button based on the `colour` option.
  #
  # @param colour [Symbol] The colour of the button.
  #
  # @option colour [Symbol] :purple.
  # @option colour [Symbol] :orange.
  #
  # @return [Hash] The colour of the button.
  #
  def colours(colour)
    case colour

    when nil, :purple
      { text: "text-white", bg: "bg-purple-600", border: "border-gray-300",
        hover: { bg: "hover:bg-indigo-900", text: "" } }
    when :light
      { text: "text-black", bg: "bg-gray-300", border: "border-black",
        hover: { bg: "hover:bg-gray-500", text: "hover:text-gray-50" } }
    when :red
      { text: "text-white", bg: "bg-red-800", border: "border-black",
        hover: { bg: "hover:bg-red-700", text: "hover:text-gray-50" } }
    when :indigo
      { text: "text-white", bg: "bg-indigo-600", border: "border-black",
        hover: { bg: "hover:bg-indigo-700", text: "hover:text-gray-50" } }
    when :orange
      { text: "text-white", bg: "bg-orange-500", border: "rounded-md",
        hover: { bg: "hover:bg-red-700", text: "" } }
    end
  end
end
