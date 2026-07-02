# frozen_string_literal: true

class Views::CashTransactions::Index < Views::Base
  include Views::CashTransactions
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag

  include CacheHelper
  include TranslateHelper

  attr_reader :index_context, :current_user, :mobile

  def initialize(index_context: {}, mobile: false)
    @index_context = index_context || {}
    @current_user = @index_context[:current_user]
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag :center_container do
      div class: "w-full" do
        div class: "min-w-full" do
          turbo_frame_tag :cash_transactions do
            div class: "min-h-screen", data: { controller: "datatable", datatable_locale_value: I18n.locale } do
              div class: "mb-8 flex sm:flex-row gap-4 items-start sm:items-center justify-between bg-white p-4 rounded-lg shadow-sm" do
                render IndexSearchForm.new(url: cash_transactions_path, index_context:, mobile:)
              end

              render PayMultipleModal.new(index_context:)
              render PartialPayMultipleModal.new(index_context:)
              render TransferMultipleModal.new(index_context:)
              render Views::Shared::AddToSubscriptionModal.new(
                modal_id: "cashTransactionsAddToSubscriptionModal",
                url: add_to_subscription_cash_transactions_path,
                index_context:,
                subscriptions: available_subscriptions
              )
              render MonthYearContainer.new(index_context: index_context.slice(:search_term, :category_id, :entity_id,
                                                                               :from_ct_price, :to_ct_price, :from_price, :to_price,
                                                                               :from_installments_count, :to_installments_count,
                                                                               :exchange_bound_type, :paid, :pending, :paid_state,
                                                                               :from_date, :to_date,
                                                                               :user_bank_account_id, :active_month_years, :skip_budgets, :sort, :direction))

              BulkActionBar(
                selected_label: action_message(:selected),
                actions: [
                  {
                    name: "pay",
                    title: model_attribute(CashInstallment, :pay),
                    label: model_attribute(CashInstallment, :pay),
                    disabled_reason: I18n.t("bulk_actions.disabled.pay"),
                    menu_items: [
                      {
                        label: model_attribute(CashInstallment, :pay),
                        data: {
                          action: "click->datatable#prepareBulkAction",
                          modal_target: "cashInstallmentsModal",
                          modal_toggle: "cashInstallmentsModal"
                        }
                      },
                      {
                        label: action_message(:partial_pay),
                        data: {
                          action: "click->datatable#prepareBulkAction",
                          modal_target: "cashInstallmentsPartialModal",
                          modal_toggle: "cashInstallmentsPartialModal"
                        }
                      }
                    ]
                  },
                  {
                    name: "transfer",
                    title: model_attribute(CashInstallment, :transfer),
                    label: model_attribute(CashInstallment, :transfer),
                    disabled_reason: I18n.t("bulk_actions.disabled.transfer"),
                    data: { action: "click->datatable#prepareBulkAction", modal_target: "transferMultipleModal", modal_toggle: "transferMultipleModal" }
                  },
                  {
                    name: "subscription",
                    ids_kind: "record",
                    title: action_message(:add_to_subscription),
                    label: action_message(:add_to_subscription),
                    disabled_reason: I18n.t("bulk_actions.disabled.subscription"),
                    base_disabled: available_subscriptions.empty?,
                    base_disabled_reason: I18n.t("bulk_actions.no_subscriptions_available"),
                    data: {
                      action: "click->datatable#prepareBulkAction",
                      modal_target: "cashTransactionsAddToSubscriptionModal",
                      modal_toggle: "cashTransactionsAddToSubscriptionModal"
                    }
                  }
                ]
              )
              render_budget_bulk_forms
              render_budget_bulk_action_bar
            end

            render Views::Shared::MobileFloatingNav.new(new_href: new_cash_transaction_path(format: :turbo_stream))
          end
        end
      end
    end
  end

  private

  def available_subscriptions
    Array(index_context[:available_subscriptions])
  end

  def render_budget_bulk_forms
    budget_bulk_actions.each_key do |action|
      form_with url: bulk_update_budgets_path, method: :patch, class: "hidden", data: { turbo: true }, id: "bulk_budget_#{action}_form" do
        hidden_field_tag :ids, "", data: { bulk_ids_input: true, bulk_ids_kind: "budget" }
        hidden_field_tag :bulk_action, action
        hidden_field_tag :return_to, request.fullpath
      end
    end

    form_with url: bulk_destroy_budgets_path, method: :delete, class: "hidden", data: { turbo: true }, id: "bulk_budget_destroy_form" do
      hidden_field_tag :ids, "", data: { bulk_ids_input: true, bulk_ids_kind: "budget" }
      hidden_field_tag :return_to, request.fullpath
    end
  end

  def render_budget_bulk_action_bar
    BulkActionBar(
      selected_label: action_message(:selected),
      selection_kind: "budget",
      actions: [
        *budget_bulk_action_groups.map do |group|
          {
            name: group[:name],
            ids_kind: "budget",
            selection_kind: "budget",
            title: group[:title],
            label: group[:label],
            menu_items: group[:actions].map do |action, attrs|
              {
                label: attrs[:label],
                title: attrs[:title],
                data: { action: "click->datatable#submitBulkAction", bulk_form_id: "bulk_budget_#{action}_form" }
              }
            end
          }
        end,
        {
          name: "destroy",
          ids_kind: "budget",
          selection_kind: "budget",
          title: I18n.t("bulk_actions.budgets.destroy_title"),
          label: action_message(:destroy),
          data: { action: "click->datatable#submitBulkAction", bulk_form_id: "bulk_budget_destroy_form" }
        }
      ]
    )
  end

  def budget_bulk_action_groups
    [
      {
        name: "exclusivity",
        label: I18n.t("bulk_actions.budgets.exclusivity"),
        title: I18n.t("bulk_actions.budgets.exclusivity_title"),
        actions: budget_bulk_actions.slice(:make_inclusive, :make_exclusive)
      },
      {
        name: "installments",
        label: I18n.t("bulk_actions.budgets.installments"),
        title: I18n.t("bulk_actions.budgets.installments_title"),
        actions: budget_bulk_actions.slice(:first_installment_only, :all_installments)
      }
    ]
  end

  def budget_bulk_actions
    {
      make_inclusive: {
        label: I18n.t("bulk_actions.budgets.make_inclusive"),
        title: I18n.t("bulk_actions.budgets.make_inclusive_title")
      },
      make_exclusive: {
        label: I18n.t("bulk_actions.budgets.make_exclusive"),
        title: I18n.t("bulk_actions.budgets.make_exclusive_title")
      },
      first_installment_only: {
        label: I18n.t("bulk_actions.budgets.first_installment_only"),
        title: I18n.t("bulk_actions.budgets.first_installment_only_title")
      },
      all_installments: {
        label: I18n.t("bulk_actions.budgets.all_installments"),
        title: I18n.t("bulk_actions.budgets.all_installments_title")
      }
    }
  end
end
