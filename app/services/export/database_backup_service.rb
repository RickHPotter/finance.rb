# frozen_string_literal: true

require "zip"

module Export
  class DatabaseBackupService
    BACKUP_DIR = Rails.root.join("storage", "backups")

    attr_reader :path

    def initialize(user)
      @user = user
      @path = BACKUP_DIR.join("backup_#{@user.id}_#{Time.zone.today}.xlsx")
      @workbook = WriteXLSX.new(@path)
    end

    def run!
      export_fixed_data
      export_user_data
      export_budgets
      export_transactions
      export_final

      @workbook.close
    end

    def export_fixed_data
      export_table(Bank.all, "Banks")
      export_table(Card.all, "Cards")
    end

    def export_user_data
      export_table(UserCard.where(user_id: @user.id), "UserCard")
      export_table(UserBankAccount.where(user_id: @user.id), "UserBankAccount")
      export_table(Category.where(user_id: @user.id), "Categories")
      export_table(Entity.where(user_id: @user.id), "Entities")
    end

    def export_budgets
      export_table(Budget.includes(:budget_categories, :budget_entities), "Budgets")
      export_table(BudgetCategory.joins(:budget).where(budgets: { user_id: @user.id }), "BudgetCategories")
      export_table(BudgetEntity.joins(:budget).where(budgets: { user_id: @user.id }), "BudgetEntities")
    end

    def export_transactions
      export_table(CardTransaction.where(user_id: @user.id), "CardTransactions")
      export_table(CashTransaction.where(user_id: @user.id), "CashTransactions")

      export_table(CategoryTransaction.joins(:category).where(categories: { user_id: @user.id }), "CategoryTransactions")
      export_table(EntityTransaction.joins(:entity).where(entities: { user_id: @user.id }), "EntityTransactions")
      export_table(Exchange.joins(entity_transaction: { entity: :user }).where(entity_transactions: { entities: { user_id: @user.id } }), "Exchanges")

      export_table(CardInstallment.joins(:card_transaction).where(card_transactions: { user_id: @user.id }), "Card Installments")
      export_table(CashInstallment.joins(:cash_transaction).where(cash_transactions: { user_id: @user.id }), "Cash Installments")

      export_table(Investment.where(user_id: @user.id), "Investments")
    end

    private

    def export_table(relation, sheet_name, extra_cols = [], &block)
      sheet = @workbook.add_worksheet(sheet_name)
      records = relation.to_a
      return if records.empty?

      headers = records.first.attributes.keys + extra_cols.map(&:to_s)
      sheet.write_row(0, 0, headers)

      records.each_with_index do |record, i|
        row = record.attributes.values
        extra = block_given? ? block.call(record) : []
        sheet.write_row(i + 1, 0, row + Array(extra).flatten)
      end
    end

    def export_final # rubocop:disable Metrics/AbcSize
      sheet = @workbook.add_worksheet("CASH")

      min_date_cash = CashTransaction.order(:year, :month).first
      max_date_cash = CashTransaction.order(:year, :month).last

      min_date = Date.new(min_date_cash.year, min_date_cash.month)
      max_date = Date.new(max_date_cash.year, max_date_cash.month)

      records = []

      while min_date <= max_date
        records.concat Logic::CashInstallments.find_by_ref_month_year(@user, min_date.month, min_date.year, {})
        records.concat Logic::Budgets.find_by_ref_month_year(@user, min_date.month, min_date.year, {})

        min_date = min_date.next_month
      end

      return if records.empty?

      sheet.write_row(0, 0, records.first.attributes.keys)

      records.each_with_index do |record, i|
        sheet.write_row(i + 1, 0, record.attributes.values)
      end
    end

    def cleanup_old_backups
      return if Date.current.day.positive?

      zips = Dir[BACKUP_DIR.join("backup_#{@user.id}_*.zip")]
      to_keep = []
      grouped = zips.group_by do |f|
        Date.parse(File.basename(f).split("_")[2].to_i.to_s)
      rescue StandardError
        nil
      end

      # For each past month, keep only last-day backup; keep all backups in last two months
      grouped.each do |date, files|
        if date >= 2.months.ago.to_date.beginning_of_month
          to_keep += files
        else
          to_keep << files.max_by { |f| File.mtime(f) }
        end
      end
      to_delete = zips - to_keep
      to_delete.each { |f| FileUtils.rm_f(f) }
    end
  end
end
