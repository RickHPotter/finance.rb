# frozen_string_literal: true

class Views::Entities::Combobox < Views::Base
  include TranslateHelper

  attr_reader :name, :entities, :selected_entity_ids

  def initialize(name:, entities:, selected_entity_ids: [])
    @name = name
    @entities = entities
    @selected_entity_ids = selected_entity_ids
  end

  def view_template
    Combobox(term: pluralise_model(Entity, 2), class: "w-full", data: { ruby_ui__combobox_reorder_value: true }) do
      ComboboxTrigger(placeholder: pluralise_model(Entity, 2))

      ComboboxPopover do
        div(class: "my-1") do
          ComboboxSearchInput(placeholder: action_message(:type))
        end

        ComboboxList do
          ComboboxEmptyState { I18n.t(:rows_not_found) }

          ComboboxItem(class: "mt-1") do
            ComboboxToggleAllCheckbox(name: "entity_toggle_all", value: action_message(:all))
            span { action_message(:select_all) }
          end

          entities.each do |entity_name, id|
            ComboboxItem do
              ComboboxCheckbox(
                name:,
                value: id,
                checked: selected_entity_ids.include?(id.to_s),
                data: {
                  ruby_ui__combobox_target: "input",
                  action: "change->ruby-ui--combobox#inputChanged change->reactive-form#submitWithDelay",
                  text: entity_name
                }
              )
              span { entity_name }
            end
          end
        end
      end
    end
  end
end
