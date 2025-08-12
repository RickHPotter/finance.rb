# frozen_string_literal: true

class Views::Lalas::Index < Views::Base
  def view_template
    div(class: "w-full") do
      div(class: "flex justify-center mb-10") do
        div(class: "w-screen") do
          turbo_frame_tag :tabs do
            render partial "shared/tabs"
          end
        end
      end

      div(class: "mx-1 break-words bg-white shadow-md shadow-red-50 rounded-lg") do
        div(class: "p-1 md:p-2 lg:p-3") do
          div(class: "hidden relative", data: { controller: "price-sum" }) do
            div(
              class: [
                "absolute", "-top-8", "right-0", "p-2", "rounded-t-lg", "bg-yellow-400", "shadow-md", "border",
                "border-yellow-600", "font-lekton", "font-bold", "text-black", "text-md", "z-50"
              ]
            ) do
              span(id: :totalPriceSum)
            end
          end

          div(class: "text-center text-black pt-2") do
            turbo_frame_tag :center_container
          end
        end
      end
    end
  end
end
