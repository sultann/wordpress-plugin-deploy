# WordPress.org Plugin Deploy Action

Github Action to deploy a WordPress plugin to the WordPress.org plugin repository.

## Requirements

Add the following secrets to your repository's settings under `Settings > Secrets and Variables > Actions`.

- `SVN_USERNAME` - Your WordPress.org username.
- `SVN_PASSWORD` - Your WordPress.org password.
- `SLACK_WEBHOOK`- (Optional) Slack webhook URL to send notification when deployment is successful.

## Inputs

| Input           | Required | Description                                                                                                                                                                                           |
|-----------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `username`      | Yes      | Your WordPress.org username.                                                                                                                                                                          |
| `password`      | Yes      | Your WordPress.org password.                                                                                                                                                                          |
| `slug`          | No       | The slug of the plugin on WordPress.org. This is optional if your GitHub repository name matches the WordPress.org slug.                                                                              |
| `version`       | No       | The release version of your plugin. This is optional by default the action will use the tag name as the version.                                                                                      |
| `generate_zip`  | No       | Whether to generate a zip file of the plugin. This is optional and defaults to `false`. If set to `true`, the action will generate a zip file.                                                        |
| `dry_run`       | No       | Whether to run the action in dry run mode. This is optional and defaults to `false`. If set to `true`, the action will not deploy to WordPress.org, instead outputs the files that would be deployed. |
| `slack_webhook` | No       | Slack webhook URL to send notification when deployment is successful.                                                                                                                                 |

### Outputs

| Output     | Description                                                             |
|------------|-------------------------------------------------------------------------|
| `version`  | Version number of the release, that is being used for deployment.       |
| `zip_path` | The path to the ZIP file generated. If `generate_zip` is set to `true`. |


## Excluding files from release

If there are files or directories to be excluded from release, such as tests or editor config files, they can be
specified in either a `.distignore` file.

Sample `.distignore` file:

```
/.git
/.github
/node_modules

.distignore
.gitignore
```

## Assets Directory
Create a directory named `.wordpress-org` in the root of your repository. This directory will contain all the assets e.g. banners, icons, screenshots, etc. that you want to deploy to WordPress.org. The action will automatically copy all the files from this directory to the assets directory of the WordPress.org plugin repository.


## Usage

```yaml
- name: Deploy to WordPress.org
  id: deploy
  uses: sultann/wordpress-plugin-deploy@master
  with:
    # SVN username that has commit access to the following plugin.
    # Required.
    username: ${{ secrets.SVN_USERNAME }}

    # SVN password of the user.
    # Required.
    password: ${{ secrets.SVN_PASSWORD }}

    # Slug of the plugin on WordPress.org. If the GitHub repository name matches the WordPress.org slug, this is optional.
    # Optional.
    svn_slug: 'my-plugin-slug'

    # Version of the release. Defaults to the release tag if found otherwise version from the package.json file.
    # Optional.
    version: '1.0.0'

    # Whether to generate a zip file of the plugin. Defaults to false. If this is set to true, you can use ${{ steps.deploy.outputs.zip_path }} to get the path to the generated zip file.
    # Optional.
    generate_zip: true

    # Whether to run the action in dry run mode. Defaults to false. If this is set to true, the action will not deploy to WordPress.org, instead outputs the files that would be deployed.
    # Optional.
    dry_run: true

    # Slack webhook URL to send notification when deployment is successful.
    # Optional.
    slack_webhook: ${{ secrets.SLACK_WEBHOOK }}

```

## Example

Create a new file in your repository at `.github/workflows/deploy.yml` with the following contents:

```yaml
name: Deploy to WordPress.org
on:
  push:
    tags:
      - "*"
jobs:
  build:
    name: Build release and deploy
    runs-on: ubuntu-latest
    steps:
        - name: Checkout code
          uses: actions/checkout@v2
        - name: Build & Deploy
          uses: sultann/wordpress-plugin-deploy@master
          with:
          svn_username: ${{ secrets.SVN_USERNAME }}
          svn_password: ${{ secrets.SVN_PASSWORD }}
          svn_slug: 'my-plugin-slug' # Remove this if GitHub repo name matches SVN slug
```

If you wish to check out locally what files will be changed. Then follow the steps below:

```bash
cd wp-content
svn checkout --depth immediates https://plugins.svn.wordpress.org/my-plugin-slug/ my-plugin-slug-svn
svn update --set-depth infinity my-plugin-slug-svn/trunk
rsync -av --exclude-from=my-plugin-slug/.distignore --delete --delete-excluded my-plugin-slug/ my-plugin-slug-svn/trunk/
```

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE)