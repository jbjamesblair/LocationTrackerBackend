# frozen_string_literal: true

require 'json'

##
# HealthCheck Lambda Handler
#
# Simple health check endpoint that returns 200 OK
# Used by iOS app to verify server is reachable
def lambda_handler(event:, context:)
  puts "Health check request received"

  {
    statusCode: 200,
    headers: {
      'Content-Type' => 'application/json',
      'Access-Control-Allow-Origin' => '*'
    },
    body: JSON.generate({
      status: 'healthy',
      service: 'LocationTracker API',
      timestamp: Time.now.utc.iso8601,
      version: '1.0.0'
    })
  }
end
