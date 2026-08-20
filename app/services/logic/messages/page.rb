# frozen_string_literal: true

class Logic::Messages::Page
  DEFAULT_SIZE = 40
  MAX_SIZE = 100
  Result = Data.define(:records, :next_cursor)

  attr_reader :scope, :cursor, :size, :selector

  def self.call(...)
    new(...).call
  end

  def initialize(scope:, cursor: nil, size: DEFAULT_SIZE, selector: nil)
    @scope = scope
    @cursor = cursor
    @size = normalize_size(size)
    @selector = selector || ->(_message) { true }
  end

  def call
    matching_rows = matching_rows_after_cursor
    has_more = matching_rows.length > size
    records = matching_rows.first(size)

    Result.new(records: records.reverse, next_cursor: has_more ? cursor_for(records.last) : nil)
  end

  private

  def matching_rows_after_cursor
    records = []
    batch_cursor = cursor

    loop do
      batch = batch_after(batch_cursor)
      records.concat(batch.select(&selector))
      break if records.length > size || batch.length < batch_size

      batch_cursor = cursor_for(batch.last)
    end

    records.first(size + 1)
  end

  def batch_after(value)
    relation = scope.reorder(created_at: :desc, id: :desc)
    if value.present?
      decoded = Logic::KeysetCursor.load(value)
      relation = relation.where(
        "messages.created_at < :timestamp OR (messages.created_at = :timestamp AND messages.id < :id)",
        timestamp: decoded.timestamp,
        id: decoded.id
      )
    end
    relation.limit(batch_size).to_a
  end

  def batch_size
    [ size * 2, MAX_SIZE ].min
  end

  def cursor_for(message)
    Logic::KeysetCursor.dump(timestamp: message.created_at, id: message.id)
  end

  def normalize_size(value)
    Integer(value).clamp(1, MAX_SIZE)
  rescue ArgumentError, TypeError
    DEFAULT_SIZE
  end
end
