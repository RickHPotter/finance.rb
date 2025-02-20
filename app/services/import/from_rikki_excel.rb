# frozen_string_literal: true

module Import
  class FromRikkiExcel
    WSL_PATH = File.join("/mnt", "c", "Users", "Administrator", "Downloads", "finance.xlsx")
    LNX_PATH = File.join("/home", "lovelace", "Downloads", "finance.xlsx")

    def self.run
      delete_user

      if File.exist?(WSL_PATH)
        File.open(WSL_PATH)
      else
        File.open(LNX_PATH)
      end => file_path

      xlsx_service = Import::XlsxService.new(file_path)
      xlsx_service.import

      service = Import::MainService.new(xlsx_service.hash_collection, "PIX")
      service.import

      fix_user_card_dates
      set_category_colours
    rescue StandardError => e
      Rails.logger.error("ERROR: #{e.message}")
      debugger if Rails.env.development? # rubocop:disable Lint/Debugger

      raise
    end

    def self.delete_user
      user = User.find_by(first_name: "Rikki", last_name: "Potteru")
      user.destroy if user.present?
    end

    def self.fix_user_card_dates
      today = Date.current
      UserCard.where(user_card_name: %w[AZUL C6 PP AME]).update(active: false)
      UserCard.find_by(user_card_name: "CLICK").update(days_until_due_date: 6, current_due_date: Date.new(today.year, today.month, 1), current_closing_date: nil)
      UserCard.find_by(user_card_name: "NBNK").update(days_until_due_date: 7, current_due_date: Date.new(today.year, today.month, 13), current_closing_date: nil)
      UserCard.find_by(user_card_name: "WILL").update(days_until_due_date: 6, current_due_date: Date.new(today.year, today.month, 10), current_closing_date: nil)
    end

    def self.set_category_colours
      user = User.find_by(first_name: "Rikki", last_name: "Potteru")

      user.categories.find_each do |category|
        category.update(colour: RIKKI_COLOURS[category.category_name]) if RIKKI_COLOURS.key?(category.category_name)
      end
    end

    RIKKI_COLOURS = {
      "FOOD" => :meat,
      "GROCERY" => :lettuce,
      "EDUCATION" => :book,
      "RENT" => :urgency,
      "NEEDS" => :urgency,
      "GIFT" => :gift,
      "TRANSPORT" => :honda,
      "SALARY" => :gold,
      "CARD PAYMENT" => :money,
      "CARD ADVANCE" => :money,
      "CARD DISCOUNT" => :money,
      "CARD REVERSAL" => :money,
      "CARD INSTALLMENT" => :money,
      "DEPOSIT" => :money,
      "PROMO" => :money,
      "INVESTMENT" => :bronze,
      "SELL" => :oldmoney,
      "LEISURE" => :fun,
      "BILL" => :gray,
      "FEES" => :gray,
      "BET" => :silver,
      "GODSEND" => :greek,
      "EXCHANGE" => :dirt,
      "EXCHANGE RETURN" => :yellow
    }.freeze
  end
end
