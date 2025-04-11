# frozen_string_literal: true

module Logic
  class Investments
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

      associations = build_conditions_for_associations(params)

      { **params.compact_blank, **associations.compact_blank }.compact_blank
    end

    def self.build_conditions_for_associations(params)
      user_bank_account_id = (params.delete(:user_bank_account_id) || params.delete(:user_bank_account_ids) || {}).compact_blank

      {
        user_bank_accounts: { id: user_bank_account_id }.compact_blank
      }.compact_blank
    end
  end
end
