# frozen_string_literal: true

class Views::Investments::Form < Views::Base
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag

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
        class: "contents text-slate-100",
        data: { controller: "reactive-form price-mask", reactive_form_quick_jump_value: true, action: "submit->price-mask#removeMasks" }
      ) do |form|
        form.hidden_field :user_id, value: current_user.id
        form.hidden_field :duplicate

        div(class: "mb-6 w-full") do
          form.text_field :description,
                          class: outdoor_input_class,
                          autocomplete: :off,
                          value: investment.new_record? ? model_attribute(investment, :description_placeholder) : investment.description,
                          data: description_data(autofocus_target)
        end

        div(id: "investment_piggy_bank_return_combobox", class: "combobox-shell mb-3 w-full piggy-bank-icon") do
          render Views::Shared::SingleSelectCombobox.new(
            name: "investment[piggy_bank_return_cash_transaction_id]",
            options: piggy_bank_return_options,
            selected_value: investment.piggy_bank_return_cash_transaction_id,
            placeholder: model_attribute(investment, :piggy_bank_return_cash_transaction_id),
            include_blank: true,
            disabled: investment.persisted?
          )
        end

        div(class: "w-full pb-3 lg:flex lg:gap-2") do
          div(id: "investment_user_bank_account_combobox", class: "combobox-shell w-full lg:w-3/12 mb-3 lg:mb-0 wallet-icon") do
            render Views::Shared::SingleSelectCombobox.new(
              name: "investment[user_bank_account_id]",
              options: @user_bank_accounts,
              selected_value: investment.user_bank_account_id,
              placeholder: model_attribute(investment, :user_bank_account_id)
            )
          end

          div(id: "investment_investment_type_combobox", class: "combobox-shell w-full lg:w-3/12 mb-3 lg:mb-0 plus-icon",
              data: { reactive_form_target: :investmentTypeCombobox }) do
            render Views::Shared::SingleSelectCombobox.new(
              name: "investment[investment_type_id]",
              options: @investment_types,
              selected_value: investment.investment_type_id,
              placeholder: model_attribute(investment, :investment_type_id)
            )
          end

          div(class: "w-full lg:w-3/12 mb-3 lg:mb-0") do
            render Views::Shared::DatetimeInput.new(
              form:,
              field: :date,
              value: investment.date || Time.zone.now,
              id: :investment_date,
              show_time: false,
              hidden_data: { reactive_form_target: :dateInput },
              autofocus: autofocus_target == :date,
              calendar: mobile?
            )
          end

          div(class: "w-full lg:w-3/12 mb-3 lg:mb-0") do
            TextField \
              form, :price,
              inputmode: :numeric,
              svg: :money,
              id: :transaction_price,
              class: "font-graduate dark:font-mono",
              data: price_data(autofocus_target)
          end
        end

        div(class: "w-full") do
          div(class: "flex w-full flex-col gap-3") do
            unless investment.persisted?
              hidden_field_tag(:next_day, "1") if next_day_duplicate_requested?

              render Views::Transactions::ChainControls.new(
                mode: chain_mode,
                record_ids: chain_record_ids,
                checked: chain_checked?
              )
            end

            div(class: "grid grid-cols-1 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center gap-2 mx-auto w-full") do
              Button(type: :submit, class: "w-64 #{submit_button_class(form_action_mode(investment))}") { action_message(:submit) }

              unless investment.persisted?
                Button(type: :submit, variant: :outline, class: secondary_action_button_class, name: "finish_chain", value: "1") do
                  action_message(:finish_chain)
                end

                Button(type: :submit, variant: :outline, class: secondary_action_button_class, name: "finish_chain_without_save",
                       value: "1") do
                  action_message(:finish_chain_without_save)
                end
              end

              if investment.persisted?
                Button(
                  link: duplicate_investment_path(investment),
                  class: "min-w-64 #{duplicate_button_class}",
                  data: { turbo_frame: "_top" }
                ) do
                  action_message(:duplicate)
                end

                LinkWithConfirmation(
                  id: investment.id,
                  text: action_message(:destroy),
                  link_params: {
                    href: investment_path(investment),
                    id: "delete_investment_#{investment.id}",
                    variant: :outline,
                    class: "min-w-64 #{destroy_button_class}",
                    data: { turbo_method: :delete }
                  }
                )
              end
            end
          end
        end

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end

  private

  def piggy_bank_return_options
    open_returns = CashTransaction.open_piggy_bank_returns_for(user: current_user, context: current_context)
    if investment.piggy_bank_return_cash_transaction.present? && open_returns.exclude?(investment.piggy_bank_return_cash_transaction)
      open_returns << investment.piggy_bank_return_cash_transaction
    end

    open_returns.uniq.sort_by { |transaction| [ transaction.description.downcase, transaction.date, transaction.id ] }.map do |transaction|
      entity_name = transaction.entities.first&.entity_name
      label = [ transaction.description, entity_name, I18n.l(transaction.date, format: :short) ].compact_blank.join(" - ")
      [ label, transaction.id ]
    end
  end

  def description_data(autofocus_target)
    data = { controller: "blinking-placeholder", text: model_attribute(investment, :description) }
    return data unless autofocus_target == :description

    data.merge(autofocus_focus_data)
  end

  def price_data(autofocus_target)
    data = {
      controller: "input-select",
      price_mask_target: :input,
      reactive_form_target: :priceInput,
      action: "click->input-select#select input->price-mask#applyMask"
    }
    return data unless autofocus_target == :price

    autofocus_data = autofocus_focus_data(select: true)
    data.merge(
      autofocus_data,
      controller: [ data[:controller], autofocus_data[:controller] ].join(" ")
    )
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

  def next_day_duplicate_requested? = ActiveModel::Type::Boolean.new.cast(params[:next_day])

  def chain_record_ids
    chain_context&.dig(:record_ids) || []
  end

  def chain_checked?
    chain_context&.dig(:checked) || false
  end

  def secondary_action_button_class
    secondary_submit_row_button_class
  end
end
