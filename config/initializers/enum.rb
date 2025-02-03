# frozen_string_literal: true

MONTHS_FULL = %w[Janvier Fevrier Mars Avril Mai June Jui Août Septembre Octobre Novembre Decembre].freeze
MONTHS_ABBR = %w[Jan Fev Mars Avril Mai June Jui Août Sept Oct Nov Dec].freeze

def import_from_excel
  user = User.find_by(first_name: "Rikki", last_name: "Potteru")
  user.destroy if user.present?

  wsl = File.join("/mnt", "c", "Users", "Administrator", "Downloads", "finance.xlsx")
  lnx = File.join("/home", "lovelace", "Downloads", "finance.xlsx")

  if File.exist?(wsl)
    File.open(wsl)
  else
    File.open(lnx)
  end => file_path

  xlsx_service = Import::XlsxService.new(file_path)
  xlsx_service.import

  service = Import::MainService.new(xlsx_service.hash_collection, "PIX")
  service.import

  today = Date.current
  UserCard.where(user_card_name: %w[AZUL C6 PP AME]).update(active: false)
  UserCard.find_by(user_card_name: "CLICK").update(days_until_due_date: 6, current_due_date: Date.new(today.year, today.month, 1), current_closing_date: nil)
  UserCard.find_by(user_card_name: "NBNK").update(days_until_due_date: 7, current_due_date: Date.new(today.year, today.month, 13), current_closing_date: nil)
  UserCard.find_by(user_card_name: "WILL").update(days_until_due_date: 6, current_due_date: Date.new(today.year, today.month, 10), current_closing_date: nil)
end
