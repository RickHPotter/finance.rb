# frozen_string_literal: true

class Views::CardTransactions::Index < Views::Base
  include Views::CardTransactions

  include CacheHelper
  include TranslateHelper

  attr_reader :index_context, :current_user, :user_card, :search, :url, :mobile

  def initialize(index_context: {}, search: false, mobile: false)
    @index_context = index_context
    @current_user = index_context[:current_user]
    @user_card = index_context[:user_card]
    @search = search
    @mobile = mobile
  end

  def view_template
    @url = search ? search_card_transactions_path : card_transactions_path

    turbo_frame_tag :center_container do
      div class: "w-full" do
        div class: "min-w-full" do
          turbo_frame_tag :card_transactions do
            div class: "min-h-screen", data: { controller: "datatable", datatable_locale_value: I18n.locale } do
              div class: "mb-8 flex sm:flex-row gap-4 items-start sm:items-center justify-between bg-white p-4 rounded-lg shadow-sm" do
                render IndexSearchForm.new(url:, index_context:, mobile:)
              end

              render Views::Shared::AddToSubscriptionModal.new(
                modal_id: "cardTransactionsAddToSubscriptionModal",
                url: add_to_subscription_card_transactions_path,
                index_context:,
                subscriptions: available_subscriptions
              )
              render MonthYearContainer.new(index_context: index_context.slice(:search_term, :category_id, :entity_id,
                                                                               :from_ct_price, :to_ct_price, :from_price, :to_price,
                                                                               :from_installments_count, :to_installments_count,
                                                                               :user_card, :active_month_years, :sort, :direction, :order_by))

              BulkActionBar(
                selected_label: action_message(:selected),
                actions: [
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
                      modal_target: "cardTransactionsAddToSubscriptionModal",
                      modal_toggle: "cardTransactionsAddToSubscriptionModal"
                    }
                  }
                ]
              )
            end

            render Views::Shared::MobileFloatingNav.new(new_href: new_card_transaction_path(user_card_id: user_card&.id, format: :turbo_stream))
          end
        end
      end
    end
  end

  private

  def available_subscriptions
    Array(index_context[:available_subscriptions])
  end
end
