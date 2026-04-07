# frozen_string_literal: true

class Views::Investments::Form < Views::Base
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::FormWith

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :current_user, :user_card, :investment, :user_bank_accounts, :investment_types, :chain_context

  def initialize(current_user:, investment:, chain_context: nil)
    @current_user = current_user
    @investment = investment
    @chain_context = chain_context

    set_user_bank_accounts
    set_investment_types
  end

  def which_target_to_autofocus
    return :price if investment.duplicate
    return :price if params[:next_day]
    return :description if investment.user_bank_account.nil?

    :price
  end

  def view_template
    autofocus_target = which_target_to_autofocus

    turbo_frame_tag dom_id investment do
      form_with(
        model: investment,
        id: :investment_form,
        class: "contents text-black",
        data: { controller: "price-mask", action: "submit->price-mask#removeMasks" }
      ) do |form|
        form.hidden_field :user_id, value: current_user.id
        form.hidden_field :duplicate

        div(class: "w-full mb-6") do
          form.text_field :description,
                          class: outdoor_input_class,
                          autocomplete: :off,
                          value: investment.new_record? ? model_attribute(investment, :description_placeholder) : investment.description,
                          data: description_data(autofocus_target)
        end

        div(class: "lg:flex lg:gap-2 w-full pb-3") do
          div(id: "investment_user_bank_account_combobox", class: "combobox-shell w-full lg:w-3/12 mb-3 lg:mb-0 wallet-icon") do
            render Views::Shared::SingleSelectCombobox.new(
              name: "investment[user_bank_account_id]",
              options: @user_bank_accounts,
              selected_value: investment.user_bank_account_id,
              placeholder: model_attribute(investment, :user_bank_account_id)
            )
          end

          div(id: "investment_investment_type_combobox", class: "combobox-shell w-full lg:w-3/12 mb-3 lg:mb-0 plus-icon") do
            render Views::Shared::SingleSelectCombobox.new(
              name: "investment[investment_type_id]",
              options: @investment_types,
              selected_value: investment.investment_type_id,
              placeholder: model_attribute(investment, :investment_type_id)
            )
          end

          div(class: "w-full lg:w-3/12 mb-3 lg:mb-0") do
            TextField \
              form, :date,
              id: :investment_date,
              type: :date, svg: :calendar,
              value: investment.date.to_date || Time.zone.today,
              class: "font-graduate",
              data: { reactive_form_target: :dateInput }
          end

          div(class: "w-full lg:w-3/12 mb-3 lg:mb-0") do
            TextField \
              form, :price,
              inputmode: :numeric,
              svg: :money,
              id: :transaction_price,
              class: "font-graduate",
              onclick: "this.select();",
              data: price_data(autofocus_target)
          end
        end

        div(class: "w-full") do
          div(class: "flex w-full flex-col gap-3") do
            unless investment.persisted?
              render Views::Transactions::ChainControls.new(
                mode: chain_mode,
                record_ids: chain_record_ids,
                checked: chain_checked?
              )
            end

            div(class: "grid grid-cols-1 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center gap-2 mx-auto w-full") do
              Button(type: :submit, variant: :purple, class: "w-64") { action_model(:submit, investment) }

              unless investment.persisted?
                Button(type: :submit, variant: :outline, class: "w-64", name: "finish_chain", value: "1") do
                  action_message(:finish_chain)
                end

                Button(type: :submit, variant: :outline, class: "w-64", name: "finish_chain_without_save", value: "1") do
                  action_message(:finish_chain_without_save)
                end
              end

              if investment.persisted?
                Button(link: duplicate_investment_path(investment), class: "min-w-64", data: { turbo_frame: "_top" }) do
                  action_message(:duplicate)
                end
              end
            end
          end
        end

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end

  private

  def description_data(autofocus_target)
    data = { controller: "blinking-placeholder", text: model_attribute(investment, :description) }
    return data unless autofocus_target == :description

    data.merge(autofocus_focus_data)
  end

  def price_data(autofocus_target)
    data = {
      price_mask_target: :input,
      reactive_form_target: :priceInput,
      action: "input->price-mask#applyMask"
    }
    return data unless autofocus_target == :price

    data.merge(autofocus_focus_data(select: true))
  end

  def autofocus_focus_data(select: false)
    {
      controller: "autofocus",
      autofocus_select_value: select
    }
  end

  def chain_mode
    chain_context&.dig(:mode) || (investment.duplicate ? "duplicate" : "create")
  end

  def chain_record_ids
    chain_context&.dig(:record_ids) || []
  end

  def chain_checked?
    chain_context&.dig(:checked) || false
  end
end
