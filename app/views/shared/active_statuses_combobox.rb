# frozen_string_literal: true

class Views::Shared::ActiveStatusesCombobox < Views::Base
  include TranslateHelper

  attr_reader :model, :name, :selected_statuses

  def initialize(model:, name:, selected_statuses: [])
    @model = model
    @name = name
    @selected_statuses = selected_statuses
  end

  def view_template
    Combobox(term: model_attribute(model, :status), class: "w-full", data: { ruby_ui__combobox_reorder_value: true }) do
      ComboboxTrigger(placeholder: model_attribute(model, :status))

      ComboboxPopover do
        div(class: "my-1") do
          ComboboxSearchInput(placeholder: action_message(:type))
        end

        ComboboxList do
          ComboboxEmptyState { I18n.t(:rows_not_found) }

          ComboboxItem(class: "mt-1") do
            ComboboxToggleAllCheckbox(name: "#{name}_toggle_all", value: action_message(:all))
            span { action_message(:select_all) }
          end

          %w[active inactive].each do |status|
            ComboboxItem do
              ComboboxCheckbox(
                name:,
                value: status,
                checked: selected_statuses.include?(status),
                data: {
                  ruby_ui__combobox_target: "input",
                  action: "change->ruby-ui--combobox#inputChanged change->reactive-form#submitWithDelay",
                  text: model_attribute(model, "statuses.#{status}")
                }
              )
              span { model_attribute(model, "statuses.#{status}") }
            end
          end
        end
      end
    end
  end
end
