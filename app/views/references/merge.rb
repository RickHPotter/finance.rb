# frozen_string_literal: true

class Views::References::Merge < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :reference, :user_card, :return_to, :merge_mode

  def initialize(reference:, user_card:, return_to: "/user_cards", merge_mode: nil)
    @reference = reference
    @user_card = user_card
    @return_to = return_to
    @merge_mode = merge_mode
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "bg-white p-4 shadow-md rounded-lg") do
        h1(class: "text-2xl font-bold mb-4") { action_model(:merge, Reference, 2) }

        form_with(url: perform_merge_user_card_references_path(user_card), method: :post, data: { turbo: true, controller: "reference-merge" }) do |form|
          hidden_field_tag :return_to, return_to

          div(class: "grid grid-cols-2 gap-4") do
            div(class: "mb-4") do
              form.label :source_reference_date, model_attribute(Reference, :source_reference_date), class: "block text-sm font-medium text-gray-700"
              TextFieldTag(
                :source_reference_date,
                type: :month,
                svg: :calendar,
                class: "font-graduate",
                value: reference.reference_date.strftime("%Y-%m"),
                data: { reference_merge_target: "source", action: "change->reference-merge#syncModeAvailability" }
              )
            end

            div(class: "mb-4") do
              form.label :target_reference_date, model_attribute(Reference, :target_reference_date), class: "block text-sm font-medium text-gray-700"
              TextFieldTag(
                :target_reference_date,
                type: :month,
                svg: :calendar,
                class: "font-graduate",
                value: reference.reference_date.next_month.strftime("%Y-%m"),
                data: { reference_merge_target: "target", action: "change->reference-merge#syncModeAvailability" }
              )
            end
          end

          merge_mode_fields(form)

          div(class: "flex items-center justify-between") do
            form.submit action_model(:merge, Reference, 2),
                        class: "inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md
                                text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500",
                        data: { turbo_frame: "_top", turbo_action: "replace" }

            link_to I18n.t("confirmation.cancel"),
                    user_card_edit_destination,
                    class: "py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
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
      raw form.radio_button(:merge_mode, mode, id:, checked: merge_mode == mode, required: true, data: input_data)

      span do
        strong(class: "block") { I18n.t("references.merge.modes.#{mode}.label") }
        small(class: "mt-1 block text-xs text-slate-500 dark:text-slate-400") { I18n.t("references.merge.modes.#{mode}.hint") }
      end
    end
  end

  def user_card_edit_destination
    return edit_user_card_path(user_card) if return_to == "/user_cards"

    edit_user_card_path(user_card, return_to:)
  end
end
