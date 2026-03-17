# frozen_string_literal: true

class Views::Subscriptions::Form < Views::Base
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::FormWith
  include Views::Transactions

  include TranslateHelper
  include ComponentsHelper
  include ContextHelper

  attr_reader :current_user, :subscription

  def initialize(current_user:, subscription:)
    @current_user = current_user
    @subscription = subscription

    set_categories
    set_entities
    set_user_cards
    set_user_bank_accounts
  end

  def view_template
    turbo_frame_tag dom_id(subscription) do
      div(class: "flex h-full min-h-full flex-col",
          data: { controller: "subscription-transactions", subscription_transactions_locale_value: current_user.locale || I18n.locale }) do
        form_with(model: subscription, id: :form, class: "contents text-black",
                  data: { action: "input->subscription-transactions#recalculatePrice" }) do |form|
          div(class: "flex flex-1 flex-col") do
            form.hidden_field :user_id, value: current_user.id
            form.hidden_field :price, value: subscription.price, data: { subscription_transactions_target: "totalPriceInput" }

            render Views::Transactions::FormIntroFields.new(
              form:,
              transaction: subscription,
              description_class: outdoor_input_class
            )

            div(class: "mb-6 w-full lg:flex lg:gap-2") do
              div(id: "hw_subscription_category_id", class: "hw-cb mb-3 w-full plus-icon lg:mb-0 lg:w-1/3") do
                form.combobox \
                  :category_id,
                  @categories,
                  mobile_at: "360px",
                  include_blank: true,
                  placeholder: model_attribute(subscription, :category_id)
              end

              div(id: "hw_subscription_entity_id", class: "hw-cb mb-3 w-full user-icon lg:mb-0 lg:w-1/3") do
                form.combobox \
                  :entity_id,
                  @entities,
                  mobile_at: "360px",
                  include_blank: true,
                  placeholder: model_attribute(subscription, :entity_id)
              end

              div(id: "hw_subscription_status", class: "hw-cb w-full status-icon lg:w-1/3") do
                form.combobox \
                  :status,
                  Subscription.statuses.keys.map { |status| [ model_attribute(Subscription, "statuses.#{status}"), status ] },
                  mobile_at: "360px",
                  include_blank: false,
                  placeholder: model_attribute(subscription, :status)
              end
            end

            transactions_section(form:)

            div(class: "pt-4 grid w-full grid-cols-1 items-center justify-items-center gap-2 sm:grid-flow-col sm:auto-cols-fr") do
              Button(
                type: :submit,
                variant: :purple,
                class: "w-64"
              ) { action_model(:submit, subscription) }

              if subscription.persisted? && subscription.can_be_destroyed?
                Button(
                  id: "delete_subscription_#{subscription.id}",
                  type: :submit,
                  variant: :destructive,
                  link: subscription_path(subscription),
                  data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }
                ) { action_model(:destroy, subscription) }
              end
            end

            form.submit "Update", class: "opacity-0 pointer-events-none"
          end
        end

        render Views::Subscriptions::AddTransactionModal.new(
          user_cards: @user_cards,
          user_bank_accounts: @user_bank_accounts,
          user_card_options: subscription_modal_user_card_options
        )
      end
    end
  end

  private

  def transactions_section(form:)
    section(class: "flex flex-1 flex-col") do
      div(class: "mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between") do
        div(class: "flex items-center gap-3") do
          h3(class: "text-lg font-semibold text-slate-900") do
            model_attribute(Subscription, :transactions_count).upcase
          end

          span(class: "rounded-full bg-slate-100 px-3 py-1 text-sm font-semibold text-slate-600") do
            subscription.transactions_count
          end

          span(class: "rounded-full bg-slate-100 px-3 py-1 text-sm font-semibold text-slate-600") do
            span(data: { subscription_transactions_target: "totalPriceDisplay" }) do
              from_cent_based_to_float(subscription.price, "R$")
            end
          end
        end

        div(class: "flex gap-2") do
          button(
            type: :button,
            class: next_transaction_button_class,
            disabled: ordered_transactions.empty?,
            data: {
              action: "subscription-transactions#openNextModal",
              subscription_transactions_target: "nextButton"
            }
          ) { I18n.t("navigation.next") }

          button(
            type: :button,
            class: "py-2 px-3 rounded-sm border border-sky-900 bg-blue-600 hover:bg-blue-800 transition-colors text-white shadow-lg font-thin",
            data: { action: "subscription-transactions#openCustomModal" }
          ) { action_message(:new) }
        end
      end

      div(
        class: "min-h-[14rem] max-h-[14rem] flex-1 space-y-2 overflow-y-auto border-1 border-slate-200 bg-white/80 p-3 shadow-inner",
        style: "scrollbar-width: thin; scrollbar-color: #94a3b8 #e2e8f0;",
        data: {
          controller: "nested-form",
          nested_form_wrapper_selector_value: ".nested-form-wrapper"
        }
      ) do
        template(data: { kind: :cash, nested_form_target: :template, subscription_transactions_target: :template }) do
          form.fields_for :cash_transactions, CashTransaction.new(user: current_user), child_index: "NEW_RECORD" do |cash_transaction_fields|
            render Views::Subscriptions::CashTransactionFields.new(form: cash_transaction_fields, user_bank_accounts: @user_bank_accounts)
          end
        end

        template(data: { kind: :card, nested_form_target: :template, subscription_transactions_target: :template }) do
          form.fields_for :card_transactions, CardTransaction.new(user: current_user), child_index: "NEW_RECORD" do |card_transaction_fields|
            render Views::Subscriptions::CardTransactionFields.new(form: card_transaction_fields, user_cards: @user_cards)
          end
        end

        div(class: "space-y-3", data: { nested_form_target: :target, subscription_transactions_target: "target" }) do
          ordered_transactions.each do |transaction|
            if transaction.is_a?(CashTransaction)
              form.fields_for :cash_transactions, transaction do |cash_transaction_fields|
                render Views::Subscriptions::CashTransactionFields.new(form: cash_transaction_fields, user_bank_accounts: @user_bank_accounts)
              end
            else
              form.fields_for :card_transactions, transaction do |card_transaction_fields|
                render Views::Subscriptions::CardTransactionFields.new(form: card_transaction_fields, user_cards: @user_cards)
              end
            end
          end
        end
      end
    end
  end

  def ordered_transactions
    subscription.transactions.sort_by { |transaction| [ transaction.year.to_i, transaction.month.to_i, transaction.date, transaction.description.to_s ] }.reverse
  end

  def next_transaction_button_class
    "rounded-sm border border-emerald-800 bg-emerald-600 px-3 py-2 font-thin text-white shadow-lg transition-colors hover:bg-emerald-700 disabled:cursor-not-allowed disabled:border-slate-300 disabled:bg-slate-200 disabled:text-slate-500 disabled:shadow-none"
  end

  def subscription_modal_user_card_options
    current_user.user_cards.active.order(:user_card_name).map do |user_card|
      [
        user_card.user_card_name,
        user_card.id,
        {
          "data-due-date-day": user_card.due_date_day,
          "data-days-until-due-date": user_card.days_until_due_date
        }
      ]
    end
  end
end
