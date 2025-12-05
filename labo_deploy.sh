#!/usr/bin/env bash

VERSION=3.1.3

docker compose up db -d
docker buildx build --network=host --target=backend -t rg.fr-par.scw.cloud/labo-depot/recoco-backend:v$VERSION .
docker buildx build --network=host --target=frontend -t rg.fr-par.scw.cloud/labo-depot/recoco-frontend:v$VERSION .
docker push rg.fr-par.scw.cloud/labo-depot/recoco-backend:v$VERSION
docker push rg.fr-par.scw.cloud/labo-depot/recoco-frontend:v$VERSION
