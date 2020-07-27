# Rails docker template
A template I'm  using to set up docker development environment for a Rails application.

The template takes into account the use of MariaDB and Redis. It's not something
that works out of the box once cloned, but I do believe it's a good starting point.

## Description

I've created two Docker files, one for development and one for production.
The development one takes into account the fact that in a Linux environment Docker runs as a daemon with root permissions and takes ownership of your mounted folder.
To avoid this problem the container runs with a user that has the same group and user Id of the one on your development machine.

The production file is pretty straightforward and standard.

To easily build the image and run the containers I created a bash script that takes some input parameters and that you can find [here](scripts/build.sh)
