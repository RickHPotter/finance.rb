# frozen_string_literal: true

MONTHS_FULL = %w[Janvier Fevrier Mars Avril Mai June Jui Aout Septembre Octobre Novembre Decembre].freeze
MONTHS_ABBR = %w[Jan Fev Mars Avril Mai June Jui Août Sept Oct Nov Dec].freeze

def yo
  User.destroy_all

  # file_path = File.open(File.join("/mnt", "c", "Users", "Administrator", "Downloads", "finance.xlsx"))
  file_path = File.open(File.join("/home", "lovelace", "Downloads", "finance.xlsx"))

  xlsx_service = Import::XlsxService.new(file_path)
  xlsx_service.import

  service = Import::MainService.new(xlsx_service.hash_collection, "PIX")
  service.import
end
