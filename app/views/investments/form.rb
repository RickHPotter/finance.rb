# frozen_string_literal: true

class Views::Investments::Form < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :current_user, :user_card, :investment, :user_bank_accounts

  def initialize(current_user:, investment:)
    @current_user = current_user
    @investment = investment

    set_user_bank_accounts
  end

  def view_template
    turbo_frame_tag dom_id @investment do
      form_with(
        model: investment,
        id: :investment_form,
        class: "contents text-black",
        data: { controller: "price-mask", action: "submit->price-mask#removeMasks" }
      ) do |form|
        form.hidden_field :user_id, value: current_user.id

        div(class: "w-full mb-6") do
          form.text_field :description,
                          class: outdoor_input_class,
                          autofocus: true,
                          autocomplete: :off,
                          value: investment.new_record? ? model_attribute(investment, :description_placeholder) : investment.description,
                          data: { controller: "blinking-placeholder", text: model_attribute(investment, :description) }
        end

        div(class: "lg:flex lg:gap-2 w-full pb-3") do
          div(id: "hw_investment_user_bank_account_id", class: "hw-cb w-full lg:w-4/12 mb-3 lg:mb-0 wallet-icon") do
            form.combobox \
              :user_bank_account_id,
              @user_bank_accounts,
              mobile_at: "360px",
              include_blank: false,
              placeholder: model_attribute(investment, :user_bank_account_id),
              data: { reactive_form_target: :input,
                      action: "hw-combobox:selection->reactive-form#requestSubmit",
                      value: ".hw-combobox__input" }
          end

          div(class: "w-full lg:w-4/12 mb-3 lg:mb-0") do
            TextField \
              form, :date,
              id: :investment_date,
              type: :date, svg: :calendar,
              value: investment.date.to_date || Time.zone.today,
              class: "font-graduate",
              data: { reactive_form_target: :dateInput }
          end

          div(class: "w-full lg:w-4/12 mb-3 lg:mb-0") do
            TextField \
              form, :price,
              inputmode: :numeric,
              svg: :money,
              id: :transaction_price,
              class: "font-graduate",
              data: { price_mask_target: :input,
                      reactive_form_target: :priceInput,
                      action: "input->price-mask#applyMask" }
          end
        end

        div(class: "w-full") do
          Button(type: :submit, variant: :purple) { action_model(:submit, investment) }
        end

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end
end
