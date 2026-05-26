# frozen_string_literal: true

class Views::Lalas::CardTransactions::MonthYearContainer < Views::Base
  attr_reader :search_term, :card_installment_ids,
              :category_id, :entity_id,
              :from_ct_price, :to_ct_price,
              :from_price, :to_price,
              :from_installments_count, :to_installments_count,
              :user_card_id, :active_month_years,
              :force_mobile, :external_route_params, :internal_route_params

  def initialize(index_context: {})
    @search_term = index_context[:search_term]
    @card_installment_ids = index_context[:card_installment_ids]
    @category_id = index_context[:category_id]
    @entity_id = index_context[:entity_id]
    @user_card_id = index_context[:user_card]&.id
    @active_month_years = index_context[:active_month_years]
    @force_mobile = index_context[:force_mobile]
    @external_route_params = index_context[:external_route_params]
    @internal_route_params = index_context[:internal_route_params]
  end

  def view_template
    custom_params = {
      card_transaction: {
        card_installment_ids:,
        user_card_id:,
        category_id:,
        entity_id:
      },
      search_term:,
      force_mobile:
    }

    render Views::Shared::MonthYearContainer.new(
      active_month_years:,
      custom_params:,
      path_lambda: ->(params) { month_year_card_transactions_path(params) }
    )
  end

  private

  def month_year_card_transactions_path(params)
    return month_year_internal_card_transactions_path(**internal_route_params, **params) if internal_route_params.present?
    return month_year_external_card_transactions_path(**external_route_params, **params) if external_route_params.present?

    month_year_lalas_card_transactions_path(params)
  end
end
