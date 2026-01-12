#!/bin/bash
# =============================================================================
# Hetzner Cloud Remote Build Script for EAS Local Builds
# =============================================================================
# Spins up a CPX52 VPS, syncs project, runs eas build --local, retrieves artifact
# 
# Usage: ./build-remote.sh [profile]
#   profile: development | preview | production (default: preview)
#
# Environment Variables:
#   HCLOUD_TOKEN       - Required: Hetzner Cloud API token
#   HETZNER_SSH_KEY    - Optional: SSH key name in Hetzner (default: first available)
#   HETZNER_SSH_KEY_FILE- Optional: Path to local private key (default: ~/.ssh/id_hetzner)
#   HETZNER_SERVER_TYPE - Optional: Server type (default: cpx52)
#   HETZNER_LOCATION   - Optional: Location (default: fsn1)
#   EXPO_TOKEN         - Optional: For remote credentials
# =============================================================================

set -e

# Configuration
PROFILE="${1:-preview}"
SERVER_NAME="eas-builder-$(date +%s)"
SERVER_TYPE="${HETZNER_SERVER_TYPE:-cpx52}"
LOCATION="${HETZNER_LOCATION:-fsn1}"
IMAGE="ubuntu-24.04"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_OUTPUT_DIR="$PROJECT_DIR/build-output"
CLOUD_INIT_FILE="$SCRIPT_DIR/cloud-init-builder.yaml"
SSH_KEY_FILE="${HETZNER_SSH_KEY_FILE:-$HOME/.ssh/id_hetzner}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -i $SSH_KEY_FILE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Cleanup function - always delete server on exit
cleanup() {
    if [ -n "$SERVER_ID" ]; then
        log_warn "Cleaning up server $SERVER_NAME (ID: $SERVER_ID)..."
        hcloud server delete "$SERVER_ID" --poll-interval 1s || true
        log_success "Server deleted"
    fi
}
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v hcloud &> /dev/null; then
        log_error "hcloud CLI not found. Install from: https://github.com/hetznercloud/cli"
        exit 1
    fi
    
    if [ -z "$HCLOUD_TOKEN" ]; then
        # Check if context is configured
        if ! hcloud context active &> /dev/null; then
            log_error "HCLOUD_TOKEN not set and no active hcloud context found"
            log_info "Set HCLOUD_TOKEN or run: hcloud context create <name>"
            exit 1
        fi
    fi
    
    if ! command -v rsync &> /dev/null; then
        log_error "rsync not found. Please install rsync."
        exit 1
    fi
    
    if [ ! -f "$CLOUD_INIT_FILE" ]; then
        log_error "Cloud-init file not found: $CLOUD_INIT_FILE"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get SSH key (use first available if not specified)
get_ssh_key() {
    if [ -n "$HETZNER_SSH_KEY" ]; then
        echo "$HETZNER_SSH_KEY"
    else
        hcloud ssh-key list -o noheader -o columns=name | head -1
    fi
}

# Create the server
create_server() {
    log_info "Creating server: $SERVER_NAME ($SERVER_TYPE in $LOCATION)..."
    
    SSH_KEY=$(get_ssh_key)
    if [ -z "$SSH_KEY" ]; then
        log_error "No SSH key found. Add one via: hcloud ssh-key create --name mykey --public-key-from-file ~/.ssh/id_rsa.pub"
        exit 1
    fi
    log_info "Using SSH key: $SSH_KEY"
    
    # Create server with cloud-init
    SERVER_OUTPUT=$(hcloud server create \
        --name "$SERVER_NAME" \
        --type "$SERVER_TYPE" \
        --image "$IMAGE" \
        --location "$LOCATION" \
        --ssh-key "$SSH_KEY" \
        --user-data-from-file "$CLOUD_INIT_FILE" \
        --poll-interval 1s \
        2>&1)
    
    SERVER_ID=$(echo "$SERVER_OUTPUT" | grep -oP 'Server \K[0-9]+')
    SERVER_IP=$(hcloud server ip "$SERVER_NAME")
    
    log_success "Server created: $SERVER_IP (ID: $SERVER_ID)"
}

# Wait for server to be ready and cloud-init to complete
wait_for_server() {
    log_info "Waiting for server to be ready..."
    
    # Wait for SSH to be available
    local max_attempts=60
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if ssh -o ConnectTimeout=5 $SSH_OPTS \
            root@"$SERVER_IP" "echo ready" 2>/dev/null; then
            break
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    echo ""
    
    if [ $attempt -eq $max_attempts ]; then
        log_error "Timeout waiting for SSH"
        exit 1
    fi
    
    log_info "Waiting for cloud-init to complete (installing dependencies)..."
    ssh $SSH_OPTS root@"$SERVER_IP" "cloud-init status --wait" 2>/dev/null || true
    
    # Wait for apt locks to be released
    log_info "Waiting for apt locks to be released..."
    ssh $SSH_OPTS root@"$SERVER_IP" << 'APTLOCK'
        while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
            echo "Waiting for apt lock..."
            sleep 5
        done
APTLOCK
    
    log_success "Server is ready"
}

# Sync project files to server
sync_project() {
    log_info "Syncing project files to server..."
    
    rsync -avz --progress \
        --exclude 'node_modules' \
        --exclude '.expo' \
        --exclude 'android' \
        --exclude 'ios' \
        --exclude '.git' \
        --exclude 'coverage' \
        --exclude 'build-output' \
        -e "ssh $SSH_OPTS" \
        "$PROJECT_DIR/" \
        "root@$SERVER_IP:/root/project/"
    
    log_success "Project synced"
}

