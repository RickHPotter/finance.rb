# frozen_string_literal: true

class Views::UserCards::Form < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo

  include CacheHelper
  include TranslateHelper
  include ComponentsHelper

  attr_reader :current_user, :user_card, :cards

  def initialize(current_user:, user_card:, cards:)
    @current_user = current_user
    @user_card = user_card
    @cards = cards
  end

  def view_template
    turbo_frame_tag dom_id(user_card) do
      form_url = user_card.persisted? ? user_card_path(user_card) : user_cards_path

      form_with(
        model: user_card,
        url: form_url,
        id: :form,
        class: "contents text-black",
        data: { controller: "reactive-form price-mask", action: "submit->price-mask#removeMasks" }
      ) do |form|
        form.hidden_field :user_id, value: current_user.id

        div(class: "w-full mb-6") do
          form.text_field(
            :user_card_name,
            class: outdoor_input_class,
            autofocus: true,
            autocomplete: :off,
            data: { controller: "blinking-placeholder", text: model_attribute(user_card, :user_card_name) }
          )
        end

        div(class: "lg:flex lg:gap-2 w-full mb-3") do
          div(id: "hw_user_card_card_id", class: "hw-cb w-full lg:w-3/12 mb-2 wallet-icon") do
            bold_label(form, :card_id, "user_card_card_id")

            form.combobox(
              :card_id,
              cards,
              mobile_at: "360px",
              render_in: { partial: "user_cards/card" },
              include_blank: false,
              placeholder: action_attribute(:select, user_card, :card_id)
            )
          end

          div(class: "w-full lg:w-3/12 mb-2") do
            bold_label(form, :current_closing_date)

            TextField(
              form, :current_closing_date,
              type: :date, svg: :calendar, class: "font-graduate",
              min: (Date.current.prev_month.beginning_of_month - 15.days).strftime("%Y-%m-%d"),
              max: (Date.current.next_month.end_of_month + 15.days).strftime("%Y-%m-%d"),
              value: user_card.new_record? ? Date.current : user_card.calculate_reference_date(Date.current) - user_card.days_until_due_date
            )
          end

          div(class: "w-full lg:w-3/12 mb-2") do
            bold_label(form, :current_due_date)

            TextField(
              form, :current_due_date,
              type: :date, svg: :calendar, class: "font-graduate",
              min: (Date.current.prev_month.beginning_of_month - 15.days).strftime("%Y-%m-%d"),
              max: (Date.current.next_month.end_of_month + 15.days).strftime("%Y-%m-%d"),
              value: user_card.new_record? ? Date.current + 7.days : user_card.calculate_reference_date(Date.current)
            )
          end

          div(class: "w-full lg:w-2/12 mb-2") do
            bold_label(form, :min_spend)
            TextField(
              form, :min_spend,
              inputmode: :numeric, svg: :money, class: "font-graduate", onclick: "this.select();",
              data: { price_mask_target: :input, action: "input->price-mask#applyMask" }
            )
          end

          div(class: "w-full lg:w-2/12 mb-2") do
            bold_label(form, :credit_limit)

            TextField(
              form, :credit_limit,
              inputmode: :numeric, svg: :money, class: "font-graduate", onclick: "this.select();",
              data: { price_mask_target: :input, action: "input->price-mask#applyMask" }
            )
          end
        end

        bold_label(form, :active)

        div(class: "pb-3") do
          form.checkbox :active, class: "rounded-sm border-gray-300 text-indigo-600 focus:ring-indigo-500", checked: user_card.new_record? || user_card.active
        end

        unpaid_month_years = user_card.unpaid_invoices.distinct.pluck(:month, :year).to_set
        unpaid_references = user_card.references
                                     .select { |reference| unpaid_month_years.include?([ reference.month, reference.year ]) }
                                     .sort_by { |reference| [ reference.year, reference.month ] }

        if user_card.persisted? && unpaid_references.any?
          div(class: "w-full mt-8 mb-8") do
            h3(class: "text-lg font-bold mb-4") { pluralise_model(Reference, 2) }

            div(class: "rounded-lg border-1 border-slate-300 shadow-sm overflow-hidden") do
              div(class: "bg-slate-300 grid grid-cols-5 py-1 gap-1 border-b border-slate-400 font-semibold text-black font-graduate") do
                div(class: "text-center") { model_attribute(Reference, :year) }
                div(class: "text-center") { model_attribute(Reference, :month) }
                div(class: "text-center") { model_attribute(Reference, :reference_closing_date) }
                div(class: "text-center") { model_attribute(Reference, :reference_date) }
                div(class: "text-center") { I18n.t(:datatable_actions) }
              end

              unpaid_references.each_with_index do |reference, index|
                row_class = index.even? ? "bg-gray-100" : "bg-gray-200"

                div(class: "grid grid-cols-5 gap-2 border-b border-slate-200 #{row_class} hover:bg-white") do
                  div(class: "px-1 flex items-center justify-center mx-auto") { reference.year }
                  div(class: "px-1 flex items-center justify-center mx-auto") { I18n.t("date.month_names")[reference.month] }
                  div(class: "px-1 flex items-center justify-center mx-auto") { I18n.l(reference.reference_closing_date, format: :short) }
                  div(class: "px-1 flex items-center justify-center mx-auto") { I18n.l(reference.reference_date, format: :short) }
                  div(class: "flex items-center justify-center") do
                    link_to(edit_user_card_reference_path(user_card, reference), class: "text-blue-600 hover:text-blue-800 mx-2", data: { turbo_frame: :_top }) do
                      cached_icon(:pencil)
                    end
                    link_to(merge_user_card_references_path(user_card, id: reference.id), class: "text-gray-700 hover:text-gray-800 mx-2",
                                                                                          data: { turbo_frame: :_top }) do
                      cached_icon(:uturn_right)
                    end
                  end
                end
              end
            end
          end
        end

        div(class: "w-full") { render RubyUI::Button.new(type: :submit, variant: :purple) { action_model(:submit, user_card) } }

        if user_card.persisted?
          div(class: "w-full") do
            render RubyUI::Button.new(
              id: "delete_user_card_#{user_card.id}",
              type: :submit,
              variant: :destructive,
              link: user_card_path(user_card),
              data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }
            ) { action_model(:destroy, user_card) }
          end
        end

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end
end
