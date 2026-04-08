# frozen_string_literal: true

class Views::Shared::DatetimeInput < Views::Base
  include ComponentsHelper
  include CacheHelper

  attr_reader :form, :field, :value, :id, :hidden_data, :autofocus, :disabled

  def initialize(form:, field:, value:, id:, **options)
    @form = form
    @field = field
    @value = value
    @id = id
    @hidden_data = options.fetch(:hidden_data, {})
    @autofocus = options.fetch(:autofocus, false)
    @disabled = options.fetch(:disabled, false)
  end

  def view_template
    div(
      class: "w-full",
      data: {
        controller: "datetime-input",
        datetime_input_invalid_time_message_value: I18n.t("datetime_input.invalid_time")
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
        div(class: "relative min-w-0 grow") do
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
              action: "change->datetime-input#sync"
            }
          )
        end

        div(class: "relative w-28 shrink-0") do
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
              datetime_input_target: "timeInput",
              action: "input->datetime-input#formatTimeInput blur->datetime-input#sync change->datetime-input#sync keydown->datetime-input#handleKeydown"
            }
          )
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
