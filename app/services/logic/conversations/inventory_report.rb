# frozen_string_literal: true

class Logic::Conversations::InventoryReport
  Issue = Data.define(:code, :record_type, :record_ids, :details)

  attr_reader :conversation_count, :generated_at, :issues, :message_count

  def initialize(conversation_count:, message_count:, issues:, generated_at: Time.current)
    @conversation_count = conversation_count
    @message_count = message_count
    @issues = issues.freeze
    @generated_at = generated_at
  end

  def clean?
    issues.empty?
  end

  def summary
    issues.group_by(&:code).transform_values(&:count).sort.to_h
  end

  def to_text
    lines = [
      "Conversation/message inventory at #{generated_at.iso8601}",
      "Conversations: #{conversation_count}",
      "Messages: #{message_count}",
      "Issues: #{issues.count}"
    ]
    lines << "No issues found." if clean?
    lines.concat(issues.map { |issue| issue_line(issue) })
    lines.join("\n")
  end

  private

  def issue_line(issue)
    ids = issue.record_ids.join(",")
    details = issue.details.map { |key, value| "#{key}=#{value.inspect}" }.join(" ")
    "[#{issue.code}] #{issue.record_type} ids=#{ids} #{details}".rstrip
  end
end
