#!/bin/bash

set -eo

#########################################
# CHECK IF EVERYTHING IS SET CORRECTLY #
#########################################
# Verify SVN credentials are set, otherwise exit.
if [ -z "$SVN_USERNAME" ] || [ -z "$SVN_PASSWORD" ]; then
  echo "x︎ SVN credentials not set. Exiting..."
  exit 1
fi

# Slug is not set, exit.
if [[ -z "$SVN_SLUG" ]]; then
  echo "x︎ SVN slug not set. Exiting..."
  exit 1
fi

# Check if working directory is set and exists, otherwise exit.
if [ -z "$WORKING_DIR" ] || [ ! -d "$WORKING_DIR" ]; then
  echo "x︎ Working directory not set or does not exist. Exiting..."
  exit 1
fi

#########################################
# PREPARE FILES FOR DEPLOYMENT #
#########################################
SVN_DIR=/tmp/svn
# If the SVN directory doesn't exist, create it.
if [ ! -d "$SVN_DIR" ]; then
  echo "➤ Creating SVN directory..."
  mkdir -p "$SVN_DIR"
  echo "✓ SVN directory created!"
fi

echo "::set-output name=svn_path::$SVN_DIR"

# Checkout the SVN repo
echo "➤ Checking out SVN repo..."
svn checkout --depth immediates "https://plugins.svn.wordpress.org/$SVN_SLUG/" "$SVN_DIR" >> /dev/null || exit 1
svn update --set-depth infinity "$SVN_DIR/trunk" >> /dev/null || exit 1
svn update --set-depth infinity "$SVN_DIR/assets" >> /dev/null || exit 1


echo "➤ Copying files..."
# If .distignore file exists, use it to exclude files from the SVN repo, otherwise use the default.
if [[ -r "$WORKING_DIR/.distignore" ]]; then
  echo "ℹ︎ Using .distignore"
  rsync -rc --exclude-from="$WORKING_DIR/.distignore" "$WORKING_DIR/" "$SVN_DIR/trunk/" --delete --delete-excluded
else
  echo "ℹ︎ Using default ignore"
  rsync -rc --exclude-from="$GITHUB_ACTION_PATH/.defaultignore" "$WORKING_DIR/" "$SVN_DIR/trunk/" --delete --delete-excluded
fi
echo "✓ Files copied!"


# Copy assets
# If .wordpress-org is a directory and contains files, copy them to the SVN repo.
if [[ -d "$WORKSPACE/.wordpress-org" ]]; then
  echo "➤ Copying assets..."
  rsync -rc "$WORKSPACE/.wordpress-org/" "$SVN_DIR/assets/" --delete --delete-excluded
  # Fix screenshots getting force downloaded when clicking them
  # https://developer.wordpress.org/plugins/wordpress-org/plugin-assets/
  if test -d "$SVN_DIR/assets" && test -n "$(find "$SVN_DIR/assets" -maxdepth 1 -name "*.png" -print -quit)"; then
      svn propset svn:mime-type "image/png" "$SVN_DIR/assets/"*.png || true
  fi
  if test -d "$SVN_DIR/assets" && test -n "$(find "$SVN_DIR/assets" -maxdepth 1 -name "*.jpg" -print -quit)"; then
      svn propset svn:mime-type "image/jpeg" "$SVN_DIR/assets/"*.jpg || true
  fi
  if test -d "$SVN_DIR/assets" && test -n "$(find "$SVN_DIR/assets" -maxdepth 1 -name "*.gif" -print -quit)"; then
      svn propset svn:mime-type "image/gif" "$SVN_DIR/assets/"*.gif || true
  fi
  if test -d "$SVN_DIR/assets" && test -n "$(find "$SVN_DIR/assets" -maxdepth 1 -name "*.svg" -print -quit)"; then
      svn propset svn:mime-type "image/svg+xml" "$SVN_DIR/assets/"*.svg || true
  fi
  echo "✓ Assets copied!"
fi

#########################################
# VERSIONING #
#########################################
# Clean up the version number.
VERSION=$(echo "$VERSION" | sed -e 's/[^0-9.]*//g')

# If version is not empty, and if the event is a tag push or publish, use the tag name as version.
if [[ -z "$VERSION" ]]; then
	TAG="${GITHUB_REF#refs/tags/}"
	echo "ℹ︎ Checking if github ref could be used as version ($TAG)"
	TAG=$(echo "$TAG" | sed -e 's/[^0-9.]*//g')
	# If the tag is a valid version number, use it as version.
	if [[ "$TAG" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    VERSION="$TAG"
    echo "ℹ︎ Yes, found a valid version number in the tag name ($VERSION)"
  else
    echo "ℹ︎ Ops, no valid version number found in the tag name"
  fi
fi

# If the version is not set, get the version from the main plugin file.
# If the version is not set, check if the plugin file exists, if so get the version from the plugin file.
if [[ -z "$VERSION" ]]; then
  if [[ -f "$WORKING_DIR/$SVN_SLUG.php" ]]; then
    echo "ℹ︎ Checking if we can find from plugin file ($SVN_SLUG.php)"
    # Find the version in the plugin file.

    WP_VERSION=$(awk '/[^[:graph:]]Version/{print $NF}' "$WORKING_DIR/$SVN_SLUG.php" | sed -e 's/[^0-9.]*//g')
    # If the version is a valid version number, use it as version.
    if [[ "$WP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
      VERSION="$WP_VERSION"
      echo "ℹ︎ Yes, found a valid version number in the plugin file ($VERSION)"
    else
      echo "ℹ︎ Ops, no valid version number found in the plugin file"
    fi
  fi
fi


# If the version is exist and a valid version number, then crate the svn tag.
if [[ -n "$VERSION" ]] && [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  # Versioning
  echo "::set-output name=version::$SVN_DIR"
  echo "➤ Versioning..."
  echo "ℹ︎ SVN tag is $VERSION"
  echo "➤ Creating SVN tag..."
  svn copy "$SVN_DIR/trunk" "$SVN_DIR/tags/$VERSION" >> /dev/null
  echo "✓ SVN tag created!"
else
  echo "ℹ︎ Could not find a valid version number, skipping versioning..."
fi


# Update contents.
echo "➤ Updating files ..."
# SVN add new files and remove deleted files from the SVN repo.
cd "$SVN_DIR" || exit
svn add . --force > /dev/null
# SVN delete all deleted files
# Also suppress stdout here
svn status | grep '^\!' | sed 's/! *//' | xargs -I% svn rm %@ > /dev/null
svn status
cd - || exit
echo "✓ Files updated!"

# Check if there are changes to commit.
if [[ -n "$(svn status "$SVN_DIR")" ]]; then
  echo "➤ Committing changes..."
  # If DRY_RUN is set, then exit.
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "ℹ︎ DRY_RUN is set. Exiting..."
    exit 0
    else
    # If DRY_RUN is not set, then commit the changes.
    svn commit "$SVN_DIR" -m "Deploy to WordPress.org" --username "$SVN_USERNAME" --password "$SVN_PASSWORD" --no-auth-cache --non-interactive >> /dev/null || exit 1
    echo "✓ Changes committed!"
  fi
else
  echo "ℹ︎ No changes to commit."
fi