# frozen_string_literal: true

# rubocop:disable Layout/LineLength

# Helper for Components
module ComponentsHelper
  # @return [String] tailwind class for input.
  #
  def input_class
    "block w-full ps-12 p-2.5 border-1 border-gray-300 focus:ring-1 focus:ring-indigo-600 rounded-md shadow-sm outline-none appearance-none bg-gray-700 dark:bg-white text-white dark:text-gray-900"
  end

  # @return [String] tailwind class for autosave input.
  #
  def autosave_input_class
    "mx-2 mb-4 text-gray-900 text-center text-ellipsis text-4xl sm:text-5xl lg:text-6xl leading-10 sm:leading-none font-extrabold border-0 focus:border-0 focus:ring-0 focus:outline-none sm:tracking-tight"
  end

  # @return [String] tailwind class for label.
  #
  def label_class
    "block mb-2 text-sm font-medium dark:text-gray-900 text-white"
  end

  # @return [String] tailwind class for form button.
  #
  def form_button_class(options)
    "flex w-full py-2 px-4 justify-center transition duration-500 hover:scale-[1.01] rounded-md border
    #{options[:colour][:border]} #{options[:colour][:bg]} text-sm font-medium #{options[:colour][:text]}
    shadow-sm #{options[:colour][:hover][:bg]} #{options[:colour][:hover][:text]} focus:outline-none"
  end
end

# rubocop:enable Layout/LineLength
