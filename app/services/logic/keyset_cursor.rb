# frozen_string_literal: true

require "base64"
require "json"
require "time"

class Logic::KeysetCursor
  class InvalidCursor < ActiveRecord::RecordNotFound; end

  Value = Data.define(:timestamp, :id)

  def self.dump(timestamp:, id:)
    Base64.urlsafe_encode64([ timestamp.utc.iso8601(6), id ].to_json, padding: false)
  end

  def self.load(value)
    encoded = value.to_s
    encoded += "=" * ((4 - (encoded.length % 4)) % 4)
    timestamp, id = JSON.parse(Base64.urlsafe_decode64(encoded))
    parsed_id = Integer(id)
    raise InvalidCursor if parsed_id <= 0

    Value.new(timestamp: Time.iso8601(timestamp), id: parsed_id)
  rescue ArgumentError, JSON::ParserError, TypeError
    raise InvalidCursor
  end
end
