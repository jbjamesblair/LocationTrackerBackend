# frozen_string_literal: true

##
# UserHelper - Centralized user identification logic
#
# Currently returns a hardcoded user ID, but designed to easily switch
# to dynamic user identification in the future.
#
# Future migration options:
# 1. API Key mapping: Map API keys to user IDs
# 2. Request header: Extract from X-User-Id header
# 3. Request body: Include userId/deviceId in payload
# 4. AWS Cognito: Extract from authenticated identity
module UserHelper
  # Get user ID from the Lambda event
  # Currently returns hardcoded value, but single point of change for future
  #
  # @param event [Hash] Lambda event object
  # @return [String] User identifier
  def self.get_user_id(event)
    # Phase 1: Hardcoded single user (CURRENT)
    ENV['USER_ID'] || 'user-001'

    # Phase 2 (FUTURE): Uncomment one of these approaches:
    # extract_from_api_key(event)
    # extract_from_header(event)
    # extract_from_body(event)
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

  # FUTURE: Extract user ID from request body
  # Requires iOS app to send userId/deviceId in payload
  #
  # @param event [Hash] Lambda event object
  # @return [String] User identifier
  def self.extract_from_body(event)
    body = JSON.parse(event['body'] || '{}')
    body['userId'] || body['deviceId'] || 'user-001'
  rescue JSON::ParserError
    'user-001'
  end

  # FUTURE: API Key to User mapping
  # Replace with actual mappings when you create multiple API keys
  API_KEY_TO_USER_MAP = {
    # 'api-key-123' => 'user-001',
    # 'api-key-456' => 'user-002',
  }.freeze
end
