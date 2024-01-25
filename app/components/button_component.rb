# frozen_string_literal: true

# Component to render an autocomplete select
class ButtonComponent < ViewComponent::Base
  # @includes .................................................................
  include ComponentsHelper

  # @security (i.e. attr_accessible) ..........................................
  attr_reader :form, :link, :options

  # @public_instance_methods ..................................................
  # Initialises a Component of Type Button
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
    @link = link
    @options = default_options(options)
    super
  end

  # Sets default options for the button.
  #
  # @param options [Hash] Additional options for customizing the button.
  #
  # @return [Hash] Merged options with default values.
  #
  def default_options(options)
    {
      id: options[:id] || button_id,
      label: options[:label] || 'Button Without A Name',
      colour: { colour: colours(options[:colour]) },
      type: 'button',
      data: data_attributes(options[:data])
    }
  end

  # Sets html id for button based on the presence of a link.
  #
  # @return [String] HTML id for the button tag.
  #
  def button_id
    return "#{link}_button" if link

    "#{form.object.model_name.singular}_submit_button"
  end

  # Sets the colour for the button based on the colour option.
  #
  # @param colour [Symbol] The colour of the button.
  # @option colour [Symbol] :indigo
  # @option colour [Symbol] :red
  #
  # @return [Hash] The colour of the button.
  #
  def colours(colour)
    case colour
    when nil, :indigo
      { text: 'text-white', bg: 'bg-indigo-600',
        hover: { bg: 'hover:bg-indigo-700' }, focus: { ring: 'focus:ring-black' } }
    when :red
      { text: 'text-black', bg: 'bg-red-500',
        hover: { bg: 'hover:bg-red-600' }, focus: { ring: 'focus:ring-black' } }
    end
  end
end
