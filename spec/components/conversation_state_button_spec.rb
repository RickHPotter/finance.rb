# frozen_string_literal: true

require "rails_helper"

RSpec.describe Components::ConversationStateButton, type: :component do
  it "renders a compact button link without link decoration" do
    button = render_component(action: :mute, href: "/conversations/thread/mute", label: "Mute")

    expect(button.name).to eq("a")
    expect(button["href"]).to eq("/conversations/thread/mute")
    expect(button["class"]).to include("min-h-8", "no-underline", "hover:no-underline", "border-violet-300")
    expect(button["class"]).not_to include("hover:underline")
    expect(button["data-conversation-action"]).to eq("mute")
    expect(button["aria-label"]).to eq("Mute")
  end

  it "gives active restoration controls a distinct treatment" do
    unmute = render_component(action: :unmute, href: "/conversations/thread/unmute", label: "Unmute")
    unarchive = render_component(action: :unarchive, href: "/conversations/thread/unarchive", label: "Restore")

    expect(unmute["class"]).to include("bg-violet-600", "text-white")
    expect(unarchive["class"]).to include("bg-sky-50", "text-sky-800")
  end

  it "rejects an unknown state action" do
    expect do
      described_class.new(action: :delete, href: "/conversations/thread", label: "Delete")
    end.to raise_error(ArgumentError, "invalid conversation state action")
  end

  def render_component(**attributes)
    Nokogiri::HTML.fragment(described_class.new(**attributes).call).at_css("a")
  end
end
