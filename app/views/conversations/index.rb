# frozen_string_literal: true

class Views::Conversations::Index < Views::Base
  attr_reader :conversations

  def initialize(conversations:)
    @conversations = conversations
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "mx-1 break-words bg-white shadow-md shadow-red-50 rounded-lg") do
        div(class: "p-1 md:p-2 lg:p-3") do
          div(class: "text-center text-black pt-2") do
            @conversations.each do |conversation|
              turbo_stream_from conversation
            end
          end
        end
      end
    end
  end
end
