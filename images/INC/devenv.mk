#TAG="devenv/$(NAME):$(VERSION)"
TAG="devenv/$(NAME)"

all: clean build finish

setup:
	-mkdir tmp
	cp ../../INC/scripts/* tmp
ifdef MY_UID
	echo "********** Set myid to $(MY_UID)"
	echo $(MY_UID) > tmp/myid
else
	id -u > tmp/myid
endif
ifdef MY_GID
	echo "********** Set myid to $(MY_GID)"
	echo $(MY_GID) > tmp/mygroup
else
#	id -g > tmp/mygroup
	echo "1000" > tmp/mygroup
endif

clean:
	-docker rmi -f $(TAG)
	-rm -rf tmp

build: setup
	docker build --rm=true --no-cache=true -t $(TAG) .

finish:
	-rm -rf tmp
