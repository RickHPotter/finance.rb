# frozen_string_literal: true

class Views::Shared::MultiSelectCombobox < Views::Base
  include TranslateHelper

  attr_reader :combobox_data, :input_data, :name, :options, :placeholder, :selected_values, :term, :toggle_all_name

  def initialize(name:, options:, placeholder:, **attrs)
    @name = name
    @options = options
    @placeholder = placeholder
    @selected_values = Array(attrs.fetch(:selected_values, nil).presence || options.map { |option| option[:value].to_s })
    @term = attrs.fetch(:term, "items")
    @toggle_all_name = attrs.fetch(:toggle_all_name, "#{name}_toggle_all")
    @combobox_data = attrs.fetch(:combobox_data, {})
    @input_data = attrs.fetch(:input_data, {})
  end

  def view_template
    Combobox(term:, class: "w-full", data: combobox_data) do
      ComboboxTrigger(placeholder:)

      ComboboxPopover do
        div(class: "my-1") do
          ComboboxSearchInput(placeholder: action_message(:type))
        end

        ComboboxList do
          ComboboxEmptyState { I18n.t(:rows_not_found) }

          ComboboxItem(class: "mt-1") do
            ComboboxToggleAllCheckbox(
              name: toggle_all_name,
              value: action_message(:all),
              checked: all_selected?,
              data: {
                ruby_ui__combobox_target: "toggleAll",
                action: "change->ruby-ui--combobox#toggleAllItems change->pie-breakdown-chart#changeFilter"
              }
            )
            span { action_message(:select_all) }
          end

          options.each do |option|
            ComboboxItem do
              ComboboxCheckbox(
                name:,
                value: option[:value],
                checked: selected?(option[:value]),
                data: {
                  ruby_ui__combobox_target: "input",
                  pie_breakdown_chart_target: "filterInput",
                  action: "change->ruby-ui--combobox#inputChanged change->pie-breakdown-chart#changeFilter",
                  text: option[:label]
                }.merge(input_data).merge(option[:data] || {})
              )
              span { option[:label] }
            end
          end
        end
      end
    end
  end

  private

  def selected?(value)
    selected_values.include?(value.to_s)
  end

  def all_selected?
    options.all? { |option| selected?(option[:value]) }
  end
end
