# frozen_string_literal: true

class Views::Shared::SingleSelectCombobox < Views::Base
  include TranslateHelper

  attr_reader :autofocus, :blank_label, :combobox_data, :disabled, :include_blank, :input_data, :name, :options, :placeholder, :selected_value, :term, :trigger_data

  def initialize(name:, options:, selected_value:, placeholder:, **attrs)
    @name = name
    @options = options
    @selected_value = selected_value
    @placeholder = placeholder
    @autofocus = attrs.fetch(:autofocus, false)
    @disabled = attrs.fetch(:disabled, false)
    @include_blank = attrs.fetch(:include_blank, false)
    @blank_label = attrs.fetch(:blank_label, placeholder)
    @term = attrs.fetch(:term, "items")
    @combobox_data = attrs.fetch(:combobox_data, {})
    @input_data = attrs.fetch(:input_data, {})
    @trigger_data = attrs.fetch(:trigger_data, {})
  end

  def view_template
    Combobox(term:, class: "w-full", data: combobox_data) do
      ComboboxTrigger(
        placeholder:,
        autofocus:,
        disabled:,
        class: combobox_trigger_class,
        data: trigger_data
      )

      ComboboxPopover(class: "absolute inset-auto m-0 rounded-lg border bg-background shadow-lg dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100") do
        div(class: "my-1") do
          ComboboxSearchInput(
            placeholder: action_message(:type),
            class: combobox_search_input_class
          )
        end

        ComboboxList(class: "flex max-h-72 flex-col gap-1 overflow-y-auto p-1 text-foreground dark:text-slate-100") do
          ComboboxEmptyState(class: "py-6 text-center text-sm text-muted-foreground dark:text-slate-500") { I18n.t(:rows_not_found) }

          if include_blank
            ComboboxItem(class: combobox_item_class) do
              ComboboxRadio(
                name:,
                value: "",
                id: input_id_for("blank"),
                checked: selected?(nil),
                disabled:,
                data: radio_data(blank_label, {})
              )
              span { blank_label }
            end
          end

          options.each do |label, value, option_data|
            ComboboxItem(class: combobox_item_class) do
              ComboboxRadio(
                name:,
                value:,
                id: input_id_for(value),
                checked: selected?(value),
                disabled:,
                data: radio_data(label, option_data || {})
              )
              span { label }
            end
          end
        end
      end
    end
  end

  private

  def input_id_for(value)
    "#{name.to_s.parameterize(separator: '_')}_#{value}"
  end

  def radio_data(label, option_data)
    {
      text: label
    }.merge(input_data).merge(option_data)
  end

  def selected?(value)
    selected_value.to_s == value.to_s
  end

  def combobox_item_class
    "relative flex cursor-default select-none items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-none hover:bg-accent dark:hover:bg-slate-800 " \
      "dark:text-slate-100 data-[disabled]:pointer-events-none data-[disabled]:opacity-50"
  end

  def combobox_trigger_class
    "flex h-10 w-full items-center justify-between overflow-hidden whitespace-nowrap rounded-md border border-slate-300 bg-white px-4 py-2 " \
      "text-sm text-slate-900 shadow-sm transition-colors hover:border-slate-400 hover:bg-slate-50 focus-visible:ring-2 focus-visible:ring-ring " \
      "disabled:pointer-events-none disabled:opacity-50 " \
      "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 dark:hover:bg-slate-700/70 dark:focus-visible:ring-sky-500/60 dark:disabled:opacity-40"
  end

  def combobox_search_input_class
    "flex h-10 w-full rounded-md border-none bg-transparent py-3 text-sm outline-none placeholder:text-muted-foreground disabled:cursor-not-allowed " \
      "disabled:opacity-50 dark:text-slate-100 dark:placeholder:text-slate-500"
  end
end
