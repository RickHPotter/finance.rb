# frozen_string_literal: true

module Logic
  class Investments
    def self.create(investment_params)
      investment = Investment.new(investment_params)
      _handle_creation(investment)
    end

    def self.update(investment, investment_params)
      investment.assign_attributes(investment_params)
      _handle_creation(investment)
    end

    def self._handle_creation(investment)
      investment.save
      investment
    end

    def self.find_ref_month_year_by_params(user, params)
      params = params.symbolize_keys
      month_year = params.delete(:month_year)
      year = month_year[0..3]
      month = month_year[4..]
      search_term = params.delete(:search_term) || ""

      conditions = build_conditions_from_params(params)

      user.investments
          .where(conditions)
          .where("description ILIKE ?", "%#{search_term}%")
          .where("year = ? AND month = ?", year, month)
          .order(:date)
    end

    def self.build_conditions_from_params(params)
      params.delete(:controller)
      params.delete(:action)

      return {} if params.blank?

      params[:user_bank_account_id] = params.delete(:user_bank_account_ids)

      params.compact_blank
    end
  end
end
