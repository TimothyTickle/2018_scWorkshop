#!/bin/sh

set -ev

VERSION=`cat VERSION.txt`

docker build -t trinityctat/scellbern2018:$VERSION .
docker build -t trinityctat/scellbern2018:latest .

