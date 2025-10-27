# frozen_string_literal: true

require 'json'

##
# ResponseHelper - Standardized HTTP response helpers
module ResponseHelper
  # Generate a successful JSON response
  #
  # @param data [Hash] Response data
  # @param status_code [Integer] HTTP status code
  # @return [Hash] Lambda response object
  def self.success(data, status_code = 200)
    {
      statusCode: status_code,
      headers: {
        'Content-Type' => 'application/json',
        'Access-Control-Allow-Origin' => '*'
      },
      body: JSON.generate(data)
    }
  end

  # Generate an error JSON response
  #
  # @param message [String, Array<String>] Error message(s)
  # @param status_code [Integer] HTTP status code
  # @return [Hash] Lambda response object
  def self.error(message, status_code = 400)
    {
      statusCode: status_code,
      headers: {
        'Content-Type' => 'application/json',
        'Access-Control-Allow-Origin' => '*'
      },
      body: JSON.generate({
        success: false,
        message: message
      })
    }
  end

  # Generate a validation error response
  #
  # @param errors [Array<String>] Validation error messages
  # @return [Hash] Lambda response object
  def self.validation_error(errors)
    error(errors, 400)
  end

  # Generate an internal server error response
  #
  # @param exception [Exception] The exception that occurred
  # @return [Hash] Lambda response object
  def self.server_error(exception)
    puts "ERROR: #{exception.class}: #{exception.message}"
    puts exception.backtrace.join("\n")

    error('Internal server error', 500)
  end
end
