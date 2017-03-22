# v1.1.2

- Reverted Yet Another Docker Plugin to version 0.1.0-rc30 until a solution to [this problem](https://github.com/KostyaSha/yet-another-docker-plugin/issues/136) has been addressed.
- Changed plugins.txt to include the latest plugins on installation (except Yet Another Docker Plugin which is set to v0.1.0-rc30).
- Updated documentation to include information on accessing the Yet Another Docker Plugin release archives.

# v1.1.1

- Updated main documentation to refine step for resolving a plugin problem.
- Included Yet Another Docker Plugin version 0.1.0-rc31 install file for manual installation.
- Removed unneeded altered plugin file.

# v1.1.0

- Bumped Jenkins version to 2.32.3-alpine.
- Bumped NGINX version to 1.11.10-alpine.
- Updated docker-compose.yml to use version 3.
- Optimized Jenkins Slave Dockerfile.
- Removed copying of SSL files into image ([see this article](https://developer.atlassian.com/blog/2016/06/common-dockerfile-mistakes/)). Please review updated README.md.
- Removed dummy SSL files.
- Changed volume mapping for SSL files.
- Updated .gitignore and .dockerignore to account for SSL file changes.
- Updated plugins file used to install default plugins on image build.
- Fixed problem with makefile not working due to missing indents.
- Removed main NGINX volume as it's not needed.
- Added cloud-stats 0.8 to plugins.txt since latest Yet Another Docker Plugin requires it.
- Added a version of `yet-another-docker-plugin.jar` which fixes the [problem described here](https://github.com/KostyaSha/yet-another-docker-plugin/issues/132). Please review updated README.md.
- Updated relevant documentation.

# v1.0.0

- Initial release
