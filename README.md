# Location Tracker Backend

AWS serverless backend for the iOS Location Tracker application. Built with AWS SAM, Lambda (Ruby), DynamoDB, and API Gateway.

## Architecture

```
┌─────────────┐
│   iOS App   │
└──────┬──────┘
       │ HTTPS + API Key
       ▼
┌─────────────────────┐
│   API Gateway       │
│  /api/v1/locations  │
│  /api/v1/health     │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Lambda Functions   │
│  - SaveLocation     │
│  - HealthCheck      │
│  - QueryLocations*  │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│    DynamoDB         │
│  LocationHistory    │
└─────────────────────┘

* QueryLocations currently returns 501 (future feature)
```

## Features

- ✅ **POST /api/v1/locations** - Save location data from iOS app
- ✅ **GET /api/v1/health** - Health check endpoint
- ✅ **GET /api/v1/locations** - Query locations (stub, returns 501)
- ✅ **API Key Authentication** - Secure access control
- ✅ **Idempotent Writes** - Prevent duplicate location saves
- ✅ **Input Validation** - Validate coordinates, timestamps, etc.
- ✅ **Infinite Retention** - Keep all location data forever
- ✅ **Auto-scaling** - Serverless architecture scales automatically
- ✅ **Infrastructure as Code** - Entire stack defined in SAM template

## Prerequisites

### Required

1. **AWS Account** - You'll need an AWS account with appropriate permissions
2. **AWS CLI** - Install and configure with your credentials
   ```bash
   # Install (macOS)
   brew install awscli

   # Configure with your credentials
   aws configure
   ```

3. **AWS SAM CLI** - Serverless Application Model CLI
   ```bash
   # Install (macOS)
   brew install aws-sam-cli
   ```

### Optional (for local development/testing)

4. **Ruby 3.3** - For local Lambda testing
   ```bash
   # Check version
   ruby --version

   # Install if needed (macOS)
   brew install ruby@3.3
   ```

## Quick Start

### 1. Configure AWS Credentials

If you haven't already, configure your AWS credentials:

```bash
aws configure
```

You'll be prompted for:
- **AWS Access Key ID**: Your access key
- **AWS Secret Access Key**: Your secret key
- **Default region**: `us-east-1`
- **Default output format**: `json`

**Where to get credentials:**
1. Log into AWS Console
2. Navigate to IAM → Users → Your User → Security Credentials
3. Create Access Key if you don't have one
4. Copy the Access Key ID and Secret Access Key

### 2. Deploy to AWS

Run the deployment script:

```bash
cd location-tracker-backend

# First time deployment (interactive)
./deploy.sh --guided

# Subsequent deployments (uses saved config)
./deploy.sh
```

The script will:
1. ✅ Check prerequisites
2. ✅ Build the Lambda functions
3. ✅ Deploy to AWS (create stack, API Gateway, Lambda, DynamoDB)
4. ✅ Display your API endpoint and API key

### 3. Update iOS App

After deployment, you'll see output like:

```
API Endpoint: https://abc123xyz.execute-api.us-east-1.amazonaws.com/Prod/api/v1
API Key: AbCdEf123456789...
```

Update your iOS app's `AppConfig.swift`:

```swift
static let apiBaseURL = "https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Prod/api/v1"
```

And add API key authentication in `APIService.swift`:

```swift
func uploadLocation(_ record: LocationRecord) async throws -> Bool {
    let url = URL(string: "\(baseURL)/locations")!

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("YOUR-API-KEY", forHTTPHeaderField: "X-API-Key")  // Add this line

    // ... rest of the code
}
```

## API Reference

### POST /api/v1/locations

Save a location record.

**Request:**
```bash
curl -X POST https://YOUR-API-ENDPOINT/api/v1/locations \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR-API-KEY" \
  -d '{
    "timestamp": "2025-10-26T15:30:00Z",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "accuracy": 10.0,
    "altitude": 15.0,
    "speed": 0.0
  }'
```

