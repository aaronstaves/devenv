IMAGE=devenv/web_nginx
VERSION=1.0.0
TAG=$(IMAGE):$(VERSION)

all: clean build

clean:
	-docker rmi -f $(TAG)

build:
	docker build --rm=true --no-cache=true -t $(TAG) .
