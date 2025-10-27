#!/bin/bash

##
# Location Tracker Backend - Deployment Script
#
# This script builds and deploys the location tracker backend to AWS
# using AWS SAM (Serverless Application Model)
#
# Prerequisites:
# 1. AWS CLI installed and configured with credentials
# 2. AWS SAM CLI installed
# 3. Ruby 3.3 installed (for local testing)
#
# Usage:
#   ./deploy.sh              # Deploy to AWS
#   ./deploy.sh --guided     # Interactive deployment (first time)
#   ./deploy.sh --help       # Show help

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Show help
show_help() {
    cat << EOF
Location Tracker Backend - Deployment Script

Usage:
    ./deploy.sh [OPTIONS]

Options:
    --guided        Interactive guided deployment (recommended for first time)
    --build-only    Only build the application, don't deploy
    --help          Show this help message

Examples:
    ./deploy.sh --guided        # First time deployment with prompts
    ./deploy.sh                 # Subsequent deployments (uses saved config)
    ./deploy.sh --build-only    # Test build without deploying

Prerequisites:
    - AWS CLI configured with credentials
    - AWS SAM CLI installed
    - Appropriate AWS permissions (Lambda, DynamoDB, API Gateway, IAM)

After deployment:
    - Check the outputs for your API endpoint URL
    - Get your API key: aws apigateway get-api-keys --include-values
    - Update your iOS app's AppConfig.swift with the endpoint and API key

EOF
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install it first."
        echo "  Installation: https://aws.amazon.com/cli/"
        exit 1
    fi
    print_success "AWS CLI installed"

    # Check SAM CLI
    if ! command -v sam &> /dev/null; then
        print_error "AWS SAM CLI not found. Please install it first."
        echo "  Installation: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
        exit 1
    fi
    print_success "AWS SAM CLI installed"

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured."
        print_info "Please run: aws configure"
        print_info "You'll need:"
        print_info "  - AWS Access Key ID"
        print_info "  - AWS Secret Access Key"
        print_info "  - Default region (us-east-1)"
        exit 1
    fi

    # Show AWS account info
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region || echo "us-east-1")
    print_success "AWS credentials configured"
    print_info "Account ID: ${ACCOUNT_ID}"
    print_info "Region: ${AWS_REGION}"

    # Check Docker (required for container builds)
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker Desktop."
        echo "  Installation: https://www.docker.com/products/docker-desktop/"
        exit 1
    fi
    print_success "Docker installed"

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running."
        print_info "Please start Docker Desktop and try again."
        exit 1
    fi
    print_success "Docker daemon is running"

    # Check Ruby (optional, for local testing)
    if command -v ruby &> /dev/null; then
        RUBY_VERSION=$(ruby --version)
        print_success "Ruby installed: ${RUBY_VERSION}"
    else
        print_warning "Ruby not found (optional, only needed for local testing)"
    fi
}

# Build the application
build_application() {
    print_header "Building Application"

    print_info "Running SAM build..."
    if sam build; then
        print_success "Build completed successfully"
    else
        print_error "Build failed"
        exit 1
    fi
}

# Deploy the application
deploy_application() {
    print_header "Deploying to AWS"

    if [ "$GUIDED_DEPLOY" = true ]; then
        print_info "Starting guided deployment..."
        print_warning "You'll be prompted for deployment parameters."
        echo ""
        sam deploy --guided
    else
        print_info "Deploying with saved configuration..."
        sam deploy
    fi

    if [ $? -eq 0 ]; then
        print_success "Deployment completed successfully!"
    else
        print_error "Deployment failed"
        exit 1
    fi
}

# Get and display outputs
show_deployment_info() {
    print_header "Deployment Information"

    # Get stack outputs
    STACK_NAME="location-tracker-backend"

    print_info "Retrieving deployment outputs..."

    API_ENDPOINT=$(aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
        --output text 2>/dev/null)

    API_KEY_ID=$(aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiKeyId`].OutputValue' \
        --output text 2>/dev/null)

    if [ -n "$API_ENDPOINT" ]; then
        echo ""
        print_success "API Endpoint: ${API_ENDPOINT}"
        echo ""

        print_info "Retrieving API Key..."
        API_KEY=$(aws apigateway get-api-key \
            --api-key ${API_KEY_ID} \
            --include-value \
            --query 'value' \
            --output text 2>/dev/null)

        if [ -n "$API_KEY" ]; then
            print_success "API Key: ${API_KEY}"
            echo ""

            print_header "Next Steps"
            echo "1. Update your iOS app's AppConfig.swift:"
            echo ""
            echo "   static let apiBaseURL = \"${API_ENDPOINT}\""
            echo ""
            echo "2. Add the API key to your iOS app's APIService.swift:"
            echo ""
            echo "   request.setValue(\"${API_KEY}\", forHTTPHeaderField: \"X-API-Key\")"
            echo ""
            echo "3. Test the health endpoint:"
            echo ""
            echo "   curl ${API_ENDPOINT}/health"
            echo ""
            echo "4. Test saving a location:"
            echo ""
            echo "   curl -X POST ${API_ENDPOINT}/locations \\"
            echo "     -H \"Content-Type: application/json\" \\"
            echo "     -H \"X-API-Key: ${API_KEY}\" \\"
            echo "     -d '{\"timestamp\":\"2025-10-26T15:00:00Z\",\"latitude\":37.7749,\"longitude\":-122.4194,\"accuracy\":10.0,\"altitude\":15.0,\"speed\":0.0}'"
            echo ""
        else
            print_warning "Could not retrieve API key automatically."
            print_info "Run this command to get your API key:"
            echo "  aws apigateway get-api-key --api-key ${API_KEY_ID} --include-value --query 'value' --output text"
        fi
    else
        print_warning "Could not retrieve deployment outputs automatically."
        print_info "Run this command to see all outputs:"
        echo "  aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query 'Stacks[0].Outputs'"
    fi

    echo ""
}

# Main script
main() {
    GUIDED_DEPLOY=false
    BUILD_ONLY=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --guided)
                GUIDED_DEPLOY=true
                shift
                ;;
            --build-only)
                BUILD_ONLY=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    print_header "Location Tracker Backend Deployment"

    check_prerequisites
    build_application

    if [ "$BUILD_ONLY" = false ]; then
        deploy_application
        show_deployment_info
    else
        print_success "Build-only mode: Skipping deployment"
    fi

    print_header "Deployment Complete! 🚀"
}

# Run main function
main "$@"
