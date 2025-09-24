# frozen_string_literal: true

class Views::Conversations::Show < Views::Base
  register_value_helper :current_user
  attr_reader :conversation

  include Phlex::Rails::Helpers::TurboStreamFrom
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include TranslateHelper

  def initialize(conversation:)
    @conversation = conversation
  end

  def view_template
    div(class: "w-full") do
      participants = conversation.users
      friend = participants.where.not(id: current_user.id).first

      turbo_frame_tag :center_container do
        div(class: "mx-1 break-words bg-white shadow-md shadow-red-50 rounded-lg") do
          div(class: "p-1 md:p-2 lg:p-3") do
            div(class: "text-center text-black pt-2") do
              div(class: "flex justify-between flex-col h-[75vh] bg-white rounded-lg shadow-md overflow-hidden", data: { controller: :chat }) do
                div(class: "flex p-4 bg-slate-200 border-b border-slate-300") do
                  image_tag(asset_path("avatars/dogs/10.png"), class: "w-6 h-6 rounded-full")
                  h2(class: "flex-1 text-lg font-semibold text-gray-800") { "#{model_attribute(conversation, :chat_with)} #{friend.first_name}" }
                  image_tag(asset_path("avatars/dogs/16.png"), class: "w-6 h-6 rounded-full")
                end

                div(class: "flex-1 overflow-y-auto p-4 space-y-2 bg-slate-100", id: "messages_#{conversation.id}", data: { chat_target: :scroll }) do
                  turbo_stream_from conversation
                  render Views::Messages::Index.new(messages: conversation.messages.order(:created_at))
                end

                div(class: "p-3 bg-slate-200 border-t border-slate-300") do
                  render Views::Messages::Form.new(conversation:)
                end
              end
            end
          end
        end
      end
    end
  end
end
