# frozen_string_literal: true

##
# UserHelper - Device identification logic
#
# Extracts device identifier from request body
# Each iOS device sends its unique identifierForVendor
#
# Migration options for multi-user in the future:
# 1. API Key mapping: Map API keys to user IDs
# 2. Request header: Extract from X-User-Id header
# 3. AWS Cognito: Extract from authenticated identity
module UserHelper
  # Get device ID from the Lambda event
  # Extracts from request body (sent by iOS app)
  #
  # @param event [Hash] Lambda event object
  # @return [String] Device identifier
  def self.get_user_id(event)
    # Extract deviceId from request body
    extract_from_body(event)
  end

  # Alias for clarity - this is actually extracting device ID
  class << self
    alias get_device_id get_user_id
  end

  # FUTURE: Extract user ID from API key
  # Map each API key to a specific user
  #
  # @param event [Hash] Lambda event object
  # @return [String] User identifier
  def self.extract_from_api_key(event)
    api_key = event.dig('requestContext', 'identity', 'apiKey')
    API_KEY_TO_USER_MAP[api_key] || 'unknown'
  end

  # FUTURE: Extract user ID from request header
  #
  # @param event [Hash] Lambda event object
  # @return [String] User identifier
  def self.extract_from_header(event)
    headers = event['headers'] || {}
    # Headers are case-insensitive in API Gateway
    headers['X-User-Id'] || headers['x-user-id'] || 'user-001'
  end

  # Extract device ID from request body
  # iOS app sends deviceId in payload
  #
  # @param event [Hash] Lambda event object
  # @return [String] Device identifier
  def self.extract_from_body(event)
    body = JSON.parse(event['body'] || '{}')
    body['deviceId'] || body['userId'] || 'unknown-device'
  rescue JSON::ParserError
    'unknown-device'
  end

  # FUTURE: API Key to User mapping
  # Replace with actual mappings when you create multiple API keys
  API_KEY_TO_USER_MAP = {
    # 'api-key-123' => 'user-001',
    # 'api-key-456' => 'user-002',
  }.freeze
end
