# devenv
So the goal of this project is to make a Linux enviroment on my Mac to develop Linux based web apps. Got sick of having a Linux box running 24x7 in the basement ( full of spiders ) that required a VPN tunnel if I wanted to develop outside of my house. And the fact I have 8 cores on my MacBook Pro and I'm using like one when developing.

So I wanted to make a way to quickly provision virtual machines that contained dockers. And an enviroment I can add and remove dockers quickly.

So this is that project. The real goal was to get something working so I could program other projects. So this project, while it works, needs a little more documentation, and a bit more functionality. It's not designed to be overly complicated.

# setup

    git clone git@github.com:jwalstra/devenv.git

    # Either command line or in .bashrc or .profile
    eval $(/path/to/devenv/bin/devenv init)

    # At this point, DEVENV based vars should exists in your environment
    
    # Got custom images or configs?
    export DEVENV_CONFIG_DIR=/Users/me/custom/config
    export DEVENV_IMAGE_DIR=/Users/me/custom/images

	# Optional. Allows containers to get hosts information from Host OS
	devenv helper --start

	# Build an environment called myvm
	devenv vm --start -i myvm -c default.yml

	# What's running
	devenv vm --status

	# SSH into the docker inside of the VM
	ssh -p 22222 dev@myvm.local
	#(passowrd dev)

	# Shut it down
	devenv vm --stop -i myvm