**Response:**
```json
{
  "success": true,
  "message": "Location recorded",
  "locationId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Validation:**
- `timestamp`: ISO8601 format required
- `latitude`: -90 to 90
- `longitude`: -180 to 180
- `accuracy`: >= 0
- `altitude`: -500 to 10000 meters
- `speed`: >= -1

### GET /api/v1/health

Health check endpoint (no authentication required).

**Request:**
```bash
curl https://YOUR-API-ENDPOINT/api/v1/health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "LocationTracker API",
  "timestamp": "2025-10-26T15:30:00Z",
  "version": "1.0.0"
}
```

### GET /api/v1/locations (Future)

Currently returns 501 Not Implemented. Will be enabled in a future update.

**Planned features:**
- Query by date range
- Query last N days
- Pagination for large result sets
- Summary statistics

## Project Structure

```
location-tracker-backend/
├── template.yaml              # SAM infrastructure template
├── samconfig.toml            # SAM configuration
├── deploy.sh                 # Deployment script
├── README.md                 # This file
├── .gitignore
│
├── src/
│   ├── common/               # Shared modules
│   │   ├── user_helper.rb    # User ID extraction (future-proof)
│   │   ├── response_helper.rb # HTTP response helpers
│   │   └── validator.rb      # Input validation
│   │
│   ├── save_location/        # Save location Lambda
│   │   ├── app.rb
│   │   └── Gemfile
│   │
│   ├── health_check/         # Health check Lambda
│   │   ├── app.rb
│   │   └── Gemfile
│   │
│   └── query_locations/      # Query Lambda (stub)
│       ├── app.rb
│       └── Gemfile
│
└── .aws-sam/                 # Build artifacts (gitignored)
```

## DynamoDB Schema

**Table:** `LocationHistory`

**Keys:**
- Partition Key: `userId` (STRING)
- Sort Key: `timestamp` (STRING, ISO8601)

**Attributes:**
- `locationId` (STRING, UUID)
- `latitude` (NUMBER)
- `longitude` (NUMBER)
- `accuracy` (NUMBER)
- `altitude` (NUMBER)
- `speed` (NUMBER)
- `receivedAt` (STRING, ISO8601) - Server timestamp

**Indexes:**
- `locationId-index` (GSI) - For deduplication lookups

**Billing:** On-demand (pay per request)

## Multi-User Support (Future)

The architecture is designed to easily support multiple users:

### Current: Single User
```ruby
# src/common/user_helper.rb
def self.get_user_id(event)
  'user-001'  # Hardcoded
end
```

### Future: API Key Mapping
```ruby
def self.get_user_id(event)
  extract_from_api_key(event)  # Uncomment this line
end

# Add mapping
API_KEY_TO_USER_MAP = {
  'api-key-abc' => 'user-001',
  'api-key-xyz' => 'user-002'
}
```

**Steps to enable:**
1. Create multiple API keys in API Gateway
2. Uncomment the mapping code in `user_helper.rb`
3. Add API key → user ID mappings
4. Redeploy: `./deploy.sh`

## Costs

With on-demand pricing, costs scale with usage:

**Estimated monthly costs (10,000 locations/month):**
- API Gateway: $0.04
- Lambda: $0.00 (free tier)
- DynamoDB: $1.25
- CloudWatch Logs: $0.50
- **Total: ~$2/month**

Most of this is covered by AWS Free Tier for the first 12 months!

**Cost optimization tips:**
- DynamoDB auto-scales with on-demand pricing (no wasted capacity)
- Lambda only runs when called (no idle costs)
- API throttling prevents unexpected spikes

## Development

### Local Testing

Test Lambda functions locally:

```bash
# Start local API
sam local start-api

# Test health endpoint
curl http://localhost:3000/api/v1/health

# Test save location endpoint
curl -X POST http://localhost:3000/api/v1/locations \
  -H "Content-Type: application/json" \
  -d '{"timestamp":"2025-10-26T15:00:00Z","latitude":37.7749,"longitude":-122.4194,"accuracy":10,"altitude":15,"speed":0}'
```

### Invoke Functions Directly

```bash
# Build first
sam build

# Invoke SaveLocationFunction
sam local invoke SaveLocationFunction --event events/test-location.json

# Invoke HealthCheckFunction
sam local invoke HealthCheckFunction
```

### Build Only (no deployment)

```bash
./deploy.sh --build-only
```

## Monitoring

### CloudWatch Logs

View Lambda logs:

```bash
# List log groups
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/location-tracker

