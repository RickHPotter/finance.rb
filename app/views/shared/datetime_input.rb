# frozen_string_literal: true

class Views::Shared::DatetimeInput < Views::Base
  include ComponentsHelper
  include CacheHelper

  attr_reader :form, :field, :value, :id, :hidden_class, :hidden_data, :date_data, :time_data, :date_actions, :time_actions, :autofocus, :time_autofocus, :disabled,
              :readonly, :compact, :min_datetime, :min_datetime_message, :max_datetime, :max_datetime_message, :show_time, :calendar

  def initialize(form:, field:, value:, id:, **options)
    @form = form
    @field = field
    @value = value
    @id = id
    @hidden_class = options.fetch(:hidden_class, "transaction-date")
    @hidden_data = options.fetch(:hidden_data, {})
    @date_data = options.fetch(:date_data, {})
    @time_data = options.fetch(:time_data, {})
    @date_actions = Array(options.fetch(:date_actions, []))
    @time_actions = Array(options.fetch(:time_actions, []))
    @autofocus = options.fetch(:autofocus, false)
    @time_autofocus = options.fetch(:time_autofocus, false)
    @disabled = options.fetch(:disabled, false)
    @readonly = options.fetch(:readonly, false)
    @compact = options.fetch(:compact, false)
    @min_datetime = options.fetch(:min_datetime, nil)
    @min_datetime_message = options.fetch(:min_datetime_message, nil)
    @max_datetime = options.fetch(:max_datetime, nil)
    @max_datetime_message = options.fetch(:max_datetime_message, nil)
    @show_time = options.fetch(:show_time, true)
    @calendar = options.fetch(:calendar, false)
  end

  def view_template
    div(
      class: datetime_root_class,
      data: {
        controller: "datetime-input",
        action: "datetime-input:refresh->datetime-input#refresh datetime-input:readonly->datetime-input#setReadonly",
        datetime_input_invalid_time_message_value: I18n.t("datetime_input.invalid_time"),
        datetime_input_readonly_value: readonly,
        datetime_input_min_datetime_value: min_datetime&.strftime("%Y-%m-%dT%H:%M"),
        datetime_input_min_datetime_message_value: min_datetime_message || I18n.t("datetime_input.invalid_min"),
        datetime_input_max_datetime_value: max_datetime&.strftime("%Y-%m-%dT%H:%M"),
        datetime_input_max_datetime_message_value: max_datetime_message || I18n.t("datetime_input.invalid_max")
      }
    ) do
      raw form.hidden_field(
        field,
        id:,
        value: formatted_datetime,
        class: hidden_class,
        disabled:,
        data: { datetime_input_target: "hiddenInput" }.merge(hidden_data)
      )

      div(class: datetime_layout_class) do
        div(class: date_container_class) do
          div(class: calendar ? "hidden" : "relative") do
            div(class: datetime_icon_class) do
              cached_icon :calendar
            end

            input(
              type: "date",
              id: "#{id}_date_input",
              value: date_value,
              min: min_datetime&.strftime("%Y-%m-%d"),
              max: max_datetime&.strftime("%Y-%m-%d"),
              disabled: visible_input_disabled?,
              autofocus: autofocus,
              aria: { label: I18n.t("datetime_input.date"), readonly: },
              class: "#{visible_input_class} datetime-input-date font-graduate dark:font-mono",
              data: {
                datetime_input_target: "dateInput",
                controller: date_input_controllers,
                action: [
                  "input->datetime-input#syncQuiet",
                  "change->datetime-input#commit",
                  "blur->datetime-input#commit",
                  "keydown->datetime-input#handleDateKeydown",
                  *date_actions
                ].join(" ")
              }.merge(date_data).compact
            )
          end

          unless calendar || compact
            p(
              class: "mt-0.5 min-h-4 px-1 font-graduate text-2xs leading-4 text-muted-foreground dark:font-mono dark:text-slate-500",
              data: { datetime_input_target: "weekdayLabel" }
            )
          end

          if calendar
            Calendar(
              input_id: "##{id}_date_input",
              selected_date: date_value,
              class: "w-full rounded-md border border-slate-200 bg-white p-3 shadow-sm dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100"
            )
          end
        end

        if show_time
          div(class: time_container_class) do
            div(class: calendar ? "hidden" : "relative") do
              div(class: datetime_icon_class) do
                cached_icon :clock
              end

              input(
                type: "text",
                id: "#{id}_time_input",
                value: time_value,
                disabled: visible_input_disabled?,
                autofocus: visible_time_autofocus?,
                inputmode: "numeric",
                autocomplete: "off",
                placeholder: "20:20",
                maxlength: 5,
                aria: { label: I18n.t("datetime_input.time"), readonly: },
                class: "#{visible_input_class} text-center font-graduate dark:font-mono",
                data: {
                  controller: time_input_controllers,
                  autofocus_select_value: visible_time_autofocus?,
                  datetime_input_target: "timeInput",
                  action: [
                    "click->input-select#select",
                    "input->datetime-input#formatTimeInput",
                    "blur->datetime-input#commit",
                    "change->datetime-input#commit",
                    "keydown->datetime-input#handleKeydown",
                    *time_actions
                  ].join(" ")
                }.merge(time_data).compact
              )
            end

            TimePicker(input_id: "##{id}_time_input", value: time_value, autofocus: time_autofocus) if calendar
          end
        end
      end
    end
  end

  private

  def datetime_root_class
    return "w-full [&_input]:h-9 [&_input]:py-1" if compact

    "w-full"
  end

  def datetime_icon_class
    "#{'hidden ' if compact}pointer-events-none absolute inset-y-0 start-0 z-1 flex items-center ps-3.5 text-black dark:text-white"
  end

  def visible_input_class
    return "#{input_class_without_icon} px-2" if compact

    input_class
  end

  def formatted_datetime
    value&.strftime("%Y-%m-%dT%H:%M")
  end

  def date_value
    value&.strftime("%Y-%m-%d")
  end

  def time_value
    value&.strftime("%H:%M")
  end

  def date_input_controllers
    [
      ("autofocus" if autofocus),
      ("ruby-ui--calendar-input" if calendar)
    ].compact.join(" ").presence
  end

  def datetime_layout_class
    return "grid grid-cols-[minmax(0,2fr)_minmax(7rem,1fr)] gap-2" if calendar && show_time
    return "flex justify-center" if calendar
    return "grid grid-cols-[minmax(0,1fr)_5.5rem] gap-1" if compact && show_time
    return "block" if compact

    "flex gap-1"
  end

  def time_container_class
    return "w-full" if calendar
    return "w-[5.5rem] shrink-0" if compact

    "w-28 shrink-0"
  end

  def date_container_class
    return "min-w-0 w-full grow mx-auto" if calendar && !show_time

    "min-w-0 grow"
  end

  def time_input_controllers
    [
      "input-select",
      ("autofocus" if visible_time_autofocus?)
    ].compact.join(" ")
  end

  def visible_time_autofocus?
    time_autofocus && !calendar
  end

  def visible_input_disabled?
    disabled || readonly
  end
end
