# frozen_string_literal: true

MONTHS_FULL = %w[Janvier Fevrier Mars Avril Mai June Jui Aout Septembre Octobre Novembre Decembre].freeze
MONTHS_ABBR = %w[Jan Fev Mars Avril Mai June Jui Août Sept Oct Nov Dec].freeze

def yo
  # User.destroy_all

  xls_service = Import::Xls.new(File.open(File.join("/home", "lovelace", "Downloads", "finance.xlsx")))
  xls_service.import

  hash_service = Import::CardTransactionImport.new(xls_service.hash_collection, "PIX")
  hash_service.import
end