# Run the build on remote server
run_build() {
    log_info "Running eas build --local --platform android --profile $PROFILE..."
    log_info "This may take 10-20 minutes..."
    log_info "Build is wrapped in nohup to survive connection drops."
    
    # Log if EXPO_TOKEN is set locally
    if [ -n "$EXPO_TOKEN" ]; then
        log_info "EXPO_TOKEN is set (${#EXPO_TOKEN} chars)"
    else
        log_warn "EXPO_TOKEN is NOT set - build may fail if remote credentials needed"
    fi
    
    # Start the build in background with nohup to survive disconnects
    ssh $SSH_OPTS root@"$SERVER_IP" << ENDSSH
        set -e
        
        # Write environment to a file that nohup can source
        cat > /root/build-env.sh << 'ENVFILE'
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools
ENVFILE

        # Add EXPO_TOKEN if provided
        echo "Adding EXPO_TOKEN: ${EXPO_TOKEN:+YES (${#EXPO_TOKEN} chars)}${EXPO_TOKEN:-NO}"
        if [ -n "$EXPO_TOKEN" ]; then
            echo "export EXPO_TOKEN='$EXPO_TOKEN'" >> /root/build-env.sh
        fi
        
        # Add PROFILE
        echo "export PROFILE='$PROFILE'" >> /root/build-env.sh
        
        # Debug: show what's in the env file
        echo "=== build-env.sh contents ==="
        cat /root/build-env.sh
        echo "=== end build-env.sh ==="
        
        cd /root/project
        
        # Initialize git repo (EAS requires it)
        git config --global --add safe.directory /root/project
        git config --global user.email "build@localhost"
        git config --global user.name "EAS Builder"
        git init -q
        git add -A
        git commit -m "Build commit" -q
        
        # Run build in nohup to survive SSH disconnects
        nohup bash -c '
            source /root/build-env.sh
            echo "EXPO_TOKEN in subshell: \${EXPO_TOKEN:+SET}\${EXPO_TOKEN:-NOT SET}"
            echo "PROFILE in subshell: \$PROFILE"
            set -e
            echo "Installing npm dependencies..."
            npm install
            
            echo "Running EAS build..."
            # Determine output extension based on profile
            if [ "\$PROFILE" = "production" ]; then
                OUTPUT_FILE="/root/build-output.aab"
            else
                OUTPUT_FILE="/root/build-output.apk"
            fi
            npx eas-cli build --local --platform android --profile \$PROFILE --non-interactive --output \$OUTPUT_FILE
            
            echo "BUILD_COMPLETE" > /root/build-status
        ' > /root/build.log 2>&1 &
        
        echo "Build started in background (PID: \$!)"
ENDSSH
    
    # Monitor the build progress
    log_info "Monitoring build progress..."
    while true; do
        # Check if build completed
        if ssh $SSH_OPTS root@"$SERVER_IP" "test -f /root/build-status" 2>/dev/null; then
            log_success "Build completed"
            break
        fi
        
        # Check if build failed (process died but no status file)
        if ! ssh $SSH_OPTS root@"$SERVER_IP" "pgrep -f 'eas-cli build' > /dev/null || pgrep -f 'npm install' > /dev/null || pgrep -f 'gradlew' > /dev/null" 2>/dev/null; then
            # No build processes running - check if there's output
            if ssh $SSH_OPTS root@"$SERVER_IP" "test -f /root/build-output.apk -o -f /root/build-output.aab" 2>/dev/null; then
                log_success "Build completed"
                break
            fi
            # Wait a bit more in case build just finished
            sleep 10
            if ssh $SSH_OPTS root@"$SERVER_IP" "test -f /root/build-output.apk -o -f /root/build-output.aab" 2>/dev/null; then
                log_success "Build completed"
                break
            fi
            log_error "Build process died unexpectedly. Check logs:"
            ssh $SSH_OPTS root@"$SERVER_IP" "tail -100 /root/build.log" 2>/dev/null || true
            exit 1
        fi
        
        # Show recent log output
        ssh $SSH_OPTS root@"$SERVER_IP" "tail -3 /root/build.log 2>/dev/null" || true
        sleep 30
    done
}

# Retrieve build artifact
retrieve_artifact() {
    log_info "Retrieving build artifact..."
    
    mkdir -p "$BUILD_OUTPUT_DIR"
    
    # Try to get APK first, then AAB
    if ssh $SSH_OPTS root@"$SERVER_IP" "test -f /root/build-output.apk" 2>/dev/null; then
        ARTIFACT_NAME="build-$(date +%Y%m%d-%H%M%S).apk"
        scp $SSH_OPTS "root@$SERVER_IP:/root/build-output.apk" "$BUILD_OUTPUT_DIR/$ARTIFACT_NAME"
    else
        ARTIFACT_NAME="build-$(date +%Y%m%d-%H%M%S).aab"
        scp $SSH_OPTS "root@$SERVER_IP:/root/build-output.aab" \
            "$BUILD_OUTPUT_DIR/$ARTIFACT_NAME"
    fi
    
    log_success "Artifact saved: $BUILD_OUTPUT_DIR/$ARTIFACT_NAME"
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  Hetzner Cloud EAS Build Script"
    echo "=========================================="
    echo "  Profile: $PROFILE"
    echo "  Server:  $SERVER_TYPE @ $LOCATION"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    create_server
    wait_for_server
    sync_project
    run_build
    retrieve_artifact
    
    echo ""
    log_success "Build complete!"
    log_info "Artifact location: $BUILD_OUTPUT_DIR/$ARTIFACT_NAME"
    echo ""
}

main
