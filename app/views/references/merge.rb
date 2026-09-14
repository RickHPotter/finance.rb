# frozen_string_literal: true

class Views::References::Merge < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :reference, :user_card, :return_to, :merge_mode, :historical_correction_confirmation

  def initialize(reference:, user_card:, return_to: "/user_cards", merge_mode: nil, historical_correction_confirmation: false)
    @reference = reference
    @user_card = user_card
    @return_to = return_to
    @merge_mode = merge_mode
    @historical_correction_confirmation = ActiveModel::Type::Boolean.new.cast(historical_correction_confirmation)
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "rounded-lg bg-white p-3 text-slate-900 shadow-md dark:bg-slate-950 dark:text-slate-100 sm:p-4") do
        h1(class: "mb-4 text-xl font-bold sm:text-2xl") { action_model(:merge, Reference, 2) }

        form_with(url: perform_merge_user_card_references_path(user_card), method: :post, data: { turbo: true, controller: "reference-merge" }) do |form|
          hidden_field_tag :return_to, return_to

          div(class: "grid grid-cols-1 gap-4 sm:grid-cols-2") do
            div(class: "mb-4") do
              form.label :source_reference_date, model_attribute(Reference, :source_reference_date),
                         class: "block text-sm font-medium text-slate-700 dark:text-slate-300"
              TextFieldTag(
                :source_reference_date,
                type: :month,
                svg: :calendar,
                class: "font-graduate",
                value: source_reference_value,
                data: { reference_merge_target: "source", action: "change->reference-merge#syncModeAvailability" }
              )
            end

            div(class: "mb-4") do
              form.label :target_reference_date, model_attribute(Reference, :target_reference_date),
                         class: "block text-sm font-medium text-slate-700 dark:text-slate-300"
              TextFieldTag(
                :target_reference_date,
                type: :month,
                svg: :calendar,
                class: "font-graduate",
                value: target_reference_value,
                data: { reference_merge_target: "target", action: "change->reference-merge#syncModeAvailability" }
              )
            end
          end

          merge_mode_fields(form)
          historical_correction_confirmation_field(form)

          div(class: "flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between") do
            form.submit action_model(:merge, Reference, 2),
                        class: primary_action_classes,
                        data: { turbo_frame: "_top", turbo_action: "replace" }

            link_to I18n.t("confirmation.cancel"),
                    user_card_edit_destination,
                    class: secondary_action_classes
          end
        end
      end
    end
  end

  private

  def merge_mode_fields(form)
    fieldset(class: "mb-6 rounded-lg border border-slate-300 bg-white p-4 dark:border-slate-700 dark:bg-slate-950") do
      legend(class: "px-1 text-sm font-semibold text-slate-900 dark:text-slate-100") { I18n.t("references.merge.mode_legend") }
      p(class: "mb-3 text-sm text-slate-600 dark:text-slate-400") { I18n.t("references.merge.mode_hint") }

      div(class: "grid gap-3 md:grid-cols-2") do
        Logic::References::MERGE_MODES.each { |mode| merge_mode_field(form, mode) }
      end

      next if reference.errors[:merge_mode].blank?

      p(class: "mt-2 text-sm text-red-600 dark:text-red-400", role: "alert") { reference.errors.full_messages_for(:merge_mode).to_sentence }
    end
  end

  def merge_mode_field(form, mode)
    id = "reference_merge_mode_#{mode}"

    label(
      for: id,
      class: "flex cursor-pointer items-start gap-3 rounded-md border border-slate-300 p-3 text-sm text-slate-800 " \
             "has-checked:border-sky-600 has-checked:bg-sky-50 dark:border-slate-700 dark:text-slate-100 dark:has-checked:bg-slate-800",
      data: mode == Logic::References::REALLOCATE_INSTALLMENTS ? { reference_merge_target: "reallocateLabel" } : {}
    ) do
      input_data = mode == Logic::References::REALLOCATE_INSTALLMENTS ? { reference_merge_target: "reallocate" } : {}
      raw form.radio_button(:merge_mode, mode, id:, checked: merge_mode == mode, required: true, class: "mt-0.5 accent-sky-600", data: input_data)

      span do
        strong(class: "block") { I18n.t("references.merge.modes.#{mode}.label") }
        small(class: "mt-1 block text-xs text-slate-500 dark:text-slate-400") { I18n.t("references.merge.modes.#{mode}.hint") }
      end
    end
  end

  def historical_correction_confirmation_field(form)
    label(
      for: "historical_correction_confirmation",
      class: "mb-6 flex items-start gap-3 rounded-md border border-amber-300 bg-amber-50 p-3 text-sm text-amber-950 " \
             "dark:border-amber-700 dark:bg-amber-950/40 dark:text-amber-100"
    ) do
      raw form.check_box(
        :historical_correction_confirmation,
        { id: "historical_correction_confirmation", checked: historical_correction_confirmation, class: "mt-0.5 accent-amber-600" },
        "1",
        "0"
      )

      span do
        strong(class: "block") { I18n.t("references.merge.historical_confirmation.label") }
        small(class: "mt-1 block text-xs text-amber-800 dark:text-amber-200") { I18n.t("references.merge.historical_confirmation.hint") }
      end
    end
  end

  def user_card_edit_destination
    return edit_user_card_path(user_card) if return_to == "/user_cards"

    edit_user_card_path(user_card, return_to:)
  end

  def source_reference_value
    reference.source_reference_date.presence || reference.reference_date.strftime("%Y-%m")
  end

  def target_reference_value
    reference.target_reference_date.presence || reference.reference_date.next_month.strftime("%Y-%m")
  end

  def primary_action_classes
    "inline-flex w-full justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm " \
      "hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 dark:focus:ring-offset-slate-950 sm:w-auto"
  end

  def secondary_action_classes
    "inline-flex w-full justify-center rounded-md border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 shadow-sm " \
      "hover:bg-slate-50 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800 sm:w-auto"
  end
end
