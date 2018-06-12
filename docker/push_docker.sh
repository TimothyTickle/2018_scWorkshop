#!/bin/sh

set -ev

VERSION=`cat VERSION.txt`

docker push trinityctat/scellbern2018:${VERSION}
docker push trinityctat/scellbern2018:latest
