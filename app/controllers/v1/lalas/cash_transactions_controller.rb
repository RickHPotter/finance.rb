# frozen_string_literal: true

module V1
  module Lalas
    class CashTransactionsController < V1::LalasController
      include TranslateHelper

      def index
        build_index_context(User.first.cash_installments)

        respond_to do |format|
          format.html do
            render Views::Lalas::CashTransactions::Index.new(index_context: @index_context)
          end

          format.turbo_stream do
            set_tabs(active_menu: :cash, active_sub_menu: :pix)
          end
        end
      end

      def month_year
        mobile = search_cash_transaction_params[:force_mobile] || @mobile
        month_year = search_cash_transaction_params[:month_year]
        month_year_str = I18n.l(Date.parse("#{month_year[0..3]}-#{month_year[4..]}-01"), format: "%B %Y")

        cash_installments, = Logic::CashTransactions.find_by_ref_month_year(User.first, cash_transaction_params, search_cash_transaction_params)

        render Views::Lalas::CashTransactions::MonthYear.new(mobile:, month_year:, month_year_str:, cash_installments:)
      end

      def build_index_context(cash_installments) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        min_date = cash_installments.minimum("MAKE_DATE(installments.year, installments.month, 1)") || Time.zone.today
        max_date = cash_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)") || Time.zone.today
        default_active_month_years = [ Time.zone.today.clamp(min_date, max_date).strftime("%Y%m").to_i ]
        years = (min_date.year..max_date.year)

        category_id = User.first.categories.where(category_name: [ "EXCHANGE RETURN", "BORROW RETURN" ]).ids
        entity_id = User.first.entities.where(entity_name: "LALA").ids
        user_bank_account_id = [ cash_transaction_params[:user_bank_account_id] ].flatten&.compact_blank
        search_term = search_cash_transaction_params[:search_term]
        paid = ActiveModel::Type::Boolean.new.cast(search_cash_transaction_params[:paid])
        pending = ActiveModel::Type::Boolean.new.cast(search_cash_transaction_params[:pending])
        skip_budgets = search_cash_transaction_params[:skip_budgets]
        force_mobile = search_cash_transaction_params[:force_mobile]

        active_month_years = params[:active_month_years] ? JSON.parse(params[:active_month_years]).map(&:to_i) : default_active_month_years
        default_year = (active_month_years.max.to_s.first(4) || params[:default_year])&.to_i || [ max_date, Time.zone.today ].min.year

        count_by_month_year = Logic::CashTransactions.find_count_based_on_search(
          User.first,
          cash_transaction_params.merge(category_id:, entity_id:),
          search_cash_transaction_params
        )

        @index_context = {
          current_user: User.first,
          years:,
          default_year:,
          active_month_years:,
          search_term:,
          category_id:,
          entity_id:,
          user_bank_account_id:,
          user_card: @user_card,
          paid:,
          pending:,
          skip_budgets:,
          force_mobile:,
          count_by_month_year:
        }
      end

      private

      def cash_transaction_params
        return {} if params[:cash_transaction].blank?

        params.require(:cash_transaction).permit(
          %i[id description comment date month year price paid user_id user_bank_account_id category_id entity_id],
          user_bank_account_id: [], category_id: [], entity_id: [],
          category_transactions_attributes: %i[id category_id _destroy],
          cash_installments_attributes: %i[id number date month year price _destroy],
          entity_transactions_attributes: [
            :id, :entity_id, :is_payer, :price, :price_to_be_returned, :_destroy,
            { exchanges_attributes: %i[id number exchange_type bound_type price _destroy] }
          ]
        )
      end

      def search_cash_transaction_params
        params.permit(
          %i[
            search_term
            paid
            pending
            month_year
            skip_budgets
            force_mobile
          ]
        )
      end
    end
  end
end
