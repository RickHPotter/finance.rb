# frozen_string_literal: true

# Component to render an autocomplete select
class ButtonComponent < ViewComponent::Base
  # includes ..................................................................
  include ComponentsHelper

  # security (i.e. attr_accessible) ...........................................
  attr_reader :form, :link, :options

  # public instance methods ...................................................
  def initialize(form: nil, link: nil, options: {})
    @form = form
    @link = link
    @options = default_options(options)
    super
  end

  # private instance methods ..................................................
  private

  def default_options(options)
    {
      id: options[:id] || button_id,
      label: options[:label] || 'Button Without A Name',
      colour: options[:colour] || :indigo,
      type: 'button',
      data: data_attributes(options[:data])
    }
  end

  def button_id
    return "#{link}_button" if link

    "#{form.object.model_name.singular}_submit_button"
  end
end

# TODO: Following Features
# - Add colour variants
