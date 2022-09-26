# WordPress.org Plugin Deploy Action
Github Action to deploy a WordPress plugin to the WordPress.org plugin repository.

## Requirements
There are secrets required for this action to work. You can set them in your repository's settings under `Settings > Secrets`.
- `SVN_USERNAME` - Your WordPress.org username.
- `SVN_PASSWORD` - Your WordPress.org password.

## Usage
```yaml
- name: Deploy to WordPress.org
  uses: sultann/action-plugin-deploy@master
  with:
    svn_username: ${{ secrets.SVN_USERNAME }}
    svn_password: ${{ secrets.SVN_PASSWORD }}
    svn_slug: 'my-plugin-slug' # Remove this if GitHub repo name matches SVN slug
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
            uses: sultann/action-plugin-deploy@master
            with:
            svn_username: ${{ secrets.SVN_USERNAME }}
            svn_password: ${{ secrets.SVN_PASSWORD }}
            svn_slug: 'my-plugin-slug' # Remove this if GitHub repo name matches SVN slug
```
This will deploy your plugin to WordPress.org when you push a new tag to your repository.

## Excluding files from deployment
If you want to exclude certain files from being deployed to WordPress.org, you can add a `.distignore` file to your repository. This file should contain a list of files and directories to exclude, one per line. For example:
```
.git
.github
.gitignore
.travis.yml
```
By default, the action will exclude the [following](https://github.com/sultann/action-plugin-deploy/.defaultignore) files and directories.

## Inputs
- `svn_username` - Your WordPress.org username.
- `svn_password` - Your WordPress.org password.
- `svn_slug` - The slug of your plugin on WordPress.org. This is optional if your GitHub repository name matches the WordPress.org slug.
- `working_dir` - The directory where your plugin is located. This is optional if your plugin is located in the root of your repository.
- `version` - The release version of your plugin. This is optional by default the action will use the tag name as the version if it's a valid version number. Otherwise, it will use the version from plugin main file.
- `dry_run` - Whether to run the action in dry run mode. This is optional and defaults to `false`. If set to `true`, the action will not deploy to WordPress.org, instead outputs the files that would be deployed.

## Output
- `svn_path` - The path to the folder where the svn checkout is located.
- `version` - Version number of the release, that is being used for deployment.


## Debugging
If you want to see what files will be changed in the WordPress.org repository, you can run the action in dry run mode. To do this, add the following to your workflow file:
```yaml
- name: Deploy to WordPress.org
  uses: sultann/action-plugin-deploy@master
  with:
    svn_username: ${{ secrets.SVN_USERNAME }}
    svn_password: ${{ secrets.SVN_PASSWORD }}
    svn_slug: 'my-plugin-slug' # Remove this if GitHub repo name matches SVN slug
    dry_run: true
```
This will output the files that would be changed in the WordPress.org repository. Once you are satisfied with the output, you can remove the `dry_run` input.

If you wish to check out locally what files will be changed. Then follow the steps below:
```bash
cd wp-content
svn checkout --depth immediates https://plugins.svn.wordpress.org/my-plugin-slug/ my-plugin-slug-svn
svn update --set-depth infinity my-plugin-slug-svn/trunk
rsync -av --exclude-from=my-plugin-slug/.distignore --delete --delete-excluded my-plugin-slug/ my-plugin-slug-svn/trunk/
```

## License
The scripts and documentation in this project are released under the [MIT License](LICENSE)