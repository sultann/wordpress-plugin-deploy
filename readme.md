# WordPress Plugin Deploy Action

Deploy WordPress plugins to the WordPress.org plugin repository with automated SVN management, asset handling, and optional Slack notifications.

## Features

- Automated SVN repository management
- Support for `.distignore` file exclusions
- Automatic asset deployment (banners, icons, screenshots)
- Proper MIME type setting for assets
- Tag management and versioning
- Optional zip file generation
- Dry-run mode for testing
- Slack notifications for successful deployments
- Automatic version detection from tags or package.json

## Quick Start

```yaml
name: Deploy to WordPress.org

on:
  push:
    tags:
      - "*"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: sultann/wordpress-plugin-deploy@v1
        with:
          username: ${{ secrets.SVN_USERNAME }}
          password: ${{ secrets.SVN_PASSWORD }}
```

## Requirements

Add the following secrets to your repository's settings under `Settings > Secrets and Variables > Actions`:

- `SVN_USERNAME` - Your WordPress.org username
- `SVN_PASSWORD` - Your WordPress.org password
- `SLACK_WEBHOOK` - (Optional) Slack webhook URL for deployment notifications

## Configuration

### Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `username` | WordPress.org SVN username | Yes | - |
| `password` | WordPress.org SVN password | Yes | - |
| `slug` | Plugin slug on WordPress.org | No | Repository name |
| `version` | Release version | No | Tag name or package.json |
| `generate_zip` | Generate zip file of plugin | No | `false` |
| `dry_run` | Preview deployment without committing | No | `false` |
| `slack_webhook` | Slack webhook URL for notifications | No | - |
| `slack_message` | Custom Slack message | No | Auto-generated |

### Outputs

| Output | Description |
|--------|-------------|
| `version` | Version number used for deployment |
| `zip_path` | Path to generated ZIP file (if `generate_zip: true`) |

## Common Use Cases

### Basic Deployment

Deploy when a tag is pushed:

```yaml
name: Deploy to WordPress.org

on:
  push:
    tags:
      - "*"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: sultann/wordpress-plugin-deploy@v1
        with:
          username: ${{ secrets.SVN_USERNAME }}
          password: ${{ secrets.SVN_PASSWORD }}
```

### With Custom Slug

If your GitHub repo name differs from WordPress.org slug:

```yaml
- uses: sultann/wordpress-plugin-deploy@v1
  with:
    username: ${{ secrets.SVN_USERNAME }}
    password: ${{ secrets.SVN_PASSWORD }}
    slug: 'my-custom-slug'
```

### Generate Release Zip

Generate a zip file for distribution:

```yaml
- name: Deploy to WordPress.org
  id: deploy
  uses: sultann/wordpress-plugin-deploy@v1
  with:
    username: ${{ secrets.SVN_USERNAME }}
    password: ${{ secrets.SVN_PASSWORD }}
    generate_zip: true

- name: Upload Release Artifact
  uses: actions/upload-artifact@v3
  with:
    name: plugin-zip
    path: ${{ steps.deploy.outputs.zip_path }}
```

### With Slack Notifications

Get notified in Slack when deployment succeeds:

```yaml
- uses: sultann/wordpress-plugin-deploy@v1
  with:
    username: ${{ secrets.SVN_USERNAME }}
    password: ${{ secrets.SVN_PASSWORD }}
    slack_webhook: ${{ secrets.SLACK_WEBHOOK }}
```

### Testing with Dry Run

Preview what would be deployed without committing:

```yaml
- uses: sultann/wordpress-plugin-deploy@v1
  with:
    username: ${{ secrets.SVN_USERNAME }}
    password: ${{ secrets.SVN_PASSWORD }}
    dry_run: true
```

## Excluding Files from Release

If there are files or directories to be excluded from release, such as tests or editor config files, they can be specified in a `.distignore` file.

Sample `.distignore` file:

```
/.git
/.github
/node_modules

.distignore
.gitignore
composer.json
composer.lock
package.json
package-lock.json
```

## Assets Directory

Create a directory named `.wordpress-org` in the root of your repository. This directory will contain all the assets (banners, icons, screenshots) that you want to deploy to WordPress.org. The action will automatically copy all files from this directory to the assets directory of the WordPress.org plugin repository.

Recommended structure:

```
.wordpress-org/
├── banner-772x250.png
├── banner-1544x500.png
├── icon-128x128.png
├── icon-256x256.png
├── screenshot-1.png
└── screenshot-2.png
```

## How It Works

The action follows these steps:

1. Checks out the WordPress.org SVN repository
2. Copies files from your repository to SVN trunk
3. Applies exclusions from `.distignore` file
4. Copies assets from `.wordpress-org` directory (if exists)
5. Sets proper MIME types for asset images
6. Creates or updates the version tag
7. Commits changes to WordPress.org SVN
8. Optionally generates a zip file
9. Sends Slack notification (if configured)

## Testing Locally

To preview what files would be deployed locally:

```bash
cd wp-content
svn checkout --depth immediates https://plugins.svn.wordpress.org/my-plugin-slug/ my-plugin-slug-svn
svn update --set-depth infinity my-plugin-slug-svn/trunk
rsync -av --exclude-from=my-plugin-slug/.distignore --delete --delete-excluded my-plugin-slug/ my-plugin-slug-svn/trunk/
```

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE)