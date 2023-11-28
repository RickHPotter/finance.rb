# frozen_string_literal: true

# Helpers for CardTransactions
# @TODO: Something needs to be done here
module CardTransactionsHelper
  NOTICE = {
    create: 'Card Transaction created successfully',
    update: 'Card Transaction updated successfully',
    delete: 'Card Transaction deleted successfully',
    error: 'Something went wrong'
  }.freeze

  def notice_stream(message:, status:)
    turbo_stream.replace 'notice', partial: 'notice', locals: { notice: NOTICE[message], status: }
  end

  def form_card_transaction_stream(card_transaction:)
    turbo_stream.replace 'form', partial: 'form', locals: { card_transaction: }
  end
end
