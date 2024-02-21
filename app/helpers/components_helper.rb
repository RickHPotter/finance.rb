# frozen_string_literal: true

# rubocop:disable Layout/LineLength

# Helper for Components
module ComponentsHelper
  # @return [String] tailwind class for input
  #
  def input_class
    "peer border-1 shadow-md outline-none w-full px-2.5 pb-2.5 pt-3 appearance-none text-sm text-gray-900 transition-all focus:ring-1 focus:ring-indigo-600"
  end

  # @return [String] tailwind class for label
  #
  def label_class
    "absolute top-1 px-2 z-10 bg-white text-sm text-gray-500 duration-300 transform -translate-y-4 scale-75 origin-[0] start-1 peer-focus:text-indigo-600 peer-focus:top-1 peer-focus:scale-100 peer-focus:-translate-y-4 peer-placeholder-shown:scale-100 peer-placeholder-shown:-translate-y-1/2 peer-placeholder-shown:top-2 peer-placeholder-shown:text-sm"
  end

  # @return [String] tailwind class for form button
  #
  def form_button_class(options)
    "flex w-full py-2 px-4 justify-center transition duration-500 hover:scale-[1.01] rounded-md border
    #{options[:colour][:border]} #{options[:colour][:bg]} text-sm font-medium #{options[:colour][:text]}
    shadow-sm #{options[:colour][:hover][:bg]} #{options[:colour][:hover][:text]} focus:outline-none"
  end
end

# rubocop:enable Layout/LineLength