# Tail SaveLocation logs
sam logs -n SaveLocationFunction --stack-name location-tracker-backend --tail
```

### CloudWatch Metrics

Key metrics to monitor:
- Lambda Invocations
- Lambda Errors
- Lambda Duration
- DynamoDB ConsumedReadCapacityUnits
- DynamoDB ConsumedWriteCapacityUnits
- API Gateway 4XXError
- API Gateway 5XXError

### API Gateway Monitoring

View API usage:

```bash
aws apigateway get-usage \
  --usage-plan-id YOUR-USAGE-PLAN-ID \
  --start-date 2025-10-01 \
  --end-date 2025-10-31
```

## Troubleshooting

### Deployment Fails

**Issue:** SAM deploy fails with "Unable to locate credentials"

**Solution:** Configure AWS credentials:
```bash
aws configure
```

---

**Issue:** SAM deploy fails with "Stack already exists"

**Solution:** The stack exists but deployment failed. Either:
1. Delete the stack: `aws cloudformation delete-stack --stack-name location-tracker-backend`
2. Or use `sam deploy` again (it will update the existing stack)

---

**Issue:** Ruby bundler errors during build

**Solution:** SAM will automatically install Ruby gems. If it fails:
1. Ensure `Gemfile` exists in each Lambda function directory
2. Check SAM CLI version: `sam --version` (should be >= 1.70.0)

### API Errors

**Issue:** 403 Forbidden when calling API

**Solution:** API key missing or invalid. Ensure:
```bash
curl -H "X-API-Key: YOUR-API-KEY" https://...
```

---

**Issue:** 500 Internal Server Error

**Solution:** Check Lambda logs:
```bash
sam logs -n SaveLocationFunction --stack-name location-tracker-backend --tail
```

---

**Issue:** 400 Bad Request - validation errors

**Solution:** Check request body format:
- `timestamp` must be ISO8601: `2025-10-26T15:30:00Z`
- `latitude`/`longitude` must be numbers
- All required fields must be present

### DynamoDB Issues

**Issue:** ConditionalCheckFailedException

**Solution:** This is normal! It means a location with that timestamp already exists (idempotent behavior).

---

**Issue:** Can't find data in DynamoDB

**Solution:** Check the table:
```bash
aws dynamodb scan --table-name LocationHistory --limit 10
```

## Security

### Current Security Measures

- ✅ HTTPS enforced (API Gateway)
- ✅ API Key authentication
- ✅ Input validation
- ✅ Least-privilege IAM roles
- ✅ No public database access
- ✅ CloudWatch logging for audit trail

### Recommendations

1. **Rotate API Keys Regularly**
   ```bash
   # Create new API key
   aws apigateway create-api-key --name LocationTrackerAPIKey-2 --enabled

   # Update usage plan
   # Delete old key
   ```

2. **Enable AWS CloudTrail** (optional, for audit logs)

3. **Set up CloudWatch Alarms** for unusual activity

4. **Consider AWS WAF** if you add a web interface later

## Updating the Backend

### Code Changes

1. Make changes to Lambda function code
2. Redeploy:
   ```bash
   ./deploy.sh
   ```

### Infrastructure Changes

1. Update `template.yaml`
2. Redeploy:
   ```bash
   ./deploy.sh
   ```

SAM will create a changeset and show you what will change before deploying.

## Cleanup / Deletion

To delete all AWS resources:

```bash
aws cloudformation delete-stack --stack-name location-tracker-backend
```

**Warning:** This will delete:
- All Lambda functions
- DynamoDB table (and ALL location data)
- API Gateway
- CloudWatch logs

**Backup your data first** if you want to keep it!

## Future Enhancements

### Phase 2: Query Endpoint

Enable location querying by uncommenting code in `src/query_locations/app.rb`:

```ruby
def lambda_handler(event:, context:)
  query_locations(event, context)  # Uncomment this line
end
```

Then redeploy: `./deploy.sh`

### Phase 3: Location Summarization

Add AI-powered summarization:
1. Create new Lambda function
2. Call Claude API (Anthropic) or Amazon Bedrock
3. Generate natural language summaries of location history

### Phase 4: Multi-User Support

See "Multi-User Support" section above.

### Phase 5: Data Archival

Archive old data to S3 for cost savings:
1. Create S3 bucket
2. Add Lambda function triggered by EventBridge (monthly)
3. Export old DynamoDB records to S3
4. Optionally delete from DynamoDB

## Support

For issues or questions:
1. Check CloudWatch Logs for errors
2. Review this README
3. Check AWS SAM documentation: https://docs.aws.amazon.com/serverless-application-model/

## License

Personal use project.
