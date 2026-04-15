# frozen_string_literal: true

class Views::Shared::SortPresetSelect < Views::Base
  include Phlex::Rails::Helpers::SelectTag
  include Phlex::Rails::Helpers::OptionsForSelect
  include ComponentsHelper

  attr_reader :input_id, :options, :selected_value

  def initialize(input_id:, options:, selected_value:)
    @input_id = input_id
    @options = options
    @selected_value = selected_value
  end

  def view_template
    div(class: "mt-2 w-full") do
      select_tag(
        :sort_preset,
        class: input_class_without_icon,
        id: input_id,
        data: { action: "change->datatable#applySortPreset", sort_preset: true }
      ) do
        options_for_select(options, selected_value)
      end
    end
  end
end
