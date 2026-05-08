# frozen_string_literal: true

class Views::Shared::DatetimeInput < Views::Base
  include ComponentsHelper
  include CacheHelper

  attr_reader :form, :field, :value, :id, :hidden_data, :date_data, :time_data, :date_actions, :time_actions, :autofocus, :disabled, :max_datetime,
              :max_datetime_message, :show_time

  def initialize(form:, field:, value:, id:, **options)
    @form = form
    @field = field
    @value = value
    @id = id
    @hidden_data = options.fetch(:hidden_data, {})
    @date_data = options.fetch(:date_data, {})
    @time_data = options.fetch(:time_data, {})
    @date_actions = Array(options.fetch(:date_actions, []))
    @time_actions = Array(options.fetch(:time_actions, []))
    @autofocus = options.fetch(:autofocus, false)
    @disabled = options.fetch(:disabled, false)
    @max_datetime = options.fetch(:max_datetime, nil)
    @max_datetime_message = options.fetch(:max_datetime_message, nil)
    @show_time = options.fetch(:show_time, true)
  end

  def view_template
    div(
      class: "w-full",
      data: {
        controller: "datetime-input",
        datetime_input_invalid_time_message_value: I18n.t("datetime_input.invalid_time"),
        datetime_input_max_datetime_value: max_datetime&.strftime("%Y-%m-%dT%H:%M"),
        datetime_input_max_datetime_message_value: max_datetime_message || I18n.t("datetime_input.invalid_max")
      }
    ) do
      raw form.hidden_field(
        field,
        id:,
        value: formatted_datetime,
        class: "transaction-date",
        disabled:,
        data: { datetime_input_target: "hiddenInput" }.merge(hidden_data)
      )

      div(class: "flex gap-1") do
        div(class: "min-w-0 grow") do
          div(class: "relative") do
            div(class: "absolute inset-y-0 start-0 flex items-center ps-3.5 pointer-events-none z-1") do
              cached_icon :calendar
            end

            input(
              type: "date",
              id: "#{id}_date_input",
              value: date_value,
              disabled:,
              autofocus: autofocus,
              aria: { label: I18n.t("datetime_input.date") },
              class: "#{input_class} datetime-input-date font-graduate",
              data: {
                datetime_input_target: "dateInput",
                controller: ("autofocus" if autofocus),
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

          p(
            class: "mt-0.5 min-h-4 px-1 text-2xs leading-4 font-graduate text-muted-foreground",
            data: { datetime_input_target: "weekdayLabel" }
          )
        end

        if show_time
          div(class: "w-28 shrink-0") do
            div(class: "relative") do
              div(class: "absolute inset-y-0 start-0 flex items-center ps-3.5 pointer-events-none z-1") do
                cached_icon :clock
              end

              input(
                type: "text",
                id: "#{id}_time_input",
                value: time_value,
                disabled:,
                inputmode: "numeric",
                autocomplete: "off",
                placeholder: "20:20",
                maxlength: 5,
                aria: { label: I18n.t("datetime_input.time") },
                class: "#{input_class} text-center font-graduate",
                data: {
                  controller: "input-select",
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
          end
        end
      end
    end
  end

  private

  def formatted_datetime
    value&.strftime("%Y-%m-%dT%H:%M")
  end

  def date_value
    value&.strftime("%Y-%m-%d")
  end

  def time_value
    value&.strftime("%H:%M")
  end
end
