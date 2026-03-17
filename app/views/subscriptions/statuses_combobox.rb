# frozen_string_literal: true

class Views::Subscriptions::StatusesCombobox < Views::Base
  include TranslateHelper

  attr_reader :name, :selected_statuses

  def initialize(name:, selected_statuses: [])
    @name = name
    @selected_statuses = selected_statuses
  end

  def view_template
    Combobox(term: model_attribute(Subscription, :status), class: "w-full", data: { ruby_ui__combobox_reorder_value: true }) do
      ComboboxTrigger(placeholder: model_attribute(Subscription, :status))

      ComboboxPopover do
        div(class: "my-1") do
          ComboboxSearchInput(placeholder: action_message(:type))
        end

        ComboboxList do
          ComboboxEmptyState { I18n.t(:rows_not_found) }

          ComboboxItem(class: "mt-1") do
            ComboboxToggleAllCheckbox(name: "status_toggle_all", value: action_message(:all))
            span { action_message(:select_all) }
          end

          Subscription.statuses.each_key do |status|
            ComboboxItem do
              ComboboxCheckbox(
                name:,
                value: status,
                checked: selected_statuses.include?(status),
                data: {
                  ruby_ui__combobox_target: "input",
                  action: "change->ruby-ui--combobox#inputChanged change->reactive-form#submitWithDelay",
                  text: model_attribute(Subscription, "statuses.#{status}")
                }
              )
              span { model_attribute(Subscription, "statuses.#{status}") }
            end
          end
        end
      end
    end
  end
end
