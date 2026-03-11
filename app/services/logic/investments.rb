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
          .includes(:user_bank_account, :investment_type)
          .where(investment_params)
          .where("description ILIKE ?", "%#{search_term}%")
          .where("year = ? AND month = ?", year, month)
          .order(:date)
    end

    def self.find_count_based_on_search(user, investment_params, search_investment_params)
      search_term = search_investment_params.delete(:search_term) || ""

      if investment_params.is_a?(Hash)
        investment_params.except("date", "price")
      else
        investment_params.to_unsafe_h.except("date", "price")
      end => params

      params.filter! do |_, value|
        value = value.compact_blank if value.is_a?(Array) || value.is_a?(Hash)

        value.present?
      end

      relation = user.investments
                     .where(params)
                     .where("description ILIKE ?", "%#{search_term}%")

      relation = relation.distinct.select("investments.id, investments.month, investments.year")

      relation.group_by { |record| Date.new(record.year, record.month, 1).strftime("%Y%m").to_i }
    end
  end
end
