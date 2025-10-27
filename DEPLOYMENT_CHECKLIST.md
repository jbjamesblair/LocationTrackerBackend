# Deployment Checklist

Quick reference for deploying the Location Tracker backend.

## ✅ Pre-Deployment

- [ ] AWS Account created
- [ ] AWS CLI installed (`aws --version`)
- [ ] AWS SAM CLI installed (`sam --version`)
- [ ] AWS credentials configured (`aws configure`)
- [ ] Verified credentials work (`aws sts get-caller-identity`)

## ✅ Deploy Backend

```bash
cd /Users/jblair/Development/codex/location-tracker-backend

# First time
./deploy.sh --guided

# Accept all defaults, press Enter through prompts
# Wait 3-5 minutes for deployment to complete
```

## ✅ Get API Details

After deployment completes, save these values:

```bash
# API Endpoint (copy this)
export API_ENDPOINT="https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Prod/api/v1"

# API Key (copy this)
export API_KEY="YOUR-API-KEY-HERE"
```

## ✅ Test Backend

```bash
# Test health endpoint
curl $API_ENDPOINT/health

# Expected: {"status":"healthy",...}

# Test save location
curl -X POST $API_ENDPOINT/locations \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{"timestamp":"2025-10-26T15:00:00Z","latitude":37.7749,"longitude":-122.4194,"accuracy":10.0,"altitude":15.0,"speed":0.0}'

# Expected: {"success":true,"message":"Location recorded",...}
```

## ✅ Update iOS App

### 1. Update AppConfig.swift

File: `ios/LocationTracker/LocationTracker/Config/AppConfig.swift`

```swift
static let apiBaseURL = "PASTE-YOUR-API-ENDPOINT-HERE"
static let apiKey = "PASTE-YOUR-API-KEY-HERE"
```

### 2. Update APIService.swift

File: `ios/LocationTracker/LocationTracker/Services/APIService.swift`

In `uploadLocation()` method, add API key header:

```swift
request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
```

Also update `checkServerReachability()` if needed (health endpoint doesn't require API key).

## ✅ Test iOS App

- [ ] Build and run iOS app
- [ ] Grant location permissions ("Always")
- [ ] Verify location tracking starts
- [ ] Check location appears in app history
- [ ] Verify sync status shows "Synced" (green checkmark)

## ✅ Verify Data in AWS

```bash
# Check DynamoDB table
aws dynamodb scan --table-name LocationHistory --limit 5

# Should see your location records
```

## ✅ Monitor

```bash
# View Lambda logs
sam logs -n SaveLocationFunction --stack-name location-tracker-backend --tail

# View recent invocations
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=location-tracker-backend-SaveLocationFunction \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## 🎉 Done!

Your location tracker is now live on AWS!

## 🔄 Future Updates

When you make changes to the backend code:

```bash
cd location-tracker-backend
./deploy.sh
```

No need for `--guided` after the first deployment.

## 🗑️ Cleanup (if needed)

To delete everything and stop charges:

```bash
aws cloudformation delete-stack --stack-name location-tracker-backend
```

**WARNING:** This deletes all your location data!

## 📊 Cost Monitoring

Set up a billing alarm:

1. Go to AWS Console → CloudWatch → Alarms
2. Create alarm for "EstimatedCharges"
3. Set threshold (e.g., $10)
4. Add email notification

## 🔒 Security Checklist

- [ ] API key is NOT committed to git
- [ ] API key is stored securely in iOS app
- [ ] CloudWatch logs are enabled
- [ ] DynamoDB point-in-time recovery is enabled
- [ ] API throttling is configured (100 req/min)

## 📱 iOS App Configuration Summary

After deployment, your iOS app needs:

1. **API Base URL**: `https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/Prod/api/v1`
2. **API Key**: `AbCdEfGh123456789...` (shown after deployment)

Both go in `AppConfig.swift`:

```swift
static let apiBaseURL = "YOUR-ENDPOINT"
static let apiKey = "YOUR-KEY"
```

And add to all API requests in `APIService.swift`:

```swift
request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
```

## 🚀 Quick Redeploy Commands

```bash
# Build and deploy
cd location-tracker-backend && ./deploy.sh

# Build only (test)
./deploy.sh --build-only

# View logs
sam logs -n SaveLocationFunction --tail

# Test locally
sam local start-api
```

## ❓ Troubleshooting

| Issue | Solution |
|-------|----------|
| 403 Forbidden | Add API key header |
| 500 Error | Check CloudWatch logs |
| Can't find API key | Re-run: `aws apigateway get-api-key --api-key ID --include-value` |
| Deployment fails | Check AWS credentials: `aws sts get-caller-identity` |
| No data in DynamoDB | Check Lambda logs for errors |

## 📚 Documentation

- **Quick Start**: `SETUP.md`
- **Full Documentation**: `README.md`
- **This Checklist**: `DEPLOYMENT_CHECKLIST.md`
