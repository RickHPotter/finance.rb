# frozen_string_literal: true

module Logic
  class UserBankAccounts
    def self.create(user_bank_account_params)
      user_bank_account = UserBankAccount.new(user_bank_account_params)
      _handle_creation(user_bank_account)
    end

    def self.find_by(user, conditions)
      user.user_bank_accounts
          .left_joins(:cash_transactions)
          .where(conditions)
          .group("user_bank_accounts.id")
          .order(:agency_number, :account_number)
    end

    def self.update(user_bank_account, user_bank_account_params)
      user_bank_account.assign_attributes(user_bank_account_params)
      _handle_creation(user_bank_account)
    end

    def self._handle_creation(user_bank_account)
      user_bank_account.save
      user_bank_account
    end
  end
end
