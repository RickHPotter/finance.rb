# frozen_string_literal: true

module Import
  class FromRikkiExcel
    VPS_FILE = File.join("./", "vps-only", "finance.xlsx")
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
      new(VPS_FILE).run
    end

    def run
      delete_user

      xlsx_service = Import::XlsxService.new(@file)
      xlsx_service.import

      service = Import::MainService.new(xlsx_service.hash_collection, "PIX")
      service.import

      aftermath_fix
      create_budgets
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
      UserCard.find_by(user_card_name: "C6").update(active: false, card: Card.find_by(card_name: "C6"))
      UserCard.find_by(user_card_name: "PP").update(active: false, card: Card.find_by(card_name: "PICPAY"))
      UserCard.find_by(user_card_name: "AME").update(active: false, card: Card.find_by(card_name: "AME"))
      UserCard.find_by(user_card_name: "AZUL").update(due_date_day: 8, days_until_due_date: 6, active: false, card: Card.find_by(card_name: "ITAU"))
      UserCard.find_by(user_card_name: "WILL").update(due_date_day: 10, days_until_due_date: 6, card: Card.find_by(card_name: "WILL"))
      UserCard.find_by(user_card_name: "CLICK").update(due_date_day: 1, days_until_due_date: 6, card: Card.find_by(card_name: "ITAU"))
      UserCard.find_by(user_card_name: "MELIUZ").update(due_date_day: 1, days_until_due_date: 7, card: Card.find_by(card_name: "MELIUZ"))
      UserCard.find_by(user_card_name: "NBNK").update(due_date_day: 13, days_until_due_date: 7, card: Card.find_by(card_name: "NUBANK"))
    end

    def fix_missing_references
      @user.user_cards.find_each do |user_card|
        month_years = user_card.card_installments_invoices.pluck(:month, :year).uniq

        month_years.each do |month, year|
          next if user_card.references.exists?(month: month, year: year)

          card_payment = user_card.card_installments_invoices.find_by(month:, year:)
          next if card_payment.nil?

          reference_date = user_card.calculate_reference_date(card_payment.date)
          user_card.references.create(month: month, year: year, reference_date: reference_date)
        end
      end
    end

    def fix_card_payment_dates
      beginning_of_month = Date.current.beginning_of_month
      end_of_an_era = Date.new(3000, 12, 31)

      @user.user_cards.find_each do |user_card|
        user_card.card_installments_invoices.where(date: beginning_of_month..end_of_an_era).find_each do |card_payment|
          reference = user_card.references.find_by(month: card_payment.month, year: card_payment.year)
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

    def create_budgets
      food_category = @user.categories.find_by(category_name: "FOOD")
      transport_category = @user.categories.find_by(category_name: "TRANSPORT")
      needs_category = @user.categories.find_by(category_name: "NEEDS")

      budgets = @user.budgets
      budgets.create(month: 4, year: 2025, value: -45_000, inclusive: false, description: "FOOD", categories: [ food_category ])
      budgets.create(month: 5, year: 2025, value: -16_200, inclusive: false, description: "FOOD", categories: [ food_category ])
      budgets.create(month: 5, year: 2025, value: -958_00, inclusive: false, description: "TRANSPORT", categories: [ transport_category ])
      budgets.create(month: 6, year: 2025, value: -16_200, inclusive: false, description: "FOOD", categories: [ food_category ])
      budgets.create(month: 6, year: 2025, value: -958_00, inclusive: false, description: "TRANSPORT", categories: [ transport_category ])

      start_date = Date.new(2025, 7, 1)
      (0..8).each do |index|
        date = start_date + index.months
        month = date.month
        year = date.year

        budgets.create(month:, year:, value: -30_000, inclusive: false, description: "FOOD", categories: [ food_category ])
        budgets.create(month:, year:, value: -1_458_00, inclusive: false, description: "TRANSPORT", categories: [ transport_category ])
        budgets.create(month:, year:, value: -70_000, inclusive: false, description: "NEEDS", categories: [ needs_category ])
      end
    end
  end
end
