# frozen_string_literal: true

MONTHS_FULL = %w[Janvier Fevrier Mars Avril Mai June Jui Août Septembre Octobre Novembre Decembre].freeze
MONTHS_ABBR = %w[Jan Fev Mars Avril Mai June Jui Août Sept Oct Nov Dec].freeze

def import_from_excel
  User.find_by(first_name: "Rikki", last_name: "Potteru").destroy

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
end
