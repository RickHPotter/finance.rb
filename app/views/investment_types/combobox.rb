# frozen_string_literal: true

class Views::InvestmentTypes::Combobox < Views::Base
  include TranslateHelper

  attr_reader :name, :investment_types, :selected_investment_type_ids

  def initialize(name:, investment_types:, selected_investment_type_ids: [])
    @name = name
    @investment_types = investment_types
    @selected_investment_type_ids = selected_investment_type_ids
  end

  def view_template
    Combobox(term: pluralise_model(InvestmentType, 2), class: "w-full", data: { ruby_ui__combobox_reorder_value: true }) do
      ComboboxTrigger(placeholder: pluralise_model(InvestmentType, 2))

      ComboboxPopover do
        div(class: "my-1") do
          ComboboxSearchInput(placeholder: action_message(:type))
        end

        ComboboxList do
          ComboboxEmptyState { I18n.t(:rows_not_found) }

          ComboboxItem(class: "mt-1") do
            ComboboxToggleAllCheckbox(name: "investment_type_toggle_all", value: action_message(:all))
            span { action_message(:select_all) }
          end

          investment_types.each do |investment_type_name, id|
            ComboboxItem do
              ComboboxCheckbox(
                name:,
                value: id,
                checked: selected_investment_type_ids.include?(id.to_s),
                data: {
                  ruby_ui__combobox_target: "input",
                  action: "change->ruby-ui--combobox#inputChanged change->reactive-form#submitWithDelay",
                  text: investment_type_name
                }
              )
              span { investment_type_name }
            end
          end
        end
      end
    end
  end
end
