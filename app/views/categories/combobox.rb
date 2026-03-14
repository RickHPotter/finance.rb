# frozen_string_literal: true

class Views::Categories::Combobox < Views::Base
  include TranslateHelper

  attr_reader :name, :categories, :selected_category_ids

  def initialize(name:, categories:, selected_category_ids: [])
    @name = name
    @categories = categories
    @selected_category_ids = selected_category_ids
  end

  def view_template
    Combobox(term: pluralise_model(Category, 2), class: "w-full", data: { ruby_ui__combobox_reorder_value: true }) do
      ComboboxTrigger(placeholder: pluralise_model(Category, 2))

      ComboboxPopover do
        div(class: "my-1") do
          ComboboxSearchInput(placeholder: action_message(:type))
        end

        ComboboxList do
          ComboboxEmptyState { I18n.t(:rows_not_found) }

          ComboboxItem(class: "mt-1") do
            ComboboxToggleAllCheckbox(name: "category_toggle_all", value: action_message(:all))
            span { action_message(:select_all) }
          end

          categories.each do |category_name, id|
            ComboboxItem do
              ComboboxCheckbox(
                name:,
                value: id,
                checked: selected_category_ids.include?(id.to_s),
                data: {
                  ruby_ui__combobox_target: "input",
                  action: "change->ruby-ui--combobox#inputChanged change->reactive-form#submitWithDelay",
                  text: category_name
                }
              )
              span { category_name }
            end
          end
        end
      end
    end
  end
end
