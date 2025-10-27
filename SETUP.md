# Quick Setup Guide

Get your Location Tracker backend running on AWS in ~10 minutes.

## Prerequisites Checklist

- [ ] AWS Account ([create one](https://aws.amazon.com/free/))
- [ ] AWS Access Keys (from IAM console)
- [ ] AWS CLI installed
- [ ] AWS SAM CLI installed

## Step 1: Install Prerequisites

### macOS

```bash
# Install AWS CLI
brew install awscli

# Install AWS SAM CLI
brew install aws-sam-cli

# Verify installations
aws --version
sam --version
```

### Linux

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install AWS SAM CLI
# Follow: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html
```

### Windows

```powershell
# Use MSI installers from:
# AWS CLI: https://aws.amazon.com/cli/
# AWS SAM CLI: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html
```

## Step 2: Get AWS Credentials

1. Log into [AWS Console](https://console.aws.amazon.com/)
2. Navigate to: **IAM → Users → Your User → Security Credentials**
3. Click **Create Access Key**
4. Choose **CLI** as use case
5. Copy your **Access Key ID** and **Secret Access Key**
6. **IMPORTANT:** Save these somewhere safe! You can't retrieve the secret key again.

## Step 3: Configure AWS CLI

```bash
aws configure
```

Enter when prompted:
- **AWS Access Key ID**: [paste your access key]
- **AWS Secret Access Key**: [paste your secret key]
- **Default region name**: `us-east-1`
- **Default output format**: `json`

Verify configuration:
```bash
aws sts get-caller-identity
```

You should see your AWS account ID and user ARN.

## Step 4: Deploy the Backend

```bash
cd location-tracker-backend

# First-time deployment (interactive)
./deploy.sh --guided
```

**During guided deployment, accept defaults for:**
- Stack Name: `location-tracker-backend`
- AWS Region: `us-east-1`
- Confirm changes before deploy: `Y`
- Allow SAM CLI IAM role creation: `Y`
- Disable rollback: `N`
- SaveLocationFunction has no auth defined: `Y` (we use API keys)
- Save arguments to configuration file: `Y`
- SAM configuration file: Press Enter (default)
- SAM configuration environment: Press Enter (default)

**Deployment takes ~3-5 minutes.**

## Step 5: Get Your API Endpoint and Key

After successful deployment, you'll see:

```
API Endpoint: https://abc123xyz.execute-api.us-east-1.amazonaws.com/Prod/api/v1
API Key: AbCdEfGh123456789...
```

**Save these values!** You'll need them for your iOS app.

If you missed them, retrieve them:

```bash
# Get API endpoint
aws cloudformation describe-stacks \
  --stack-name location-tracker-backend \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text

# Get API key ID
API_KEY_ID=$(aws cloudformation describe-stacks \
  --stack-name location-tracker-backend \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiKeyId`].OutputValue' \
  --output text)

# Get actual API key value
aws apigateway get-api-key \
  --api-key $API_KEY_ID \
  --include-value \
  --query 'value' \
  --output text
```

## Step 6: Test Your API

```bash
# Save your endpoint and key as variables
export API_ENDPOINT="https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Prod/api/v1"
export API_KEY="YOUR-API-KEY"

# Test health endpoint (no auth required)
curl $API_ENDPOINT/health

# Should return:
# {"status":"healthy","service":"LocationTracker API",...}

# Test save location (requires API key)
curl -X POST $API_ENDPOINT/locations \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{
    "timestamp": "2025-10-26T15:00:00Z",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "accuracy": 10.0,
    "altitude": 15.0,
    "speed": 0.0
  }'

# Should return:
# {"success":true,"message":"Location recorded","locationId":"..."}
```

## Step 7: Update iOS App

### Update AppConfig.swift

```swift
// In Config/AppConfig.swift
static let apiBaseURL = "https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Prod/api/v1"
```

### Add API Key Authentication

In `Services/APIService.swift`, update the `uploadLocation` method to include the API key:

```swift
func uploadLocation(_ record: LocationRecord) async throws -> Bool {
    let url = URL(string: "\(baseURL)/locations")!

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("YOUR-API-KEY", forHTTPHeaderField: "X-API-Key")  // ADD THIS LINE

    let uploadRequest = LocationUploadRequest(from: record)
    request.httpBody = try JSONEncoder().encode(uploadRequest)

    // ... rest of the code
}
```

**Better approach:** Store API key in AppConfig:

```swift
// In AppConfig.swift
static let apiKey = "YOUR-API-KEY"

// In APIService.swift
request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
```

## Step 8: Verify End-to-End

1. Build and run your iOS app
2. Grant location permissions ("Always")
3. Walk around or use Xcode's location simulation
4. Check that locations appear in the app
5. Verify data in DynamoDB:

```bash
aws dynamodb scan --table-name LocationHistory --limit 5
```

You should see your location records!

## Subsequent Deployments

After the initial guided deployment, future updates are simple:

```bash
# Make code changes, then:
./deploy.sh
```

SAM uses the saved configuration, so no prompts needed.

## Troubleshooting

### "Unable to locate credentials"

**Fix:** Run `aws configure` again and enter your credentials.

### "Access Denied" errors during deployment

**Fix:** Your AWS user needs these permissions:
- CloudFormation (create/update stacks)
- Lambda (create/update functions)
- DynamoDB (create tables)
- API Gateway (create APIs)
- IAM (create roles)

Ask your AWS admin to grant these, or attach the `PowerUserAccess` policy.

### "Stack already exists" error

**Fix:** Either:
- Use `./deploy.sh` (it will update the existing stack)
- Or delete and recreate: `aws cloudformation delete-stack --stack-name location-tracker-backend`

### API returns 403 Forbidden

**Fix:** Check that you're sending the API key:
```bash
-H "X-API-Key: YOUR-KEY"
```

### Can't find my API key

**Fix:** Run the command from Step 5 to retrieve it.

## Cost Warning

AWS Free Tier covers most usage for personal projects. However:

- **Watch your usage** if you're outside the free tier
- **Estimated cost:** ~$2/month for typical personal use
- **Set up billing alarms** in AWS Console → Billing → Billing Preferences

## Clean Up (Delete Everything)

To delete all resources and stop incurring charges:

```bash
aws cloudformation delete-stack --stack-name location-tracker-backend
```

**Warning:** This deletes ALL your location data permanently!

## Next Steps

- [ ] Update iOS app with API endpoint and key
- [ ] Test location tracking on physical device
- [ ] Monitor CloudWatch logs for any errors
- [ ] Set up billing alarms
- [ ] Consider enabling query endpoint (see README.md)

## Need Help?

- **AWS SAM Docs:** https://docs.aws.amazon.com/serverless-application-model/
- **AWS CLI Docs:** https://docs.aws.amazon.com/cli/
- **Check CloudWatch Logs:** AWS Console → CloudWatch → Log Groups
- **Review README.md** for detailed documentation
