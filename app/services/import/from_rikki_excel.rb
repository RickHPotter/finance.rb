# frozen_string_literal: true

module Import
  class FromRikkiExcel
    WSL_PATH = File.join("/mnt", "c", "Users", "Administrator", "Downloads", "finance.xlsx")
    LNX_PATH = File.join("/home", "lovelace", "Downloads", "finance.xlsx")

    def initialize(file_path = nil)
      return if file_path.blank?

      if File.exist?(file_path)
        File.open(file_path)
      else
        File.open(WSL_PATH)
      end => file

      @file = file
    end

    def self.run
      new(LNX_PATH).run
    end

    def run
      delete_user

      xlsx_service = Import::XlsxService.new(@file)
      xlsx_service.import

      service = Import::MainService.new(xlsx_service.hash_collection, "PIX")
      service.import

      aftermath_fix
    rescue StandardError => e
      Rails.logger.error("ERROR: #{e.message}")
      debugger if Rails.env.development? # rubocop:disable Lint/Debugger

      raise
    end

    def delete_user
      user = User.find_by(first_name: "Rikki", last_name: "Potteru")
      user.destroy if user.present?
    end

    def aftermath_fix
      @user = User.find_by(first_name: "Rikki", last_name: "Potteru")

      fix_user_card_dates
      fix_card_payment_dates
      set_category_colours
      correct_investment_dates
    end

    def fix_user_card_dates
      UserCard.where(user_card_name: %w[C6 PP AME]).update(active: false)
      UserCard.find_by(user_card_name: "AZUL").update(due_date_day: 8, days_until_due_date: 6, active: false)
      UserCard.find_by(user_card_name: "WILL").update(due_date_day: 10, days_until_due_date: 6)
      UserCard.find_by(user_card_name: "CLICK").update(due_date_day: 1, days_until_due_date: 6)
      UserCard.find_by(user_card_name: "NBNK").update(due_date_day: 13, days_until_due_date: 7)
    end

    def fix_card_payment_dates
      beginning_of_month = Date.current.beginning_of_month
      end_of_an_era = Date.new(3000, 12, 31)

      @user.user_cards.find_each do |user_card|
        user_card.card_installments_invoices.where(date: beginning_of_month..end_of_an_era).find_each do |card_payment|
          reference = card_payment.user_card.references.find_by(month: card_payment.month, year: card_payment.year)
          reference_date = card_payment.date.change(day: user_card.due_date_day)
          reference.update(reference_date:)

          card_payment.update(imported: true, date: reference_date)
          card_payment.cash_installments.first.update_columns(date: reference_date, paid: false)
        end
      end
    end

    def set_category_colours
      @user.categories.find_each do |category|
        category.update(colour: RIKKI_COLOURS[category.category_name]) if RIKKI_COLOURS.key?(category.category_name)
      end
    end

    def correct_investment_dates
      @user.cash_transactions.where(cash_transaction_type: "Investment").find_each do |transaction|
        date = Date.new(transaction.year, transaction.month, 1)
        transaction.update(date:)
        transaction.cash_installments.update(date:)
      end
    end
  end
end
