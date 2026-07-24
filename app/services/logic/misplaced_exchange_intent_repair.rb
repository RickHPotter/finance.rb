# frozen_string_literal: true

class Logic::MisplacedExchangeIntentRepair
  attr_reader :message_ids, :source

  def initialize(source:, message_ids:)
    @source = source
    @message_ids = Array(message_ids).compact_blank.map(&:to_i).uniq
  end

  def call
    updated_message_count = 0
    CashTransaction.transaction do
      source.update!(friend_notification_intent: "reimbursement")
      updated_message_count = rewrite_message_intents!
    end

    {
      source_id: source.id,
      updated_message_count:
    }
  end

  private

  def rewrite_message_intents!
    Message.where(id: message_ids).count do |message|
      headers = parsed_headers_for(message)
      next false if headers.blank?

      headers["intent"] = "reimbursement" if headers.key?("intent")
      headers["replay"]["intent"] = "reimbursement" if headers["replay"].is_a?(Hash)
      message.update!(headers: headers.to_json)
      true
    end
  end

  def parsed_headers_for(message)
    JSON.parse(message.headers.to_s)
  rescue JSON::ParserError
    nil
  end
end
