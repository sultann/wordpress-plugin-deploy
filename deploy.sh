#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# =============================================================================
# WordPress Plugin Deploy Action
# =============================================================================
# Deploys WordPress plugin to wordpress.org SVN repository
# =============================================================================

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "::error::$1"
}

log_warning() {
    echo "::warning::$1"
}

# -----------------------------------------------------------------------------
# Setup Defaults
# -----------------------------------------------------------------------------
VERSION="${VERSION:-${GITHUB_REF#refs/tags/}}"
VERSION="${VERSION#v}"
SLUG="${SLUG:-${GITHUB_REPOSITORY#*/}}"
readonly SVN_URL="https://plugins.svn.wordpress.org/${SLUG}/"
readonly SVN_DIR="${HOME}/svn-${SLUG}"

# If version is not set or invalid, try package.json
if [[ -z "$VERSION" || ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    if [ -f ./package.json ]; then
        VERSION=$(node -p "require('./package.json').version")
        log_info "Version from package.json: $VERSION"
    else
        VERSION=""
    fi
fi

# -----------------------------------------------------------------------------
# Input Validation
# -----------------------------------------------------------------------------
for var in USERNAME PASSWORD SLUG VERSION; do
    if [ -z "${!var:-}" ]; then
        log_error "$var is not set"
        exit 1
    fi
done

readonly VERSION
readonly SLUG

# -----------------------------------------------------------------------------
# Display Configuration
# -----------------------------------------------------------------------------
log_info "=== Deployment Configuration ==="
log_info "Slug: $SLUG"
log_info "Version: $VERSION"
log_info "SVN URL: $SVN_URL"
log_info "Dry run: ${DRY_RUN:-false}"
log_info "Generate ZIP: ${GENERATE_ZIP:-false}"
echo ""

# Output version for GitHub Actions
echo "version=$VERSION" >> "${GITHUB_OUTPUT}"

# -----------------------------------------------------------------------------
# Checkout SVN Repository
# -----------------------------------------------------------------------------
log_info "Checking out SVN repository..."
if ! svn checkout --depth immediates "$SVN_URL" "$SVN_DIR" >> /dev/null; then
    log_error "Failed to checkout SVN repository"
    exit 1
fi

cd "$SVN_DIR" || exit 1

svn update --set-depth infinity assets >> /dev/null
svn update --set-depth infinity trunk >> /dev/null
svn update --set-depth immediates tags >> /dev/null

log_info "SVN checkout completed"

# -----------------------------------------------------------------------------
# Copy Plugin Files
# -----------------------------------------------------------------------------
log_info "Copying plugin files..."

if [[ -r "$GITHUB_WORKSPACE/.distignore" ]]; then
    log_info "Using .distignore for exclusions"
    rsync -rc --exclude-from="$GITHUB_WORKSPACE/.distignore" "$GITHUB_WORKSPACE/" trunk/ --delete --delete-excluded
else
    log_info "Using default exclusions"
    rsync -rc --exclude '.*' --exclude 'node_modules' "$GITHUB_WORKSPACE/" trunk/ --delete --delete-excluded
fi

# Remove empty directories from trunk
find trunk -type d -empty -delete 2>/dev/null || true

log_info "Plugin files copied"

# -----------------------------------------------------------------------------
# Copy Assets
# -----------------------------------------------------------------------------
if [[ -d "$GITHUB_WORKSPACE/.wordpress-org" ]]; then
    log_info "Copying assets from .wordpress-org..."
    rsync -rc "$GITHUB_WORKSPACE/.wordpress-org/" assets/ --delete

    # Set MIME types for images
    if [ -d "$SVN_DIR/assets" ]; then
        log_info "Setting MIME types for assets..."

        if find "$SVN_DIR/assets" -maxdepth 1 -name "*.png" -print -quit | grep -q .; then
            svn propset svn:mime-type "image/png" "$SVN_DIR/assets/"*.png 2>/dev/null || true
        fi

        if find "$SVN_DIR/assets" -maxdepth 1 -name "*.jpg" -print -quit | grep -q .; then
            svn propset svn:mime-type "image/jpeg" "$SVN_DIR/assets/"*.jpg 2>/dev/null || true
        fi

        if find "$SVN_DIR/assets" -maxdepth 1 -name "*.gif" -print -quit | grep -q .; then
            svn propset svn:mime-type "image/gif" "$SVN_DIR/assets/"*.gif 2>/dev/null || true
        fi

        if find "$SVN_DIR/assets" -maxdepth 1 -name "*.svg" -print -quit | grep -q .; then
            svn propset svn:mime-type "image/svg+xml" "$SVN_DIR/assets/"*.svg 2>/dev/null || true
        fi
    fi

    log_info "Assets copied"
fi

# -----------------------------------------------------------------------------
# Create/Update Tag
# -----------------------------------------------------------------------------
log_info "Processing tag $VERSION..."

if svn ls "https://plugins.svn.wordpress.org/$SLUG/tags/$VERSION" >> /dev/null 2>&1; then
    log_info "Tag exists, updating..."
    svn update --set-depth infinity "$SVN_DIR/tags/$VERSION"
    rsync -rc "$SVN_DIR/trunk/" "$SVN_DIR/tags/$VERSION/" --delete --delete-excluded
else
    log_info "Creating new tag..."
    svn copy "$SVN_DIR/trunk" "$SVN_DIR/tags/$VERSION" >> /dev/null
fi

# -----------------------------------------------------------------------------
# Prepare SVN Changes
# -----------------------------------------------------------------------------
log_info "Preparing SVN changes..."
svn add . --force > /dev/null 2>&1 || true

# Remove deleted files from SVN
svn status | grep '^\!' | sed 's/! *//' | xargs -I% svn rm %@ > /dev/null 2>&1 || true
svn update >> /dev/null 2>&1 || true

log_info "Current SVN status:"
svn status

# -----------------------------------------------------------------------------
# Generate ZIP File
# -----------------------------------------------------------------------------
if [ "${GENERATE_ZIP:-false}" = "true" ]; then
    log_info "Generating ZIP file..."
    ln -s "${SVN_DIR}/trunk" "${SVN_DIR}/${SLUG}"
    zip -r "${GITHUB_WORKSPACE}/${SLUG}.zip" "$SLUG" >> /dev/null
    unlink "${SVN_DIR}/${SLUG}"

    echo "zip_path=${GITHUB_WORKSPACE}/${SLUG}.zip" >> "${GITHUB_OUTPUT}"
    log_info "ZIP file generated: ${SLUG}.zip"
fi

# -----------------------------------------------------------------------------
# Dry Run Check
# -----------------------------------------------------------------------------
if [ "${DRY_RUN:-false}" = "true" ]; then
    log_warning "Dry run mode - changes not committed"
    exit 0
fi

# -----------------------------------------------------------------------------
# Commit Changes
# -----------------------------------------------------------------------------
if [[ -n "$(svn status "$SVN_DIR")" ]]; then
    log_info "Committing changes to SVN..."
    if ! svn commit -m "Update to version $VERSION" --no-auth-cache --non-interactive --username "$USERNAME" --password "$PASSWORD"; then
        log_error "Failed to commit changes"
        exit 1
    fi
    log_info "Changes committed successfully"
else
    log_warning "No changes to commit"
fi

# -----------------------------------------------------------------------------
# Success
# -----------------------------------------------------------------------------
log_info ""
log_info "=== Deployment Complete ==="
log_info "Plugin: $SLUG"
log_info "Version: $VERSION"
log_info "SVN URL: $SVN_URL"