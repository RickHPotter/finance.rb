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

    def self.find_ref_month_year_by_params(user, investment_params, search_investment_params)
      month_year = search_investment_params.delete(:month_year)
      year = month_year[0..3]
      month = month_year[4..]
      search_term = search_investment_params.delete(:search_term) || ""

      user.investments
          .where(investment_params)
          .where("description ILIKE ?", "%#{search_term}%")
          .where("year = ? AND month = ?", year, month)
          .order(:date)
    end
  end
end
